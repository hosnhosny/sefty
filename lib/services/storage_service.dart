// lib/services/storage_service.dart
//
// تم استبدال Firebase Storage بـ Cloudinary
// نفس أسماء الدوال القديمة بالضبط، حتى لا تحتاج تعديل أي شاشة أخرى في المشروع.

import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  // ====== بيانات حساب Cloudinary ======
  static const String _cloudName = 'mfolcdyy';
  static const String _uploadPreset = 'Hosnyalmohalhel218';

  final ImagePicker _picker = ImagePicker();

  // رابط رفع الصور
  String get _imageUploadUrl =>
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';

  // رابط رفع الفيديو
  String get _videoUploadUrl =>
      'https://api.cloudinary.com/v1_1/$_cloudName/video/upload';

  // ================== اختيار صورة فقط (بدون رفع) ==================

  // Pick image from camera (returns File)
  Future<File?> pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image == null) return null;
      return File(image.path);
    } catch (e) {
      return null;
    }
  }

  // Pick image from gallery (returns File)
  Future<File?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image == null) return null;
      return File(image.path);
    } catch (e) {
      return null;
    }
  }

  // Pick video from camera (returns File, بدون رفع)
  Future<File?> pickVideoFromCamera() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 2),
      );
      if (video == null) return null;
      return File(video.path);
    } catch (e) {
      return null;
    }
  }

  // Pick video from gallery (returns File, بدون رفع)
  Future<File?> pickVideoFromGallery() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 2),
      );
      if (video == null) return null;
      return File(video.path);
    } catch (e) {
      return null;
    }
  }

  // ================== دالة الرفع الأساسية لـ Cloudinary ==================

  Future<String?> _uploadToCloudinary(
      File file,
      String folder, {
        bool isVideo = false,
      }) async {
    try {
      final uri = Uri.parse(isVideo ? _videoUploadUrl : _imageUploadUrl);
      final request = http.MultipartRequest('POST', uri);

      request.fields['upload_preset'] = _uploadPreset;
      request.fields['folder'] = folder; // ينظم الملفات داخل مجلدات Cloudinary

      request.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        return data['secure_url'] as String?; // رابط الملف النهائي
      } else {
        debugPrint('Cloudinary upload failed: $responseBody');
        return null;
      }
    } catch (e) {
      debugPrint('Error uploading to Cloudinary: $e');
      return null;
    }
  }

  // ================== رفع صورة واحدة من الكاميرا ==================

  Future<String?> pickAndUploadImage(
      String folder, {
        int maxWidth = 1920,
        int maxHeight = 1080,
        int quality = 85,
      }) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: quality,
      );

      if (image == null) return null;

      final file = File(image.path);
      return await _uploadToCloudinary(file, folder, isVideo: false);
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  // ================== رفع فيديو من الكاميرا ==================

  Future<String?> pickAndUploadVideo(String folder) async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 2), // حد أقصى دقيقتين
      );

      if (video == null) return null;

      final file = File(video.path);
      return await _uploadToCloudinary(file, folder, isVideo: true);
    } catch (e) {
      debugPrint('Error uploading video: $e');
      return null;
    }
  }

  // ================== رفع عدة صور دفعة واحدة ==================

  Future<List<String>> pickAndUploadMultipleImages(
      String folder, {
        int maxImages = 5,
      }) async {
    final List<String> urls = [];

    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (images.isEmpty) return urls;

      final limitedImages = images.take(maxImages).toList();

      for (final image in limitedImages) {
        final file = File(image.path);
        final url = await _uploadToCloudinary(file, folder, isVideo: false);
        if (url != null) urls.add(url);
      }
    } catch (e) {
      debugPrint('Error uploading multiple images: $e');
    }

    return urls;
  }

  // ================== رفع ملف من مسار محدد ==================

  Future<String?> uploadFile(
      String filePath,
      String folder,
      String fileName,
      ) async {
    try {
      final file = File(filePath);
      final isVideo = fileName.toLowerCase().endsWith('.mp4') ||
          fileName.toLowerCase().endsWith('.mov');
      return await _uploadToCloudinary(file, folder, isVideo: isVideo);
    } catch (e) {
      debugPrint('Error uploading file: $e');
      return null;
    }
  }

  // ================== حذف ملف ==================
  //
  // ملاحظة: حذف ملف من Cloudinary بأمان يحتاج "Signed Request" (مفتاح سري)،
  // وهذا غير مناسب أن يكون داخل تطبيق الموبايل مباشرة (خطر أمني).
  // الحل الأبسط: نتجاهل حذف الملف الفعلي من Cloudinary، فقط نحذف الرابط
  // من قاعدة بيانات Firestore (وهذا يكفي عملياً لإخفائه من التطبيق).
  Future<void> deleteFile(String url) async {
    // لا حاجة لفعل أي شيء هنا حالياً - الحذف يتم من Firestore فقط.
    // (تُركت الدالة موجودة لتجنب كسر أي كود يستدعيها)
    return;
  }

  // ================== ميتاداتا الملف ==================
  //
  // Cloudinary لا يحتاج هذه الدالة بنفس طريقة Firebase،
  // تم إبقاؤها فقط لتوافق الكود القديم بدون كسره.
  Future<dynamic> getFileMetadata(String url) async {
    return null;
  }
}