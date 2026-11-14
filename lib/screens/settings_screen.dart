import 'package:flutter/material.dart';
import '../services/theme_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService.isDarkMode;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('إعدادات التطبيق'),
          actions: [
            // زر سريع في شريط العنوان للتبديل بين الوضعين
            ValueListenableBuilder<ThemeMode>(
              valueListenable: ThemeService.themeNotifier,
              builder: (context, currentMode, child) {
                final isDark = currentMode == ThemeMode.dark;
                return IconButton(
                  icon: Icon(
                    isDark ? Icons.dark_mode : Icons.light_mode,
                    color: isDark ? Colors.amber : Colors.white,
                  ),
                  onPressed: () => ThemeService.toggleTheme(),
                  tooltip: isDark ? 'التحويل للوضع الفاتح' : 'التحويل للوضع الداكن',
                );
              },
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
              child: Text(
                'المظهر والتفضيلات',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ),

            // كارت تفعيل/إلغاء الوضع الداكن
            Card(
              child: ValueListenableBuilder<ThemeMode>(
                valueListenable: ThemeService.themeNotifier,
                builder: (context, currentMode, child) {
                  final isDark = currentMode == ThemeMode.dark;
                  return SwitchListTile(
                    title: const Text(
                      'الوضع الداكن (Dark Mode)',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      isDark
                          ? 'تطبيق الألوان الداكنة لراحة العين'
                          : 'تطبيق الألوان الفاتحة القياسية',
                      style: TextStyle(
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                    secondary: CircleAvatar(
                      backgroundColor: isDark
                          ? Colors.amber.withValues(alpha: 0.2)
                          : Colors.blue.withValues(alpha: 0.1),
                      child: Icon(
                        isDark ? Icons.dark_mode : Icons.light_mode,
                        color: isDark ? Colors.amber : Colors.blue,
                      ),
                    ),
                    value: isDark,
                    onChanged: (bool value) {
                      ThemeService.setTheme(value);
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // معلومات إضافية
            Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.blue),
                title: const Text('عن التطبيق'),
                subtitle: const Text('نظام الأمن والسلامة - ALDAFNIYA FOOD COMPLEX'),
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'نظام الأمن والسلامة',
                    applicationVersion: '1.0.0',
                    applicationIcon: const Icon(Icons.security, color: Color(0xFF1565C0), size: 40),
                    children: [
                      const Text('تم تطويره لإدارة المخالفات والأذونات والتقارير في مجمع الصافي الغذائي.'),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}