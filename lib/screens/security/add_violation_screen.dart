// lib/screens/security/add_violation_screen.dart
// النسخة المحسّنة النهائية — تجمع أفضل ما في النسخ الثلاث

import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/violation_model.dart';
import '../../services/pb_service.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import '../../services/sheets_service.dart';
import '../../services/notification_service.dart';
import '../../utils/constants.dart';
import '../../utils/enums.dart';

class AddViolationScreen extends StatefulWidget {
  final UserModel currentUser;
  const AddViolationScreen({super.key, required this.currentUser});

  @override
  State<AddViolationScreen> createState() => _AddViolationScreenState();
}

class _AddViolationScreenState extends State<AddViolationScreen> {
  // ─── Services ───────────────────────────────────────────────────────
  final _formKey        = GlobalKey<FormState>();
  final _db             = DatabaseService();
  final _storage        = StorageService();
  final _notification = NotificationService();

  // ─── Controllers ────────────────────────────────────────────────────
  final _searchCtrl    = TextEditingController();
  final _customTypeCtrl = TextEditingController(); // حقل نوع مخالفة حر عند اختيار "أخرى"
  final _detailsCtrl   = TextEditingController();
  final _locationCtrl  = TextEditingController();

  // ─── Employee State ──────────────────────────────────────────────────
  Map<String, dynamic>?      _selectedEmployee;
  List<Map<String, dynamic>> _allEmployees       = [];
  List<Map<String, dynamic>> _filteredEmployees  = [];
  bool _loadingEmployees = true;
  bool _showDropdown     = false;

  // ─── Camera Officer State (رجل الكاميرات المساعد — اختياري) ─────────
  UserModel? _selectedCameraOfficer;
  List<UserModel> _cameraOfficers = [];
  bool _loadingCameraOfficers = true;

  /// موظفون إضافيون يشاركون نفس دليل وبيانات المخالفة، لكن كل واحد منهم
  /// يُسجَّل كسجل مخالفة منفصل خاص به (لا يوجد سجل واحد لأكثر من موظف).
  final List<Map<String, dynamic>> _additionalEmployees = [];

  // ─── Violation State ─────────────────────────────────────────────────
  String?          _selectedViolationType;
  bool             _isCustomType    = false; // يظهر الحقل الحر عند "أخرى"
  ViolationSeverity _selectedSeverity = ViolationSeverity.light;
  final List<File> _evidenceImages  = [];
  File?            _evidenceVideo; // فيديو دليل واحد اختياري
  int              _existingViolations = 0;

  // ─── Loading State ───────────────────────────────────────────────────
  bool   _isLoading   = false;
  bool   _isUploading = false;
  String _violationNumber = '';

  // ─── Init ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadViolationNumber();
    _loadEmployees();
    _loadCameraOfficers();
  }

  Future<void> _loadCameraOfficers() async {
    try {
      final list = await _db.getCameraOfficers().first;
      if (mounted) {
        setState(() {
          _cameraOfficers = list.where((u) => u.isActive).toList();
          _loadingCameraOfficers = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingCameraOfficers = false);
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // DATA LOADING
  // ════════════════════════════════════════════════════════════════════

  Future<void> _loadViolationNumber() async {
    final number = await _db.getNextViolationNumber();
    if (mounted) setState(() => _violationNumber = number);
  }

  /// تحميل كل الموظفين مرة واحدة — الفلترة تتم محلياً بدون أي طلب شبكة
  Future<void> _loadEmployees() async {
    try {
      final list = await _db.getAllEmployees().first;

      // ترتيب محلي
      list.sort((a, b) =>
          (a['name'] as String).compareTo(b['name'] as String));

      if (mounted) {
        setState(() {
          _allEmployees      = list;
          _filteredEmployees = list;
          _loadingEmployees  = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingEmployees = false);
        _showSnack('خطأ في تحميل الموظفين: $e', Colors.red);
      }
    }
  }

  Future<void> _loadEmployeeViolations(String uid) async {
    final count = await _db.getEmployeeViolationCount(uid);
    if (mounted) setState(() => _existingViolations = count);
  }

  // ════════════════════════════════════════════════════════════════════
  // EMPLOYEE SEARCH & SELECTION
  // ════════════════════════════════════════════════════════════════════

  void _filterEmployees(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filteredEmployees = q.isEmpty
          ? _allEmployees
          : _allEmployees.where((e) {
        return (e['name']        as String).toLowerCase().contains(q) ||
            (e['employee_id'] as String).toLowerCase().contains(q) ||
            (e['department']  as String).toLowerCase().contains(q);
      }).toList();
      _showDropdown = true;
    });
  }

  void _selectEmployee(Map<String, dynamic> emp) {
    setState(() {
      _selectedEmployee  = emp;
      _searchCtrl.text   = '${emp['name']}  •  ${emp['employee_id']}';
      _showDropdown      = false;
      _existingViolations = 0;
    });
    _loadEmployeeViolations(emp['uid'] as String);
  }

  void _clearEmployee() {
    setState(() {
      _selectedEmployee   = null;
      _existingViolations = 0;
      _showDropdown       = false;
    });
    _searchCtrl.clear();
    _filteredEmployees = _allEmployees;
  }

  // ════════════════════════════════════════════════════════════════════
  // ADDITIONAL EMPLOYEES (نفس الدليل والبيانات، سجل مستقل لكل موظف)
  // ════════════════════════════════════════════════════════════════════

  /// كل معرفات الموظفين المختارين حالياً (الأساسي + الإضافيون) لمنع التكرار
  Set<String> get _selectedEmployeeIds => {
    if (_selectedEmployee != null) _selectedEmployee!['uid'] as String,
    ..._additionalEmployees.map((e) => e['uid'] as String),
  };

  void _removeAdditionalEmployee(int index) {
    setState(() => _additionalEmployees.removeAt(index));
  }

  void _showAddEmployeeSheet() {
    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> results = _allEmployees
        .where((e) => !_selectedEmployeeIds.contains(e['uid'] as String))
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, sheetSetState) {
            void filter(String query) {
              final q = query.trim().toLowerCase();
              sheetSetState(() {
                results = _allEmployees.where((e) {
                  if (_selectedEmployeeIds.contains(e['uid'] as String)) {
                    return false;
                  }
                  if (q.isEmpty) return true;
                  return (e['name'] as String).toLowerCase().contains(q) ||
                      (e['employee_id'] as String).toLowerCase().contains(q) ||
                      (e['department'] as String).toLowerCase().contains(q);
                }).toList();
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16, right: 16, top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'إضافة موظف آخر لنفس المخالفة',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'سيتم إنشاء سجل مخالفة منفصل لهذا الموظف بنفس الدليل والبيانات',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: searchCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'ابحث باسم أو رقم الموظف...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: filter,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: results.isEmpty
                          ? const Center(
                        child: Text('لا توجد نتائج',
                            style: TextStyle(color: Colors.grey)),
                      )
                          : ListView.separated(
                        itemCount: results.length,
                        separatorBuilder: (_, _) =>
                        const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final emp = results[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue.shade100,
                              child: Text(
                                (emp['name'] as String).isNotEmpty
                                    ? (emp['name'] as String)[0]
                                    : '?',
                                style: TextStyle(
                                    color: Colors.blue.shade800,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(emp['name'] as String),
                            subtitle: Text(
                                '${emp['employee_id']}  •  ${emp['department']}'),
                            onTap: () {
                              setState(() => _additionalEmployees.add(emp));
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // IMAGES
  // ════════════════════════════════════════════════════════════════════

  Future<void> _pickFromCamera() async {
    if (_evidenceImages.length >= 5) {
      _showSnack('الحد الأقصى 5 صور', Colors.orange);
      return;
    }
    final file = await _storage.pickImageFromCamera();
    if (file != null && mounted) setState(() => _evidenceImages.add(file));
  }

  Future<void> _pickFromGallery() async {
    if (_evidenceImages.length >= 5) {
      _showSnack('الحد الأقصى 5 صور', Colors.orange);
      return;
    }
    final file = await _storage.pickImageFromGallery();
    if (file != null && mounted) setState(() => _evidenceImages.add(file));
  }

  void _removeImage(int index) =>
      setState(() => _evidenceImages.removeAt(index));

  Future<void> _pickVideoFromCamera() async {
    final file = await _storage.pickVideoFromCamera();
    if (file != null && mounted) setState(() => _evidenceVideo = file);
  }

  Future<void> _pickVideoFromGallery() async {
    final file = await _storage.pickVideoFromGallery();
    if (file != null && mounted) setState(() => _evidenceVideo = file);
  }

  void _removeVideo() => setState(() => _evidenceVideo = null);

  void _showVideoSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.videocam, color: Colors.green),
                title: const Text('تصوير فيديو بالكاميرا'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickVideoFromCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library, color: Colors.blue),
                title: const Text('اختيار فيديو من المعرض'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickVideoFromGallery();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // SUBMIT
  // ════════════════════════════════════════════════════════════════════

  Future<void> _submit() async {
    // 1) Form validation
    if (!_formKey.currentState!.validate()) return;

    // 2) Manual checks
    if (_selectedEmployee == null) {
      _showSnack('يجب اختيار موظف من القائمة', Colors.red);
      return;
    }
    if (_evidenceImages.isEmpty) {
      _showSnack('يجب إضافة صورة دليل واحدة على الأقل', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 3) Upload images
      setState(() => _isUploading = true);
      final urls = <String>[];
      for (int i = 0; i < _evidenceImages.length; i++) {
        final url = await _storage.uploadFile(
          _evidenceImages[i].path,
          'violations/$_violationNumber',
          'evidence_$i.jpg',
        );
        if (url != null && url.trim().isNotEmpty) urls.add(url);
      }

      // 3.b) Upload evidence video (إن وُجد)
      if (_evidenceVideo != null) {
        final videoUrl = await _storage.uploadFile(
          _evidenceVideo!.path,
          'violations/$_violationNumber',
          'evidence_video.mp4',
        );
        if (videoUrl != null && videoUrl.trim().isNotEmpty) urls.add(videoUrl);
      }
      setState(() => _isUploading = false);

      // 4) Determine violation type
      final String violationType = _isCustomType
          ? _customTypeCtrl.text.trim()
          : (_selectedViolationType ?? '');

      // 5) قائمة كل الموظفين المشمولين (الأساسي + الإضافيون)
      //    كل موظف سيحصل على سجل مخالفة مستقل خاص به، بنفس الدليل والبيانات
      final employeesToSubmit = [
        _selectedEmployee!,
        ..._additionalEmployees,
      ];

      final sheetsService = SheetsService();
      final List<Map<String, dynamic>> savedSummaries = [];
      String nextNumber = _violationNumber;

      for (final emp in employeesToSubmit) {
        // عدد المخالفات السابقة لهذا الموظف تحديداً
        final priorCount = await _db.getEmployeeViolationCount(
          emp['uid'] as String,
        );

        final violation = ViolationModel(
          violationNumber:       nextNumber,
          createdAt:             DateTime.now(),
          securityOfficerId:     widget.currentUser.uid,
          securityOfficerName:   widget.currentUser.name,
          cameraOfficerId:       _selectedCameraOfficer?.uid,
          cameraOfficerName:     _selectedCameraOfficer?.name,
          employeeId:            emp['employee_id'] as String,
          employeeName:          emp['name']         as String,
          employeeDepartment:    emp['department']   as String,
          customType:            violationType,
          severity:              _selectedSeverity,
          details:               _detailsCtrl.text.trim(),
          evidenceUrls:          urls,
          location:              _locationCtrl.text.trim(),
          warningCount:          priorCount + 1,
        );

        // 6) الحفظ في PocketBase (قد يولّد رقماً جديداً تلقائياً لو تعارض
        // بسبب التزامن، لذلك نقرأ القيم النهائية الفعلية من السجل المحفوظ)
        final savedRecord = await _db.addViolation(violation);
        final finalViolationNumber =
            savedRecord.data['violation_number'] ?? violation.violationNumber;
        final finalWarningCount =
        (savedRecord.data['warning_count'] ?? violation.warningCount) as int;

        final savedViolation = violation.copyWith(
          violationNumber: finalViolationNumber,
          warningCount: finalWarningCount,
        );

        // 7) إرسال تلقائي إلى Google Sheets
        await sheetsService.appendViolation(savedViolation);

        // 8) إشعار الإدارة بالمخالفة الجديدة
        await _notification.notifyNewViolation(savedViolation.employeeName);

        // 9) إشعار إنذار أحمر لو وصل الموظف 3 مخالفات أو أكثر
        if (finalWarningCount >= 3) {
          await _notification.notifyRedAlert(
            savedViolation.employeeName,
            savedViolation.employeeId,
          );
        }

        // 10) تحديث نقاط رجل الأمن عن كل مخالفة مسجَّلة
        await AuthService().addSecurityPoints(
          widget.currentUser.uid,
          _selectedSeverity.points,
        );

        savedSummaries.add({
          'name': savedViolation.employeeName,
          'number': finalViolationNumber,
          'warnings': finalWarningCount,
        });

        // رقم المخالفة التالي للموظف التالي في نفس عملية الحفظ
        nextNumber = await _db.getNextViolationNumber();
      }

      if (mounted) setState(() => _violationNumber = nextNumber);

      if (mounted) _showSuccessDialog(savedSummaries);
    } catch (e) {
      _showSnack('حدث خطأ: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // DIALOGS & HELPERS
  // ════════════════════════════════════════════════════════════════════

  void _showSuccessDialog(List<Map<String, dynamic>> savedSummaries) {
    final bool isMultiple = savedSummaries.length > 1;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle,
                    color: Colors.green, size: 56),
              ),
              const SizedBox(height: 16),
              Text(
                isMultiple ? 'تم تسجيل المخالفات' : 'تم تسجيل المخالفة',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // سجل مستقل لكل موظف: رقم مخالفته + عدد إنذاراته
              ...savedSummaries.map((s) {
                final warnings = s['warnings'] as int;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: warnings >= 3
                        ? Colors.red.shade50
                        : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: warnings >= 3
                        ? Border.all(color: Colors.red)
                        : null,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s['name'] as String,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              s['number'] as String,
                              style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5),
                            ),
                          ],
                        ),
                      ),
                      if (warnings >= 3)
                        const Icon(Icons.warning, color: Colors.red, size: 20)
                      else
                        Text('$warnings إنذار',
                            style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _resetForm();
                      },
                      child: const Text('مخالفة جديدة'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0)),
                      child: const Text('إنهاء',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _selectedEmployee     = null;
      _additionalEmployees.clear();
      _existingViolations   = 0;
      _showDropdown         = false;
      _selectedViolationType = null;
      _isCustomType         = false;
      _selectedSeverity     = ViolationSeverity.light;
      _evidenceImages.clear();
      _evidenceVideo        = null;
      _filteredEmployees    = _allEmployees;
    });
    _searchCtrl.clear();
    _customTypeCtrl.clear();
    _detailsCtrl.clear();
    _locationCtrl.clear();
    _loadViolationNumber();
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: GestureDetector(
        // إغلاق الـ dropdown عند الضغط خارجه
        onTap: () {
          if (_showDropdown) setState(() => _showDropdown = false);
          FocusScope.of(context).unfocus();
        },
        child: Scaffold(
          backgroundColor: Colors.grey.shade100,
          appBar: AppBar(
            title: Column(
              children: [
                const Text(
                  'تسجيل مخالفة',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  _violationNumber,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
            centerTitle: true,
          ),
          body: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Additional Employees Option (نفس الدليل والبيانات) ──
                  _sectionCard(
                    icon: Icons.group_add,
                    color: Colors.deepPurple,
                    title: 'إضافة موظفين آخرين لنفس المخالفة',
                    child: _buildAdditionalEmployeesSection(),
                  ),
                  const SizedBox(height: 16),

                  // ── Employee Section ─────────────────────────────
                  _sectionCard(
                    icon: Icons.person,
                    color: Colors.blue,
                    title: 'بيانات الموظف',
                    child: _buildEmployeeSection(),
                  ),
                  const SizedBox(height: 16),

                  // ── Camera Officer (اختياري) ─────────────────────
                  _sectionCard(
                    icon: Icons.videocam,
                    color: Colors.deepOrange,
                    title: 'رجل الكاميرات المساعد',
                    child: _buildCameraOfficerSection(),
                  ),
                  const SizedBox(height: 16),

                  // ── Violation Details ────────────────────────────
                  _sectionCard(
                    icon: Icons.warning_amber,
                    color: Colors.red,
                    title: 'تفاصيل المخالفة',
                    child: _buildViolationSection(),
                  ),
                  const SizedBox(height: 16),

                  // ── Evidence Photos ──────────────────────────────
                  _sectionCard(
                    icon: Icons.camera_alt,
                    color: Colors.green,
                    title: 'صور وفيديو الدليل (${_evidenceImages.length}/5'
                        '${_evidenceVideo != null ? ' + فيديو' : ''})',
                    child: _buildEvidenceSection(),
                  ),
                  const SizedBox(height: 24),

                  // ── Submit Button ────────────────────────────────
                  _buildSubmitButton(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // SECTION BUILDERS
  // ════════════════════════════════════════════════════════════════════

  Widget _buildCameraOfficerSection() {
    if (_loadingCameraOfficers) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      );
    }

    if (_cameraOfficers.isEmpty) {
      return Text(
        'لا يوجد رجال كاميرات مسجّلون حالياً — يمكن ترك هذا الحقل فارغاً',
        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
      );
    }

    // نطابق بالـ uid بدل مطابقة الكائن نفسه لتفادي مشاكل إعادة البناء
    UserModel? currentValue;
    if (_selectedCameraOfficer != null) {
      for (final u in _cameraOfficers) {
        if (u.uid == _selectedCameraOfficer!.uid) {
          currentValue = u;
          break;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'اختر رجل الكاميرات الذي شارك في رصد هذه المخالفة (اختياري) — '
              'سيحصل على نصف قيمة الخصم عند قبول المدير للمخالفة.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<UserModel>(
          initialValue: currentValue,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'رجل الكاميرات المساعد',
            prefixIcon: const Icon(Icons.videocam_outlined),
            border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          items: [
            const DropdownMenuItem<UserModel>(
              value: null,
              child: Text('بدون رجل كاميرات'),
            ),
            ..._cameraOfficers.map(
                  (u) => DropdownMenuItem<UserModel>(
                value: u,
                child: Text(u.name),
              ),
            ),
          ],
          onChanged: (val) => setState(() => _selectedCameraOfficer = val),
        ),
      ],
    );
  }

  Widget _buildAdditionalEmployeesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'كل موظف يُسجَّل كمخالفة مستقلة برقم خاص به، لكن بنفس نوع '
              'المخالفة والدليل والتفاصيل المدخلة أدناه.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        if (_additionalEmployees.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_additionalEmployees.length, (i) {
              final emp = _additionalEmployees[i];
              return Chip(
                avatar: const Icon(Icons.person, size: 16),
                label: Text(
                  '${emp['name']}  •  ${emp['employee_id']}',
                  style: const TextStyle(fontSize: 12),
                ),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => _removeAdditionalEmployee(i),
                backgroundColor: Colors.deepPurple.shade50,
              );
            }),
          ),
        ],
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _loadingEmployees ? null : _showAddEmployeeSheet,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('إضافة موظف آخر'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.deepPurple,
            side: const BorderSide(color: Colors.deepPurple),
          ),
        ),
      ],
    );
  }

  Widget _buildEmployeeSection() {
    if (_loadingEmployees) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      children: [
        // Search field
        TextFormField(
          controller: _searchCtrl,
          readOnly: _selectedEmployee != null,
          decoration: InputDecoration(
            labelText: 'ابحث باسم أو رقم الموظف *',
            hintText: 'اكتب للبحث...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _selectedEmployee != null
                ? IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'إلغاء الاختيار',
              onPressed: _clearEmployee,
            )
                : null,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          onTap: () => setState(() => _showDropdown = true),
          onChanged: (v) {
            _selectedEmployee = null; // إلغاء الاختيار عند الكتابة
            _filterEmployees(v);
          },
          validator: (_) =>
          _selectedEmployee == null ? 'يجب اختيار موظف من القائمة' : null,
        ),

        // Dropdown list
        if (_showDropdown && _selectedEmployee == null) ...[
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 240),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _filteredEmployees.isEmpty
                ? const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text('لا توجد نتائج',
                    style: TextStyle(color: Colors.grey)),
              ),
            )
                : ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _filteredEmployees.length,
              separatorBuilder: (_, _) =>
              const Divider(height: 1, indent: 56),
              itemBuilder: (ctx, i) {
                final emp = _filteredEmployees[i];
                final initials = (emp['name'] as String).isNotEmpty
                    ? (emp['name'] as String)
                    .trim()
                    .split(' ')
                    .take(2)
                    .map((w) => w[0])
                    .join()
                    : '?';
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 2),
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      initials,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),
                  title: Text(
                    emp['name'] as String,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    '${emp['employee_id']}  •  ${emp['department']}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () => _selectEmployee(emp),
                );
              },
            ),
          ),
        ],

        // Selected employee card
        if (_selectedEmployee != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.shade700,
                  child: Text(
                    (_selectedEmployee!['name'] as String)
                        .trim()
                        .split(' ')
                        .take(2)
                        .map((w) => w[0])
                        .join(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedEmployee!['name'] as String,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'رقم: ${_selectedEmployee!['employee_id']}',
                        style: TextStyle(
                            color: Colors.blue.shade700, fontSize: 13),
                      ),
                      Text(
                        'القسم: ${_selectedEmployee!['department']}',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle, color: Colors.blue),
              ],
            ),
          ),
        ],

        // Previous violations warning
        if (_existingViolations > 0) ...[
          const SizedBox(height: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _existingViolations >= 2
                  ? Colors.red.shade50
                  : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _existingViolations >= 2
                    ? Colors.red
                    : Colors.orange,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _existingViolations >= 2
                      ? Icons.warning
                      : Icons.info_outline,
                  color: _existingViolations >= 2
                      ? Colors.red
                      : Colors.orange,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'لدى هذا الموظف $_existingViolations مخالفة سابقة'
                        '${_existingViolations >= 2 ? ' — قد يستوجب إجراء تأديبي' : ''}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _existingViolations >= 2
                          ? Colors.red
                          : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildViolationSection() {
    return Column(
      children: [
        // Violation type dropdown
        DropdownButtonFormField<String>(
          initialValue: _selectedViolationType,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'نوع المخالفة *',
            prefixIcon: const Icon(Icons.category),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          items: [
            ...AppStrings.violationTypes.map(
                  (t) => DropdownMenuItem(
                value: t,
                child: Text(t, overflow: TextOverflow.ellipsis),
              ),
            ),
            // ✅ خيار "أخرى" لإدخال نوع مخالفة مخصص
            const DropdownMenuItem(
              value: '__custom__',
              child: Text('أخرى (اكتب يدوياً)'),
            ),
          ],
          onChanged: (v) => setState(() {
            _selectedViolationType = v;
            _isCustomType = v == '__custom__';
          }),
          validator: (v) =>
          v == null ? 'اختر نوع المخالفة' : null,
        ),

        // Custom type field (يظهر عند اختيار "أخرى")
        if (_isCustomType) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _customTypeCtrl,
            decoration: InputDecoration(
              labelText: 'اكتب نوع المخالفة *',
              hintText: 'مثال: عدم ارتداء قفازات واقية',
              prefixIcon: const Icon(Icons.edit_note),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            validator: (v) => _isCustomType && (v == null || v.trim().isEmpty)
                ? 'اكتب نوع المخالفة'
                : null,
          ),
        ],
        const SizedBox(height: 12),

        // Severity selector
        const Align(
          alignment: Alignment.centerRight,
          child: Text(
            'درجة الخطورة *',
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: ViolationSeverity.values.map((s) {
            final isSelected = _selectedSeverity == s;
            final color = _severityColor(s);
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedSeverity = s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? color : color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: color, width: isSelected ? 2 : 1),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _severityIcon(s),
                        color: isSelected ? Colors.white : color,
                        size: 20,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : color,
                        ),
                      ),
                      // نقاط الضابط
                      Text(
                        '+${s.points} نقطة',
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected
                              ? Colors.white70
                              : color.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),

        // Location
        TextFormField(
          controller: _locationCtrl,
          decoration: InputDecoration(
            labelText: 'موقع المخالفة',
            hintText: 'مثال: قسم الإنتاج — خط 3',
            prefixIcon: const Icon(Icons.location_on),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),

        // Details
        TextFormField(
          controller: _detailsCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'تفاصيل إضافية',
            hintText: 'أي معلومات إضافية تساعد في توثيق المخالفة...',
            prefixIcon: const Icon(Icons.notes),
            alignLabelWithHint: true,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildEvidenceSection() {
    return Column(
      children: [
        // Photos + video grid
        if (_evidenceImages.isNotEmpty || _evidenceVideo != null) ...[
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount:
            _evidenceImages.length + (_evidenceVideo != null ? 1 : 0),
            itemBuilder: (ctx, i) {
              // آخر عنصر = الفيديو (إن وُجد)
              if (i == _evidenceImages.length) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(Icons.play_circle_fill,
                            color: Colors.white, size: 32),
                      ),
                    ),
                    const Positioned(
                      bottom: 4,
                      right: 4,
                      child: Text(
                        'فيديو',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      left: 4,
                      child: GestureDetector(
                        onTap: _removeVideo,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                );
              }

              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _evidenceImages[i],
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    left: 4,
                    child: GestureDetector(
                      onTap: () => _removeImage(i),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
        ],

        // Camera / Gallery / Video buttons
        Row(
          children: [
            Expanded(
              child: _photoButton(
                icon: Icons.camera_alt,
                label: 'الكاميرا',
                color: Colors.green,
                onTap: _pickFromCamera,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _photoButton(
                icon: Icons.photo_library,
                label: 'المعرض',
                color: Colors.blue,
                onTap: _pickFromGallery,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: _photoButton(
            icon: Icons.videocam,
            label: _evidenceVideo == null
                ? 'إضافة فيديو دليل (اختياري)'
                : 'استبدال الفيديو',
            color: Colors.deepPurple,
            onTap: _showVideoSourceSheet,
          ),
        ),

        // Required hint
        if (_evidenceImages.isEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.red, size: 16),
                SizedBox(width: 8),
                Text(
                  'صورة الدليل مطلوبة لحفظ المخالفة',
                  style: TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade700,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.red.shade200,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: 4,
        ),
        child: _isLoading
            ? Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.5),
            ),
            const SizedBox(width: 12),
            Text(
              _isUploading
                  ? 'جاري رفع الصور...'
                  : 'جاري الحفظ...',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        )
            : const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.save, size: 22),
            SizedBox(width: 10),
            Text(
              'حفظ المخالفة',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // SHARED WIDGETS
  // ════════════════════════════════════════════════════════════════════

  Widget _sectionCard({
    required IconData icon,
    required Color color,
    required String title,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const Divider(height: 20),
            child,
          ],
        ),
      ),
    );
  }

  Widget _photoButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // SEVERITY HELPERS
  // ════════════════════════════════════════════════════════════════════

  Color _severityColor(ViolationSeverity s) {
    switch (s) {
      case ViolationSeverity.light:    return Colors.amber.shade700;
      case ViolationSeverity.medium:   return Colors.orange;
      case ViolationSeverity.major:    return Colors.red;
      case ViolationSeverity.critical: return Colors.black87;
    }
  }

  IconData _severityIcon(ViolationSeverity s) {
    switch (s) {
      case ViolationSeverity.light:    return Icons.info_outline;
      case ViolationSeverity.medium:   return Icons.report_problem_outlined;
      case ViolationSeverity.major:    return Icons.error_outline;
      case ViolationSeverity.critical: return Icons.dangerous_outlined;
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // DISPOSE
  // ════════════════════════════════════════════════════════════════════

  @override
  void dispose() {
    _searchCtrl.dispose();
    _customTypeCtrl.dispose();
    _detailsCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }
}