import 'package:cloud_firestore/cloud_firestore.dart';

/// Leave type configuration for a school
class LeaveTypeConfig {
  final String id;
  final String schoolId;
  final String name;
  final String code; // CASUAL, SICK, EARNED, CUSTOM
  final String description;
  final int annualQuota; // Total days per academic year
  final bool carryForwardAllowed;
  final int maxCarryForwardDays; // Maximum days that can be carried forward
  final int maxDaysPerRequest; // Maximum days per single request
  final bool isPaid;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final Map<String, dynamic>? customRules; // Additional configurable rules

  const LeaveTypeConfig({
    required this.id,
    required this.schoolId,
    required this.name,
    required this.code,
    required this.description,
    required this.annualQuota,
    required this.carryForwardAllowed,
    required this.maxCarryForwardDays,
    required this.maxDaysPerRequest,
    required this.isPaid,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.customRules,
  });

  factory LeaveTypeConfig.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    // Seeded docs (casual, sick, earned) have no 'code' field — derive from doc ID
    final rawCode = data['code'] as String? ?? '';
    final code = rawCode.isNotEmpty ? rawCode.toUpperCase() : doc.id.toUpperCase();
    return LeaveTypeConfig(
      id: doc.id,
      schoolId: data['schoolId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      code: code,
      description: data['description'] as String? ?? '',
      annualQuota: (data['annualQuota'] as num?)?.toInt() ?? 0,
      carryForwardAllowed: data['carryForwardAllowed'] as bool? ?? false,
      maxCarryForwardDays: (data['maxCarryForwardDays'] as num?)?.toInt() ?? 0,
      maxDaysPerRequest: (data['maxDaysPerRequest'] as num?)?.toInt() ?? 1,
      isPaid: data['isPaid'] as bool? ?? true,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] as String? ?? 'system',
      customRules: data['customRules'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'schoolId': schoolId,
      'name': name,
      'code': code,
      'description': description,
      'annualQuota': annualQuota,
      'carryForwardAllowed': carryForwardAllowed,
      'maxCarryForwardDays': maxCarryForwardDays,
      'maxDaysPerRequest': maxDaysPerRequest,
      'isPaid': isPaid,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
      'customRules': customRules,
    };
  }

  LeaveTypeConfig copyWith({
    String? id,
    String? schoolId,
    String? name,
    String? code,
    String? description,
    int? annualQuota,
    bool? carryForwardAllowed,
    int? maxCarryForwardDays,
    int? maxDaysPerRequest,
    bool? isPaid,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    Map<String, dynamic>? customRules,
  }) {
    return LeaveTypeConfig(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      name: name ?? this.name,
      code: code ?? this.code,
      description: description ?? this.description,
      annualQuota: annualQuota ?? this.annualQuota,
      carryForwardAllowed: carryForwardAllowed ?? this.carryForwardAllowed,
      maxCarryForwardDays: maxCarryForwardDays ?? this.maxCarryForwardDays,
      maxDaysPerRequest: maxDaysPerRequest ?? this.maxDaysPerRequest,
      isPaid: isPaid ?? this.isPaid,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      customRules: customRules ?? this.customRules,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LeaveTypeConfig && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'LeaveTypeConfig(id: $id, name: $name, code: $code, schoolId: $schoolId)';
  }
}

/// Standard leave type codes
class LeaveTypeCodes {
  static const String casual = 'CASUAL';
  static const String sick = 'SICK';
  static const String earned = 'EARNED';
  static const String maternity = 'MATERNITY';
  static const String paternity = 'PATERNITY';
  static const String emergency = 'EMERGENCY';
  static const String custom = 'CUSTOM';

  static const List<String> standardTypes = [
    casual,
    sick,
    earned,
    maternity,
    paternity,
    emergency,
  ];

  static String getDisplayName(String code) {
    switch (code) {
      case casual:
        return 'Casual Leave';
      case sick:
        return 'Sick Leave';
      case earned:
        return 'Earned Leave';
      case maternity:
        return 'Maternity Leave';
      case paternity:
        return 'Paternity Leave';
      case emergency:
        return 'Emergency Leave';
      case custom:
        return 'Custom Leave';
      default:
        return code;
    }
  }
}

/// Request model for creating leave type configuration
class CreateLeaveTypeConfigRequest {
  final String name;
  final String code;
  final String description;
  final int annualQuota;
  final bool carryForwardAllowed;
  final int maxCarryForwardDays;
  final int maxDaysPerRequest;
  final bool isPaid;
  final Map<String, dynamic>? customRules;

  const CreateLeaveTypeConfigRequest({
    required this.name,
    required this.code,
    required this.description,
    required this.annualQuota,
    required this.carryForwardAllowed,
    required this.maxCarryForwardDays,
    required this.maxDaysPerRequest,
    required this.isPaid,
    this.customRules,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'code': code,
      'description': description,
      'annualQuota': annualQuota,
      'carryForwardAllowed': carryForwardAllowed,
      'maxCarryForwardDays': maxCarryForwardDays,
      'maxDaysPerRequest': maxDaysPerRequest,
      'isPaid': isPaid,
      'customRules': customRules,
    };
  }
}

/// Request model for updating leave type configuration
class UpdateLeaveTypeConfigRequest {
  final String? name;
  final String? description;
  final int? annualQuota;
  final bool? carryForwardAllowed;
  final int? maxCarryForwardDays;
  final int? maxDaysPerRequest;
  final bool? isPaid;
  final bool? isActive;
  final Map<String, dynamic>? customRules;

  const UpdateLeaveTypeConfigRequest({
    this.name,
    this.description,
    this.annualQuota,
    this.carryForwardAllowed,
    this.maxCarryForwardDays,
    this.maxDaysPerRequest,
    this.isPaid,
    this.isActive,
    this.customRules,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    if (name != null) map['name'] = name;
    if (description != null) map['description'] = description;
    if (annualQuota != null) map['annualQuota'] = annualQuota;
    if (carryForwardAllowed != null) map['carryForwardAllowed'] = carryForwardAllowed;
    if (maxCarryForwardDays != null) map['maxCarryForwardDays'] = maxCarryForwardDays;
    if (maxDaysPerRequest != null) map['maxDaysPerRequest'] = maxDaysPerRequest;
    if (isPaid != null) map['isPaid'] = isPaid;
    if (isActive != null) map['isActive'] = isActive;
    if (customRules != null) map['customRules'] = customRules;
    map['updatedAt'] = FieldValue.serverTimestamp();
    return map;
  }

  bool get hasChanges => 
    name != null || 
    description != null || 
    annualQuota != null || 
    carryForwardAllowed != null || 
    maxCarryForwardDays != null || 
    maxDaysPerRequest != null || 
    isPaid != null || 
    isActive != null || 
    customRules != null;
}
