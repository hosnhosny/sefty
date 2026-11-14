// lib/services/pb_service.dart
// يحل محل database_service.dart / firestore_service.dart القديمة بالكامل
// (PocketBase بدل Supabase/Firestore)

import 'dart:async';
import 'package:pocketbase/pocketbase.dart';
import '../main.dart'; // العميل العام pb
import '../models/violation_model.dart';
import '../models/leave_model.dart';
import '../models/report_model.dart';
import '../models/user_model.dart';

class DatabaseService {
  // ───────────────────────────────────────────────
  // مساعد عام: يحوّل مجموعة PocketBase إلى Stream<List<T>>
  // (يجلب القائمة الحالية، ثم يشترك بالتحديثات اللحظية realtime)
  // ───────────────────────────────────────────────
  Stream<List<T>> _watchCollection<T>({
    required String collection,
    required T Function(RecordModel) fromRecord,
    String? filter,
    String sort = '-created',
  }) {
    late StreamController<List<T>> controller;
    UnsubscribeFunc? unsubscribe;

    Future<void> fetchAndEmit() async {
      try {
        final records = await pb.collection(collection).getFullList(
          filter: filter,
          sort: sort,
        );
        if (!controller.isClosed) {
          controller.add(records.map(fromRecord).toList());
        }
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    controller = StreamController<List<T>>.broadcast(
      onListen: () async {
        await fetchAndEmit();
        try {
          unsubscribe = await pb.collection(collection).subscribe(
            '*',
                (e) => fetchAndEmit(),
          );
        } catch (e) {
          // لا نكسر الشاشة إذا فشل الاشتراك اللحظي (مثلاً: تعارض توثيق
          // 403 عند فتح عدة اشتراكات دفعة واحدة عقب تسجيل الدخول، أو
          // 404 إن كانت المجموعة "$collection" غير موجودة في PocketBase).
          // البيانات تبقى تُعرض من fetchAndEmit، لكن دون تحديث لحظي.
          // ignore: avoid_print
          print('Realtime subscribe failed for "$collection": $e');
        }
      },
      onCancel: () async {
        if (unsubscribe != null) await unsubscribe!();
      },
    );

    return controller.stream;
  }

  // ───────────────────────────────────────────────
  // VIOLATIONS
  // ───────────────────────────────────────────────

  Future<String> getNextViolationNumber() async {
    final year = DateTime.now().year;
    try {
      final result = await pb.collection('violations').getList(
        page: 1,
        perPage: 1,
        filter: pb.filter(
          'violation_number >= {:from} && violation_number < {:to}',
          {'from': 'V-$year-', 'to': 'V-${year + 1}-'},
        ),
        sort: '-violation_number',
      );

      if (result.items.isEmpty) {
        return 'V-$year-0001';
      }

      final lastNumber = result.items.first.data['violation_number'] as String;
      final lastId = int.parse(lastNumber.split('-').last);
      return 'V-$year-${(lastId + 1).toString().padLeft(4, '0')}';
    } catch (_) {
      return 'V-$year-0001';
    }
  }

  /// يحفظ المخالفة، ولو تعارض رقم المخالفة مع مخالفة أخرى (بسبب تزامن
  /// طلبين في نفس اللحظة) يولّد رقماً جديداً ويعيد المحاولة تلقائياً.
  /// يتطلب تفعيل خاصية "Unique" على حقل violation_number في PocketBase.
  /// يُعيد الـ RecordModel الفعلي المحفوظ (وليس مجرد id) حتى تقدر الشاشة
  /// تقرأ منه الرقم النهائي وعدد الإنذارات الفعلي بعد أي إعادة محاولة.
  Future<RecordModel> addViolation(
      ViolationModel violation, {
        int maxRetries = 3,
      }) async {
    var current = violation;

    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        // نعيد جلب عدد المخالفات الحالي للموظف قبل كل محاولة حفظ
        // (يقلّل نافذة التزامن على warningCount أيضاً)
        final freshCount = await getEmployeeViolationCount(current.employeeId);
        current = current.copyWith(warningCount: freshCount + 1);

        final record = await pb
            .collection('violations')
            .create(body: current.toMap());
        return record;
      } on ClientException catch (e) {
        final isDuplicate = e.statusCode == 400 &&
            e.response['data']?['violation_number'] != null;

        if (isDuplicate && attempt < maxRetries) {
          // رقم مكرر بسبب التزامن: نولّد رقماً جديداً ونعيد المحاولة
          final newNumber = await getNextViolationNumber();
          current = current.copyWith(violationNumber: newNumber);
          continue;
        }
        rethrow;
      }
    }

    throw Exception('تعذر حفظ المخالفة بعد عدة محاولات');
  }

  Future<void> updateViolation(String id, Map<String, dynamic> data) async {
    await pb.collection('violations').update(id, body: data);
  }

  Future<void> markViolationAsExported(String id) async {
    await pb.collection('violations').update(id, body: {
      'exported_to_excel': true,
      'excel_export_date': DateTime.now().toIso8601String(),
    });
  }

  Stream<List<ViolationModel>> getAllViolations() {
    return _watchCollection(
      collection: 'violations',
      fromRecord: ViolationModel.fromRecord,
      sort: '-created',
    );
  }

  /// جلب فوري (مرة واحدة، بدون اشتراك لحظي) لكل المخالفات — يُستخدم لتحديث
  /// الشاشة فوراً بعد أي عملية (قبول/رفض/إغلاق) دون انتظار الـ realtime.
  Future<List<ViolationModel>> getAllViolationsOnce() async {
    final records = await pb.collection('violations').getFullList(
      sort: '-created',
    );
    return records.map(ViolationModel.fromRecord).toList();
  }

  Stream<List<ViolationModel>> getViolationsBySecurityOfficer(
      String officerId) {
    return _watchCollection(
      collection: 'violations',
      fromRecord: ViolationModel.fromRecord,
      filter: pb.filter('security_officer_id = {:id}', {'id': officerId}),
    );
  }

  Stream<List<ViolationModel>> getViolationsByEmployee(String employeeId) {
    return _watchCollection(
      collection: 'violations',
      fromRecord: ViolationModel.fromRecord,
      filter: pb.filter('employee_id = {:id}', {'id': employeeId}),
    );
  }

  Future<int> getEmployeeViolationCount(String employeeId) async {
    final result = await pb.collection('violations').getList(
      page: 1,
      perPage: 1,
      filter: pb.filter('employee_id = {:id}', {'id': employeeId}),
    );
    return result.totalItems;
  }

  Future<int> getEmployeeWarningCount(String employeeId) async {
    final records = await pb.collection('violations').getFullList(
      filter: pb.filter(
        'employee_id = {:id} && warning_count >= 1',
        {'id': employeeId},
      ),
    );
    int total = 0;
    for (final r in records) {
      total += (r.data['warning_count'] ?? 0) as int;
    }
    return total;
  }

  Future<List<ViolationModel>> getUnexportedViolations() async {
    final records = await pb.collection('violations').getFullList(
      filter: 'exported_to_excel = false',
      sort: 'created',
    );
    return records.map(ViolationModel.fromRecord).toList();
  }

  // ───────────────────────────────────────────────
  // LEAVES
  // ───────────────────────────────────────────────

  Future<String> getNextLeaveNumber() async {
    final year = DateTime.now().year;
    try {
      final result = await pb.collection('leaves').getList(
        page: 1,
        perPage: 1,
        filter: pb.filter(
          'leave_number >= {:from} && leave_number < {:to}',
          {'from': 'L-$year-', 'to': 'L-${year + 1}-'},
        ),
        sort: '-leave_number',
      );

      if (result.items.isEmpty) {
        return 'L-$year-0001';
      }

      final lastNumber = result.items.first.data['leave_number'] as String;
      final lastId = int.parse(lastNumber.split('-').last);
      return 'L-$year-${(lastId + 1).toString().padLeft(4, '0')}';
    } catch (_) {
      return 'L-$year-0001';
    }
  }

  /// يتحقق إذا كان الرقم التسلسلي للإيصال الورقي مستخدماً من قبل في أي
  /// إذن انصراف سابق. يُستخدم لعرض تنبيه فوري للموظف الأمني أثناء الكتابة،
  /// وكذلك كتحقق أخير قبل الحفظ مباشرة. الحماية النهائية والمضمونة 100%
  /// تبقى قيد "Unique" على حقل receipt_number داخل PocketBase نفسه (لتغطية
  /// حالة إرسال طلبين في نفس اللحظة بالضبط).
  Future<bool> isReceiptNumberUsed(String receiptNumber) async {
    final trimmed = receiptNumber.trim();
    if (trimmed.isEmpty) return false;
    try {
      final result = await pb.collection('leaves').getList(
        page: 1,
        perPage: 1,
        filter: pb.filter(
          'receipt_number = {:num}',
          {'num': trimmed},
        ),
      );
      return result.items.isNotEmpty;
    } catch (_) {
      // في حال فشل الاتصال لا نمنع المستخدم بناءً على خطأ شبكة عابر،
      // لكن قيد Unique بقاعدة البيانات يبقى خط الدفاع الأخير.
      return false;
    }
  }

  /// يُعيد الـ RecordModel الفعلي المحفوظ حتى تقدر الشاشة تقرأ منه الرقم
  /// النهائي بعد أي إعادة محاولة بسبب تعارض في leave_number.
  /// إذا كان تعارض الحفظ بسبب receipt_number مكرر (إيصال مستخدم من قبل)،
  /// لا نعيد المحاولة تلقائياً (لأنه رقم مطبوع فعلياً على ورقة ولا يصح
  /// توليد بديل له)، بل نرمي استثناء واضح تعرضه الشاشة للمستخدم مباشرة.
  Future<RecordModel> addLeave(LeaveModel leave, {int maxRetries = 3}) async {
    var current = leave;

    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final record =
        await pb.collection('leaves').create(body: current.toMap());
        return record;
      } on ClientException catch (e) {
        final isDuplicateReceipt = e.statusCode == 400 &&
            e.response['data']?['receipt_number'] != null;

        if (isDuplicateReceipt) {
          throw Exception('⚠️ هذا الرقم التسلسلي للإيصال مستخدم من قبل مسبقاً');
        }

        final isDuplicateLeaveNumber = e.statusCode == 400 &&
            e.response['data']?['leave_number'] != null;

        if (isDuplicateLeaveNumber && attempt < maxRetries) {
          final newNumber = await getNextLeaveNumber();
          current = current.copyWith(leaveNumber: newNumber);
          continue;
        }
        rethrow;
      }
    }

    throw Exception('تعذر حفظ إذن الانصراف بعد عدة محاولات');
  }

  Future<void> updateLeaveReturn(String leaveId, DateTime returnTime) async {
    final record = await pb.collection('leaves').getOne(leaveId);
    final expectedReturn = DateTime.parse(record.data['expected_return']);
    final isLate = returnTime.isAfter(expectedReturn);

    await pb.collection('leaves').update(leaveId, body: {
      'actual_return': returnTime.toIso8601String(),
      'status': isLate ? 'late' : 'returned',
    });
  }

  Future<void> markLeaveAsNoReturn(String leaveId) async {
    await pb.collection('leaves').update(leaveId, body: {'status': 'noReturn'});
  }

  Stream<List<LeaveModel>> getAllLeaves() {
    return _watchCollection(
      collection: 'leaves',
      fromRecord: LeaveModel.fromRecord,
      sort: '-created',
    );
  }

  Stream<List<LeaveModel>> getActiveLeaves() {
    return _watchCollection(
      collection: 'leaves',
      fromRecord: LeaveModel.fromRecord,
      filter: '(status = "active" || status = "late")',
      sort: '-exit_time',
    );
  }

  Stream<List<LeaveModel>> getLeavesBySecurityOfficer(String officerId) {
    return _watchCollection(
      collection: 'leaves',
      fromRecord: LeaveModel.fromRecord,
      filter: pb.filter('requested_by_id = {:id}', {'id': officerId}),
    );
  }

  Stream<List<LeaveModel>> getLeavesByEmployee(String employeeId) {
    return _watchCollection(
      collection: 'leaves',
      fromRecord: LeaveModel.fromRecord,
      filter: pb.filter('employee_id = {:id}', {'id': employeeId}),
    );
  }

  // ───────────────────────────────────────────────
  // REPORTS
  // ───────────────────────────────────────────────

  Future<String> getNextReportNumber() async {
    final year = DateTime.now().year;
    try {
      final result = await pb.collection('reports').getList(
        page: 1,
        perPage: 1,
        filter: pb.filter(
          'report_number >= {:from} && report_number < {:to}',
          {'from': 'R-$year-', 'to': 'R-${year + 1}-'},
        ),
        sort: '-report_number',
      );

      if (result.items.isEmpty) {
        return 'R-$year-0001';
      }

      final lastNumber = result.items.first.data['report_number'] as String;
      final lastId = int.parse(lastNumber.split('-').last);
      return 'R-$year-${(lastId + 1).toString().padLeft(4, '0')}';
    } catch (_) {
      return 'R-$year-0001';
    }
  }

  /// يُعيد الـ RecordModel الفعلي المحفوظ حتى تقدر الشاشة تقرأ منه الرقم
  /// النهائي بعد أي إعادة محاولة بسبب تعارض في report_number.
  Future<RecordModel> addReport(ReportModel report, {int maxRetries = 3}) async {
    var current = report;

    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final record =
        await pb.collection('reports').create(body: current.toMap());
        return record;
      } on ClientException catch (e) {
        final isDuplicate = e.statusCode == 400 &&
            e.response['data']?['report_number'] != null;

        if (isDuplicate && attempt < maxRetries) {
          final newNumber = await getNextReportNumber();
          current = current.copyWith(reportNumber: newNumber);
          continue;
        }
        rethrow;
      }
    }

    throw Exception('تعذر حفظ التقرير بعد عدة محاولات');
  }

  Future<void> updateReportStatus(
      String reportId,
      String status, {
        String? comment,
      }) async {
    final data = <String, dynamic>{
      'status': status,
      'reviewed_at': DateTime.now().toIso8601String(),
    };
    if (comment != null) data['manager_comment'] = comment;
    await pb.collection('reports').update(reportId, body: data);
  }

  Stream<List<ReportModel>> getAllReports() {
    return _watchCollection(
      collection: 'reports',
      fromRecord: ReportModel.fromRecord,
      sort: '-created',
    );
  }

  Stream<List<ReportModel>> getReportsByStatus(String status) {
    return _watchCollection(
      collection: 'reports',
      fromRecord: ReportModel.fromRecord,
      filter: pb.filter('status = {:status}', {'status': status}),
    );
  }

  Stream<List<ReportModel>> getReportsBySecurityOfficer(String officerId) {
    return _watchCollection(
      collection: 'reports',
      fromRecord: ReportModel.fromRecord,
      filter: pb.filter('created_by_id = {:id}', {'id': officerId}),
    );
  }

  // ───────────────────────────────────────────────
  // EMPLOYEES
  // ───────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> getAllEmployees() {
    return _watchCollection<Map<String, dynamic>>(
      collection: 'employees',
      fromRecord: (r) => {'uid': r.id, ...r.data},
      filter: 'is_active = true',
      sort: 'name',
    );
  }

  Future<List<Map<String, dynamic>>> searchEmployees(String query) async {
    if (query.isEmpty) return [];

    final records = await pb.collection('employees').getFullList(
      filter: 'is_active = true',
    );

    final lowerQuery = query.toLowerCase();

    return records
        .where((r) {
      final name = (r.data['name'] ?? '').toString().toLowerCase();
      final empId = (r.data['employee_id'] ?? '').toString().toLowerCase();
      final dept = (r.data['department'] ?? '').toString().toLowerCase();
      return name.contains(lowerQuery) ||
          empId.contains(lowerQuery) ||
          dept.contains(lowerQuery);
    })
        .map((r) => {'uid': r.id, ...r.data})
        .toList();
  }

  Future<Map<String, dynamic>?> getEmployeeById(String employeeId) async {
    try {
      final record = await pb.collection('employees').getFirstListItem(
        pb.filter('employee_id = {:id}', {'id': employeeId}),
      );
      return {'uid': record.id, ...record.data};
    } catch (e) {
      return null; // لا يوجد موظف بهذا الرقم
    }
  }

  /// كل الموظفين (نشط وغير نشط) — لاستخدام لوحة تحكم المدير
  Stream<List<Map<String, dynamic>>> getAllEmployeesAdmin() {
    return _watchCollection<Map<String, dynamic>>(
      collection: 'employees',
      fromRecord: (r) => {'uid': r.id, ...r.data},
      sort: 'name',
    );
  }

  /// إضافة موظف جديد يعمل في المصنع (لا يملك حساب دخول، فقط سجل بيانات)
  Future<RecordModel> addEmployee({
    required String name,
    required String employeeId,
    required String department,
  }) async {
    return await pb.collection('employees').create(body: {
      'name': name,
      'employee_id': employeeId,
      'department': department,
      'is_active': true,
    });
  }

  /// تعديل بيانات موظف
  Future<void> updateEmployee(String id, Map<String, dynamic> data) async {
    await pb.collection('employees').update(id, body: data);
  }

  /// حذف موظف نهائياً
  Future<void> deleteEmployee(String id) async {
    await pb.collection('employees').delete(id);
  }

  // ───────────────────────────────────────────────
  // USERS (رجال الأمن والمدراء) — لوحة تحكم المدير
  // ───────────────────────────────────────────────

  /// كل المستخدمين حسب الدور (admin أو security أو camera)
  Stream<List<UserModel>> getUsersByRole(String role) {
    return _watchCollection<UserModel>(
      collection: 'users',
      fromRecord: UserModel.fromRecord,
      filter: pb.filter('role = {:role}', {'role': role}),
      sort: 'name',
    );
  }

  /// إنشاء مستخدم جديد (رجل أمن أو مدير أو رجل كاميرات) بحساب دخول كامل
  Future<RecordModel> createUser({
    required String name,
    required String email,
    required String password,
    required String role,
    String? phone,
    String? department,
  }) async {
    return await pb.collection('users').create(body: {
      'name': name,
      'username': email.split('@')[0],
      'email': email,
      'emailVisibility': true,
      'password': password,
      'passwordConfirm': password,
      'role': role,
      'phone': phone,
      'department': department,
      'is_active': true,
      'points': 0,
      'wallet_balance': 0.0,
    });
  }

  /// تعديل بيانات مستخدم (اسم، هاتف، قسم...) بدون المساس بكلمة السر
  Future<void> updateUser(String id, Map<String, dynamic> data) async {
    await pb.collection('users').update(id, body: data);
  }

  /// تفعيل/إيقاف خدمة مستخدم (رجل أمن مثلاً) دون حذف حسابه
  Future<void> setUserActive(String id, bool active) async {
    await pb.collection('users').update(id, body: {'is_active': active});
  }

  /// حذف مستخدم نهائياً
  Future<void> deleteUser(String id) async {
    await pb.collection('users').delete(id);
  }

  // ───────────────────────────────────────────────
  // STATS & ANALYTICS
  // ───────────────────────────────────────────────

  Future<Map<String, dynamic>> getDashboardStats() async {
    final violations = await pb.collection('violations').getFullList();
    final reports = await pb.collection('reports').getFullList();
    final leaves = await pb.collection('leaves').getFullList();

    int totalViolations = violations.length;
    int light = 0, medium = 0, major = 0, critical = 0;
    int redAlerts = 0;
    int pendingReports = 0;
    int activeLeaves = 0;

    for (final r in violations) {
      switch (r.data['severity']) {
        case 'light':
          light++;
          break;
        case 'medium':
          medium++;
          break;
        case 'major':
          major++;
          break;
        case 'critical':
          critical++;
          break;
      }
      final warningCount = r.data['warning_count'] ?? 0;
      if (warningCount >= 3) redAlerts++;
    }

    for (final r in reports) {
      if (r.data['status'] == 'pending') pendingReports++;
    }

    for (final r in leaves) {
      final status = r.data['status'];
      if (status == 'active' || status == 'late') activeLeaves++;
    }

    return {
      'totalViolations': totalViolations,
      'light': light,
      'medium': medium,
      'major': major,
      'critical': critical,
      'redAlerts': redAlerts,
      'pendingReports': pendingReports,
      'activeLeaves': activeLeaves,
    };
  }

  // ───────────────────────────────────────────────
  // BATCH OPERATIONS
  // (PocketBase لا يدعم bulk update حقيقي، لذلك نكرر الطلب لكل عنصر)
  // ───────────────────────────────────────────────

  Future<void> batchMarkAsExported(List<String> violationIds) async {
    final now = DateTime.now().toIso8601String();
    await Future.wait(violationIds.map((id) => pb.collection('violations').update(
      id,
      body: {'exported_to_excel': true, 'excel_export_date': now},
    )));
  }

  // ───────────────────────────────────────────────
  // REVIEW SYSTEM
  // ───────────────────────────────────────────────

  Future<void> sendToReview(String id, String managerComment) async {
    await pb.collection('violations').update(id, body: {
      'status': 'inProgress',
      'manager_comment': managerComment,
      'reviewed_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> uploadFixImage(String id, String fixImageUrl) async {
    await pb.collection('violations').update(id, body: {
      'status': 'awaitingVerify',
      'fix_image_url': fixImageUrl,
    });
  }

  Future<void> closeViolation(String id) async {
    await pb.collection('violations').update(id, body: {
      'status': 'closed',
      'closed_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> rejectFix(String id, String reason) async {
    await pb.collection('violations').update(id, body: {
      'status': 'rejected',
      'manager_comment': reason,
    });
  }

  Stream<List<ViolationModel>> getViolationsForReview() {
    return _watchCollection(
      collection: 'violations',
      fromRecord: ViolationModel.fromRecord,
      filter: '(severity = "major" || severity = "critical") && '
          '(status = "newViolation" || status = "inProgress" || '
          'status = "awaitingVerify" || status = "rejected")',
      sort: '-created',
    );
  }

  Stream<List<ViolationModel>> getMyViolationsForFollowUp(String officerId) {
    return _watchCollection(
      collection: 'violations',
      fromRecord: ViolationModel.fromRecord,
      filter: pb.filter(
        'security_officer_id = {:id} && (status = "inProgress" || status = "rejected")',
        {'id': officerId},
      ),
      sort: '-created',
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // رجال الكاميرات + القبول المالي للمخالفة + المحافظ
  // (فكرة: كل مخالفة يقبلها المدير بمبلغ خصم يُقسَّم 50% لرجل الأمن
  //  و50% لرجل الكاميرات المساعد الذي اختاره رجل الأمن عند التسجيل)
  // ═══════════════════════════════════════════════════════════════

  /// كل رجال الكاميرات النشطين — لاستخدامها في قائمة الاختيار عند تسجيل مخالفة
  Stream<List<UserModel>> getCameraOfficers() {
    return _watchCollection<UserModel>(
      collection: 'users',
      fromRecord: UserModel.fromRecord,
      filter: 'role = "camera"',
      sort: 'name',
    );
  }

  /// المخالفات التي بانتظار قرار المدير المالي (لم تُقبل ولم تُرفض بعد)
  Stream<List<ViolationModel>> getViolationsPendingFineApproval() {
    return _watchCollection<ViolationModel>(
      collection: 'violations',
      fromRecord: ViolationModel.fromRecord,
      filter: 'fine_approved_at = "" && status != "rejected"',
      sort: '-created',
    );
  }

  /// المدير يقبل المخالفة ويحدد قيمة الخصم — يُقسَّم المبلغ 50/50 تلقائيًا
  /// بين رجل الأمن ورجل الكاميرات (أو 100% لرجل الأمن إن لم يوجد رجل كاميرات).
  /// محمي من التكرار عبر التحقق من wallet_credited قبل أي إيداع.
  Future<void> approveFineAndCreditWallet({
    required String violationId,
    required double fineAmount,
    required String securityOfficerId,
    String? cameraOfficerId,
    String? managerComment,
  }) async {
    // إعادة قراءة السجل من السيرفر لتفادي إيداع مزدوج لو تم القبول مسبقًا
    final current = await pb.collection('violations').getOne(violationId);
    if (current.data['wallet_credited'] == true) {
      throw Exception('تم قبول هذه المخالفة وصرف قيمتها مسبقًا');
    }

    await pb.collection('violations').update(violationId, body: {
      'fine_amount': fineAmount,
      'fine_approved_at': DateTime.now().toIso8601String(),
      'manager_comment': managerComment,
      'wallet_credited': fineAmount > 0,
    });

    if (fineAmount <= 0) return;

    final hasCamera = cameraOfficerId != null && cameraOfficerId.isNotEmpty;
    final securityShare = hasCamera ? fineAmount / 2 : fineAmount;

    final secUser = await pb.collection('users').getOne(securityOfficerId);
    final secBalance = (secUser.data['wallet_balance'] ?? 0).toDouble();
    await pb.collection('users').update(securityOfficerId, body: {
      'wallet_balance': secBalance + securityShare,
    });

    if (hasCamera) {
      final camUser = await pb.collection('users').getOne(cameraOfficerId);
      final camBalance = (camUser.data['wallet_balance'] ?? 0).toDouble();
      await pb.collection('users').update(cameraOfficerId, body: {
        'wallet_balance': camBalance + (fineAmount / 2),
      });
    }
  }

  /// المدير يرفض المخالفة ماليًا (لا خصم ولا إيداع)
  Future<void> rejectFineApproval(String violationId, String reason) async {
    await pb.collection('violations').update(violationId, body: {
      'status': 'rejected',
      'fine_approved_at': DateTime.now().toIso8601String(),
      'manager_comment': reason,
    });
  }

  /// تصفير محافظ كل رجال الأمن والكاميرات يدويًا (نهاية الشهر)
  Future<void> resetAllWallets() async {
    final users = await pb.collection('users').getFullList(
      filter: 'role = "security" || role = "camera"',
    );
    for (final user in users) {
      final balance = (user.data['wallet_balance'] ?? 0).toDouble();
      if (balance != 0) {
        await pb.collection('users').update(user.id, body: {
          'wallet_balance': 0.0,
        });
      }
    }
  }

  /// إجمالي الخصومات المستحقة على كل موظف مصنع (من المخالفات المقبولة ماليًا)
  Future<List<Map<String, dynamic>>> getEmployeeDeductionTotals() async {
    final records = await pb.collection('violations').getFullList(
      filter: 'fine_amount > 0',
    );
    final Map<String, Map<String, dynamic>> totals = {};
    for (final r in records) {
      final empId = r.data['employee_id'] ?? '';
      if (empId.isEmpty) continue;
      final fine = (r.data['fine_amount'] ?? 0).toDouble();
      totals.putIfAbsent(
        empId,
            () => {
          'employee_id': empId,
          'employee_name': r.data['employee_name'] ?? '',
          'employee_department': r.data['employee_department'] ?? '',
          'total_deduction': 0.0,
          'violations_count': 0,
        },
      );
      totals[empId]!['total_deduction'] =
          (totals[empId]!['total_deduction'] as double) + fine;
      totals[empId]!['violations_count'] =
          (totals[empId]!['violations_count'] as int) + 1;
    }
    final list = totals.values.toList();
    list.sort((a, b) => (b['total_deduction'] as double)
        .compareTo(a['total_deduction'] as double));
    return list;
  }

  // ───────────────────────────────────────────────
  // WALLETS (رجال الأمن والكاميرات)
  // ───────────────────────────────────────────────

  /// كل رجال الأمن والكاميرات مع رصيد محفظة كل واحد منهم، مرتّبين تنازليًا.
  Future<List<Map<String, dynamic>>> getStaffWallets() async {
    final records = await pb.collection('users').getFullList(
      filter: 'role = "security" || role = "camera"',
    );
    final list = records
        .map((r) => {
      'uid': r.id,
      'name': r.data['name'] ?? '',
      'role': r.data['role'] ?? '',
      'wallet_balance': (r.data['wallet_balance'] ?? 0).toDouble(),
    })
        .toList();
    list.sort((a, b) => (b['wallet_balance'] as double)
        .compareTo(a['wallet_balance'] as double));
    return list;
  }

  /// نسخة Stream من getStaffWallets تتحدّث تلقائيًا مع أي تغيير في users
  Stream<List<Map<String, dynamic>>> watchStaffWallets() {
    return _watchCollection<Map<String, dynamic>>(
      collection: 'users',
      fromRecord: (r) => {
        'uid': r.id,
        'name': r.data['name'] ?? '',
        'role': r.data['role'] ?? '',
        'wallet_balance': (r.data['wallet_balance'] ?? 0).toDouble(),
      },
      filter: 'role = "security" || role = "camera"',
    ).map((list) {
      final sorted = [...list];
      sorted.sort((a, b) => (b['wallet_balance'] as double)
          .compareTo(a['wallet_balance'] as double));
      return sorted;
    });
  }

  /// تصفير محفظة موظف واحد فقط (رجل أمن أو كاميرات)
  Future<void> resetSingleWallet(String userId) async {
    await pb.collection('users').update(userId, body: {
      'wallet_balance': 0.0,
    });
  }
}