// lib/screens/admin/wallets_screen.dart
//
// شاشة محفظة رجال الأمن والكاميرات — تعرض رصيد كل واحد منهم من نصيبه في
// قيم المخالفات المقبولة، مع إمكانية تصفير محفظة فرد واحد أو الكل دفعة واحدة.

import 'package:flutter/material.dart';
import '../../services/pb_service.dart';

class WalletsScreen extends StatefulWidget {
  const WalletsScreen({super.key});

  @override
  State<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends State<WalletsScreen> {
  final _db = DatabaseService();
  bool _resetting = false;

  String _roleLabel(String role) {
    switch (role) {
      case 'security':
        return 'رجل أمن';
      case 'camera':
        return 'رجل كاميرات';
      default:
        return role;
    }
  }

  IconData _roleIcon(String role) =>
      role == 'camera' ? Icons.videocam : Icons.security;

  Color _roleColor(String role) =>
      role == 'camera' ? Colors.purple : Colors.blue;

  Future<void> _confirmResetAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange),
              SizedBox(width: 10),
              Text('تصفير كل المحافظ'),
            ],
          ),
          content: const Text(
            'سيتم تصفير رصيد جميع رجال الأمن ورجال الكاميرات إلى صفر. '
                'هذا الإجراء لا يمكن التراجع عنه. هل تريد المتابعة؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تصفير الكل',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() => _resetting = true);
    try {
      await _db.resetAllWallets();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم تصفير كل المحافظ'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  Future<void> _confirmResetOne(String uid, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('تصفير المحفظة'),
          content: Text('هل تريد تصفير رصيد $name؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child:
              const Text('تصفير', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      await _db.resetSingleWallet(uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم تصفير محفظة $name'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          title: const Text('محفظة رجال الأمن والكاميرات'),
          backgroundColor: const Color(0xFF1565C0),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: _resetting
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
                  : const Icon(Icons.restart_alt),
              tooltip: 'تصفير كل المحافظ',
              onPressed: _resetting ? null : _confirmResetAll,
            ),
          ],
        ),
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _db.watchStaffWallets(),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final list = snap.data ?? [];
            if (list.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.account_balance_wallet_outlined,
                        size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text('لا يوجد رجال أمن أو كاميرات مسجّلين',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 16)),
                  ],
                ),
              );
            }

            final total = list.fold<double>(
                0, (sum, e) => sum + (e['wallet_balance'] as double));

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── إجمالي المحافظ ──────────────────────────────
                Container(
                  padding: const EdgeInsets.all(18),
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
                      const Icon(Icons.account_balance_wallet,
                          color: Colors.white, size: 32),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('إجمالي أرصدة المحافظ',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 13)),
                            Text(
                              '${total.toStringAsFixed(2)} د.ل',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── قائمة الأفراد ────────────────────────────────
                ...list.map((person) {
                  final uid = person['uid'] as String;
                  final name = person['name'] as String;
                  final role = person['role'] as String;
                  final balance = person['wallet_balance'] as double;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      leading: CircleAvatar(
                        backgroundColor:
                        _roleColor(role).withValues(alpha: 0.12),
                        child: Icon(_roleIcon(role), color: _roleColor(role)),
                      ),
                      title: Text(name,
                          style:
                          const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(_roleLabel(role),
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: balance > 0
                                  ? Colors.green.shade50
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${balance.toStringAsFixed(2)} د.ل',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: balance > 0
                                    ? Colors.green.shade800
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.refresh,
                                size: 18, color: Colors.grey.shade500),
                            tooltip: 'تصفير هذه المحفظة',
                            onPressed: balance == 0
                                ? null
                                : () => _confirmResetOne(uid, name),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}