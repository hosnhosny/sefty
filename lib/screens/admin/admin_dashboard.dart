import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/violation_model.dart';
import '../../services/auth_service.dart';
import '../../services/excel_service.dart';
import '../../services/pb_service.dart';
import '../../services/notification_service.dart';
import '../../services/theme_service.dart'; // ✅ NEW
import '../notifications_screen.dart';
import '../settings_screen.dart'; // ✅ NEW
import 'admin_control_panel_screen.dart';
import 'violations_list_screen.dart';
import 'leaves_list_screen.dart';
import 'reports_list_screen.dart';
import 'review_panel_screen.dart';
import '../login_screen.dart';
import 'wallets_screen.dart';

class AdminDashboard extends StatefulWidget {
  final UserModel adminUser;
  const AdminDashboard({super.key, required this.adminUser});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _authService = AuthService();
  final _excelService = ExcelService();
  final _db = DatabaseService();
  final _notification = NotificationService();
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _notification.initialize();
    _notification
        .getUnreadCount(widget.adminUser.uid)
        .listen((count) {
      if (mounted) setState(() => _unreadCount = count);
    });
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    }
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'تصدير Excel',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _exportOption(
                icon: Icons.warning_amber,
                color: Colors.red,
                title: 'تصدير المخالفات',
                subtitle: 'المخالفات غير المصدّرة',
                onTap: () async {
                  Navigator.pop(ctx);
                  await _exportAction(
                        () => _excelService.exportViolationsToExcel(),
                    'تم تصدير المخالفات بنجاح ✅',
                  );
                },
              ),
              const SizedBox(height: 12),
              _exportOption(
                icon: Icons.exit_to_app,
                color: Colors.orange,
                title: 'تصدير إذن الانصراف',
                subtitle: 'جميع الإذونات',
                onTap: () async {
                  Navigator.pop(ctx);
                  await _exportAction(
                        () => _excelService.exportLeavesToExcel(),
                    'تم تصدير الإذونات بنجاح ✅',
                  );
                },
              ),
              const SizedBox(height: 12),
              _exportOption(
                icon: Icons.folder_zip,
                color: Colors.purple,
                title: 'تصدير شامل',
                subtitle: 'المخالفات + الإذونات',
                onTap: () async {
                  Navigator.pop(ctx);
                  await _exportAction(
                        () => _excelService.exportAllToExcel(),
                    'تم التصدير الشامل بنجاح ✅',
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportAction(
      Future<String?> Function() action,
      String successMsg,
      ) async {
    final path = await action();
    if (path != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMsg), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor, // ✅ NEW: دعم الثيم الداكن
        appBar: AppBar(
          title: const Text('لوحة المدير'),
          backgroundColor: const Color(0xFF1565C0),
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            // ✅ NEW: زر تبديل الوضع الداكن
            ValueListenableBuilder<ThemeMode>(
              valueListenable: ThemeService.themeNotifier,
              builder: (context, currentMode, child) {
                final isDark = currentMode == ThemeMode.dark;
                return IconButton(
                  icon: Icon(
                    isDark ? Icons.dark_mode : Icons.light_mode,
                    color: isDark ? Colors.amber : Colors.white,
                  ),
                  tooltip: isDark ? 'الوضع الفاتح' : 'الوضع الداكن',
                  onPressed: () => ThemeService.toggleTheme(),
                );
              },
            ),
            // ✅ NEW: زر الإعدادات
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'الإعدادات',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
            // Notification bell
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          NotificationsScreen(userId: widget.adminUser.uid),
                    ),
                  ),
                ),
                if (_unreadCount > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$_unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'تسجيل الخروج',
              onPressed: _logout,
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Welcome Banner ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white24,
                      child: Icon(
                        Icons.admin_panel_settings,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'مرحباً، ${widget.adminUser.name}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dateStr,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'SAFI FOOD COMPLEX',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Stats (real-time) ───────────────────────────────────────
              StreamBuilder<List<ViolationModel>>(
                stream: _db.getAllViolations(),
                builder: (ctx, snap) {
                  int total = 0, light = 0, medium = 0,
                      major = 0, critical = 0, redAlerts = 0;
                  if (snap.hasData) {
                    for (final v in snap.data!) {
                      total++;
                      switch (v.severity.name) {
                        case 'light':    light++;    break;
                        case 'medium':   medium++;   break;
                        case 'major':    major++;    break;
                        case 'critical': critical++; break;
                      }
                      if (v.warningCount >= 3) redAlerts++;
                    }
                  }
                  return Column(
                    children: [
                      Row(
                        children: [
                          _statCard('$total', 'إجمالي', Colors.blue, Icons.bar_chart),
                          const SizedBox(width: 12),
                          _statCard('$redAlerts', 'إنذار أحمر', Colors.red, Icons.notification_important, isAlert: redAlerts > 0),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _statCard('$light',    'خفيفة',   Colors.amber,       Icons.info_outline),
                          const SizedBox(width: 8),
                          _statCard('$medium',   'متوسطة',  Colors.orange,      Icons.report_problem_outlined),
                          const SizedBox(width: 8),
                          _statCard('$major',    'كبيرة',   Colors.red,         Icons.error_outline),
                          const SizedBox(width: 8),
                          _statCard('$critical', 'خطيرة',   Colors.black87,     Icons.dangerous_outlined),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // ── Red alerts list ─────────────────────────────────────────
              StreamBuilder<List<ViolationModel>>(
                stream: _db.getAllViolations().map((violations) {
                  final redOnes = violations
                      .where((v) => v.warningCount >= 3)
                      .toList()
                    ..sort((a, b) => b.warningCount.compareTo(a.warningCount));
                  return redOnes.take(3).toList();
                }),
                builder: (ctx, snap) {
                  if (!snap.hasData || snap.data!.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.notification_important,
                              color: Colors.red),
                          SizedBox(width: 8),
                          Text(
                            'إنذارات حمراء',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...snap.data!.map((v) {
                        return Card(
                          color: Colors.red.shade50,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Colors.red),
                          ),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(Icons.person, color: Colors.red),
                            title: Text(
                              v.employeeName.isNotEmpty ? v.employeeName : '—',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                                '${v.warningCount} إنذارات · ${v.employeeDepartment}'),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${v.warningCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),

              // ── Menu ────────────────────────────────────────────────────
              const Text(
                'القائمة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _menuCard(
                icon: Icons.admin_panel_settings,
                color: Colors.indigo,
                title: 'لوحة التحكم',
                subtitle: 'إدارة رجال الأمن والموظفين والمدراء',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const AdminControlPanelScreen())),
              ),
              const SizedBox(height: 12),
              _menuCard(
                icon: Icons.rate_review,
                color: const Color(0xFF1565C0),
                title: 'لوحة المراجعة',
                subtitle: 'متابعة وإغلاق المخالفات الكبيرة والخطيرة',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ReviewPanelScreen(
                            currentUser: widget.adminUser))),
              ),
              const SizedBox(height: 12),
              _menuCard(
                icon: Icons.account_balance_wallet,
                color: Colors.teal,
                title: 'محفظة رجال الأمن',
                subtitle: 'أرصدة رجال الأمن والكاميرات من المخالفات',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const WalletsScreen())),
              ),
              const SizedBox(height: 12),
              _menuCard(
                icon: Icons.warning_amber,
                color: Colors.red,
                title: 'المخالفات',
                subtitle: 'عرض وإدارة جميع المخالفات',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ViolationsListScreen())),
              ),
              const SizedBox(height: 12),
              _menuCard(
                icon: Icons.exit_to_app,
                color: Colors.orange,
                title: 'إذن الانصراف',
                subtitle: 'الإذونات النشطة والسابقة',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const LeavesListScreen())),
              ),
              const SizedBox(height: 12),
              _menuCard(
                icon: Icons.picture_as_pdf,
                color: Colors.purple,
                title: 'التقارير',
                subtitle: 'تقارير رجال السلامة',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ReportsListScreen())),
              ),
              const SizedBox(height: 12),
              _menuCard(
                icon: Icons.table_chart,
                color: Colors.green,
                title: 'تصدير Excel',
                subtitle: 'تصدير البيانات لملف Excel',
                onTap: _showExportOptions,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _statCard(String n, String label, Color color, IconData icon,
      {bool isAlert = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isAlert ? Colors.red.shade50 : Theme.of(context).cardColor, // ✅ NEW: دعم الثيم الداكن
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                spreadRadius: 1),
          ],
          border: isAlert ? Border.all(color: Colors.red, width: 1.5) : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(n,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style:
                TextStyle(color: Colors.grey.shade600, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _menuCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.arrow_back_ios,
                  color: Colors.grey.shade400, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _exportOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
      trailing: const Icon(Icons.arrow_back_ios, size: 14),
      onTap: onTap,
    );
  }
}