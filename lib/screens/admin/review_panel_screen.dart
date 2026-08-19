// lib/screens/admin/review_panel_screen.dart
//
// لوحة مراجعة المدير المُحدَّثة:
// - استقبال المخالفات واتخاذ قرار مالي (قبول/رفض)
// - عرض المخالفات المقبولة مع قيمتها والمرفوضة والمغلقة

import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/violation_model.dart';
import '../../models/user_model.dart';
import '../../services/pb_service.dart';
import '../../services/notification_service.dart';
import '../../utils/enums.dart';
import '../../widgets/evidence_video_dialog.dart';

class ReviewPanelScreen extends StatefulWidget {
  final UserModel currentUser;
  const ReviewPanelScreen({super.key, required this.currentUser});

  @override
  State<ReviewPanelScreen> createState() => _ReviewPanelScreenState();
}

class _ReviewPanelScreenState extends State<ReviewPanelScreen>
    with SingleTickerProviderStateMixin {
  final _db = DatabaseService();
  final _notifications = NotificationService();
  late TabController _tabController;

  /// لمنع الضغط المزدوج أثناء معالجة القبول/الرفض
  final Set<String> _processingIds = {};

  // ── قائمة المخالفات محفوظة في الحالة محلياً بدل الاعتماد الكامل على
  // StreamBuilder (اللي كان بيعيد الاشتراك بالـ realtime من الصفر مع كل
  // rebuild). الاشتراك الآن يحدث مرة واحدة فقط في initState، بالإضافة إلى
  // تحديث فوري يدوي (forceRefresh) بعد كل عملية قبول/رفض حتى لو تأخر
  // أو فشل وصول تحديث الـ realtime.
  List<ViolationModel> _violations = [];
  bool _loading = true;
  StreamSubscription<List<ViolationModel>>? _sub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _sub = _db.getAllViolations().listen((list) {
      if (mounted) setState(() => _violations = list);
    }, onError: (_) {
      // نتجاهل أخطاء الـ realtime هنا لأن forceRefresh هو خط الدفاع الأساسي
      if (mounted) setState(() => _loading = false);
    });
    // أول تحميل فوري (بدون انتظار أول رسالة realtime)
    _forceRefresh(showSpinner: true);
  }

  /// يجلب القائمة فوراً بشكل مباشر (بدون انتظار الـ realtime) — يُستخدم
  /// عند فتح الشاشة أول مرة، وبعد كل قبول/رفض حتى تنتقل المخالفة بين
  /// التبويبات فوراً على هذا الجهاز.
  Future<void> _forceRefresh({bool showSpinner = false}) async {
    if (showSpinner && mounted) setState(() => _loading = true);
    try {
      final fresh = await _db.getAllViolationsOnce();
      if (mounted) setState(() => _violations = fresh);
    } catch (_) {
      // تجاهل: القائمة الحالية (من الـ stream إن وُجدت) تبقى معروضة
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          title: const Text(
            'لوحة المراجعة',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF1565C0),
          foregroundColor: Colors.white,
          centerTitle: true,
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: const [
              Tab(text: '🔴 بانتظار القرار'),
              Tab(text: '✅ مقبولة'),
              Tab(text: '❌ مرفوضة'),
              Tab(text: '📁 مغلقة'),
            ],
          ),
        ),
        body: _loading && _violations.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
          onRefresh: () => _forceRefresh(),
          child: Builder(builder: (context) {
            final all = _violations;

            // ── تصنيف المخالفات ─────────────────────────────
            final pending = all
                .where((v) => v.isPendingFineApproval)
                .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

            final approved = all
                .where((v) => v.isFineApproved)
                .toList()
              ..sort((a, b) => (b.fineApprovedAt ?? b.createdAt)
                  .compareTo(a.fineApprovedAt ?? a.createdAt));

            final rejected = all
                .where((v) => v.status == ViolationStatus.rejected)
                .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

            final closed = all
                .where((v) => v.status == ViolationStatus.closed)
                .toList()
              ..sort((a, b) => (b.closedAt ?? b.createdAt)
                  .compareTo(a.closedAt ?? a.createdAt));

            return TabBarView(
              controller: _tabController,
              children: [
                _buildPendingList(pending, key: ValueKey('pending_${pending.length}')),
                _buildApprovedList(approved, key: ValueKey('approved_${approved.length}')),
                _buildRejectedList(rejected, key: ValueKey('rejected_${rejected.length}')),
                _buildClosedList(closed, key: ValueKey('closed_${closed.length}')),
              ],
            );
          }),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 1️⃣ بانتظار القرار
  // ═══════════════════════════════════════════════════════════════

  Widget _buildPendingList(List<ViolationModel> list, {Key? key}) {
    if (list.isEmpty) {
      return _buildEmptyState(
        icon: Icons.fact_check,
        text: 'لا توجد مخالفات بانتظار القرار المالي',
      );
    }
    return ListView.builder(
      key: key,
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      itemBuilder: (ctx, i) => _buildPendingCard(list[i]),
    );
  }

  Widget _buildPendingCard(ViolationModel v) {
    final isProcessing = _processingIds.contains(v.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
            color: v.severityColor.withValues(alpha: 0.5), width: 1.5),      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────
            Row(children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8)),
                child: Text(v.violationNumber,
                    style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: v.severityColor,
                    borderRadius: BorderRadius.circular(8)),
                child: Text(v.severityLabel,
                    style: TextStyle(
                        color: v.severityTextColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              if (v.requiresReview)
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: v.status.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: v.status.color.withValues(alpha: 0.5)),
                  ),
                  child: Text('${v.status.emoji} ${v.status.label}',
                      style: TextStyle(
                          color: v.status.color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
            ]),
            const SizedBox(height: 10),

            // ── بيانات الموظف والمخالفة ─────────────────────
            _infoRow(Icons.person, 'الموظف', v.employeeName),
            _infoRow(Icons.business, 'القسم', v.employeeDepartment),
            _infoRow(Icons.warning_amber, 'نوع المخالفة', v.customType),
            if (v.location.isNotEmpty)
              _infoRow(Icons.location_on, 'الموقع', v.location),
            if (v.details.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(v.details,
                  style: TextStyle(
                      color: Colors.grey.shade700, fontSize: 13)),
            ],

            // ── الأدلة ──────────────────────────────────────
            if (v.evidenceUrls.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildEvidenceThumbnails(v),
            ],

            const Divider(height: 20),

            // ── Footer ──────────────────────────────────────
            Row(children: [
              const Icon(Icons.calendar_today, size: 13, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                '${v.createdAt.year}/${v.createdAt.month.toString().padLeft(2, '0')}/${v.createdAt.day.toString().padLeft(2, '0')}  '
                    '${v.createdAt.hour.toString().padLeft(2, '0')}:${v.createdAt.minute.toString().padLeft(2, '0')}',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
              const Spacer(),
              Text('بواسطة: ${v.securityOfficerName}',
                  style:
                  TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ]),

            // ── أزرار القرار ────────────────────────────────
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isProcessing ? null : () => _showRejectDialog(v),
                  icon: const Icon(Icons.close, color: Colors.red, size: 18),
                  label: const Text('رفض المخالفة',
                      style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isProcessing
                      ? null
                      : () => _showApproveDialog(v),
                  icon: isProcessing
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                      : const Icon(Icons.check, size: 18),
                  label: const Text('قبول وتحديد القيمة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 2️⃣ مقبولة
  // ═══════════════════════════════════════════════════════════════

  Widget _buildApprovedList(List<ViolationModel> list, {Key? key}) {
    if (list.isEmpty) {
      return _buildEmptyState(
        icon: Icons.check_circle_outline,
        text: 'لا توجد مخالفات مقبولة مالياً',
      );
    }
    return ListView.builder(
      key: key,
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      itemBuilder: (ctx, i) => _buildApprovedCard(list[i]),
    );
  }

  Widget _buildApprovedCard(ViolationModel v) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.green.shade300, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8)),
                child: Text(v.violationNumber,
                    style: TextStyle(
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
              const Spacer(),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${v.fineAmount.toStringAsFixed(2)} د.ل',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            _infoRow(Icons.person, 'الموظف', v.employeeName),
            _infoRow(Icons.warning_amber, 'نوع المخالفة', v.customType),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _infoRow(Icons.account_balance_wallet, 'رجل الأمن',
                      '${(v.cameraOfficerId != null ? v.fineAmount / 2 : v.fineAmount).toStringAsFixed(2)} د.ل'),
                  if (v.cameraOfficerName != null)
                    _infoRow(Icons.videocam, 'رجل الكاميرات',
                        '${(v.fineAmount / 2).toStringAsFixed(2)} د.ل'),
                ],
              ),
            ),
            const Divider(height: 16),
            Row(children: [
              const Icon(Icons.calendar_today, size: 13, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                'تم القبول: ${v.fineApprovedAt!.year}/${v.fineApprovedAt!.month}/${v.fineApprovedAt!.day}',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 3️⃣ مرفوضة
  // ═══════════════════════════════════════════════════════════════

  Widget _buildRejectedList(List<ViolationModel> list, {Key? key}) {
    if (list.isEmpty) {
      return _buildEmptyState(
        icon: Icons.cancel_outlined,
        text: 'لا توجد مخالفات مرفوضة',
      );
    }
    return ListView.builder(
      key: key,
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      itemBuilder: (ctx, i) => _buildRejectedCard(list[i]),
    );
  }

  Widget _buildRejectedCard(ViolationModel v) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.red.shade300, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8)),
                child: Text(v.violationNumber,
                    style: TextStyle(
                        color: Colors.red.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
              const Spacer(),
              const Icon(Icons.cancel, color: Colors.red),
            ]),
            const SizedBox(height: 10),
            _infoRow(Icons.person, 'الموظف', v.employeeName),
            _infoRow(Icons.warning_amber, 'نوع المخالفة', v.customType),
            if (v.managerComment != null && v.managerComment!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.comment,
                        size: 16, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'سبب الرفض: ${v.managerComment}',
                        style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Divider(height: 16),
            Row(children: [
              const Icon(Icons.calendar_today, size: 13, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                '${v.createdAt.year}/${v.createdAt.month}/${v.createdAt.day}',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 4️⃣ مغلقة
  // ═══════════════════════════════════════════════════════════════

  Widget _buildClosedList(List<ViolationModel> list, {Key? key}) {
    if (list.isEmpty) {
      return _buildEmptyState(
        icon: Icons.folder_outlined,
        text: 'لا توجد مخالفات مغلقة',
      );
    }
    return ListView.builder(
      key: key,
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      itemBuilder: (ctx, i) => _buildClosedCard(list[i]),
    );
  }

  Widget _buildClosedCard(ViolationModel v) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8)),
                child: Text(v.violationNumber,
                    style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
              const Spacer(),
              const Icon(Icons.check_circle, color: Colors.green),
            ]),
            const SizedBox(height: 10),
            _infoRow(Icons.person, 'الموظف', v.employeeName),
            _infoRow(Icons.warning_amber, 'نوع المخالفة', v.customType),
            if (v.isFineApproved) ...[
              const SizedBox(height: 6),
              Text(
                'القيمة: ${v.fineAmount.toStringAsFixed(2)} د.ل',
                style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
            ],
            const Divider(height: 16),
            Row(children: [
              const Icon(Icons.calendar_today, size: 13, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                'تم الإغلاق: ${v.closedAt!.year}/${v.closedAt!.month}/${v.closedAt!.day}',
                style: const TextStyle(color: Colors.green, fontSize: 12),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 🎯 حوار القبول المالي
  // ═══════════════════════════════════════════════════════════════

  Future<void> _showApproveDialog(ViolationModel v) async {
    final amountCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<double>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 10),
              Text('قبول المخالفة'),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailText('الموظف:', v.employeeName),
                _detailText('نوع المخالفة:', v.customType),
                _detailText('رجل الأمن:', v.securityOfficerName),
                if (v.cameraOfficerName != null)
                  _detailText('رجل الكاميرات:', v.cameraOfficerName!),
                const Divider(height: 20),
                TextFormField(
                  controller: amountCtrl,
                  autofocus: true,
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'قيمة الخصم (د.ل) *',
                    prefixIcon: Icon(Icons.attach_money),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    final n = double.tryParse(val?.trim() ?? '');
                    if (n == null || n <= 0) {
                      return 'أدخل قيمة صحيحة أكبر من صفر';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    v.cameraOfficerName != null
                        ? '💰 سيُقسَّم المبلغ: 50% لـ ${v.securityOfficerName} '
                        'و50% لـ ${v.cameraOfficerName}'
                        : '💰 سيُضاف كامل المبلغ لمحفظة ${v.securityOfficerName}',
                    style:
                    TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(ctx, double.parse(amountCtrl.text.trim()));
              },
              child: const Text('تأكيد القبول',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == null) return;

    setState(() => _processingIds.add(v.id!));
    try {
      await _db.approveFineAndCreditWallet(
        violationId: v.id!,
        fineAmount: confirmed,
        securityOfficerId: v.securityOfficerId,
        cameraOfficerId: v.cameraOfficerId,
      );

      // إشعار رجل الأمن
      await _notifications.sendNotificationToUser(
        userId: v.securityOfficerId,
        title: '✅ تم قبول المخالفة',
        body:
        'تم قبول المخالفة ${v.violationNumber} وقيمتها ${confirmed.toStringAsFixed(2)} د.ل',
      );

      // إشعار رجل الكاميرات إن وُجد
      if (v.cameraOfficerId != null && v.cameraOfficerId!.isNotEmpty) {
        await _notifications.sendNotificationToUser(
          userId: v.cameraOfficerId!,
          title: '✅ تم قبول المخالفة',
          body:
          'تم قبول المخالفة ${v.violationNumber} وقيمتها ${confirmed.toStringAsFixed(2)} د.ل',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ تم قبول المخالفة وقيمتها ${confirmed.toStringAsFixed(2)} د.ل'),
            backgroundColor: Colors.green,
          ),
        );
      }
      // تحديث فوري: تنقل المخالفة من "بانتظار القرار" إلى "مقبولة" فوراً
      await _forceRefresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ حدث خطأ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(v.id!));
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 🚫 حوار الرفض
  // ═══════════════════════════════════════════════════════════════

  Future<void> _showRejectDialog(ViolationModel v) async {
    final reasonCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.cancel, color: Colors.red),
              SizedBox(width: 10),
              Text('رفض المخالفة'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailText('الموظف:', v.employeeName),
              _detailText('نوع المخالفة:', v.customType),
              const SizedBox(height: 16),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'سبب الرفض *',
                  hintText: 'اكتب سبب رفض المخالفة...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('تراجع'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                if (reasonCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('يرجى كتابة سبب الرفض'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('تأكيد الرفض',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() => _processingIds.add(v.id!));
    try {
      await _db.rejectFineApproval(v.id!, reasonCtrl.text.trim());

      // إشعار رجل الأمن بالرفض
      await _notifications.sendNotificationToUser(
        userId: v.securityOfficerId,
        title: '❌ تم رفض المخالفة',
        body:
        'تم رفض المخالفة ${v.violationNumber}: ${reasonCtrl.text.trim()}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ تم رفض المخالفة'),
            backgroundColor: Colors.red,
          ),
        );
      }
      // تحديث فوري: تنقل المخالفة من "بانتظار القرار" إلى "مرفوضة" فوراً
      await _forceRefresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(v.id!));
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 🧱 Widgets مشتركة
  // ═══════════════════════════════════════════════════════════════

  Widget _buildEmptyState({required IconData icon, required String text}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 70, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(text,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(icon, size: 15, color: Colors.grey.shade500),
          const SizedBox(width: 6),
          Text('$label: ',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          Expanded(
            child: Text(value,
                style:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _detailText(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(value,
                style:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceThumbnails(ViolationModel v) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: v.evidenceUrls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final url = v.evidenceUrls[i];
          final isVideo = ViolationModel.isVideoUrl(url);

          if (isVideo) {
            return GestureDetector(
              onTap: () => showEvidenceVideoDialog(context, url),
              child: Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(Icons.play_circle_fill,
                      color: Colors.white, size: 30),
                ),
              ),
            );
          }

          return GestureDetector(
            onTap: () => _showImageDialog(url),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                url,
                height: 80,
                width: 80,
                fit: BoxFit.cover,
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    height: 80,
                    width: 80,
                    color: Colors.grey.shade200,
                    child: const Center(
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))),
                  );
                },
                errorBuilder: (ctx, error, stack) => Container(
                  height: 80,
                  width: 80,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showImageDialog(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}