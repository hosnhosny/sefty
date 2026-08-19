// lib/screens/admin/violations_list_screen.dart

import 'package:flutter/material.dart';
import '../../services/pb_service.dart';
import '../../widgets/violation_card.dart';
import '../../models/violation_model.dart';
import '../../widgets/evidence_video_dialog.dart';

class ViolationsListScreen extends StatelessWidget {
  const ViolationsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('جميع المخالفات'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: StreamBuilder<List<ViolationModel>>(
          stream: db.getAllViolations(),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snap.hasData || snap.data!.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text(
                      'لا توجد مخالفات مسجلة',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 16),
                    ),
                  ],
                ),
              );
            }

            final violations = snap.data!;

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: violations.length,
              itemBuilder: (ctx, i) => ViolationCard(
                violation: violations[i],
                showOfficer: true,
                onTap: () => _showViolationDetails(context, violations[i]),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showViolationDetails(BuildContext context, ViolationModel v) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) => SingleChildScrollView(
            controller: controller,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      v.violationNumber,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: v.severityColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        v.severityLabel,
                        style: TextStyle(
                          color: v.severityColor == Colors.black
                              ? Colors.white
                              : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),
                _detailRow('الموظف:', v.employeeName),
                _detailRow('الرقم الوظيفي:', v.employeeId),
                _detailRow('القسم:', v.employeeDepartment),
                _detailRow('رجل السلامة:', v.securityOfficerName),
                const Divider(height: 32),
                _detailRow('نوع المخالفة:', v.customType),
                if (v.details.isNotEmpty) _detailRow('التفاصيل:', v.details),
                if (v.location.isNotEmpty) _detailRow('الموقع:', v.location),
                _detailRow(
                  'التاريخ:',
                  '${v.createdAt.day}/${v.createdAt.month}/${v.createdAt.year} ${v.createdAt.hour}:${v.createdAt.minute.toString().padLeft(2, '0')}',
                ),
                if (v.warningCount > 0)
                  _detailRow('عدد الإنذارات:', '${v.warningCount}'),
                if (v.evidenceUrls.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('الدليل:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  // عرض الصور والفيديو من Cloudinary
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: v.evidenceUrls.map((url) {
                      final isVideo = ViolationModel.isVideoUrl(url);

                      if (isVideo) {
                        return GestureDetector(
                          onTap: () => showEvidenceVideoDialog(context, url),
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.play_circle_fill,
                                color: Colors.white, size: 32),
                          ),
                        );
                      }

                      return GestureDetector(
                        onTap: () => _showImageDialog(context, url),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            url,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 100,
                              height: 100,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.broken_image),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showImageDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(8),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 5,
              child: Image.network(
                url,
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Icon(Icons.broken_image,
                      color: Colors.white, size: 48),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}