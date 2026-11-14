// lib/screens/admin/security_management_screen.dart
//
// إدارة رجال الأمن: عرض القائمة، تعديل بيانات أي منهم،
// وإيقاف/تفعيل خدمته (منعه من الدخول دون حذف حسابه).

import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/pb_service.dart';
import '../../utils/constants.dart';
import 'add_edit_user_screen.dart';

class SecurityManagementScreen extends StatefulWidget {
  const SecurityManagementScreen({super.key});

  @override
  State<SecurityManagementScreen> createState() =>
      _SecurityManagementScreenState();
}

class _SecurityManagementScreenState extends State<SecurityManagementScreen> {
  final _db = DatabaseService();

  Future<void> _toggleActive(UserModel user) async {
    final bool willDeactivate = user.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(willDeactivate ? 'إيقاف الخدمة' : 'تفعيل الخدمة'),
        content: Text(willDeactivate
            ? 'هل تريد إيقاف خدمة "${user.name}"؟ لن يتمكن من تسجيل الدخول بعد الآن.'
            : 'هل تريد إعادة تفعيل خدمة "${user.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: willDeactivate ? Colors.red : Colors.green,
            ),
            child: Text(
              willDeactivate ? 'إيقاف' : 'تفعيل',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _db.setUserActive(user.uid, !user.isActive);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(willDeactivate
                  ? 'تم إيقاف خدمة "${user.name}"'
                  : 'تم تفعيل خدمة "${user.name}"'),
              backgroundColor: willDeactivate ? Colors.red : Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('حدث خطأ: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          title: const Text('إدارة رجال الأمن'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('إضافة رجل أمن',
              style: TextStyle(color: Colors.white)),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AddEditUserScreen(role: 'security'),
              ),
            );
          },
        ),
        body: StreamBuilder<List<UserModel>>(
          stream: _db.getUsersByRole('security'),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('حدث خطأ: ${snap.error}'));
            }
            final users = snap.data ?? [];
            if (users.isEmpty) {
              return Center(
                child: Text('لا يوجد رجال أمن مسجّلين',
                    style: TextStyle(color: Colors.grey.shade600)),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              itemCount: users.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final u = users[i];
                return Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: u.isActive
                          ? Colors.grey.shade200
                          : Colors.red.shade100,
                    ),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: u.isActive
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : Colors.red.withValues(alpha: 0.1),
                      child: Icon(Icons.security,
                          color: u.isActive ? AppColors.primary : Colors.red),
                    ),
                    title: Text(
                      u.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        decoration: u.isActive
                            ? TextDecoration.none
                            : TextDecoration.lineThrough,
                        color: u.isActive ? Colors.black87 : Colors.grey,
                      ),
                    ),
                    subtitle: Text(
                      [
                        u.email,
                        if (u.department != null && u.department!.isNotEmpty)
                          u.department!,
                        if (!u.isActive) 'الخدمة موقوفة',
                      ].join(' • '),
                      style: TextStyle(
                        color: u.isActive ? null : Colors.red.shade400,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          tooltip: 'تعديل البيانات',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddEditUserScreen(
                                  role: 'security',
                                  existingUser: u,
                                ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            u.isActive ? Icons.block : Icons.check_circle,
                            color: u.isActive ? Colors.red : Colors.green,
                          ),
                          tooltip: u.isActive ? 'إيقاف الخدمة' : 'تفعيل الخدمة',
                          onPressed: () => _toggleActive(u),
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
}