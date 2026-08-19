// lib/models/violation_model.dart

import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import '../utils/enums.dart';

class ViolationModel {
  final String? id;
  final String violationNumber;
  final DateTime createdAt;

  final String securityOfficerId;
  final String securityOfficerName;

  final String? cameraOfficerId; // معرّف رجل الكاميرات المساعد (اختياري)
  final String? cameraOfficerName; // اسم رجل الكاميرات المساعد (اختياري)

  final String employeeId;
  final String employeeName;
  final String employeeDepartment;

  final String customType;
  final ViolationSeverity severity;
  final String details;
  final List<String> evidenceUrls;
  final String location;

  final bool exportedToExcel;
  final DateTime? excelExportDate;

  final int warningCount;

  final ViolationStatus status;
  final String? managerComment;
  final String? fixImageUrl;
  final DateTime? reviewedAt;
  final DateTime? closedAt;

  /// ── القبول المالي (مستقل تمامًا عن status الأصلي) ──────────────────
  /// قيمة الخصم التي حددها المدير عند قبول المخالفة (0 = لم يُحدَّد بعد)
  final double fineAmount;
  /// هل تم بالفعل إيداع 50/50 في محفظتَي رجل الأمن ورجل الكاميرات؟
  /// (حماية من الإيداع المزدوج عند الضغط أكثر من مرة)
  final bool walletCredited;
  final DateTime? fineApprovedAt;

  ViolationModel({
    this.id,
    required this.violationNumber,
    required this.createdAt,
    required this.securityOfficerId,
    required this.securityOfficerName,
    this.cameraOfficerId,
    this.cameraOfficerName,
    required this.employeeId,
    required this.employeeName,
    required this.employeeDepartment,
    required this.customType,
    required this.severity,
    this.details = '',
    this.evidenceUrls = const [],
    this.location = '',
    this.exportedToExcel = false,
    this.excelExportDate,
    this.warningCount = 0,
    this.status = ViolationStatus.newViolation,
    this.managerComment,
    this.fixImageUrl,
    this.reviewedAt,
    this.closedAt,
    this.fineAmount = 0.0,
    this.walletCredited = false,
    this.fineApprovedAt,
  });

  /// يبني ViolationModel من RecordModel القادم من مجموعة "violations" في PocketBase
  factory ViolationModel.fromRecord(RecordModel record) {
    final d = record.data;

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      final s = v.toString();
      if (s.isEmpty) return null;
      return DateTime.parse(s);
    }

    return ViolationModel(
      id: record.id,
      violationNumber: d['violation_number'] ?? '',
      createdAt: record.created.isNotEmpty
          ? DateTime.parse(record.created)
          : DateTime.now(),
      securityOfficerId: d['security_officer_id'] ?? '',
      securityOfficerName: d['security_officer_name'] ?? '',
      cameraOfficerId: (d['camera_officer_id'] as String?)?.isEmpty == true
          ? null
          : d['camera_officer_id'],
      cameraOfficerName:
      (d['camera_officer_name'] as String?)?.isEmpty == true
          ? null
          : d['camera_officer_name'],
      employeeId: d['employee_id'] ?? '',
      employeeName: d['employee_name'] ?? '',
      employeeDepartment: d['employee_department'] ?? '',
      customType: d['custom_type'] ?? '',
      severity: ViolationSeverity.values.firstWhere(
            (e) => e.name == d['severity'],
        orElse: () => ViolationSeverity.light,
      ),
      details: d['details'] ?? '',
      evidenceUrls: d['evidence_urls'] != null
          ? List<String>.from(d['evidence_urls'])
          .where(isValidEvidenceUrl)
          .toList()
          : const [],
      location: d['location'] ?? '',
      exportedToExcel: d['exported_to_excel'] ?? false,
      excelExportDate: parseDate(d['excel_export_date']),
      warningCount: d['warning_count'] ?? 0,
      status: ViolationStatus.values.firstWhere(
            (e) => e.name == d['status'],
        orElse: () => ViolationStatus.newViolation,
      ),
      managerComment: d['manager_comment'],
      fixImageUrl: isValidEvidenceUrl(d['fix_image_url'] ?? '')
          ? d['fix_image_url']
          : null,
      reviewedAt: parseDate(d['reviewed_at']),
      closedAt: parseDate(d['closed_at']),
      fineAmount: (d['fine_amount'] ?? 0).toDouble(),
      walletCredited: d['wallet_credited'] ?? false,
      fineApprovedAt: parseDate(d['fine_approved_at']),
    );
  }

  /// body لطلب create/update في PocketBase (pb.collection('violations')...)
  Map<String, dynamic> toMap() {
    return {
      'violation_number': violationNumber,
      'security_officer_id': securityOfficerId,
      'security_officer_name': securityOfficerName,
      'camera_officer_id': cameraOfficerId,
      'camera_officer_name': cameraOfficerName,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'employee_department': employeeDepartment,
      'custom_type': customType,
      'severity': severity.name,
      'details': details,
      'evidence_urls': evidenceUrls,
      'location': location,
      'exported_to_excel': exportedToExcel,
      'excel_export_date': excelExportDate?.toIso8601String(),
      'warning_count': warningCount,
      'status': status.name,
      'manager_comment': managerComment,
      'fix_image_url': fixImageUrl,
      'reviewed_at': reviewedAt?.toIso8601String(),
      'closed_at': closedAt?.toIso8601String(),
      'fine_amount': fineAmount,
      'wallet_credited': walletCredited,
      'fine_approved_at': fineApprovedAt?.toIso8601String(),
    };
  }

  /// يتحقق أن الرابط صالح فعلاً (وليس فارغاً أو مساراً محلياً تالفاً)
  static bool isValidEvidenceUrl(String url) {
    final u = url.trim();
    return u.isNotEmpty && (u.startsWith('http://') || u.startsWith('https://'));
  }

  /// يحدد إذا كان رابط الدليل فيديو (Cloudinary يضع الفيديوهات تحت /video/upload/)
  static bool isVideoUrl(String url) {
    final u = url.toLowerCase();
    return u.contains('/video/upload/') ||
        u.endsWith('.mp4') ||
        u.endsWith('.mov') ||
        u.endsWith('.webm') ||
        u.endsWith('.avi') ||
        u.endsWith('.m4v');
  }

  /// روابط الصور فقط من قائمة الأدلة
  List<String> get imageEvidenceUrls =>
      evidenceUrls.where((u) => !isVideoUrl(u)).toList();

  /// روابط الفيديو فقط من قائمة الأدلة
  List<String> get videoEvidenceUrls =>
      evidenceUrls.where(isVideoUrl).toList();

  String get severityLabel => severity.label;
  int get severityPoints => severity.points;

  Color get severityColor {
    switch (severity) {
      case ViolationSeverity.light:
        return const Color(0xFFFFF176);
      case ViolationSeverity.medium:
        return const Color(0xFFFFB74D);
      case ViolationSeverity.major:
        return const Color(0xFFE57373);
      case ViolationSeverity.critical:
        return const Color(0xFF212121);
    }
  }

  Color get severityTextColor {
    switch (severity) {
      case ViolationSeverity.light:
        return Colors.black87;
      case ViolationSeverity.medium:
      case ViolationSeverity.major:
      case ViolationSeverity.critical:
        return Colors.white;
    }
  }

  bool get isRedAlert => warningCount >= 3;

  /// هل ينتظر قرار المدير المالي (قبول بمبلغ خصم أو رفض)؟
  bool get isPendingFineApproval =>
      fineApprovedAt == null && status != ViolationStatus.rejected;

  /// هل تم قبول المخالفة ماليًا وتحديد قيمة الخصم؟
  bool get isFineApproved => fineApprovedAt != null && fineAmount > 0;

  bool get requiresReview =>
      severity == ViolationSeverity.major ||
          severity == ViolationSeverity.critical;

  ViolationModel copyWith({
    String? violationNumber,
    DateTime? createdAt,
    String? securityOfficerId,
    String? securityOfficerName,
    String? cameraOfficerId,
    String? cameraOfficerName,
    String? employeeId,
    String? employeeName,
    String? employeeDepartment,
    String? customType,
    ViolationSeverity? severity,
    String? details,
    List<String>? evidenceUrls,
    String? location,
    bool? exportedToExcel,
    DateTime? excelExportDate,
    int? warningCount,
    ViolationStatus? status,
    String? managerComment,
    String? fixImageUrl,
    DateTime? reviewedAt,
    DateTime? closedAt,
    double? fineAmount,
    bool? walletCredited,
    DateTime? fineApprovedAt,
  }) {
    return ViolationModel(
      id: id,
      violationNumber: violationNumber ?? this.violationNumber,
      createdAt: createdAt ?? this.createdAt,
      securityOfficerId: securityOfficerId ?? this.securityOfficerId,
      securityOfficerName: securityOfficerName ?? this.securityOfficerName,
      cameraOfficerId: cameraOfficerId ?? this.cameraOfficerId,
      cameraOfficerName: cameraOfficerName ?? this.cameraOfficerName,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      employeeDepartment: employeeDepartment ?? this.employeeDepartment,
      customType: customType ?? this.customType,
      severity: severity ?? this.severity,
      details: details ?? this.details,
      evidenceUrls: evidenceUrls ?? this.evidenceUrls,
      location: location ?? this.location,
      exportedToExcel: exportedToExcel ?? this.exportedToExcel,
      excelExportDate: excelExportDate ?? this.excelExportDate,
      warningCount: warningCount ?? this.warningCount,
      status: status ?? this.status,
      managerComment: managerComment ?? this.managerComment,
      fixImageUrl: fixImageUrl ?? this.fixImageUrl,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      closedAt: closedAt ?? this.closedAt,
      fineAmount: fineAmount ?? this.fineAmount,
      walletCredited: walletCredited ?? this.walletCredited,
      fineApprovedAt: fineApprovedAt ?? this.fineApprovedAt,
    );
  }
}