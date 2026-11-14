// lib/screens/security/extinguisher_inspection_screen.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../main.dart'; // العميل العام pb
import '../../models/extinguisher_model.dart';
import '../../services/extinguisher_service.dart';
import '../../services/storage_service.dart';
import '../../utils/constants.dart';

/// يحوّل الأرقام العربية والفارسية إلى أرقام إنجليزية
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

/// شاشة "الكشف عن الأسطوانات"
class ExtinguisherInspectionScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;

  const ExtinguisherInspectionScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<ExtinguisherInspectionScreen> createState() =>
      _ExtinguisherInspectionScreenState();
}

class _ExtinguisherInspectionScreenState
    extends State<ExtinguisherInspectionScreen> {
  static const double _wideBreakpoint = 700;

  static const List<String> _capacityOptions = [
    '100%',
    '75%',
    '50%',
    'تحتاج تعبئة',
  ];
  static const List<String> _metalSealOptions = ['سليم', 'تالف', 'مفقود'];
  static const List<String> _plasticSealOptions = [
    'موجود ومغلق',
    'مكسور',
    'مفقود',
  ];

  late final ExtinguisherService _service = ExtinguisherService(pb);
  final _storage = StorageService();

  // قائمة الأسطوانات (لنافذة الاختيار)
  List<Extinguisher> _extinguishers = [];
  bool _loadingList = true;
  String? _listError;

  // الأسطوانة المختارة وآخر كشف لها
  Extinguisher? _selected;
  InspectionLog? _lastInspection;
  bool _loadingLast = false;
  String? _lastError;

  // حقول الكشف الجديد
  final TextEditingController weightController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  String capacityStatus = '100%';
  String metalSeal = 'سليم';
  String plasticSeal = 'موجود ومغلق';
  File? inspectionImage;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadExtinguishers();
  }

  @override
  void dispose() {
    weightController.dispose();
    notesController.dispose();
    super.dispose();
  }

  // ───────────────────────────────────────────────
  // أدوات مساعدة
  // ───────────────────────────────────────────────

  void _snack(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  String _formatDateTime(DateTime d) {
    final l = d.toLocal();
    final date =
        '${l.year}/${l.month.toString().padLeft(2, '0')}/${l.day.toString().padLeft(2, '0')}';
    final time =
        '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
    return '$date  $time';
  }

  double? _parseWeight() {
    return double.tryParse(
      _normalizeDigits(weightController.text.trim()).replaceAll(',', '.'),
    );
  }

  /// يعيد حقول الكشف الجديد إلى قيمها الافتراضية (يُستدعى داخل setState)
  void _resetFormFields() {
    weightController.clear();
    notesController.clear();
    capacityStatus = _capacityOptions.first;
    metalSeal = _metalSealOptions.first;
    plasticSeal = _plasticSealOptions.first;
    inspectionImage = null;
  }

  // حساب الحالة العامة تلقائياً بناءً على الوزن والأختام
  String _calculateOverallStatus() {
    final ext = _selected;
    if (ext == null) return 'صالحة 🟢';
    final currentW = _parseWeight() ?? ext.baseWeight;
    final isLowWeight = ext.baseWeight > 0 && currentW < (ext.baseWeight * 0.9);

    if (isLowWeight || metalSeal == 'تالف' || plasticSeal == 'مكسور') {
      return 'تحتاج صيانة 🔴';
    }
    return 'صالحة 🟢';
  }

  // ───────────────────────────────────────────────
  // التحميل والاختيار
  // ───────────────────────────────────────────────

  Future<void> _loadExtinguishers() async {
    setState(() {
      _loadingList = true;
      _listError = null;
    });
    try {
      final list = await _service.getAllExtinguishers();
      if (!mounted) return;
      setState(() {
        _extinguishers = list;
        _loadingList = false;
      });
    } catch (e) {
      debugPrint('Error loading extinguishers: $e');
      if (!mounted) return;
      setState(() {
        _loadingList = false;
        _listError = 'تعذر تحميل قائمة الأسطوانات، تحقق من الاتصال بالسيرفر';
      });
    }
  }

  Future<void> _loadLastInspection(Extinguisher ext) async {
    setState(() {
      _loadingLast = true;
      _lastError = null;
    });
    try {
      final last = await _service.getLastInspection(ext.id);
      if (!mounted || _selected?.id != ext.id) return;
      setState(() {
        _lastInspection = last;
        _loadingLast = false;
      });
    } catch (e) {
      debugPrint('Error loading last inspection: $e');
      if (!mounted || _selected?.id != ext.id) return;
      setState(() {
        _loadingLast = false;
        _lastError = 'تعذر تحميل الكشف السابق';
      });
    }
  }

  void _selectExtinguisher(Extinguisher ext) {
    setState(() {
      _selected = ext;
      _lastInspection = null;
      _resetFormFields();
    });
    _loadLastInspection(ext);
  }

  Future<void> _openPicker() async {
    final picked = await showModalBottomSheet<Extinguisher>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ExtinguisherPickerSheet(
        items: _extinguishers,
        selectedId: _selected?.id,
      ),
    );
    if (picked != null) _selectExtinguisher(picked);
  }

  // ───────────────────────────────────────────────
  // الصورة والحفظ
  // ───────────────────────────────────────────────

  Future<void> _pickImage() async {
    if (kIsWeb) {
      _snack('التقاط الصورة مدعوم على الهاتف فقط');
      return;
    }
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.camera);
      if (picked != null && mounted) {
        setState(() => inspectionImage = File(picked.path));
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      _snack('تعذر فتح الكاميرا', color: AppColors.error);
    }
  }

  Future<void> _submitInspection() async {
    final ext = _selected;
    if (ext == null) return;

    final weight = _parseWeight();
    if (weight == null || weight <= 0) {
      _snack('أدخل الوزن الحالي للأسطوانة أولاً');
      return;
    }

    setState(() => _isSaving = true);

    // رفع صورة الكشف إن وُجدت. لا نوقف الحفظ لو فشل الرفع فقط،
    // نكمل بدون صورة وننبّه المستخدم.
    String? photoUrl;
    final image = inspectionImage;
    if (image != null) {
      photoUrl = await _storage.uploadFile(
        image.path,
        'extinguishers/${ext.number}',
        'inspection_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      if (photoUrl == null) {
        _snack('تعذر رفع الصورة، سيتم حفظ التقرير بدونها');
      }
    }

    final log = InspectionLog(
      id: '',
      extinguisherId: ext.id,
      currentWeight: weight,
      capacityStatus: capacityStatus,
      metalSeal: metalSeal,
      plasticSeal: plasticSeal,
      notes: notesController.text.trim(),
      overallStatus: _calculateOverallStatus(),
      inspectorId: widget.currentUserId,
      inspectorName: widget.currentUserName,
      inspectionDate: DateTime.now(),
      inspectionPhotoUrl: photoUrl,
    );

    final success = await _service.saveInspection(log);
    if (!mounted) return;

    if (success) {
      setState(() {
        _isSaving = false;
        _resetFormFields();
      });
      _snack('تم حفظ تقرير الكشف بنجاح', color: AppColors.success);
      // نحدّث جدول "الكشف القديم" ليعرض الكشف الذي حُفظ للتو
      _loadLastInspection(ext);
    } else {
      setState(() => _isSaving = false);
      _snack('حدث خطأ أثناء الحفظ، حاول مرة أخرى.', color: AppColors.error);
    }
  }

  // ───────────────────────────────────────────────
  // مكونات الواجهة العامة
  // ───────────────────────────────────────────────

  Widget _sectionCard({required String title, required Widget child}) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _hint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),
      ),
    );
  }

  Widget _kvRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(value.isEmpty ? '---' : value),
          ),
        ],
      ),
    );
  }

  /// حقل للقراءة فقط (بيانات الأسطوانة الثابتة)
  Widget _infoField(String label, String value) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Text(value.isEmpty ? '---' : value),
    );
  }

  /// مجموعة خيارات بأزرار اختيار (بديل أزرار الراديو في الصورة)
  Widget _optionGroup({
    required String label,
    required List<String> options,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: options
            .map(
              (option) => ChoiceChip(
            label: Text(option),
            selected: value == option,
            onSelected: _isSaving ? null : (_) => onChanged(option),
          ),
        )
            .toList(),
      ),
    );
  }

  Widget _retryRow(String message, VoidCallback onRetry) {
    return Column(
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('إعادة المحاولة'),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────
  // القسم 1: اختيار الأسطوانة
  // ───────────────────────────────────────────────

  Widget _buildPickerBody() {
    if (_loadingList) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_listError != null) {
      return _retryRow(_listError!, _loadExtinguishers);
    }

    final ext = _selected;
    return InkWell(
      onTap: _isSaving ? null : _openPicker,
      borderRadius: BorderRadius.circular(AppSizes.borderRadius),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'الأسطوانة المختارة',
          suffixIcon: Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          ext != null
              ? 'أسطوانة رقم ${ext.number} — ${ext.location}'
              : 'اضغط لاختيار أسطوانة (بحث بالرقم أو الموقع)',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: ext == null ? Colors.grey : null),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────
  // القسم 2: الكشف القديم
  // ───────────────────────────────────────────────

  Widget _buildLastInspectionBody(bool wide) {
    final ext = _selected;
    if (ext == null) {
      return _hint('اختر أسطوانة لعرض آخر كشف مسجل لها');
    }
    if (_loadingLast) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_lastError != null) {
      return _retryRow(_lastError!, () => _loadLastInspection(ext));
    }

    final log = _lastInspection;
    if (log == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppSizes.smallRadius),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.6)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.warning),
            SizedBox(width: 12),
            Expanded(
              child: Text('لم تُفحص هذه الأسطوانة من قبل، هذا أول كشف لها.'),
            ),
          ],
        ),
      );
    }

    if (wide) {
      // جدول أفقي كما في التصميم، يمكن تمريره أفقياً لو ضاقت الشاشة
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 44,
          dataRowMinHeight: 48,
          dataRowMaxHeight: 72,
          columns: const [
            DataColumn(label: Text('الأسطوانة')),
            DataColumn(label: Text('تاريخ الكشف')),
            DataColumn(label: Text('النوع')),
            DataColumn(label: Text('المكان')),
            DataColumn(label: Text('الوزن')),
            DataColumn(label: Text('سعة التعبئة')),
            DataColumn(label: Text('الختم البلاستيك')),
            DataColumn(label: Text('الختم المعدني')),
            DataColumn(label: Text('الحالة')),
            DataColumn(label: Text('الملاحظات')),
          ],
          rows: [
            DataRow(
              cells: [
                DataCell(Text('${ext.number}')),
                DataCell(Text(_formatDateTime(log.inspectionDate))),
                DataCell(Text(ext.type)),
                DataCell(Text(ext.location)),
                DataCell(Text('${log.currentWeight} كغ')),
                DataCell(Text(log.capacityStatus)),
                DataCell(Text(log.plasticSeal)),
                DataCell(Text(log.metalSeal)),
                DataCell(Text(log.overallStatus)),
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Text(
                      log.notes.isEmpty ? '---' : log.notes,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // الهاتف: عمود من الأسطر
    return Column(
      children: [
        _kvRow('الأسطوانة', '${ext.number}'),
        _kvRow('تاريخ الكشف', _formatDateTime(log.inspectionDate)),
        _kvRow('النوع', ext.type),
        _kvRow('المكان', ext.location),
        _kvRow('الوزن', '${log.currentWeight} كغ'),
        _kvRow('سعة التعبئة', log.capacityStatus),
        _kvRow('الختم البلاستيك', log.plasticSeal),
        _kvRow('الختم المعدني', log.metalSeal),
        _kvRow('الحالة', log.overallStatus),
        _kvRow('الملاحظات', log.notes),
      ],
    );
  }

  // ───────────────────────────────────────────────
  // القسم 3: تعبئة بيانات الكشف الجديد
  // ───────────────────────────────────────────────

  Widget _statusPreview() {
    final status = _calculateOverallStatus();
    final needs = status.contains('صيانة');
    final color = needs ? AppColors.error : AppColors.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.smallRadius),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(
            needs ? Icons.build_circle_outlined : Icons.verified_outlined,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'الحالة العامة المتوقعة: $status',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoRow() {
    final image = inspectionImage;
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: _isSaving ? null : _pickImage,
          icon: const Icon(Icons.camera_alt),
          label: const Text('التقاط صورة'),
        ),
        if (image != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(image, width: 56, height: 56, fit: BoxFit.cover),
          ),
          IconButton(
            tooltip: 'إزالة الصورة',
            icon: const Icon(Icons.close),
            onPressed:
            _isSaving ? null : () => setState(() => inspectionImage = null),
          ),
        ],
      ],
    );
  }

  Widget _buildNewInspectionBody(bool wide) {
    final ext = _selected;
    if (ext == null) {
      return _hint('اختر أسطوانة أولاً لبدء الكشف الجديد');
    }

    // العمود الأول: بيانات الأسطوانة الثابتة + الوزن الحالي
    final firstColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _infoField('نوع الأسطوانة', ext.type),
        const SizedBox(height: 12),
        _infoField('الموقع الحالي', ext.location),
        const SizedBox(height: 12),
        _infoField('الوزن الأساسي المعياري', '${ext.baseWeight} كغ'),
        const SizedBox(height: 12),
        TextField(
          controller: weightController,
          enabled: !_isSaving,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              RegExp(r'^[0-9٠-٩]*[.,]?[0-9٠-٩]*$'),
            ),
          ],
          onChanged: (_) => setState(() {}), // لتحديث الحالة المتوقعة
          decoration: const InputDecoration(labelText: 'الوزن الحالي (كغ)'),
        ),
      ],
    );

    // العمود الثاني: حالة التعبئة والأختام والملاحظات
    final secondColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _optionGroup(
          label: 'سعة التعبئة',
          options: _capacityOptions,
          value: capacityStatus,
          onChanged: (v) => setState(() => capacityStatus = v),
        ),
        const SizedBox(height: 12),
        _optionGroup(
          label: 'حالة الختم المعدني',
          options: _metalSealOptions,
          value: metalSeal,
          onChanged: (v) => setState(() => metalSeal = v),
        ),
        const SizedBox(height: 12),
        _optionGroup(
          label: 'حالة الختم البلاستيك (أمان الصمام)',
          options: _plasticSealOptions,
          value: plasticSeal,
          onChanged: (v) => setState(() => plasticSeal = v),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: notesController,
          enabled: !_isSaving,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'ملاحظات إضافية (المفتش الميداني)',
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: firstColumn),
              const SizedBox(width: 24),
              Expanded(child: secondColumn),
            ],
          )
        else ...[
          firstColumn,
          const SizedBox(height: 12),
          secondColumn,
        ],
        const SizedBox(height: 16),
        _buildPhotoRow(),
        const SizedBox(height: 16),
        _statusPreview(),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: SizedBox(
                height: AppSizes.buttonHeight,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submitInspection,
                  child: _isSaving
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                      : const Text(
                    'حفظ الكشف الجديد',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: SizedBox(
                height: AppSizes.buttonHeight,
                child: OutlinedButton(
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                  child: const Text(AppStrings.cancel),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────
  // البناء
  // ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الكشف عن الأسطوانات'),
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= _wideBreakpoint;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _sectionCard(
                        title: 'اختيار الأسطوانة',
                        child: _buildPickerBody(),
                      ),
                      _sectionCard(
                        title: 'الكشف القديم',
                        child: _buildLastInspectionBody(wide),
                      ),
                      _sectionCard(
                        title: 'تعبئة بيانات الكشف الجديد',
                        child: _buildNewInspectionBody(wide),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// نافذة اختيار الأسطوانة (بحث بالرقم أو الموقع أو النوع)
// ═══════════════════════════════════════════════════════════

class _ExtinguisherPickerSheet extends StatefulWidget {
  final List<Extinguisher> items;
  final String? selectedId;

  const _ExtinguisherPickerSheet({
    required this.items,
    required this.selectedId,
  });

  @override
  State<_ExtinguisherPickerSheet> createState() =>
      _ExtinguisherPickerSheetState();
}

class _ExtinguisherPickerSheetState extends State<_ExtinguisherPickerSheet> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _normalizeDigits(_searchController.text.trim().toLowerCase());
    final filtered = widget.items.where((e) {
      if (q.isEmpty) return true;
      return e.number.toString().contains(q) ||
          e.location.toLowerCase().contains(q) ||
          e.type.toLowerCase().contains(q);
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        // لرفع النافذة فوق لوحة المفاتيح
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'اختر الأسطوانة',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'بحث برقم الأسطوانة أو الموقع أو النوع...',
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
              Expanded(
                child: widget.items.isEmpty
                    ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'لا توجد أسطوانات مسجلة. أضفها أولاً من شاشة إدارة الأسطوانات.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
                    : filtered.isEmpty
                    ? const Center(child: Text('لا توجد نتائج مطابقة'))
                    : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final ext = filtered[index];
                    final isSelected = ext.id == widget.selectedId;
                    return ListTile(
                      selected: isSelected,
                      leading: CircleAvatar(
                        backgroundColor: AppColors.secondary
                            .withValues(alpha: 0.15),
                        child: Text(
                          '${ext.number}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                      title: Text('أسطوانة رقم ${ext.number}'),
                      subtitle: Text('${ext.location} • ${ext.type}'),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle,
                          color: AppColors.success)
                          : null,
                      onTap: () => Navigator.pop(context, ext),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}