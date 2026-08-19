// lib/models/user_model.dart

import 'package:pocketbase/pocketbase.dart';

class UserModel {
  final String uid; // = record.id (معرّف PocketBase الحقيقي)
  final String name;
  final String email;
  final String role; // 'admin' | 'security' | 'camera'
  final String? employeeId;
  final String? department;
  final int points;
  final double walletBalance; // رصيد محفظة رجل الأمن/الكاميرات من المخالفات المقبولة
  final bool isActive;
  final DateTime createdAt;
  final String? phone;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.employeeId,
    this.department,
    this.points = 0,
    this.walletBalance = 0.0,
    this.isActive = true,
    required this.createdAt,
    this.phone,
  });

  /// يبني UserModel من RecordModel القادم من مجموعة "users" في PocketBase
  factory UserModel.fromRecord(RecordModel record) {
    return UserModel(
      uid: record.id,
      name: record.getStringValue('name'),
      email: record.getStringValue('email'),
      role: record.data['role'] ?? 'security',
      employeeId: record.data['employee_id'],
      department: record.data['department'],
      points: record.getIntValue('points'),
      walletBalance: (record.data['wallet_balance'] ?? 0).toDouble(),
      isActive: record.data['is_active'] ?? true,
      createdAt: record.created.isNotEmpty
          ? DateTime.parse(record.created)
          : DateTime.now(),
      phone: record.data['phone'],
    );
  }

  /// للاستخدام عند إنشاء/تحديث سجل (body لطلب create/update في PocketBase)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'employee_id': employeeId,
      'department': department,
      'points': points,
      'wallet_balance': walletBalance,
      'is_active': isActive,
      'phone': phone,
    };
  }

  bool get isAdmin => role == 'admin';
  bool get isSecurity => role == 'security';
  bool get isCamera => role == 'camera';

  UserModel copyWith({
    String? name,
    String? email,
    String? role,
    String? employeeId,
    String? department,
    int? points,
    double? walletBalance,
    bool? isActive,
    String? phone,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      employeeId: employeeId ?? this.employeeId,
      department: department ?? this.department,
      points: points ?? this.points,
      walletBalance: walletBalance ?? this.walletBalance,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      phone: phone ?? this.phone,
    );
  }
}