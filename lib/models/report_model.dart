// lib/models/report_model.dart

import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

class ReportModel {
  final String? id;
  final String reportNumber;
  final DateTime createdAt;

  final String createdById;
  final String createdByName;

  final String title;
  final String content;
  final String type; // 'daily' | 'incident' | 'monthly' | 'patrol'

  final String pdfUrl;
  final String? fileName;
  final int? fileSize;

  final String status; // 'pending' | 'approved' | 'rejected'
  final String? managerComment;
  final DateTime? reviewedAt;

  final List<String>? attachments;

  ReportModel({
    this.id,
    required this.reportNumber,
    required this.createdAt,
    required this.createdById,
    required this.createdByName,
    required this.title,
    required this.content,
    this.type = 'daily',
    required this.pdfUrl,
    this.fileName,
    this.fileSize,
    this.status = 'pending',
    this.managerComment,
    this.reviewedAt,
    this.attachments,
  });

  /// يبني ReportModel من RecordModel القادم من مجموعة "reports" في PocketBase
  factory ReportModel.fromRecord(RecordModel record) {
    final d = record.data;

    return ReportModel(
      id: record.id,
      reportNumber: d['report_number'] ?? '',
      createdAt: record.created.isNotEmpty
          ? DateTime.parse(record.created)
          : DateTime.now(),
      createdById: d['created_by_id'] ?? '',
      createdByName: d['created_by_name'] ?? '',
      title: d['title'] ?? '',
      content: d['content'] ?? '',
      type: d['type'] ?? 'daily',
      pdfUrl: d['pdf_url'] ?? '',
      fileName: d['file_name'],
      fileSize: d['file_size'],
      status: d['status'] ?? 'pending',
      managerComment: d['manager_comment'],
      reviewedAt: (d['reviewed_at'] != null &&
          d['reviewed_at'].toString().isNotEmpty)
          ? DateTime.parse(d['reviewed_at'])
          : null,
      attachments:
      d['attachments'] != null ? List<String>.from(d['attachments']) : null,
    );
  }

  /// body لطلب create/update في PocketBase (pb.collection('reports')...)
  Map<String, dynamic> toMap() {
    return {
      'report_number': reportNumber,
      'created_by_id': createdById,
      'created_by_name': createdByName,
      'title': title,
      'content': content,
      'type': type,
      'pdf_url': pdfUrl,
      'file_name': fileName,
      'file_size': fileSize,
      'status': status,
      'manager_comment': managerComment,
      'reviewed_at': reviewedAt?.toIso8601String(),
      'attachments': attachments,
    };
  }

  String get typeLabel {
    switch (type) {
      case 'daily':
        return 'يومي';
      case 'incident':
        return 'حادث';
      case 'monthly':
        return 'شهري';
      case 'patrol':
        return 'جولة';
      default:
        return 'آخر';
    }
  }

  Color get statusColor {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'بانتظار المراجعة';
      case 'approved':
        return 'تمت الموافقة';
      case 'rejected':
        return 'مرفوض';
      default:
        return '---';
    }
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  ReportModel copyWith({
    String? reportNumber,
    DateTime? createdAt,
    String? createdById,
    String? createdByName,
    String? title,
    String? content,
    String? type,
    String? pdfUrl,
    String? fileName,
    int? fileSize,
    String? status,
    String? managerComment,
    DateTime? reviewedAt,
    List<String>? attachments,
  }) {
    return ReportModel(
      id: id,
      reportNumber: reportNumber ?? this.reportNumber,
      createdAt: createdAt ?? this.createdAt,
      createdById: createdById ?? this.createdById,
      createdByName: createdByName ?? this.createdByName,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      status: status ?? this.status,
      managerComment: managerComment ?? this.managerComment,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      attachments: attachments ?? this.attachments,
    );
  }
}
