// lib/utils/enums.dart

import 'package:flutter/material.dart';

enum ViolationSeverity {
  light,      // خفيفة
  medium,     // متوسطة
  major,      // كبيرة
  critical,   // خطيرة جداً
}

enum ViolationStatus {
  newViolation,     // جديدة
  inProgress,       // قيد المعالجة
  awaitingVerify,   // بانتظار التأكيد
  closed,           // مغلقة ومصلحة
  rejected,         // مرفوضة
}

enum LeaveReason {
  medical,    // زيارة طبيب
  family,     // ظرف عائلي
  official,   // موعد رسمي
  personal,   // شخصي  ← جديد
  emergency,  // طارئ   ← جديد
  other,      // أخرى
}

enum LeaveStatus {
  active,     // نشط (خارج)
  returned,   // عاد
  noReturn,   // لم يعد
  late,       // تأخر
}

enum UserRole {
  admin,      // مدير
  security,   // رجل أمن وسلامة
}

extension ViolationSeverityExtension on ViolationSeverity {
  String get label {
    switch (this) {
      case ViolationSeverity.light:    return 'خفيفة';
      case ViolationSeverity.medium:   return 'متوسطة';
      case ViolationSeverity.major:    return 'كبيرة';
      case ViolationSeverity.critical: return 'خطيرة جداً';
    }
  }

  int get points {
    switch (this) {
      case ViolationSeverity.light:    return 1;
      case ViolationSeverity.medium:   return 2;
      case ViolationSeverity.major:    return 3;
      case ViolationSeverity.critical: return 4;
    }
  }
}

extension LeaveReasonExtension on LeaveReason {
  String get label {
    switch (this) {
      case LeaveReason.medical:   return 'زيارة طبيب';
      case LeaveReason.family:    return 'ظرف عائلي';
      case LeaveReason.official:  return 'موعد رسمي';
      case LeaveReason.personal:  return 'شخصي';
      case LeaveReason.emergency: return 'طارئ';
      case LeaveReason.other:     return 'أخرى';
    }
  }
}

extension LeaveStatusExtension on LeaveStatus {
  String get label {
    switch (this) {
      case LeaveStatus.active:    return 'خارج';
      case LeaveStatus.returned:  return 'عاد';
      case LeaveStatus.noReturn:  return 'لم يعد';
      case LeaveStatus.late:      return 'تأخر';
    }
  }
}

extension ViolationStatusExtension on ViolationStatus {
  String get label {
    switch (this) {
      case ViolationStatus.newViolation:   return 'جديدة';
      case ViolationStatus.inProgress:     return 'قيد المعالجة';
      case ViolationStatus.awaitingVerify: return 'بانتظار التأكيد';
      case ViolationStatus.closed:         return 'مغلقة';
      case ViolationStatus.rejected:       return 'مرفوضة';
    }
  }

  String get emoji {
    switch (this) {
      case ViolationStatus.newViolation:   return '🔴';
      case ViolationStatus.inProgress:     return '🟡';
      case ViolationStatus.awaitingVerify: return '🔵';
      case ViolationStatus.closed:         return '✅';
      case ViolationStatus.rejected:       return '❌';
    }
  }

  Color get color {
    switch (this) {
      case ViolationStatus.newViolation:   return const Color(0xFFC62828);
      case ViolationStatus.inProgress:     return const Color(0xFFF9A825);
      case ViolationStatus.awaitingVerify: return const Color(0xFF0277BD);
      case ViolationStatus.closed:         return const Color(0xFF2E7D32);
      case ViolationStatus.rejected:       return const Color(0xFF6D4C41);
    }
  }
}
