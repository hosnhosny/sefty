// lib/screens/admin/leaves_list_screen.dart

import 'package:flutter/material.dart';
import '../../services/pb_service.dart';
import '../../models/leave_model.dart';
import '../../utils/enums.dart';

class LeavesListScreen extends StatelessWidget {
  const LeavesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('إذن الانصراف'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: StreamBuilder<List<LeaveModel>>(
          stream: db.getAllLeaves(),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snap.hasData || snap.data!.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text('لا توجد إذونات مسجلة',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 16)),
                  ],
                ),
              );
            }

            final leaves = snap.data!;

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: leaves.length,
              itemBuilder: (ctx, i) => _leaveCard(ctx, db, leaves[i]),
            );
          },
        ),
      ),
    );
  }

  Widget _leaveCard(BuildContext context, DatabaseService db, LeaveModel l) {    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: l.status == LeaveStatus.active || l.status == LeaveStatus.late
            ? BorderSide(color: Colors.orange.shade300, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(l.leaveNumber,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: l.statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: l.statusColor, width: 1),
                  ),
                  child: Text(l.statusLabel,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.person, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l.employeeName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${l.employeeDepartment} | سجّلها: ${l.requestedByName}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.exit_to_app,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        'خروج: ${l.exitTime.hour.toString().padLeft(2, '0')}:${l.exitTime.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.keyboard_return,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        'رجوع متوقع: ${l.expectedReturn.hour.toString().padLeft(2, '0')}:${l.expectedReturn.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  if (l.actualReturn != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.check_circle,
                            size: 16,
                            color: l.isLate ? Colors.red : Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          'رجوع فعلي: ${l.actualReturn!.hour.toString().padLeft(2, '0')}:${l.actualReturn!.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 14,
                            color: l.isLate ? Colors.red : Colors.green,
                            fontWeight: l.isLate
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.label, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(l.reasonLabel,
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 13)),
                if (l.reasonDetails != null) ...[
                  const SizedBox(width: 8),
                  Text('(${l.reasonDetails})',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 12)),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today,
                    size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  '${l.createdAt.day}/${l.createdAt.month}/${l.createdAt.year}',
                  style:
                  TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),

            // ── أزرار تسجيل العودة (فقط للإذونات النشطة/المتأخرة) ──
            if (l.status == LeaveStatus.active ||
                l.status == LeaveStatus.late) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _markReturned(context, db, l),
                      icon: const Icon(Icons.check_circle,
                          size: 18, color: Colors.green),
                      label: const Text('تسجيل العودة'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _markNoReturn(context, db, l),
                      icon: const Icon(Icons.cancel,
                          size: 18, color: Colors.red),
                      label: const Text('لم يعد'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
  );
  }

  // ── تأكيد ثم تسجيل عودة الموظف ──────────────────────────────────
  Future<void> _markReturned(
      BuildContext context, DatabaseService db, LeaveModel l) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد العودة'),
        content: Text('هل تؤكد عودة ${l.employeeName} الآن؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await db.updateLeaveReturn(l.id!, DateTime.now());

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تسجيل عودة الموظف ✅'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // ── تأكيد ثم تسجيل عدم عودة الموظف ──────────────────────────────
  Future<void> _markNoReturn(
      BuildContext context, DatabaseService db, LeaveModel l) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد عدم العودة'),
        content: Text('هل تؤكد أن ${l.employeeName} لم يعد من الإذن؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('تأكيد', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await db.markLeaveAsNoReturn(l.id!);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تسجيل عدم عودة الموظف'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}