class Extinguisher {
  final String id;
  final int number;
  final String location;
  final String type;
  final double baseWeight;
  final String? photoUrl;

  Extinguisher({
    required this.id,
    required this.number,
    required this.location,
    required this.type,
    required this.baseWeight,
    this.photoUrl,
  });

  factory Extinguisher.fromJson(Map<String, dynamic> json) {
    return Extinguisher(
      id: json['id']?.toString() ?? '',
      // PocketBase عادة يُرجع حقل Number كـ int عندما يكون صحيحاً بدون كسور،
      // لكن لا نضمن ذلك دائماً (يعتمد على كيفية تخزينه). نستخدم num ثم
      // .toInt() حتى لا ينهار التطبيق لو وصل كـ double (مثل 45.0).
      number: (json['number'] as num?)?.toInt() ?? 0,
      location: json['location'] ?? '',
      type: json['type'] ?? '',
      baseWeight: (json['base_weight'] as num?)?.toDouble() ?? 0.0,
      photoUrl: json['photo_url'],
    );
  }
}

class InspectionLog {
  final String id;
  final String extinguisherId;
  final double currentWeight;
  final String capacityStatus;
  final String metalSeal;
  final String plasticSeal;
  final String notes;
  final String overallStatus;
  final String inspectorId;
  final String inspectorName;
  final DateTime inspectionDate;
  final String? inspectionPhotoUrl;

  InspectionLog({
    required this.id,
    required this.extinguisherId,
    required this.currentWeight,
    required this.capacityStatus,
    required this.metalSeal,
    required this.plasticSeal,
    required this.notes,
    required this.overallStatus,
    required this.inspectorId,
    required this.inspectorName,
    required this.inspectionDate,
    this.inspectionPhotoUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'extinguisher_id': extinguisherId,
      'current_weight': currentWeight,
      'capacity_status': capacityStatus,
      'metal_seal': metalSeal,
      'plastic_seal': plasticSeal,
      'notes': notes,
      'overall_status': overallStatus,
      'inspector_id': inspectorId,
      'inspector_name': inspectorName,
      'inspection_date': inspectionDate.toIso8601String(),
      'inspection_photo_url': inspectionPhotoUrl,
    };
  }
}