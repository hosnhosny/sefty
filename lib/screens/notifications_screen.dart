// lib/screens/notifications_screen.dart
//
// شاشة إشعارات مشتركة تُستخدم من لوحة المدير ومن شاشة الموظف (رجل الأمن).
// تعرض الإشعارات المخزّنة في مجموعة "notifications" بـ PocketBase،
// وتسمح بتمييزها كمقروءة عند فتحها.

import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';

class NotificationsScreen extends StatefulWidget {
  final String userId;
  const NotificationsScreen({super.key, required this.userId});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _notificationService = NotificationService();

  IconData _iconFor(String? type) {
    switch (type) {
      case 'red_alert':
        return Icons.notification_important;
      case 'new_violation':
        return Icons.warning_amber;
      case 'new_report':
        return Icons.picture_as_pdf;
      case 'late_return':
      case 'no_return':
        return Icons.exit_to_app;
      default:
        return Icons.notifications;
    }
  }

  Color _colorFor(String? type) {
    switch (type) {
      case 'red_alert':
        return Colors.red;
      case 'new_violation':
        return Colors.orange;
      case 'new_report':
        return Colors.purple;
      case 'late_return':
      case 'no_return':
        return Colors.amber.shade800;
      default:
        return AppColors.primary;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
    if (diff.inDays < 30) return 'منذ ${diff.inDays} يوم';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          title: const Text('الإشعارات'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _notificationService.getNotifications(widget.userId),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Text(
                  'تعذر تحميل الإشعارات',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              );
            }
            final items = snap.data ?? [];
            if (items.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_off_outlined,
                        size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text(
                      'لا توجد إشعارات حالياً',
                      style:
                      TextStyle(color: Colors.grey.shade600, fontSize: 16),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final n = items[i];
                final bool isRead = n['read'] == true;
                final String type =
                (n['data'] is Map) ? (n['data']['type'] ?? '') : '';
                DateTime created;
                try {
                  created = DateTime.parse(n['created'] ?? '');
                } catch (_) {
                  created = DateTime.now();
                }

                return Card(
                  elevation: isRead ? 0 : 2,
                  color: isRead ? Colors.white : Colors.blue.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: isRead
                        ? BorderSide(color: Colors.grey.shade200)
                        : BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: ListTile(
                    onTap: () {
                      if (!isRead) {
                        _notificationService.markAsRead(n['id']);
                      }
                    },
                    leading: CircleAvatar(
                      backgroundColor: _colorFor(type).withValues(alpha: 0.15),
                      child: Icon(_iconFor(type), color: _colorFor(type)),
                    ),
                    title: Text(
                      n['title'] ?? '',
                      style: TextStyle(
                        fontWeight:
                        isRead ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(n['body'] ?? ''),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _timeAgo(created),
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 11),
                        ),
                        if (!isRead) ...[
                          const SizedBox(height: 6),
                          Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
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