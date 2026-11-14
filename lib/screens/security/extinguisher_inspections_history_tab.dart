// lib/screens/security/extinguisher_inspections_history_tab.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../main.dart'; // العميل العام pb
import '../../models/extinguisher_model.dart';
import '../../services/extinguisher_service.dart';
import '../../utils/constants.dart';

/// تبويب "سجل الكشف" داخل شاشة إدارة الأسطوانات.
/// يعرض كل الكشوفات السابقة مع بحث وفلتر بالحالة وتصدير Excel.
class ExtinguisherInspectionsHistoryTab extends StatefulWidget {
  const ExtinguisherInspectionsHistoryTab({super.key});

  @override
  State<ExtinguisherInspectionsHistoryTab> createState() =>
      _ExtinguisherInspectionsHistoryTabState();
}

class _ExtinguisherInspectionsHistoryTabState
    extends State<ExtinguisherInspectionsHistoryTab>
    with AutomaticKeepAliveClientMixin {
  // نحافظ على حالة التبويب حتى لا يُعاد التحميل عند التنقل بين التبويبات
  @override
  bool get wantKeepAlive => true;

  late final ExtinguisherService _service = ExtinguisherService(pb);

  List<InspectionEntry> _all = [];
  bool _isLoading = true;
  bool _exporting = false;
  String? _error;

  /// 0 = الكل، 1 = صالحة، 2 = تحتاج صيانة
  int _statusFilter = 0;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ───────────────────────────────────────────────
  // أدوات مساعدة
  // ───────────────────────────────────────────────

  String _normalizeDigits(String input) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    final buffer = StringBuffer();
    for (final ch in input.split('')) {
      var index = arabic.indexOf(ch);
      if (index == -1) index = persian.indexOf(ch);
      buffer.write(index == -1 ? ch : index.toString());
    }
    return buffer.toString();
  }

  String _formatDateTime(DateTime d) {
    final l = d.toLocal();
    final date =
        '${l.year}/${l.month.toString().padLeft(2, '0')}/${l.day.toString().padLeft(2, '0')}';
    final time =
        '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
    return '$date  $time';
  }

  bool _needsMaintenance(InspectionLog log) =>
      log.overallStatus.contains('صيانة');

  void _showSnack(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  // ───────────────────────────────────────────────
  // التحميل والفلترة
  // ───────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await _service.getInspectionHistory();
      if (!mounted) return;
      setState(() {
        _all = list;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading inspection history: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'تعذر تحميل سجل الكشف، تحقق من الاتصال ومن صلاحيات القراءة';
      });
    }
  }

  List<InspectionEntry> get _filtered {
    final q = _normalizeDigits(_searchController.text.trim().toLowerCase());

    return _all.where((entry) {
      final needs = _needsMaintenance(entry.log);
      if (_statusFilter == 1 && needs) return false;
      if (_statusFilter == 2 && !needs) return false;

      if (q.isEmpty) return true;
      final ext = entry.extinguisher;
      return (ext?.number.toString().contains(q) ?? false) ||
          (ext?.location.toLowerCase().contains(q) ?? false) ||
          entry.log.inspectorName.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _export() async {
    if (kIsWeb) {
      _showSnack('التصدير إلى Excel غير مدعوم في المتصفح، جرّبه على الهاتف');
      return;
    }
    setState(() => _exporting = true);
    await _service.exportToExcel();
    if (!mounted) return;
    setState(() => _exporting = false);
  }

  // ───────────────────────────────────────────────
  // عناصر الواجهة
  // ───────────────────────────────────────────────

  Widget _statusBadge(InspectionLog log) {
    final needs = _needsMaintenance(log);
    final color = needs ? AppColors.error : AppColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        needs ? 'تحتاج صيانة' : 'صالحة',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '---' : value,
              style: TextStyle(color: valueColor, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(InspectionEntry entry) {
    final log = entry.log;
    final ext = entry.extinguisher;

    final lowWeight = ext != null &&
        ext.baseWeight > 0 &&
        log.currentWeight < ext.baseWeight * 0.9;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        // إخفاء الخطوط الفاصلة الافتراضية داخل ExpansionTile
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          leading: CircleAvatar(
            backgroundColor: AppColors.secondary.withValues(alpha: 0.15),
            child: Text(
              ext != null ? '${ext.number}' : '؟',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.secondary,
              ),
            ),
          ),
          title: Text(
            ext != null ? 'أسطوانة رقم ${ext.number}' : 'أسطوانة محذوفة',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ext != null) Text('الموقع: ${ext.location}'),
                Text(
                  '${_formatDateTime(log.inspectionDate)}  •  ${log.inspectorName}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _statusBadge(log),
                ),
              ],
            ),
          ),
          children: [
            const Divider(),
            if (ext != null) _detailRow('النوع', ext.type),
            _detailRow(
              'الوزن الحالي',
              ext != null
                  ? '${log.currentWeight} كغ (الأساسي ${ext.baseWeight} كغ)'
                  : '${log.currentWeight} كغ',
              valueColor: lowWeight ? AppColors.error : null,
            ),
            _detailRow('سعة التعبئة', log.capacityStatus),
            _detailRow('الختم المعدني', log.metalSeal),
            _detailRow('الختم البلاستيك', log.plasticSeal),
            _detailRow('الحالة العامة', log.overallStatus),
            _detailRow('الملاحظات', log.notes),
            if (log.inspectionPhotoUrl != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  log.inspectionPhotoUrl!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox(
                    height: 60,
                    child: Center(child: Text('تعذر عرض الصورة')),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<InspectionEntry> filtered) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  minimumSize: const Size(160, 44),
                ),
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    if (filtered.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            const SizedBox(height: 120),
            Center(
              child: Text(
                _all.isEmpty
                    ? 'لا توجد كشوفات مسجلة بعد'
                    : 'لا توجد نتائج مطابقة',
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        itemCount: filtered.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, index) => _buildEntryCard(filtered[index]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // مطلوب مع AutomaticKeepAliveClientMixin

    final filtered = _filtered;
    final validCount =
        _all.where((e) => !_needsMaintenance(e.log)).length;
    final maintenanceCount = _all.length - validCount;

    return Column(
      children: [
        // البحث
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'بحث برقم الأسطوانة أو الموقع أو اسم المفتش...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
              ),
            ),
          ),
        ),

        // الفلاتر + التصدير
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text('الكل (${_all.length})'),
                      selected: _statusFilter == 0,
                      onSelected: (_) => setState(() => _statusFilter = 0),
                    ),
                    ChoiceChip(
                      label: Text('صالحة ($validCount)'),
                      selected: _statusFilter == 1,
                      onSelected: (_) => setState(() => _statusFilter = 1),
                    ),
                    ChoiceChip(
                      label: Text('تحتاج صيانة ($maintenanceCount)'),
                      selected: _statusFilter == 2,
                      onSelected: (_) => setState(() => _statusFilter = 2),
                    ),
                  ],
                ),
              ),
              _exporting
                  ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
                  : IconButton(
                icon: const Icon(Icons.table_chart),
                tooltip: 'تصدير إلى Excel',
                onPressed: _all.isEmpty ? null : _export,
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'تحديث السجل',
                onPressed: _isLoading ? null : _load,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),

        Expanded(child: _buildBody(filtered)),
      ],
    );
  }
}