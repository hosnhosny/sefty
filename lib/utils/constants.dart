import 'package:flutter/material.dart';

class AppColors {
  static const Color primary   = Color(0xFF1565C0);
  static const Color secondary = Color(0xFF00838F);
  static const Color accent    = Color(0xFFFF6F00);

  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF9A825);
  static const Color error   = Color(0xFFC62828);
  static const Color info    = Color(0xFF0277BD);

  // Severity
  static const Color light    = Color(0xFFFFEB3B);
  static const Color medium   = Color(0xFFFF9800);
  static const Color major    = Color(0xFFF44336);
  static const Color critical = Color(0xFF212121);

  // Warning levels
  static const Color warning1 = Color(0xFFFFF176);
  static const Color warning2 = Color(0xFFFFB74D);
  static const Color warning3 = Color(0xFFE57373);
}

class AppStrings {
  static const String appName     = 'نظام الأمن والسلامة';
  static const String companyName = 'ALDAFNIYA FOOD COMPLEX';
  static const String companyAr   = 'مجمع الدافنية الغذائي';

  // Roles
  static const String admin    = 'مدير';
  static const String security = 'رجل أمن وسلامة';

  // Violation
  static const String violationNumber  = 'رقم المخالفة';
  static const String violationType    = 'نوع المخالفة';
  static const String violationDetails = 'تفاصيل المخالفة';
  static const String severity         = 'درجة الخطورة';
  static const String evidence         = 'الدليل';

  // Leave
  static const String leaveNumber     = 'رقم الإذن';
  static const String exitTime        = 'وقت الخروج';
  static const String expectedReturn  = 'وقت الرجوع المتوقع';
  static const String actualReturn    = 'وقت الرجوع الفعلي';

  // Employee
  static const String employeeName = 'اسم الموظف';
  static const String employeeId   = 'الرقم الوظيفي';
  static const String department   = 'القسم';

  // Buttons
  static const String save   = 'حفظ';
  static const String cancel = 'إلغاء';
  static const String submit = 'إرسال';
  static const String delete = 'حذف';
  static const String edit   = 'تعديل';
  static const String search = 'بحث';

  // Messages
  static const String successMsg = 'تم بنجاح';
  static const String errorMsg   = 'حدث خطأ';
  static const String loading    = 'جاري التحميل...';
  static const String noData     = 'لا توجد بيانات';

  // Departments
  static const List<String> departments = [
    'الإنتاج',
    'التعبئة والتغليف',
    'المستودع',
    'الصيانة',
    'الجودة',
    'المختبر',
    'الإدارة',
    'السلامة',
    'النقل',
    'أخرى',
  ];

  // Violation types (Amn & Salama)
  static const List<String> violationTypes = [
    'عدم ارتداء خوذة الحماية',
    'عدم ارتداء حذاء السلامة',
    'عدم ارتداء قناع الوجه',
    'عدم ارتداء قفازات الحماية',
    'عدم ارتداء نظارات السلامة',
    'عدم ارتداء سترة الأمان',
    'التدخين في منطقة ممنوعة',
    'الإهمال في التعامل مع المواد الكيميائية',
    'عدم اتباع إجراءات السلامة',
    'ترك المعدات بدون حراسة',
    'العمل بدون إذن في منطقة خطرة',
    'إزالة لافتات التحذير',
    'استخدام معدات تالفة',
    'سلوك غير آمن',
    'مخالفة أخرى',
  ];
}

class AppSizes {
  static const double padding       = 16.0;
  static const double smallPadding  = 8.0;
  static const double largePadding  = 24.0;

  static const double borderRadius  = 12.0;
  static const double smallRadius   = 8.0;
  static const double largeRadius   = 16.0;

  static const double buttonHeight  = 52.0;
  static const double iconSize      = 24.0;
  static const double avatarSize    = 40.0;
}
