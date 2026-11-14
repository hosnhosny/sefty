// lib/screens/admin/admin_control_panel_screen.dart
//
// لوحة تحكم المدير: نقطة دخول موحّدة لكل عمليات إدارة المستخدمين
// والموافقات المالية على المخالفات ومحافظ رجال الأمن/الكاميرات.

import 'package:flutter/material.dart';
import '../../services/pb_service.dart';
import '../../utils/constants.dart';
import 'add_edit_user_screen.dart';
import 'security_management_screen.dart';
import 'employees_management_screen.dart';
import 'employee_violations_balance_screen.dart';

class AdminControlPanelScreen extends StatelessWidget {
  const AdminControlPanelScreen({super.key});

  Future<void> _resetWallets(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تصفير رصيد المحفظات'),
          content: const Text(
              'هل أنت متأكد من تصفير أرصدة محفظات جميع رجال الأمن والكاميرات؟ '
                  'يُفضّل القيام بهذا نهاية كل شهر بعد صرف المستحقات. لا يمكن التراجع.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأكيد التصفير',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await DatabaseService().resetAllWallets();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تصفير جميع المحافظ بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء التصفير: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = <_PanelItem>[
      _PanelItem(
        title: 'لوحة رصيد المخالفات',
        subtitle: 'إجمالي قيمة الخصومات المستحقة على كل موظف',
        icon: Icons.account_balance_wallet,
        color: Colors.red,
        onTap: (ctx) => Navigator.push(
          ctx,
          MaterialPageRoute(
              builder: (_) => const EmployeeViolationsBalanceScreen()),
        ),
      ),
      _PanelItem(
        title: 'تصفير رصيد المحفظات',
        subtitle: 'تصفير محفظة رجال الأمن والكاميرات (يدويًا، نهاية الشهر)',
        icon: Icons.cleaning_services,
        color: Colors.orange,
        onTap: (ctx) => _resetWallets(ctx),
      ),
      _PanelItem(
        title: 'إضافة رجل أمن',
        subtitle: 'إنشاء حساب دخول جديد لرجل أمن',
        icon: Icons.security,
        color: Colors.blue,
        onTap: (ctx) => Navigator.push(
          ctx,
          MaterialPageRoute(
            builder: (_) => const AddEditUserScreen(role: 'security'),
          ),
        ),
      ),
      _PanelItem(
        title: 'إضافة رجل كاميرات',
        subtitle: 'إنشاء حساب جديد لرجل كاميرات مساعد',
        icon: Icons.videocam,
        color: Colors.deepOrange,
        onTap: (ctx) => Navigator.push(
          ctx,
          MaterialPageRoute(
            builder: (_) => const AddEditUserScreen(role: 'camera'),
          ),
        ),
      ),
      _PanelItem(
        title: 'إضافة موظف مصنع',
        subtitle: 'تسجيل موظف جديد للربط مع المخالفات',
        icon: Icons.badge,
        color: Colors.teal,
        onTap: (ctx) => Navigator.push(
          ctx,
          MaterialPageRoute(builder: (_) => const EmployeesManagementScreen()),
        ),
      ),
      _PanelItem(
        title: 'إضافة مدير آخر',
        subtitle: 'منح صلاحيات إدارية كاملة لمستخدم جديد',
        icon: Icons.admin_panel_settings,
        color: Colors.deepPurple,
        onTap: (ctx) => Navigator.push(
          ctx,
          MaterialPageRoute(
            builder: (_) => const AddEditUserScreen(role: 'admin'),
          ),
        ),
      ),
      _PanelItem(
        title: 'إدارة رجال الأمن',
        subtitle: 'تعديل البيانات، الأرصدة، أو إيقاف/تفعيل الخدمة',
        icon: Icons.manage_accounts,
        color: Colors.indigo,
        onTap: (ctx) => Navigator.push(
          ctx,
          MaterialPageRoute(builder: (_) => const SecurityManagementScreen()),
        ),
      ),
      _PanelItem(
        title: 'إدارة الموظفين',
        subtitle: 'تعديل بيانات موظف أو حذفه',
        icon: Icons.group,
        color: Colors.brown,
        onTap: (ctx) => Navigator.push(
          ctx,
          MaterialPageRoute(builder: (_) => const EmployeesManagementScreen()),
        ),
      ),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          title: const Text('لوحة تحكم المدير'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (ctx, i) {
            final item = items[i];
            return Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => item.onTap(ctx),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(item.icon, color: item.color, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.subtitle,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_left, color: Colors.grey.shade400),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PanelItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final void Function(BuildContext) onTap;

  _PanelItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}