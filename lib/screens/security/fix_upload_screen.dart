// lib/screens/security/fix_upload_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/violation_model.dart';
import '../../services/pb_service.dart';
import '../../services/storage_service.dart';

class FixUploadScreen extends StatefulWidget {
  final ViolationModel violation;
  const FixUploadScreen({super.key, required this.violation});

  @override
  State<FixUploadScreen> createState() => _FixUploadScreenState();
}

class _FixUploadScreenState extends State<FixUploadScreen> {
  final _db = DatabaseService();
  final _storage = StorageService();

  File? _fixImage;
  bool _isUploading = false;

  Future<void> _pickImage() async {
    final file = await _storage.pickImageFromCamera();
    if (file != null && mounted) setState(() => _fixImage = file);
  }

  Future<void> _pickFromGallery() async {
    final file = await _storage.pickImageFromGallery();
    if (file != null && mounted) setState(() => _fixImage = file);
  }

  Future<void> _submit() async {
    if (_fixImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب إرفاق صورة الإصلاح'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final url = await _storage.uploadFile(
        _fixImage!.path,
        'violations/${widget.violation.violationNumber}/fix',
        'fix_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      if (url == null) throw Exception('فشل رفع الصورة');

      await _db.uploadFixImage(widget.violation.id!, url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم رفع صورة الإصلاح بنجاح ✅'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.violation;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          title: const Text('رفع صورة الإصلاح'),
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // بطاقة المخالفة
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.info_outline, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('تفاصيل المخالفة',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                      ]),
                      const Divider(height: 16),
                      _infoRow('رقم المخالفة', v.violationNumber),
                      _infoRow('الموظف', v.employeeName),
                      _infoRow('نوع المخالفة', v.customType),
                      _infoRow('الموقع', v.location),
                      const SizedBox(height: 8),
                      // درجة الخطورة
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: v.severityColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          v.severityLabel,
                          style: TextStyle(
                              color: v.severityTextColor,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // تعليق المدير
              if (v.managerComment != null &&
                  v.managerComment!.isNotEmpty) ...[
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(children: [
                          Icon(Icons.comment, color: Colors.blue, size: 18),
                          SizedBox(width: 8),
                          Text('تعليق المدير',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue)),
                        ]),
                        const SizedBox(height: 8),
                        Text(v.managerComment!,
                            style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // رفع الصورة
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.camera_alt, color: Colors.green),
                        SizedBox(width: 8),
                        Text('صورة بعد الإصلاح *',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                      ]),
                      const Divider(height: 16),

                      // معاينة الصورة
                      if (_fixImage != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            _fixImage!,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: () =>
                              setState(() => _fixImage = null),
                          icon: const Icon(Icons.delete, color: Colors.red),
                          label: const Text('حذف الصورة',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ] else ...[
                        Container(
                          height: 150,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.grey.shade300,
                                style: BorderStyle.solid),
                          ),
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate,
                                    size: 48, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('أضف صورة تثبت الإصلاح',
                                    style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),

                      // أزرار الاختيار
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('كاميرا'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green,
                              side: const BorderSide(color: Colors.green),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickFromGallery,
                            icon: const Icon(Icons.photo_library),
                            label: const Text('المعرض'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue,
                              side: const BorderSide(color: Colors.blue),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // زر الإرسال
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isUploading
                      ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('جاري الرفع...'),
                    ],
                  )
                      : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.upload, size: 22),
                      SizedBox(width: 10),
                      Text('إرسال صورة الإصلاح',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ',
              style: const TextStyle(
                  color: Colors.grey, fontSize: 13)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}