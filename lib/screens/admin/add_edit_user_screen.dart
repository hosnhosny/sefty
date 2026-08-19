// lib/screens/admin/add_edit_user_screen.dart
//
// شاشة موحّدة لإضافة أو تعديل مستخدم (مدير أو رجل أمن أو رجل كاميرات) في مجموعة "users".
// - وضع الإضافة: يطلب البريد وكلمة السر (لإنشاء حساب دخول جديد).
// - وضع التعديل: يعدّل فقط الاسم/الهاتف/القسم دون المساس بكلمة السر أو البريد.

import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/pb_service.dart';
import '../../utils/constants.dart';

class AddEditUserScreen extends StatefulWidget {
  /// 'admin' أو 'security' أو 'camera'
  final String role;
  final UserModel? existingUser; // null = إضافة جديد، غير null = تعديل

  const AddEditUserScreen({
    super.key,
    required this.role,
    this.existingUser,
  });

  bool get isEdit => existingUser != null;

  @override
  State<AddEditUserScreen> createState() => _AddEditUserScreenState();
}

class _AddEditUserScreenState extends State<AddEditUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseService();

  late final _nameController =
  TextEditingController(text: widget.existingUser?.name ?? '');
  late final _emailController =
  TextEditingController(text: widget.existingUser?.email ?? '');
  late final _phoneController =
  TextEditingController(text: widget.existingUser?.phone ?? '');
  late final _departmentController =
  TextEditingController(text: widget.existingUser?.department ?? '');
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  bool get _isSecurity => widget.role == 'security';
  bool get _isCamera => widget.role == 'camera';

  String get _roleLabel {
    if (_isSecurity) return 'رجل أمن';
    if (_isCamera) return 'رجل كاميرات';
    return 'مدير';
  }

  IconData get _roleIcon {
    if (_isSecurity) return Icons.security;
    if (_isCamera) return Icons.videocam;
    return Icons.admin_panel_settings;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (widget.isEdit) {
        await _db.updateUser(widget.existingUser!.uid, {
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          if (_isSecurity || _isCamera) 'department': _departmentController.text.trim(),
        });
      } else {
        await _db.createUser(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          role: widget.role,
          phone: _phoneController.text.trim(),
          department: (_isSecurity || _isCamera) ? _departmentController.text.trim() : null,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEdit
                ? 'تم تعديل بيانات $_roleLabel بنجاح'
                : 'تمت إضافة $_roleLabel بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          title: Text(widget.isEdit
              ? 'تعديل بيانات $_roleLabel'
              : 'إضافة $_roleLabel جديد'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  _roleIcon,
                  size: 72,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'الاسم الكامل',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => (val == null || val.trim().isEmpty)
                      ? 'يرجى إدخال الاسم'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  enabled: !widget.isEdit,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'البريد الإلكتروني',
                    prefixIcon: const Icon(Icons.email),
                    border: const OutlineInputBorder(),
                    helperText:
                    widget.isEdit ? 'لا يمكن تعديل البريد هنا' : null,
                  ),
                  validator: (val) {
                    if (widget.isEdit) return null;
                    if (val == null || val.trim().isEmpty) {
                      return 'يرجى إدخال البريد الإلكتروني';
                    }
                    if (!val.contains('@')) return 'البريد غير صحيح';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف (اختياري)',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_isSecurity || _isCamera) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _departmentController,
                    decoration: const InputDecoration(
                      labelText: 'موقع/قسم العمل (اختياري)',
                      prefixIcon: Icon(Icons.badge),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                if (!widget.isEdit) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'كلمة السر',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().length < 8) {
                        return 'كلمة السر يجب ألا تقل عن 8 رموز';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscurePassword,
                    decoration: const InputDecoration(
                      labelText: 'تأكيد كلمة السر',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (val != _passwordController.text) {
                        return 'كلمتا السر غير متطابقتين';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : Text(
                    widget.isEdit ? 'حفظ التعديلات' : 'حفظ وإضافة',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}