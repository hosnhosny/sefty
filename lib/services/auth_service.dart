// lib/services/auth_service.dart

import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';
import '../main.dart'; // للوصول إلى العميل العام pb
import '../models/user_model.dart';

class AuthService {
  static final ValueNotifier<UserModel?> currentUserNotifier =
  ValueNotifier<UserModel?>(null);

  /// المستخدم الحالي كـ UserModel (يُقرأ من pb.authStore.record المخزّن محلياً)
  UserModel? get currentUser {
    final record = pb.authStore.record;
    if (record == null) return null;
    return UserModel.fromRecord(record);
  }

  String? get currentUserId => pb.authStore.record?.id;

  bool get isLoggedIn => pb.authStore.isValid;

  /// تسجيل الدخول عبر مجموعة "users" في PocketBase.
  /// يُعيد null عند النجاح، أو رسالة الخطأ بالعربي عند الفشل.
  Future<String?> login(String email, String password) async {
    try {
      final auth = await pb.collection('users').authWithPassword(
        email.trim(),
        password,
      );

      // auth.record غير قابل لأن يكون null في النسخ الحديثة من PocketBase
      final record = auth.record;

      final isActive = record.data['is_active'] ?? true;
      if (!isActive) {
        pb.authStore.clear();
        return 'هذا الحساب معطل حالياً';
      }

      // لا حاجة لحفظ الجلسة يدوياً — AsyncAuthStore في main.dart
      // يحفظها تلقائياً في SharedPreferences بعد كل تسجيل دخول.
      currentUserNotifier.value = UserModel.fromRecord(record);
      return null;
    } on ClientException catch (e) {
      if (e.statusCode == 400) {
        return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
      }
      return 'حدث خطأ أثناء الاتصال بالسيرفر: ${e.response['message'] ?? e.toString()}';
    } catch (e) {
      return 'حدث خطأ أثناء تسجيل الدخول: $e';
    }
  }

  Future<void> logout() async {
    // authStore.clear() يمسح الجلسة، وAsyncAuthStore في main.dart
    // يحذفها تلقائياً من SharedPreferences أيضاً عبر دالة clear.
    pb.authStore.clear();
    currentUserNotifier.value = null;
  }

  Future<UserModel?> getCurrentUserData() async {
    if (!pb.authStore.isValid) return null;
    try {
      final id = pb.authStore.record?.id;
      if (id == null) return null;
      final record = await pb.collection('users').getOne(id);
      return UserModel.fromRecord(record);
    } catch (e) {
      debugPrint('Error getting user data: $e');
      return null;
    }
  }

  Future<bool> isAdmin() async {
    final userData = await getCurrentUserData();
    return userData?.isAdmin ?? false;
  }

  Future<bool> isSecurity() async {
    final userData = await getCurrentUserData();
    return userData?.isSecurity ?? false;
  }

  Future<UserModel?> getUserById(String id) async {
    try {
      final record = await pb.collection('users').getOne(id);
      return UserModel.fromRecord(record);
    } catch (e) {
      debugPrint('Error getting user: $e');
      return null;
    }
  }

  Future<void> updateUserPoints(String id, int points) async {
    await pb.collection('users').update(id, body: {'points': points});
  }

  Future<void> addSecurityPoints(String id, int pointsToAdd) async {
    try {
      final record = await pb.collection('users').getOne(id);
      final currentPoints = (record.data['points'] ?? 0) as int;
      await pb.collection('users').update(
        id,
        body: {'points': currentPoints + pointsToAdd},
      );
    } catch (e) {
      debugPrint('Error adding points: $e');
    }
  }
}