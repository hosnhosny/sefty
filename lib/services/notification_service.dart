// lib/services/notification_service.dart
//
// إشعارات داخل التطبيق (in-app) فقط، مخزّنة في مجموعة "notifications"
// في PocketBase. لا يوجد Push Notification فعلي هنا (كان معطلاً أصلاً
// في نسخة Firebase القديمة أيضاً). إن أردت Push حقيقي لاحقاً، أضف
// OneSignal أو Firebase Cloud Messaging بشكل منفصل عن قاعدة البيانات.

import 'dart:async';
import 'package:pocketbase/pocketbase.dart';
import '../main.dart'; // العميل العام pb
import 'package:flutter/foundation.dart';

class NotificationService {
  Future<void> initialize() async {
    // لا حاجة لأي تهيئة خاصة بـ PocketBase هنا حالياً.
  }

  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await pb.collection('notifications').create(body: {
        'user_id': userId,
        'title': title,
        'body': body,
        'data': data,
        'read': false,
      });
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Error sending notification: $e');
    }
  }

  Future<void> notifyAdmin({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final admins = await pb.collection('users').getFullList(
        filter: 'role = "admin"',
      );
      for (final admin in admins) {
        await sendNotificationToUser(
          userId: admin.id,
          title: title,
          body: body,
          data: data,
        );
      }
    } catch (e) {
      debugPrint('Error notifying admins: $e');
    }
  }

  Future<void> notifyRedAlert(String employeeName, String employeeId) async {
    await notifyAdmin(
      title: '🚨 إنذار أحمر',
      body: 'الموظف $employeeName وصل 3 إنذارات - يجب عقد جلسة تأديبية',
      data: {
        'type': 'red_alert',
        'employeeId': employeeId,
        'employeeName': employeeName,
      },
    );
  }

  Future<void> notifyNewViolation(String employeeName) async {
    await notifyAdmin(
      title: 'مخالفة جديدة',
      body: 'تم تسجيل مخالفة جديدة على الموظف $employeeName',
      data: {
        'type': 'new_violation',
        'employeeName': employeeName,
      },
    );
  }

  Future<void> notifyNewReport(String securityName) async {
    await notifyAdmin(
      title: 'تقرير جديد',
      body: 'رجل السلامة $securityName قدم تقريراً جديداً',
      data: {
        'type': 'new_report',
        'securityName': securityName,
      },
    );
  }

  Future<void> notifyLateReturn(String employeeName, String leaveId) async {
    await notifyAdmin(
      title: 'تأخر في الرجوع',
      body: 'الموظف $employeeName تأخر عن وقت الرجوع المحدد',
      data: {
        'type': 'late_return',
        'leaveId': leaveId,
        'employeeName': employeeName,
      },
    );
  }

  Future<void> notifyNoReturn(String employeeName, String leaveId) async {
    await notifyAdmin(
      title: 'لم يعد',
      body: 'الموظف $employeeName لم يعد من إذن الانصراف',
      data: {
        'type': 'no_return',
        'leaveId': leaveId,
        'employeeName': employeeName,
      },
    );
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await pb.collection('notifications').update(notificationId, body: {
        'read': true,
        'read_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await pb.collection('notifications').delete(notificationId);
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  // ───────────────────────────────────────────────
  // Realtime streams (نفس أسلوب pb_service.dart)
  // ───────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> getNotifications(String userId) {
    return _watchNotifications(userId);
  }

  Stream<int> getUnreadCount(String userId) {
    return _watchNotifications(userId)
        .map((list) => list.where((n) => n['read'] == false).length);
  }

  Stream<List<Map<String, dynamic>>> _watchNotifications(String userId) {
    late StreamController<List<Map<String, dynamic>>> controller;
    UnsubscribeFunc? unsubscribe;

    Future<void> fetchAndEmit() async {
      try {
        final records = await pb.collection('notifications').getFullList(
          filter: pb.filter('user_id = {:id}', {'id': userId}),
          sort: '-created',
        );
        if (!controller.isClosed) {
          controller.add(records.map((r) => {'id': r.id, ...r.data}).toList());
        }
      } catch (e) {
        // لا نستخدم controller.addError هنا عمداً: أي شاشة تستمع للستريم
        // عبر .listen(...) بدون تمرير onError كانت ستتلقى استثناءً غير
        // معالَج (وهذا بالضبط ما كان يظهر في اللوق كـ Unhandled Exception).
        // بدل ذلك نتدهور بهدوء: نعرض قائمة فاضية (فيرجع العداد للصفر) لحين
        // إصلاح مجموعة "notifications" في PocketBase، دون كسر الشاشة.
        debugPrint('Error fetching notifications for "$userId": $e');
        if (!controller.isClosed) controller.add(const []);
      }
    }

    controller = StreamController<List<Map<String, dynamic>>>.broadcast(
      onListen: () async {
        await fetchAndEmit();
        try {
          unsubscribe = await pb.collection('notifications').subscribe(
            '*',
                (e) => fetchAndEmit(),
          );
        } catch (e) {
          // نفس منطق pb_service.dart: فشل الاشتراك اللحظي لا يكسر الشاشة،
          // البيانات (أو القائمة الفاضية) تبقى معروضة بدون تحديث لحظي فقط.
          debugPrint('Realtime subscribe failed for "notifications": $e');
        }
      },
      onCancel: () async {
        if (unsubscribe != null) await unsubscribe!();
      },
    );

    return controller.stream;
  }
}