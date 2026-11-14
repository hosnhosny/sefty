// lib/screens/security/extinguishers_management_screen.dart

import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../main.dart'; // العميل العام pb
import '../../models/extinguisher_model.dart';
import '../../utils/constants.dart';
import 'extinguisher_inspections_history_tab.dart';

/// آخر فحص مسجّل لأسطوانة معيّنة (من مجموعة extinguisher_inspections)
class _LastInspection {
  final DateTime? date;
  final String status;
  const _LastInspection(this.date, this.status);
}

class ExtinguishersManagementScreen extends StatefulWidget {
  /// true  = يظهر زر الإضافة والتعديل
  /// false = عرض وبحث فقط
  final bool canManage;

  const ExtinguishersManagementScreen({super.key, this.canManage = true});

  @override
  State<ExtinguishersManagementScreen> createState() =>
      _ExtinguishersManagementScreenState();
}

class _ExtinguishersManagementScreenState
    extends State<ExtinguishersManagementScreen>
    with SingleTickerProviderStateMixin {
  static const int _maxCount = 400;

  List<Extinguisher> _all = [];
  List<Extinguisher> _filtered = [];
  Map<String, _LastInspection> _lastInspections = {};

  bool _isLoading = true;
  bool _inspectionsLoaded = false;
  bool _onlyNotInspected = false;
  String? _loadError;

  final TextEditingController _searchController = TextEditingController();
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // لتحديث زر الإضافة وزر التحديث عند تبديل التبويب
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) setState(() {});
    });
    _loadExtinguishers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ───────────────────────────────────────────────
  // أدوات مساعدة
  // ───────────────────────────────────────────────

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

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  String _formatDate(DateTime d) {
    final local = d.toLocal();
    return '${local.year}/${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')}';
  }

  // ───────────────────────────────────────────────
  // تحميل البيانات
  // ───────────────────────────────────────────────

  Future<void> _loadExtinguishers() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final records = await pb.collection('extinguishers').getFullList(
        sort: 'number',
      );

      final list = records
          .map((r) => Extinguisher.fromJson({...r.data, 'id': r.id}))
          .toList();

      if (!mounted) return;
      setState(() {
        _all = list;
        _isLoading = false;
      });
      _applyFilters();

      // آخر فحص لكل أسطوانة (لا يوقف الشاشة إن فشل)
      _loadLastInspections();
    } catch (e) {
      debugPrint('Error loading extinguishers: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'تعذر تحميل الأسطوانات، تحقق من الاتصال بالسيرفر';
      });
    }
  }

  Future<void> _loadLastInspections() async {
    try {
      final records =
      await pb.collection('extinguisher_inspections').getFullList(
        sort: '-inspection_date',
        fields: 'extinguisher_id,overall_status,inspection_date',
      );

      // السجلات مرتبة من الأحدث، فأول سجل لكل أسطوانة هو آخر فحص لها
      final map = <String, _LastInspection>{};
      for (final r in records) {
        final extId = r.data['extinguisher_id']?.toString() ?? '';
        if (extId.isEmpty || map.containsKey(extId)) continue;
        final dateStr = r.data['inspection_date']?.toString() ?? '';
        map[extId] = _LastInspection(
          DateTime.tryParse(dateStr),
          r.data['overall_status']?.toString() ?? '',
        );
      }

      if (!mounted) return;
      setState(() {
        _lastInspections = map;
        _inspectionsLoaded = true;
      });
      _applyFilters();
    } catch (e) {
      debugPrint('Error loading last inspections: $e');
    }
  }

  // ───────────────────────────────────────────────
  // البحث والفلترة
  // ───────────────────────────────────────────────

  void _applyFilters() {
    final q = _normalizeDigits(_searchController.text.trim().toLowerCase());

    setState(() {
      _filtered = _all.where((e) {
        if (_onlyNotInspected && _lastInspections.containsKey(e.id)) {
          return false;
        }
        if (q.isEmpty) return true;
        return e.number.toString().contains(q) ||
            e.location.toLowerCase().contains(q) ||
            e.type.toLowerCase().contains(q);
      }).toList();
    });
  }

  int get _notInspectedCount =>
      _all.where((e) => !_lastInspections.containsKey(e.id)).length;

  // ───────────────────────────────────────────────
  // نافذة الإضافة / التعديل
  // ───────────────────────────────────────────────

  Future<void> _showAddEditDialog({Extinguisher? extinguisher}) async {
    final ext = extinguisher;
    final isEditing = ext != null;

    final numberController =
    TextEditingController(text: ext != null ? '${ext.number}' : '');
    final locationController =
    TextEditingController(text: ext?.location ?? '');
    final typeController =
    TextEditingController(text: ext?.type ?? 'بودرة جافة ABC');
    final weightController =
    TextEditingController(text: ext != null ? '${ext.baseWeight}' : '6.0');
    final formKey = GlobalKey<FormState>();
    var saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text(
                ext != null
                    ? 'تعديل بيانات الأسطوانة #${ext.number}'
                    : 'إضافة أسطوانة جديدة',
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: numberController,
                        keyboardType: TextInputType.number,
                        enabled: !isEditing && !saving,
                        decoration: const InputDecoration(
                          labelText: 'رقم الأسطوانة (1 - $_maxCount)',
                        ),
                        validator: (v) {
                          final n = int.tryParse(_normalizeDigits(v?.trim() ?? ''));
                          if (n == null) return 'أدخل رقماً صحيحاً';
                          if (n < 1 || n > _maxCount) {
                            return 'الرقم يجب أن يكون بين 1 و $_maxCount';
                          }
                          if (!isEditing && _all.any((e) => e.number == n)) {
                            return 'هذا الرقم مستخدم لأسطوانة أخرى';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: locationController,
                        enabled: !saving,
                        decoration: const InputDecoration(
                          labelText: 'الموقع الثابت',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'أدخل الموقع'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: typeController,
                        enabled: !saving,
                        decoration: const InputDecoration(labelText: 'النوع'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'أدخل النوع'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: weightController,
                        enabled: !saving,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'الوزن الأساسي (كغ)',
                        ),
                        validator: (v) {
                          final w = double.tryParse(
                            _normalizeDigits(v?.trim() ?? '')
                                .replaceAll(',', '.'),
                          );
                          if (w == null || w <= 0) return 'أدخل وزناً صحيحاً';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(ctx),
                  child: const Text(AppStrings.cancel),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    minimumSize: const Size(100, 44),
                  ),
                  onPressed: saving
                      ? null
                      : () async {
                    if (!formKey.currentState!.validate()) return;

                    final navigator = Navigator.of(ctx);
                    setDialogState(() => saving = true);

                    final data = <String, dynamic>{
                      if (!isEditing)
                        'number': int.parse(
                          _normalizeDigits(numberController.text.trim()),
                        ),
                      'location': locationController.text.trim(),
                      'type': typeController.text.trim(),
                      'base_weight': double.parse(
                        _normalizeDigits(weightController.text.trim())
                            .replaceAll(',', '.'),
                      ),
                    };

                    try {
                      if (ext != null) {
                        await pb
                            .collection('extinguishers')
                            .update(ext.id, body: data);
                      } else {
                        await pb
                            .collection('extinguishers')
                            .create(body: data);
                      }

                      navigator.pop();
                      _showSnack('تم الحفظ بنجاح', AppColors.success);
                      await _loadExtinguishers();
                    } on ClientException catch (e) {
                      // نُبقي النافذة مفتوحة حتى لا يضيع ما كتبه المستخدم
                      setDialogState(() => saving = false);
                      _showSnack(
                        'تعذر الحفظ: ${e.response['message'] ?? e.toString()}',
                        AppColors.error,
                      );
                    } catch (e) {
                      setDialogState(() => saving = false);
                      _showSnack('حدث خطأ: $e', AppColors.error);
                    }
                  },
                  child: saving
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text(AppStrings.save),
                ),
              ],
            ),
          );
        },
      ),
    );

    numberController.dispose();
    locationController.dispose();
    typeController.dispose();
    weightController.dispose();
  }

  // ───────────────────────────────────────────────
  // واجهة العناصر
  // ───────────────────────────────────────────────

  Widget _buildInspectionLine(Extinguisher ext) {
    if (!_inspectionsLoaded) return const SizedBox.shrink();

    final last = _lastInspections[ext.id];
    if (last == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 4),
        child: Text(
          'لم تُفحص بعد',
          style: TextStyle(
            color: AppColors.warning,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }

    final parts = <String>[
      if (last.date != null) 'آخر فحص: ${_formatDate(last.date!)}',
      if (last.status.isNotEmpty) last.status,
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        parts.join(' — '),
        style: const TextStyle(
          color: AppColors.info,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(_loadError!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  minimumSize: const Size(160, 44),
                ),
                onPressed: _loadExtinguishers,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    if (_filtered.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadExtinguishers,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(child: Text('لا توجد أسطوانات مطابقة')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadExtinguishers,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(12, 4, 12, widget.canManage ? 88 : 16),
        itemCount: _filtered.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (ctx, index) {
          final ext = _filtered[index];
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.secondary.withValues(alpha: 0.15),
                child: Text(
                  '${ext.number}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                  ),
                ),
              ),
              title: Text(
                'النوع: ${ext.type}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الموقع: ${ext.location} | الوزن الأساسي: ${ext.baseWeight} كغ',
                  ),
                  _buildInspectionLine(ext),
                ],
              ),
              isThreeLine: _inspectionsLoaded,
              trailing: widget.canManage
                  ? IconButton(
                icon: const Icon(Icons.edit, color: AppColors.info),
                tooltip: AppStrings.edit,
                onPressed: () => _showAddEditDialog(extinguisher: ext),
              )
                  : null,
            ),
          );
        },
      ),
    );
  }

  /// تبويب "الأسطوانات": البحث + الفلتر + القائمة
  Widget _buildListTab() {
    return Column(
      children: [
        // حقل البحث
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => _applyFilters(),
            decoration: InputDecoration(
              hintText: 'بحث برقم الأسطوانة أو الموقع أو النوع...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  _applyFilters();
                },
              ),
            ),
          ),
        ),

        // فلتر + عدد النتائج
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              FilterChip(
                label: Text(
                  _inspectionsLoaded
                      ? 'لم تُفحص بعد ($_notInspectedCount)'
                      : 'لم تُفحص بعد',
                ),
                selected: _onlyNotInspected,
                onSelected: _inspectionsLoaded
                    ? (v) {
                  _onlyNotInspected = v;
                  _applyFilters();
                }
                    : null,
              ),
              const Spacer(),
              Text(
                'النتائج: ${_filtered.length}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),

        Expanded(child: _buildList()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final onListTab = _tabController.index == 0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إدارة الأسطوانات'),
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
          actions: [
            // التحديث هنا لقائمة الأسطوانات فقط (للسجل زر تحديث خاص به)
            if (onListTab)
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'تحديث القائمة',
                onPressed: _isLoading ? null : _loadExtinguishers,
              ),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(
                icon: const Icon(Icons.inventory_2),
                text: 'الأسطوانات (${_all.length} / $_maxCount)',
              ),
              const Tab(
                icon: Icon(Icons.history),
                text: 'سجل الكشف',
              ),
            ],
          ),
        ),
        floatingActionButton: (widget.canManage && onListTab)
            ? FloatingActionButton.extended(
          backgroundColor: AppColors.secondary,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            'إضافة أسطوانة',
            style: TextStyle(color: Colors.white),
          ),
          onPressed: () => _showAddEditDialog(),
        )
            : null,
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildListTab(),
            const ExtinguisherInspectionsHistoryTab(),
          ],
        ),
      ),
    );
  }
}