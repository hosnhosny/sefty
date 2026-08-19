// lib/screens/security/write_report_screen.dart

import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/report_model.dart';
import '../../services/pb_service.dart';
import '../../services/notification_service.dart';

class WriteReportScreen extends StatefulWidget {
  final UserModel currentUser;
  const WriteReportScreen({super.key, required this.currentUser});

  @override
  State<WriteReportScreen> createState() => _WriteReportScreenState();
}

class _WriteReportScreenState extends State<WriteReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseService();
  final _notification = NotificationService();

  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();

  String _type = 'daily';
  bool _isLoading = false;

  final Map<String, String> _typeLabels = const {
    'daily': 'يومي',
    'incident': 'حادث',
    'monthly': 'شهري',
    'patrol': 'جولة',
  };

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final reportNumber = await _db.getNextReportNumber();

      final report = ReportModel(
        reportNumber: reportNumber,
        createdAt: DateTime.now(),
        createdById: widget.currentUser.uid,
        createdByName: widget.currentUser.name,
        title: _titleCtrl.text.trim(),
        content: _contentCtrl.text.trim(),
        type: _type,
        pdfUrl: '',
      );

      final savedRecord = await _db.addReport(report);
      // تحديث الرقم المعروض ليطابق الرقم الفعلي المحفوظ (مهم فقط بحال إعادة المحاولة)
      final finalReportNumber =
          (savedRecord.data['report_number'] as String?) ?? reportNumber;

      await _notification.notifyNewReport(widget.currentUser.name);

      if (mounted) _showSuccessDialog(finalReportNumber);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(String reportNumber) {
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
              const Text(
                'تم إرسال التقرير',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  reportNumber,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade700,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'التقرير الآن بانتظار مراجعة الإدارة',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade700),
                  child:
                  const Text('إنهاء', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          title: const Text('كتابة تقرير'),
          backgroundColor: Colors.purple.shade700,
          foregroundColor: Colors.white,
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 2,
                  shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _type,
                          decoration: InputDecoration(
                            labelText: 'نوع التقرير',
                            prefixIcon: const Icon(Icons.category),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          items: _typeLabels.entries
                              .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _type = v);
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _titleCtrl,
                          decoration: InputDecoration(
                            labelText: 'عنوان التقرير *',
                            prefixIcon: const Icon(Icons.title),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'اكتب عنوان التقرير'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _contentCtrl,
                          maxLines: 8,
                          decoration: InputDecoration(
                            labelText: 'محتوى التقرير *',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'اكتب محتوى التقرير'
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade700),
                    child: _isLoading
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                        : const Text(
                      'إرسال التقرير',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }
}