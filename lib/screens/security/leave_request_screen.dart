// lib/screens/security/add_leave_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/leave_model.dart';
import '../../services/pb_service.dart';
import '../../services/storage_service.dart';
import '../../utils/enums.dart';

class LeaveRequestScreen extends StatefulWidget {
  final UserModel currentUser;
  const LeaveRequestScreen({super.key, required this.currentUser});

  @override
  State<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends State<LeaveRequestScreen> {
  // ─── Services ───────────────────────────────────────────────────────
  final _formKey   = GlobalKey<FormState>();
  final _db        = DatabaseService();
  final _storage   = StorageService();

  // ─── Controllers ────────────────────────────────────────────────────
  final _searchCtrl        = TextEditingController();
  final _reasonDetailsCtrl = TextEditingController();

  // ─── Employee State ──────────────────────────────────────────────────
  Map<String, dynamic>?      _selectedEmployee;
  List<Map<String, dynamic>> _allEmployees      = [];
  List<Map<String, dynamic>> _filteredEmployees = [];
  bool _loadingEmployees = true;
  bool _showDropdown     = false;

  // ─── Leave State ─────────────────────────────────────────────────────
  LeaveReason _selectedReason = LeaveReason.medical;
  DateTime    _exitTime       = DateTime.now();
  DateTime    _expectedReturn = DateTime.now().add(const Duration(hours: 1));
  File?       _evidenceImage;
  bool        _isFinalExit    = false; // انصراف نهائي: بدون وقت عودة أو حساب مدة غياب

  // ─── Loading State ───────────────────────────────────────────────────
  bool   _isLoading    = false;
  bool   _isUploading  = false;
  String _leaveNumber  = '';

  // ════════════════════════════════════════════════════════════════════
  // INIT
  // ════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _loadLeaveNumber();
    _loadEmployees();
  }

  // ════════════════════════════════════════════════════════════════════
  // DATA LOADING
  // ════════════════════════════════════════════════════════════════════

  Future<void> _loadLeaveNumber() async {
    final number = await _db.getNextLeaveNumber();
    if (mounted) setState(() => _leaveNumber = number);
  }

  Future<void> _loadEmployees() async {
    try {
      final list = await _db.getAllEmployees().first;

      list.sort((a, b) =>
          (a['name'] as String).compareTo(b['name'] as String));

      if (mounted) {
        setState(() {
          _allEmployees      = list;
          _filteredEmployees = list;
          _loadingEmployees  = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingEmployees = false);
        _showSnack('خطأ في تحميل الموظفين: $e', Colors.red);
      }
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // EMPLOYEE SEARCH & SELECTION
  // ════════════════════════════════════════════════════════════════════

  void _filterEmployees(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filteredEmployees = q.isEmpty
          ? _allEmployees
          : _allEmployees.where((e) {
        return (e['name']        as String).toLowerCase().contains(q) ||
            (e['employee_id'] as String).toLowerCase().contains(q) ||
            (e['department']  as String).toLowerCase().contains(q);
      }).toList();
      _showDropdown = true;
    });
  }

  void _selectEmployee(Map<String, dynamic> emp) {
    setState(() {
      _selectedEmployee = emp;
      _searchCtrl.text  = '${emp['name']}  •  ${emp['employee_id']}';
      _showDropdown     = false;
    });
  }

  void _clearEmployee() {
    setState(() {
      _selectedEmployee  = null;
      _showDropdown      = false;
      _filteredEmployees = _allEmployees;
    });
    _searchCtrl.clear();
  }

  // ════════════════════════════════════════════════════════════════════
  // DATE / TIME PICKERS
  // ════════════════════════════════════════════════════════════════════

  Future<void> _pickExitTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _exitTime,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 30)),
      locale: const Locale('ar'),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_exitTime),
    );
    if (time == null || !mounted) return;

    setState(() {
      _exitTime = DateTime(
          date.year, date.month, date.day, time.hour, time.minute);
      // إذا أصبح وقت الخروج بعد وقت العودة المتوقعة، نضبط العودة تلقائياً
      if (_exitTime.isAfter(_expectedReturn)) {
        _expectedReturn = _exitTime.add(const Duration(hours: 1));
      }
    });
  }

  Future<void> _pickExpectedReturn() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _expectedReturn,
      firstDate: _exitTime,
      lastDate: _exitTime.add(const Duration(days: 7)),
      locale: const Locale('ar'),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_expectedReturn),
    );
    if (time == null || !mounted) return;

    final selected = DateTime(
        date.year, date.month, date.day, time.hour, time.minute);

    if (selected.isBefore(_exitTime)) {
      _showSnack('وقت العودة يجب أن يكون بعد وقت الخروج', Colors.orange);
      return;
    }

    setState(() => _expectedReturn = selected);
  }

  // ════════════════════════════════════════════════════════════════════
  // IMAGE
  // ════════════════════════════════════════════════════════════════════

  Future<void> _pickFromCamera() async {
    final file = await _storage.pickImageFromCamera();
    if (file != null && mounted) setState(() => _evidenceImage = file);
  }

  Future<void> _pickFromGallery() async {
    final file = await _storage.pickImageFromGallery();
    if (file != null && mounted) setState(() => _evidenceImage = file);
  }

  // ════════════════════════════════════════════════════════════════════
  // SUBMIT
  // ════════════════════════════════════════════════════════════════════

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedEmployee == null) {
      _showSnack('يجب اختيار موظف من القائمة', Colors.red);
      return;
    }
    if (_evidenceImage == null) {
      _showSnack('يجب إضافة صورة دليل الإذن', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // رفع صورة الدليل
      setState(() => _isUploading = true);
      final url = await _storage.uploadFile(
        _evidenceImage!.path,
        'leaves/$_leaveNumber',
        'evidence.jpg',
      );
      setState(() => _isUploading = false);

      if (url == null) {
        _showSnack('فشل رفع صورة الدليل، حاول مرة أخرى', Colors.red);
        return;
      }

      // بناء النموذج
      final leave = LeaveModel(
        leaveNumber:         _leaveNumber,
        createdAt:           DateTime.now(),
        requestedById:       widget.currentUser.uid,
        requestedByName:     widget.currentUser.name,
        employeeId:          _selectedEmployee!['employee_id'] as String,
        employeeName:        _selectedEmployee!['name']       as String,
        employeeDepartment:  _selectedEmployee!['department'] as String,
        reason:              _selectedReason,
        reasonDetails:       _reasonDetailsCtrl.text.trim().isEmpty
            ? null
            : _reasonDetailsCtrl.text.trim(),
        exitTime:            _exitTime,
        // في حالة الانصراف النهائي: لا يوجد وقت عودة متوقع فعلياً،
        // لذا نسجّل الإذن كمكتمل مباشرة (بلا حاجة لمتابعة الرجوع لاحقاً).
        expectedReturn:      _isFinalExit ? _exitTime : _expectedReturn,
        actualReturn:        _isFinalExit ? _exitTime : null,
        evidenceUrl:         url,
        status:              _isFinalExit ? LeaveStatus.returned : LeaveStatus.active,
      );

      // حفظ في PocketBase
      final savedRecord = await _db.addLeave(leave);
      // تحديث الرقم المعروض ليطابق الرقم الفعلي المحفوظ (مهم فقط بحال إعادة المحاولة)
      final finalLeaveNumber =
          (savedRecord.data['leave_number'] as String?) ?? _leaveNumber;
      if (mounted) setState(() => _leaveNumber = finalLeaveNumber);

      if (mounted) _showSuccessDialog();
    } catch (e) {
      _showSnack('حدث خطأ: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // DIALOGS & HELPERS
  // ════════════════════════════════════════════════════════════════════

  void _showSuccessDialog() {
    final empName = _selectedEmployee!['name'] as String;
    final duration = _expectedReturn.difference(_exitTime);
    final hours   = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final durationText = _isFinalExit
        ? 'انصراف نهائي (لا يوجد رجوع متوقع)'
        : 'مدة الغياب المتوقعة: $hoursس $minutesد';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // أيقونة النجاح
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle,
                    color: Colors.green, size: 56),
              ),
              const SizedBox(height: 16),
              const Text(
                'تم تسجيل إذن الانصراف',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // رقم الإذن
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _leaveNumber,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade700,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'الموظف: $empName',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                durationText,
                style: TextStyle(
                    color: Colors.teal.shade700,
                    fontWeight: FontWeight.w600),
              ),

              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _resetForm();
                      },
                      child: const Text('إذن جديد'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade700),
                      child: const Text('إنهاء',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _selectedEmployee  = null;
      _showDropdown      = false;
      _selectedReason    = LeaveReason.medical;
      _exitTime          = DateTime.now();
      _expectedReturn    = DateTime.now().add(const Duration(hours: 1));
      _evidenceImage     = null;
      _isFinalExit       = false;
      _filteredEmployees = _allEmployees;
    });
    _searchCtrl.clear();
    _reasonDetailsCtrl.clear();
    _loadLeaveNumber();
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final hour   = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final day    = dt.day.toString().padLeft(2, '0');
    final month  = dt.month.toString().padLeft(2, '0');
    return '$day/$month/${dt.year}  $hour:$minute';
  }

  Duration get _plannedDuration => _expectedReturn.difference(_exitTime);

  // ════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: GestureDetector(
        onTap: () {
          if (_showDropdown) setState(() => _showDropdown = false);
          FocusScope.of(context).unfocus();
        },
        child: Scaffold(
          backgroundColor: Colors.grey.shade100,
          appBar: AppBar(
            title: Column(
              children: [
                const Text(
                  'تسجيل إذن انصراف',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  _leaveNumber,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
            backgroundColor: Colors.teal.shade700,
            foregroundColor: Colors.white,
            centerTitle: true,
          ),
          body: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Employee Section ─────────────────────────────
                  _sectionCard(
                    icon: Icons.person,
                    color: Colors.blue,
                    title: 'بيانات الموظف',
                    child: _buildEmployeeSection(),
                  ),
                  const SizedBox(height: 16),

                  // ── Leave Details ────────────────────────────────
                  _sectionCard(
                    icon: Icons.exit_to_app,
                    color: Colors.teal,
                    title: 'تفاصيل الإذن',
                    child: _buildLeaveDetailsSection(),
                  ),
                  const SizedBox(height: 16),

                  // ── Time Section ─────────────────────────────────
                  _sectionCard(
                    icon: Icons.schedule,
                    color: Colors.orange,
                    title: 'توقيت الانصراف والعودة',
                    child: _buildTimeSection(),
                  ),
                  const SizedBox(height: 16),

                  // ── Evidence Photo ───────────────────────────────
                  _sectionCard(
                    icon: Icons.camera_alt,
                    color: Colors.green,
                    title: 'صورة الدليل',
                    child: _buildEvidenceSection(),
                  ),
                  const SizedBox(height: 24),

                  // ── Submit Button ────────────────────────────────
                  _buildSubmitButton(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // SECTION BUILDERS
  // ════════════════════════════════════════════════════════════════════

  Widget _buildEmployeeSection() {
    if (_loadingEmployees) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      children: [
        // حقل البحث
        TextFormField(
          controller: _searchCtrl,
          readOnly: _selectedEmployee != null,
          decoration: InputDecoration(
            labelText: 'ابحث باسم أو رقم الموظف *',
            hintText: 'اكتب للبحث...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _selectedEmployee != null
                ? IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'إلغاء الاختيار',
              onPressed: _clearEmployee,
            )
                : null,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          onTap: () => setState(() => _showDropdown = true),
          onChanged: (v) {
            _selectedEmployee = null;
            _filterEmployees(v);
          },
          validator: (_) =>
          _selectedEmployee == null ? 'يجب اختيار موظف من القائمة' : null,
        ),

        // قائمة البحث المنسدلة
        if (_showDropdown && _selectedEmployee == null) ...[
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 240),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _filteredEmployees.isEmpty
                ? const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text('لا توجد نتائج',
                    style: TextStyle(color: Colors.grey)),
              ),
            )
                : ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _filteredEmployees.length,
              separatorBuilder: (_, __) =>
              const Divider(height: 1, indent: 56),
              itemBuilder: (ctx, i) {
                final emp = _filteredEmployees[i];
                final initials = (emp['name'] as String).isNotEmpty
                    ? (emp['name'] as String)
                    .trim()
                    .split(' ')
                    .take(2)
                    .map((w) => w[0])
                    .join()
                    : '?';
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 2),
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.teal.shade100,
                    child: Text(
                      initials,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade800,
                      ),
                    ),
                  ),
                  title: Text(
                    emp['name'] as String,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    '${emp['employee_id']}  •  ${emp['department']}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () => _selectEmployee(emp),
                );
              },
            ),
          ),
        ],

        // بطاقة الموظف المختار
        if (_selectedEmployee != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.teal.shade200),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.teal.shade700,
                  child: Text(
                    (_selectedEmployee!['name'] as String)
                        .trim()
                        .split(' ')
                        .take(2)
                        .map((w) => w[0])
                        .join(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedEmployee!['name'] as String,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'رقم: ${_selectedEmployee!['employee_id']}',
                        style: TextStyle(
                            color: Colors.teal.shade700, fontSize: 13),
                      ),
                      Text(
                        'القسم: ${_selectedEmployee!['department']}',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle, color: Colors.teal),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLeaveDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // سبب الإذن
        const Text(
          'سبب الانصراف *',
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: LeaveReason.values.map((reason) {
            final isSelected = _selectedReason == reason;
            return GestureDetector(
              onTap: () => setState(() => _selectedReason = reason),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.teal.shade700
                      : Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? Colors.teal.shade700
                        : Colors.teal.shade200,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _reasonIcon(reason),
                      size: 18,
                      color: isSelected
                          ? Colors.white
                          : Colors.teal.shade700,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      reason.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : Colors.teal.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),

        // تفاصيل إضافية
        TextFormField(
          controller: _reasonDetailsCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'تفاصيل إضافية (اختياري)',
            hintText: 'أي معلومات إضافية تتعلق بسبب الانصراف...',
            prefixIcon: const Icon(Icons.notes),
            alignLabelWithHint: true,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSection() {
    final hours   = _plannedDuration.inHours;
    final minutes = _plannedDuration.inMinutes % 60;

    return Column(
      children: [
        // ── مفتاح الانصراف النهائي ─────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _isFinalExit ? Colors.red.shade50 : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isFinalExit ? Colors.red.shade300 : Colors.grey.shade300,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.no_backpack_outlined,
                color: _isFinalExit ? Colors.red : Colors.grey.shade600,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'انصراف نهائي',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _isFinalExit ? Colors.red.shade700 : Colors.black87,
                      ),
                    ),
                    Text(
                      'الموظف لن يعود، بدون تحديد وقت رجوع',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isFinalExit,
                activeThumbColor: Colors.red,
                onChanged: (v) => setState(() => _isFinalExit = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // وقت الخروج
        _timeTile(
          icon: Icons.logout,
          iconColor: Colors.orange,
          label: 'وقت الخروج',
          value: _formatDateTime(_exitTime),
          onTap: _pickExitTime,
        ),

        // وقت العودة المتوقعة ومدة الغياب (تُخفى في حالة الانصراف النهائي)
        if (!_isFinalExit) ...[
          const SizedBox(height: 10),
          _timeTile(
            icon: Icons.login,
            iconColor: Colors.green,
            label: 'وقت العودة المتوقعة',
            value: _formatDateTime(_expectedReturn),
            onTap: _pickExpectedReturn,
          ),
          const SizedBox(height: 12),

          // بطاقة المدة الإجمالية
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _plannedDuration.inHours >= 4
                  ? Colors.red.shade50
                  : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _plannedDuration.inHours >= 4
                    ? Colors.red.shade300
                    : Colors.orange.shade300,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.timer,
                  color: _plannedDuration.inHours >= 4
                      ? Colors.red
                      : Colors.orange,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'مدة الغياب المتوقعة',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        '$hoursس $minutesد',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _plannedDuration.inHours >= 4
                              ? Colors.red
                              : Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_plannedDuration.inHours >= 4)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'غياب طويل',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
        ] else ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.red, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'سيتم تسجيل هذا الإذن كانصراف نهائي دون حاجة لتسجيل عودة لاحقاً',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEvidenceSection() {
    return Column(
      children: [
        // عرض الصورة المختارة
        if (_evidenceImage != null) ...[
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _evidenceImage!,
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: GestureDetector(
                  onTap: () => setState(() => _evidenceImage = null),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close,
                        color: Colors.white, size: 16),
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle,
                          color: Colors.green, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'تم اختيار الصورة',
                        style: TextStyle(
                            color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // زر تغيير الصورة
          TextButton.icon(
            onPressed: _pickFromCamera,
            icon: const Icon(Icons.refresh),
            label: const Text('تغيير الصورة'),
          ),
        ] else ...[
          // أزرار الكاميرا والمعرض
          Row(
            children: [
              Expanded(
                child: _photoButton(
                  icon: Icons.camera_alt,
                  label: 'الكاميرا',
                  color: Colors.green,
                  onTap: _pickFromCamera,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _photoButton(
                  icon: Icons.photo_library,
                  label: 'المعرض',
                  color: Colors.blue,
                  onTap: _pickFromGallery,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.red, size: 16),
                SizedBox(width: 8),
                Text(
                  'صورة الدليل مطلوبة (نموذج الإذن أو المستند الرسمي)',
                  style: TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.teal.shade700,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.teal.shade200,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: 4,
        ),
        child: _isLoading
            ? Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.5),
            ),
            const SizedBox(width: 12),
            Text(
              _isUploading
                  ? 'جاري رفع الصورة...'
                  : 'جاري الحفظ...',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        )
            : const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.exit_to_app, size: 22),
            SizedBox(width: 10),
            Text(
              'حفظ إذن الانصراف',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // SHARED WIDGETS
  // ════════════════════════════════════════════════════════════════════

  Widget _sectionCard({
    required IconData icon,
    required Color color,
    required String title,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const Divider(height: 20),
            child,
          ],
        ),
      ),
    );
  }

  Widget _timeTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.edit_calendar_outlined,
                color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _photoButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // REASON ICON HELPER
  // ════════════════════════════════════════════════════════════════════

  IconData _reasonIcon(LeaveReason reason) {
    switch (reason) {
      case LeaveReason.medical:
        return Icons.local_hospital_outlined;
      case LeaveReason.personal:
        return Icons.person_outline;
      case LeaveReason.official:
        return Icons.business_center_outlined;
      case LeaveReason.emergency:
        return Icons.warning_amber_outlined;
      case LeaveReason.other:
        return Icons.more_horiz;
      case LeaveReason.family:
        return Icons.family_restroom_outlined;
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // DISPOSE
  // ════════════════════════════════════════════════════════════════════

  @override
  void dispose() {
    _searchCtrl.dispose();
    _reasonDetailsCtrl.dispose();
    super.dispose();
  }
}