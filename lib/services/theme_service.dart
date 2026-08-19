import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static const String _themePreferenceKey = "is_dark_mode";

  // متصل مع الواجهات لإعادة البناء فور التغيير
  static final ValueNotifier<ThemeMode> themeNotifier =
  ValueNotifier(ThemeMode.light);

  /// تحميل الخيار المحفوظ عند تشغيل التطبيق
  static Future<void> initTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_themePreferenceKey) ?? false;
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  /// التبديل بين الوضع الفاتح والداكن وحفظ الحالة
  static Future<void> toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    if (themeNotifier.value == ThemeMode.light) {
      themeNotifier.value = ThemeMode.dark;
      await prefs.setBool(_themePreferenceKey, true);
    } else {
      themeNotifier.value = ThemeMode.light;
      await prefs.setBool(_themePreferenceKey, false);
    }
  }

  /// تعيين وضع محدد (فاتح / داكن) وحفظ الخيار
  static Future<void> setTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
    await prefs.setBool(_themePreferenceKey, isDark);
  }

  /// التحقق مما إذا كان الوضع الحالي داكن أم لا
  static bool get isDarkMode => themeNotifier.value == ThemeMode.dark;
}