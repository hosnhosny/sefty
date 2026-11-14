// lib/models/leave_model.dart

import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import '../utils/enums.dart';

class LeaveModel {
  final String? id;
  final String leaveNumber;
  final String receiptNumber; // الرقم التسلسلي المطبوع على الإيصال الورقي
  final DateTime createdAt;

  final String requestedById;
  final String requestedByName;

  final String employeeId;
  final String employeeName;
  final String employeeDepartment;

  final LeaveReason reason;
  final String? reasonDetails;

  final DateTime exitTime;
  final DateTime expectedReturn;
  final DateTime? actualReturn;

  final String evidenceUrl;

  final LeaveStatus status;

  final Duration? actualDuration;
  final bool isLate;

  LeaveModel({
    this.id,
    required this.leaveNumber,
    required this.receiptNumber,
    required this.createdAt,
    required this.requestedById,
    required this.requestedByName,
    required this.employeeId,
    required this.employeeName,
    required this.employeeDepartment,
    required this.reason,
    this.reasonDetails,
    required this.exitTime,
    required this.expectedReturn,
    this.actualReturn,
    required this.evidenceUrl,
    this.status = LeaveStatus.active,
    this.actualDuration,
    this.isLate = false,
  });

  /// يبني LeaveModel من RecordModel القادم من مجموعة "leaves" في PocketBase
  factory LeaveModel.fromRecord(RecordModel record) {
    final d = record.data;

    final actualReturn = (d['actual_return'] != null &&
        d['actual_return'].toString().isNotEmpty)
        ? DateTime.parse(d['actual_return'])
        : null;

    final exitTime = DateTime.parse(d['exit_time']);
    final expected = DateTime.parse(d['expected_return']);

    // حقل "created" لم يعد خاصية مخصصة مضمونة الوجود في RecordModel، لذلك
    // نقرأه عبر get<T> العام بدل record.created المهجورة، مع تعامل آمن
    // في حال كان غائباً أو فارغاً.
    final createdStr = record.get<String?>('created');

    return LeaveModel(
      id: record.id,
      leaveNumber: d['leave_number'] ?? '',
      receiptNumber: d['receipt_number'] ?? '',
      createdAt: (createdStr != null && createdStr.isNotEmpty)
          ? DateTime.parse(createdStr)
          : DateTime.now(),
      requestedById: d['requested_by_id'] ?? '',
      requestedByName: d['requested_by_name'] ?? '',
      employeeId: d['employee_id'] ?? '',
      employeeName: d['employee_name'] ?? '',
      employeeDepartment: d['employee_department'] ?? '',
      reason: LeaveReason.values.firstWhere(
            (e) => e.name == d['reason'],
        orElse: () => LeaveReason.other,
      ),
      reasonDetails: d['reason_details'],
      exitTime: exitTime,
      expectedReturn: expected,
      actualReturn: actualReturn,
      evidenceUrl: d['evidence_url'] ?? '',
      status: LeaveStatus.values.firstWhere(
            (e) => e.name == d['status'],
        orElse: () => LeaveStatus.active,
      ),
      actualDuration: actualReturn?.difference(exitTime),
      isLate: actualReturn != null ? actualReturn.isAfter(expected) : false,
    );
  }

  /// body لطلب create/update في PocketBase (pb.collection('leaves')...)
  Map<String, dynamic> toMap() {
    return {
      'leave_number': leaveNumber,
      'receipt_number': receiptNumber,
      'requested_by_id': requestedById,
      'requested_by_name': requestedByName,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'employee_department': employeeDepartment,
      'reason': reason.name,
      'reason_details': reasonDetails,
      'exit_time': exitTime.toIso8601String(),
      'expected_return': expectedReturn.toIso8601String(),
      'actual_return': actualReturn?.toIso8601String(),
      'evidence_url': evidenceUrl,
      'status': status.name,
    };
  }

  String get reasonLabel => reason.label;
  String get statusLabel => status.label;

  Color get statusColor {
    switch (status) {
      case LeaveStatus.active:
        return Colors.orange;
      case LeaveStatus.returned:
        return isLate ? Colors.red : Colors.green;
      case LeaveStatus.noReturn:
        return Colors.red.shade900;
      case LeaveStatus.late:
        return Colors.red;
    }
  }

  String get formattedDuration {
    if (actualDuration == null) return '---';
    final hours = actualDuration!.inHours;
    final minutes = actualDuration!.inMinutes % 60;
    return '$hoursس $minutesد';
  }

  LeaveModel copyWith({
    String? leaveNumber,
    String? receiptNumber,
    DateTime? createdAt,
    String? requestedById,
    String? requestedByName,
    String? employeeId,
    String? employeeName,
    String? employeeDepartment,
    LeaveReason? reason,
    String? reasonDetails,
    DateTime? exitTime,
    DateTime? expectedReturn,
    DateTime? actualReturn,
    String? evidenceUrl,
    LeaveStatus? status,
  }) {
    return LeaveModel(
      id: id,
      leaveNumber: leaveNumber ?? this.leaveNumber,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      createdAt: createdAt ?? this.createdAt,
      requestedById: requestedById ?? this.requestedById,
      requestedByName: requestedByName ?? this.requestedByName,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      employeeDepartment: employeeDepartment ?? this.employeeDepartment,
      reason: reason ?? this.reason,
      reasonDetails: reasonDetails ?? this.reasonDetails,
      exitTime: exitTime ?? this.exitTime,
      expectedReturn: expectedReturn ?? this.expectedReturn,
      actualReturn: actualReturn ?? this.actualReturn,
      evidenceUrl: evidenceUrl ?? this.evidenceUrl,
      status: status ?? this.status,
    );
  }
}