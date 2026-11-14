import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import '../main.dart'; // العميل العام pb
import '../models/leave_model.dart';
import '../models/violation_model.dart';
import 'pb_service.dart';

class ExcelService {
  final DatabaseService _db = DatabaseService();

  // ───────────────────────────────────────────────
  // SHARE HELPER (share_plus الحديثة)
  // ───────────────────────────────────────────────

  Future<void> _shareFile(String path, String text) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path)],
        text: text,
      ),
    );
  }

  // ───────────────────────────────────────────────
  // EXPORT VIOLATIONS
  // ───────────────────────────────────────────────

  Future<String?> exportViolationsToExcel({
    bool onlyUnexported = true,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final filters = <String>[];
      if (onlyUnexported) filters.add('exported_to_excel = false');
      if (startDate != null) {
        filters.add(pb.filter(
          'created >= {:start}',
          {'start': startDate.toIso8601String()},
        ));
      }
      if (endDate != null) {
        filters.add(pb.filter(
          'created <= {:end}',
          {'end': endDate.toIso8601String()},
        ));
      }

      final records = await pb.collection('violations').getFullList(
        filter: filters.isEmpty ? null : filters.join(' && '),
        sort: 'created',
      );

      if (records.isEmpty) return null;

      final violations = records.map(ViolationModel.fromRecord).toList();

      final workbook = xlsio.Workbook();
      final sheet = workbook.worksheets[0];
      sheet.name = 'المخالفات';

      final headers = [
        'رقم المخالفة',
        'التاريخ',
        'الوقت',
        'رجل السلامة',
        'الموظف المخالف',
        'الرقم الوظيفي',
        'القسم',
        'نوع المخالفة',
        'درجة الخطورة',
        'التفاصيل',
        'الموقع',
        'عدد الإنذارات',
        'تم التصدير',
      ];

      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.getRangeByIndex(1, i + 1);
        cell.setText(headers[i]);
        cell.cellStyle.bold = true;
        cell.cellStyle.backColor = '#4472C4';
        cell.cellStyle.fontColor = '#FFFFFF';
      }

      int row = 2;
      final List<String> exportedIds = [];

      for (final v in violations) {
        sheet.getRangeByIndex(row, 1).setText(v.violationNumber);
        sheet.getRangeByIndex(row, 2).setText(
          '${v.createdAt.year}/${v.createdAt.month.toString().padLeft(2, '0')}/${v.createdAt.day.toString().padLeft(2, '0')}',
        );
        sheet.getRangeByIndex(row, 3).setText(
          '${v.createdAt.hour.toString().padLeft(2, '0')}:${v.createdAt.minute.toString().padLeft(2, '0')}',
        );
        sheet.getRangeByIndex(row, 4).setText(v.securityOfficerName);
        sheet.getRangeByIndex(row, 5).setText(v.employeeName);
        sheet.getRangeByIndex(row, 6).setText(v.employeeId);
        sheet.getRangeByIndex(row, 7).setText(v.employeeDepartment);
        sheet.getRangeByIndex(row, 8).setText(v.customType);
        sheet.getRangeByIndex(row, 9).setText(v.severityLabel);
        sheet.getRangeByIndex(row, 10).setText(v.details);
        sheet.getRangeByIndex(row, 11).setText(v.location);
        sheet.getRangeByIndex(row, 12).setNumber(v.warningCount.toDouble());
        sheet.getRangeByIndex(row, 13).setText(v.exportedToExcel ? 'نعم' : 'لا');

        final severityCell = sheet.getRangeByIndex(row, 9);
        switch (v.severity.name) {
          case 'light':
            severityCell.cellStyle.backColor = '#FFF176';
            break;
          case 'medium':
            severityCell.cellStyle.backColor = '#FFB74D';
            break;
          case 'major':
            severityCell.cellStyle.backColor = '#E57373';
            severityCell.cellStyle.fontColor = '#FFFFFF';
            break;
          case 'critical':
            severityCell.cellStyle.backColor = '#212121';
            severityCell.cellStyle.fontColor = '#FFFFFF';
            break;
        }

        if (v.id != null) exportedIds.add(v.id!);
        row++;
      }

      for (int i = 1; i <= headers.length; i++) {
        sheet.getRangeByIndex(1, i).autoFitColumns();
      }

      final dir = await getApplicationDocumentsDirectory();
      final fileName =
          'violations_${DateTime.now().toIso8601String().split('T')[0]}.xlsx';
      final path = '${dir.path}/$fileName';
      final file = File(path);
      final bytes = workbook.saveAsStream();
      await file.writeAsBytes(bytes);
      workbook.dispose();

      if (onlyUnexported && exportedIds.isNotEmpty) {
        await _db.batchMarkAsExported(exportedIds);
      }

      await _shareFile(
        path,
        'تقرير المخالفات - ${DateTime.now().toIso8601String().split('T')[0]}',
      );

      return path;
    } catch (e) {
      debugPrint('Error exporting violations: $e');
      return null;
    }
  }

  // ───────────────────────────────────────────────
  // EXPORT LEAVES
  // ───────────────────────────────────────────────

  Future<String?> exportLeavesToExcel({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final filters = <String>[];
      if (startDate != null) {
        filters.add(pb.filter(
          'created >= {:start}',
          {'start': startDate.toIso8601String()},
        ));
      }
      if (endDate != null) {
        filters.add(pb.filter(
          'created <= {:end}',
          {'end': endDate.toIso8601String()},
        ));
      }

      final records = await pb.collection('leaves').getFullList(
        filter: filters.isEmpty ? null : filters.join(' && '),
        sort: 'created',
      );

      if (records.isEmpty) return null;

      final leaves = records.map(LeaveModel.fromRecord).toList();

      final workbook = xlsio.Workbook();
      final sheet = workbook.worksheets[0];
      sheet.name = 'إذن الانصراف';
      _fillLeavesSheet(sheet, leaves);

      for (int i = 1; i <= 10; i++) {
        sheet.getRangeByIndex(1, i).autoFitColumns();
      }

      final dir = await getApplicationDocumentsDirectory();
      final fileName =
          'leaves_${DateTime.now().toIso8601String().split('T')[0]}.xlsx';
      final path = '${dir.path}/$fileName';
      final file = File(path);
      final bytes = workbook.saveAsStream();
      await file.writeAsBytes(bytes);
      workbook.dispose();

      await _shareFile(
        path,
        'تقرير إذن الانصراف - ${DateTime.now().toIso8601String().split('T')[0]}',
      );

      return path;
    } catch (e) {
      debugPrint('Error exporting leaves: $e');
      return null;
    }
  }

  // ───────────────────────────────────────────────
  // EXPORT ALL (Combined)
  // ───────────────────────────────────────────────

  Future<String?> exportAllToExcel() async {
    try {
      final violationRecords =
      await pb.collection('violations').getFullList(sort: 'created');
      final leaveRecords =
      await pb.collection('leaves').getFullList(sort: 'created');

      if (violationRecords.isEmpty && leaveRecords.isEmpty) return null;

      final violations =
      violationRecords.map(ViolationModel.fromRecord).toList();
      final leaves = leaveRecords.map(LeaveModel.fromRecord).toList();

      final workbook = xlsio.Workbook();

      if (violations.isNotEmpty) {
        final vSheet = workbook.worksheets[0];
        vSheet.name = 'المخالفات';
        _fillViolationsSheet(vSheet, violations);
      }

      if (leaves.isNotEmpty) {
        final lSheet = workbook.worksheets.addWithName('إذن الانصراف');
        _fillLeavesSheet(lSheet, leaves);
      }

      final dir = await getApplicationDocumentsDirectory();
      final fileName =
          'full_report_${DateTime.now().toIso8601String().split('T')[0]}.xlsx';
      final path = '${dir.path}/$fileName';
      final file = File(path);
      final bytes = workbook.saveAsStream();
      await file.writeAsBytes(bytes);
      workbook.dispose();

      await _shareFile(
        path,
        'التقرير الشامل - ${DateTime.now().toIso8601String().split('T')[0]}',
      );

      return path;
    } catch (e) {
      debugPrint('Error exporting all: $e');
      return null;
    }
  }

  // ───────────────────────────────────────────────
  // HELPER METHODS
  // ───────────────────────────────────────────────

  void _fillViolationsSheet(
      xlsio.Worksheet sheet, List<ViolationModel> violations) {
    final headers = [
      'رقم المخالفة', 'التاريخ', 'الوقت', 'رجل السلامة',
      'الموظف', 'الرقم الوظيفي', 'القسم', 'نوع المخالفة',
      'الخطورة', 'التفاصيل', 'الموقع', 'الإنذارات',
    ];

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.getRangeByIndex(1, i + 1);
      cell.setText(headers[i]);
      cell.cellStyle.bold = true;
    }

    int row = 2;
    for (final v in violations) {
      sheet.getRangeByIndex(row, 1).setText(v.violationNumber);
      sheet.getRangeByIndex(row, 2).setText(
          '${v.createdAt.year}/${v.createdAt.month}/${v.createdAt.day}');
      sheet.getRangeByIndex(row, 3)
          .setText('${v.createdAt.hour}:${v.createdAt.minute}');
      sheet.getRangeByIndex(row, 4).setText(v.securityOfficerName);
      sheet.getRangeByIndex(row, 5).setText(v.employeeName);
      sheet.getRangeByIndex(row, 6).setText(v.employeeId);
      sheet.getRangeByIndex(row, 7).setText(v.employeeDepartment);
      sheet.getRangeByIndex(row, 8).setText(v.customType);
      sheet.getRangeByIndex(row, 9).setText(v.severityLabel);
      sheet.getRangeByIndex(row, 10).setText(v.details);
      sheet.getRangeByIndex(row, 11).setText(v.location);
      sheet.getRangeByIndex(row, 12).setNumber(v.warningCount.toDouble());
      row++;
    }
  }

  void _fillLeavesSheet(xlsio.Worksheet sheet, List<LeaveModel> leaves) {
    final headers = [
      'رقم الإذن', 'التاريخ', 'رجل السلامة', 'الموظف',
      'القسم', 'السبب', 'وقت الخروج', 'وقت الرجوع المتوقع',
      'وقت الرجوع الفعلي', 'الحالة',
    ];

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.getRangeByIndex(1, i + 1);
      cell.setText(headers[i]);
      cell.cellStyle.bold = true;
    }

    int row = 2;
    for (final l in leaves) {
      sheet.getRangeByIndex(row, 1).setText(l.leaveNumber);
      sheet.getRangeByIndex(row, 2).setText(
          '${l.createdAt.year}/${l.createdAt.month}/${l.createdAt.day}');
      sheet.getRangeByIndex(row, 3).setText(l.requestedByName);
      sheet.getRangeByIndex(row, 4).setText(l.employeeName);
      sheet.getRangeByIndex(row, 5).setText(l.employeeDepartment);
      sheet.getRangeByIndex(row, 6).setText(l.reasonLabel);
      sheet.getRangeByIndex(row, 7)
          .setText('${l.exitTime.hour}:${l.exitTime.minute}');
      sheet.getRangeByIndex(row, 8)
          .setText('${l.expectedReturn.hour}:${l.expectedReturn.minute}');
      sheet.getRangeByIndex(row, 9).setText(
        l.actualReturn != null
            ? '${l.actualReturn!.hour}:${l.actualReturn!.minute}'
            : '---',
      );
      sheet.getRangeByIndex(row, 10).setText(l.statusLabel);
      row++;
    }
  }
}