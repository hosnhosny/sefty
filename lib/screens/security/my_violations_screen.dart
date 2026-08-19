// lib/screens/security/my_violations_screen.dart

import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/violation_model.dart';
import '../../services/pb_service.dart';
import '../../utils/enums.dart';
import '../../widgets/evidence_video_dialog.dart';
import 'fix_upload_screen.dart';

class MyViolationsScreen extends StatefulWidget {
  final UserModel currentUser;
  const MyViolationsScreen({super.key, required this.currentUser});

  @override
  State<MyViolationsScreen> createState() => _MyViolationsScreenState();
}

class _MyViolationsScreenState extends State<MyViolationsScreen> {
  final _db = DatabaseService();

  // ─── فلتر ────────────────────────────────────────────────────────────
  String _filterSeverity = 'الكل';
  final List<String> _severityOptions = ['الكل', 'خفيفة', 'متوسطة', 'كبيرة', 'خطيرة جداً'];

  // ════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          title: const Text(
            'سجل مخالفاتي',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red.shade700,
          foregroundColor: Colors.white,
          centerTitle: true,
          actions: [
            // فلتر الخطورة
            PopupMenuButton<String>(
              icon: const Icon(Icons.filter_list),
              onSelected: (v) => setState(() => _filterSeverity = v),
              itemBuilder: (_) => _severityOptions
                  .map((s) => PopupMenuItem(value: s, child: Text(s)))
                  .toList(),
            ),
          ],
        ),
        body: StreamBuilder<List<ViolationModel>>(
          stream: _db.getViolationsBySecurityOfficer(
            widget.currentUser.uid,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text('خطأ: ${snapshot.error}'),
              );
            }

            final list = snapshot.data ?? [];

            if (list.isEmpty) {
              return _buildEmpty();
            }

            // فلترة حسب الخطورة
            var violations = list;
            if (_filterSeverity != 'الكل') {
              violations = violations
                  .where((v) => v.severityLabel == _filterSeverity)
                  .toList();
            }

            if (violations.isEmpty) {
              return _buildEmpty(filtered: true);
            }

            return Column(
              children: [
                // ── إحصائيات سريعة ────────────────────────────────
                _buildStats(violations),

                // ── فلتر نشط ──────────────────────────────────────
                if (_filterSeverity != 'الكل')
                  Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.filter_alt,
                            size: 16, color: Colors.orange),
                        const SizedBox(width: 6),
                        Text('فلتر: $_filterSeverity',
                            style:
                            const TextStyle(color: Colors.orange)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _filterSeverity = 'الكل'),
                          child: const Icon(Icons.close,
                              size: 16, color: Colors.orange),
                        ),
                      ],
                    ),
                  ),

                // ── القائمة ───────────────────────────────────────
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: violations.length,
                    itemBuilder: (ctx, i) =>
                        _buildViolationCard(violations[i]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // WIDGETS
  // ════════════════════════════════════════════════════════════════════

  Widget _buildStats(List<ViolationModel> violations) {
    final light = violations
        .where((v) => v.severity.name == 'light')
        .length;
    final medium = violations
        .where((v) => v.severity.name == 'medium')
        .length;
    final major = violations
        .where((v) => v.severity.name == 'major')
        .length;
    final critical = violations
        .where((v) => v.severity.name == 'critical')
        .length;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart, color: Colors.red),
              const SizedBox(width: 8),
              const Text(
                'إجمالي المخالفات المسجّلة',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${violations.length}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statChip('خفيفة', light, const Color(0xFFFFEB3B),
                  Colors.black87),
              const SizedBox(width: 8),
              _statChip('متوسطة', medium, const Color(0xFFFF9800),
                  Colors.white),
              const SizedBox(width: 8),
              _statChip(
                  'كبيرة', major, const Color(0xFFF44336), Colors.white),
              const SizedBox(width: 8),
              _statChip('خطيرة', critical, const Color(0xFF212121),
                  Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(
      String label, int count, Color bg, Color textColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18),
            ),
            Text(
              label,
              style: TextStyle(color: textColor, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViolationCard(ViolationModel v) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: v.severityColor.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────
            Row(
              children: [
                // رقم المخالفة
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    v.violationNumber,
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const Spacer(),
                // حالة المراجعة (للمخالفات الكبيرة والخطيرة)
                if (v.requiresReview) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: v.status.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: v.status.color.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      '${v.status.emoji} ${v.status.label}',
                      style: TextStyle(
                          color: v.status.color,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                // درجة الخطورة
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: v.severityColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    v.severityLabel,
                    style: TextStyle(
                      color: v.severityTextColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── اسم الموظف ──────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    v.employeeName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // ── القسم ───────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.business, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  v.employeeDepartment,
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // ── نوع المخالفة ─────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.warning_amber,
                    size: 16, color: Colors.orange),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    v.customType,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),

            // ── الموقع ──────────────────────────────────────────
            if (v.location.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    v.location,
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ],

            const Divider(height: 16),

            // ── زر رفع صورة الإصلاح ─────────────────────────────
            if (v.requiresReview &&
                (v.status == ViolationStatus.inProgress ||
                    v.status == ViolationStatus.rejected)) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FixUploadScreen(violation: v),
                    ),
                  ),
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: Text(
                    v.status == ViolationStatus.rejected
                        ? 'إعادة رفع صورة الإصلاح ❌'
                        : 'رفع صورة الإصلاح 📸',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: v.status == ViolationStatus.rejected
                        ? Colors.red
                        : Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // تعليق المدير
            if (v.managerComment != null &&
                v.managerComment!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.comment, size: 14, color: Colors.blue),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(v.managerComment!,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.blue)),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
            ],

            // ── Footer ──────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '${v.createdAt.year}/${v.createdAt.month.toString().padLeft(2, '0')}/${v.createdAt.day.toString().padLeft(2, '0')}  '
                      '${v.createdAt.hour.toString().padLeft(2, '0')}:${v.createdAt.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 12),
                ),
                const Spacer(),
                // إنذارات
                if (v.warningCount >= 3)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning,
                            size: 12, color: Colors.red),
                        const SizedBox(width: 4),
                        Text(
                          '${v.warningCount} إنذارات',
                          style: const TextStyle(
                              color: Colors.red,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            // ── أدلة المخالفة (صور وفيديو) ───────────────────────
            if (v.evidenceUrls.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: v.evidenceUrls.length,
                  itemBuilder: (ctx, i) {
                    final url = v.evidenceUrls[i];
                    final isVideo = ViolationModel.isVideoUrl(url);

                    if (isVideo) {
                      return GestureDetector(
                        onTap: () => showEvidenceVideoDialog(context, url),
                        child: Container(
                          margin: const EdgeInsets.only(left: 6),
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.play_circle_fill,
                              color: Colors.white, size: 26),
                        ),
                      );
                    }

                    return GestureDetector(
                      onTap: () => _showImageDialog(url),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          url,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          loadingBuilder: (ctx, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey.shade200,
                              child: const Center(
                                  child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))),
                            );
                          },
                          errorBuilder: (ctx, error, stack) => Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image,
                                color: Colors.grey, size: 20),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty({bool filtered = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            filtered ? Icons.filter_alt_off : Icons.assignment_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            filtered
                ? 'لا توجد مخالفات بهذا الفلتر'
                : 'لم تسجّل أي مخالفة بعد',
            style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 16,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  void _showImageDialog(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}