// lib/screens/admin/financial_approval_screen.dart
//
// شاشة المدير للموافقة على المخالفات ماليًا:
// - يستعرض كل المخالفات التي لم يُتخذ فيها قرار مالي بعد (بانتظار الموافقة).
// - "قبول" يطلب إدخال قيمة الخصم، ثم تُقسَّم تلقائيًا 50% لرجل الأمن
//   و50% لرجل الكاميرات المساعد (أو 100% لرجل الأمن إن لم يوجد رجل كاميرات).
// - "رفض" يغلق المخالفة دون أي خصم أو إيداع.

import 'package:flutter/material.dart';
import '../../models/violation_model.dart';
import '../../services/pb_service.dart';
import '../../utils/constants.dart';

class FinancialApprovalScreen extends StatefulWidget {
  const FinancialApprovalScreen({super.key});

  @override
  State<FinancialApprovalScreen> createState() =>
      _FinancialApprovalScreenState();
}

class _FinancialApprovalScreenState extends State<FinancialApprovalScreen> {
  final _db = DatabaseService();
  final Set<String> _processingIds = {}; // لمنع الضغط المزدوج أثناء المعالجة

  Future<void> _showApproveDialog(ViolationModel v) async {
    final amountCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<double>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('قبول المخالفة'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الموظف: ${v.employeeName}'),
                const SizedBox(height: 4),
                Text('نوع المخالفة: ${v.customType}',
                    style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: amountCtrl,
                  autofocus: true,
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'قيمة الخصم (د.ل)',
                    prefixIcon: Icon(Icons.attach_money),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final n = double.tryParse(v?.trim() ?? '');
                    if (n == null || n <= 0) return 'أدخل قيمة صحيحة أكبر من صفر';
                    return null;
                  },
                ),
                if (v.cameraOfficerName != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'سيُقسَّم المبلغ: 50% لـ ${v.securityOfficerName} '
                        '(رجل الأمن) و50% لـ ${v.cameraOfficerName} (رجل الكاميرات)',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  Text(
                    'سيُضاف كامل المبلغ لمحفظة ${v.securityOfficerName} '
                        '(لا يوجد رجل كاميرات مرتبط بهذه المخالفة)',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'تم قبول المخالفة وإيداع ${confirmed.toStringAsFixed(2)} د.ل'),
            backgroundColor: Colors.green,
          ),
        );
      }
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

  Future<void> _showRejectDialog(ViolationModel v) async {
    final reasonCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('رفض المخالفة'),
          content: TextField(
            controller: reasonCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'سبب الرفض (اختياري)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('تراجع'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child:
              const Text('تأكيد الرفض', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() => _processingIds.add(v.id!));
    try {
      await _db.rejectFineApproval(v.id!, reasonCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم رفض المخالفة'), backgroundColor: Colors.red),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          title: const Text('الموافقة على المخالفات ماليًا'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: StreamBuilder<List<ViolationModel>>(
          stream: _db.getViolationsPendingFineApproval(),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('حدث خطأ: ${snap.error}'));
            }
            final violations = snap.data ?? [];
            if (violations.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.task_alt, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text('لا توجد مخالفات بانتظار الموافقة',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: violations.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final v = violations[i];
                final isProcessing = _processingIds.contains(v.id);

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: v.severityColor.withValues(alpha: 0.5)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: v.severityColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                v.severityLabel,
                                style: TextStyle(
                                    fontSize: 11, color: v.severityTextColor),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                v.customType.isEmpty ? 'مخالفة' : v.customType,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text('#${v.violationNumber}',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade500)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _infoRow(Icons.person, 'الموظف', v.employeeName),
                        _infoRow(Icons.security, 'رجل الأمن', v.securityOfficerName),
                        if (v.cameraOfficerName != null)
                          _infoRow(Icons.videocam, 'رجل الكاميرات',
                              v.cameraOfficerName!),
                        if (v.details.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(v.details,
                              style: TextStyle(color: Colors.grey.shade700)),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed:
                                isProcessing ? null : () => _showRejectDialog(v),
                                icon: const Icon(Icons.close, color: Colors.red),
                                label: const Text('رفض',
                                    style: TextStyle(color: Colors.red)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.red),
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
                                    : const Icon(Icons.check),
                                label: const Text('قبول وتحديد الخصم'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade500),
          const SizedBox(width: 6),
          Text('$label: ', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}