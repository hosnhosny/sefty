// lib/screens/admin/employee_violations_balance_screen.dart

import 'package:flutter/material.dart';
import '../../models/violation_model.dart';
import '../../services/pb_service.dart';
import '../../utils/constants.dart';

class EmployeeViolationsBalanceScreen extends StatelessWidget {
  const EmployeeViolationsBalanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          title: const Text('لوحة رصيد المخالفات والخصومات'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: StreamBuilder<List<ViolationModel>>(
          stream: db.getAllViolations(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final violations = snapshot.data ?? [];

            // تجميع الخصومات والمخالفات حسب كل موظف
            // فقط المخالفات المقبولة مالياً (fineAmount > 0)
            final Map<String, _EmployeeBalanceInfo> employeeMap = {};

            for (var v in violations) {
              // ✅ تجاهل المخالفات غير المقبولة مالياً
              if (v.fineAmount <= 0) continue;
              if (v.employeeId.isEmpty) continue;

              if (!employeeMap.containsKey(v.employeeId)) {
                employeeMap[v.employeeId] = _EmployeeBalanceInfo(
                  id: v.employeeId,
                  name: v.employeeName,
                  department: v.employeeDepartment,
                  totalDeduction: 0.0,
                  violationsCount: 0,
                );
              }

              final current = employeeMap[v.employeeId]!;
              current.totalDeduction += v.fineAmount;
              current.violationsCount += 1;
            }

            final list = employeeMap.values.toList()
              ..sort((a, b) => b.totalDeduction.compareTo(a.totalDeduction));

            if (list.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.assignment_turned_in,
                        size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'لا توجد خصومات مقبولة مسجلة على الموظفين',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'يتم احتساب الرصيد فقط من المخالفات التي تم قبولها مالياً في لوحة المراجعة',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    ),
                  ],
                ),
              );
            }

            final grandTotal = list.fold<double>(
                0.0, (sum, item) => sum + item.totalDeduction);

            return Column(
              children: [
                // كارت الإجمالي العام
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade700,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.account_balance_wallet,
                              color: Colors.white, size: 28),
                          SizedBox(width: 12),
                          Text(
                            'إجمالي الخصومات المصنعية',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${grandTotal.toStringAsFixed(2)} د.ل',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // قائمة الموظفين
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (ctx, index) {
                      final item = list[index];
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 1,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: Colors.red.shade50,
                            child: const Icon(Icons.person, color: Colors.red),
                          ),
                          title: Text(
                            item.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            'القسم: ${item.department} | عدد المخالفات المقبولة: ${item.violationsCount}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'الخصم المستحق',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey),
                              ),
                              Text(
                                '${item.totalDeduction.toStringAsFixed(2)} د.ل',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EmployeeBalanceInfo {
  final String id;
  final String name;
  final String department;
  double totalDeduction;
  int violationsCount;

  _EmployeeBalanceInfo({
    required this.id,
    required this.name,
    required this.department,
    required this.totalDeduction,
    required this.violationsCount,
  });
}