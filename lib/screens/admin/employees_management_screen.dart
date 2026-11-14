// lib/screens/admin/employees_management_screen.dart
//
// إدارة موظفي المصنع (مجموعة "employees" — بدون حساب دخول):
// إضافة موظف جديد، تعديل بياناته، أو حذفه.

import 'package:flutter/material.dart';
import '../../services/pb_service.dart';
import '../../utils/constants.dart';

class EmployeesManagementScreen extends StatefulWidget {
  const EmployeesManagementScreen({super.key});

  @override
  State<EmployeesManagementScreen> createState() =>
      _EmployeesManagementScreenState();
}

class _EmployeesManagementScreenState
    extends State<EmployeesManagementScreen> {
  final _db = DatabaseService();

  Future<void> _showEmployeeForm({Map<String, dynamic>? existing}) async {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final idCtrl =
    TextEditingController(text: existing?['employee_id'] ?? '');
    final deptCtrl =
    TextEditingController(text: existing?['department'] ?? '');
    final formKey = GlobalKey<FormState>();
    final bool isEdit = existing != null;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isEdit ? 'تعديل بيانات الموظف' : 'إضافة موظف جديد',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم الموظف',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'أدخل الاسم' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: idCtrl,
                    decoration: const InputDecoration(
                      labelText: 'الرقم الوظيفي',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'أدخل الرقم الوظيفي'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: deptCtrl,
                    decoration: const InputDecoration(
                      labelText: 'القسم/الإدارة',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'أدخل القسم' : null,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      try {
                        if (isEdit) {
                          await _db.updateEmployee(existing['uid'], {
                            'name': nameCtrl.text.trim(),
                            'employee_id': idCtrl.text.trim(),
                            'department': deptCtrl.text.trim(),
                          });
                        } else {
                          await _db.addEmployee(
                            name: nameCtrl.text.trim(),
                            employeeId: idCtrl.text.trim(),
                            department: deptCtrl.text.trim(),
                          );
                        }
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('حدث خطأ: $e')),
                          );
                        }
                      }
                    },
                    child: Text(isEdit ? 'حفظ التعديلات' : 'إضافة'),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEdit ? 'تم تعديل بيانات الموظف' : 'تمت إضافة الموظف'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> employee) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف موظف'),
        content: Text(
            'هل تريد حذف الموظف "${employee['name']}"؟ لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _db.deleteEmployee(employee['uid']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم حذف "${employee['name']}"'),
              backgroundColor: Colors.red,
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
          title: const Text('إدارة الموظفين'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add, color: Colors.white),
          label:
          const Text('إضافة موظف', style: TextStyle(color: Colors.white)),
          onPressed: () => _showEmployeeForm(),
        ),
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _db.getAllEmployeesAdmin(),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('حدث خطأ: ${snap.error}'));
            }
            final employees = snap.data ?? [];
            if (employees.isEmpty) {
              return Center(
                child: Text('لا يوجد موظفون مسجّلون',
                    style: TextStyle(color: Colors.grey.shade600)),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              itemCount: employees.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final e = employees[i];
                final bool active = e['is_active'] ?? true;
                return Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                      child: const Icon(Icons.badge, color: AppColors.primary),
                    ),
                    title: Text(e['name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      '${e['employee_id'] ?? ''} • ${e['department'] ?? ''}'
                          '${active ? '' : ' • غير نشط'}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          tooltip: 'تعديل',
                          onPressed: () => _showEmployeeForm(existing: e),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'حذف',
                          onPressed: () => _confirmDelete(e),
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