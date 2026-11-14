import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/extinguisher_model.dart';

/// سجل كشف واحد مع بيانات الأسطوانة التابع لها (قد تكون null لو حُذفت الأسطوانة)
class InspectionEntry {
  final InspectionLog log;
  final Extinguisher? extinguisher;

  const InspectionEntry({required this.log, required this.extinguisher});
}

class ExtinguisherService {
  final PocketBase pb;

  ExtinguisherService(this.pb);

  // ───────────────────────────────────────────────
  // تحويل السجلات
  // ───────────────────────────────────────────────

  Extinguisher _extinguisherFromRecord(RecordModel r) {
    return Extinguisher.fromJson({...r.data, 'id': r.id});
  }

  /// يحوّل سجل PocketBase من مجموعة extinguisher_inspections إلى InspectionLog
  InspectionLog inspectionFromRecord(RecordModel r) {
    final d = r.data;

    final dateStr = d['inspection_date']?.toString() ?? '';
    final createdStr = r.get<String?>('created') ?? '';
    final date = DateTime.tryParse(dateStr) ??
        DateTime.tryParse(createdStr) ??
        DateTime.now();

    final photo = d['inspection_photo_url']?.toString();

    return InspectionLog(
      id: r.id,
      extinguisherId: d['extinguisher_id']?.toString() ?? '',
      currentWeight: (d['current_weight'] as num?)?.toDouble() ?? 0.0,
      capacityStatus: d['capacity_status']?.toString() ?? '',
      metalSeal: d['metal_seal']?.toString() ?? '',
      plasticSeal: d['plastic_seal']?.toString() ?? '',
      notes: d['notes']?.toString() ?? '',
      overallStatus: d['overall_status']?.toString() ?? '',
      inspectorId: d['inspector_id']?.toString() ?? '',
      inspectorName: d['inspector_name']?.toString() ?? '',
      inspectionDate: date,
      inspectionPhotoUrl: (photo == null || photo.isEmpty) ? null : photo,
    );
  }

  // ───────────────────────────────────────────────
  // الأسطوانات
  // ───────────────────────────────────────────────

  /// كل الأسطوانات مرتبة بالرقم (تُستخدم في نافذة اختيار الأسطوانة).
  /// تُرمي الاستثناء عند الفشل ليعرض الواجهة رسالة وزر إعادة المحاولة.
  Future<List<Extinguisher>> getAllExtinguishers() async {
    final records = await pb.collection('extinguishers').getFullList(
      sort: 'number',
    );
    return records.map(_extinguisherFromRecord).toList();
  }

  // جلب أسطوانة برقمها (1 إلى 400)
  Future<Extinguisher?> getExtinguisherByNumber(int number) async {
    try {
      final records = await pb.collection('extinguishers').getList(
        filter: pb.filter('number = {:n}', {'n': number}),
      );
      if (records.items.isNotEmpty) {
        return _extinguisherFromRecord(records.items.first);
      }
    } catch (e) {
      debugPrint('Error fetching extinguisher: $e');
    }
    return null;
  }

  // ───────────────────────────────────────────────
  // الكشوفات
  // ───────────────────────────────────────────────

  /// آخر كشف مسجّل لأسطوانة معيّنة، أو null إن لم تُفحص من قبل.
  /// تُرمي الاستثناء عند فشل الاتصال حتى لا نعرض "لم تُفحص" خطأً.
  Future<InspectionLog?> getLastInspection(String extinguisherId) async {
    final result = await pb.collection('extinguisher_inspections').getList(
      page: 1,
      perPage: 1,
      filter: pb.filter('extinguisher_id = {:id}', {'id': extinguisherId}),
      sort: '-inspection_date',
    );
    if (result.items.isEmpty) return null;
    return inspectionFromRecord(result.items.first);
  }

  /// كل سجل الكشوفات من الأحدث إلى الأقدم، مع بيانات كل أسطوانة.
  /// تُرمي الاستثناء عند الفشل ليعرض تبويب السجل زر إعادة المحاولة.
  Future<List<InspectionEntry>> getInspectionHistory() async {
    final inspectionRecords =
    await pb.collection('extinguisher_inspections').getFullList(
      sort: '-inspection_date',
    );
    final extinguishers = await getAllExtinguishers();
    final byId = {for (final e in extinguishers) e.id: e};

    return inspectionRecords.map((r) {
      final log = inspectionFromRecord(r);
      return InspectionEntry(log: log, extinguisher: byId[log.extinguisherId]);
    }).toList();
  }

  // حفظ تقرير الكشف الدوري
  Future<bool> saveInspection(InspectionLog log) async {
    try {
      await pb.collection('extinguisher_inspections').create(body: log.toJson());
      return true;
    } catch (e) {
      debugPrint('Error saving inspection: $e');
      return false;
    }
  }

  // ───────────────────────────────────────────────
  // التصدير إلى Excel
  // ───────────────────────────────────────────────

  Future<void> exportToExcel() async {
    try {
      final xlsio.Workbook workbook = xlsio.Workbook();
      final xlsio.Worksheet sheet = workbook.worksheets[0];
      sheet.name = 'الكشف عن الأسطوانات';

      // العناوين الرئيسية
      sheet.getRangeByIndex(1, 1).setText('رقم الأسطوانة');
      sheet.getRangeByIndex(1, 2).setText('الموقع الثابت');
      sheet.getRangeByIndex(1, 3).setText('النوع');
      sheet.getRangeByIndex(1, 4).setText('الوزن الأساسي');
      sheet.getRangeByIndex(1, 5).setText('الوزن الحالي');
      sheet.getRangeByIndex(1, 6).setText('الختم المعدني');
      sheet.getRangeByIndex(1, 7).setText('الختم البلاستيك');
      sheet.getRangeByIndex(1, 8).setText('الحالة العامة');
      sheet.getRangeByIndex(1, 9).setText('المفتش');
      sheet.getRangeByIndex(1, 10).setText('التاريخ');
      sheet.getRangeByIndex(1, 11).setText('الملاحظات');

      // نجلب سجلات الكشف وكل الأسطوانات في طلبين منفصلين، ثم نربطهما
      // يدوياً بمعرّف الأسطوانة (بدون الاعتماد على expand).
      final inspections = await pb
          .collection('extinguisher_inspections')
          .getFullList(sort: '-inspection_date');
      final extinguisherRecords =
      await pb.collection('extinguishers').getFullList();
      final Map<String, RecordModel> extinguishersById = {
        for (final e in extinguisherRecords) e.id: e,
      };

      int rowIndex = 2;
      for (final record in inspections) {
        final extId = record.data['extinguisher_id']?.toString() ?? '';
        final extData = extinguishersById[extId];

        sheet.getRangeByIndex(rowIndex, 1).setText(
          extData != null ? extData.data['number'].toString() : '-',
        );
        sheet.getRangeByIndex(rowIndex, 2).setText(
          extData != null ? extData.data['location'].toString() : '-',
        );
        sheet.getRangeByIndex(rowIndex, 3).setText(
          extData != null ? extData.data['type'].toString() : '-',
        );
        sheet.getRangeByIndex(rowIndex, 4).setNumber(
          extData != null
              ? ((extData.data['base_weight'] as num?) ?? 0).toDouble()
              : 0.0,
        );
        sheet.getRangeByIndex(rowIndex, 5).setNumber(
          ((record.data['current_weight'] as num?) ?? 0).toDouble(),
        );
        sheet
            .getRangeByIndex(rowIndex, 6)
            .setText(record.data['metal_seal']?.toString() ?? '');
        sheet
            .getRangeByIndex(rowIndex, 7)
            .setText(record.data['plastic_seal']?.toString() ?? '');
        sheet
            .getRangeByIndex(rowIndex, 8)
            .setText(record.data['overall_status']?.toString() ?? '');
        sheet
            .getRangeByIndex(rowIndex, 9)
            .setText(record.data['inspector_name']?.toString() ?? '');
        sheet
            .getRangeByIndex(rowIndex, 10)
            .setText(record.data['inspection_date']?.toString() ?? '');
        sheet
            .getRangeByIndex(rowIndex, 11)
            .setText(record.data['notes']?.toString() ?? '');
        rowIndex++;
      }

      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/Extinguishers_Inspection_Report.xlsx';
      final file = File(path);
      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          text: 'تقرير الكشف عن الأسطوانات الشامل',
        ),
      );
    } catch (e) {
      debugPrint('Error exporting excel: $e');
    }
  }
}