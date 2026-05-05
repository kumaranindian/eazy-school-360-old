import 'package:cloud_firestore/cloud_firestore.dart';

/// RFID Card entity representing a physical RFID card assigned to a staff member
class RfidCard {
  final String id;
  final String uuid;
  final String staffId;
  final String staffName;
  final RfidCardType cardType;
  final bool isActive;
  final DateTime assignedAt;
  final DateTime? lastUsedAt;
  final String schoolId;
  final Map<String, dynamic>? metadata;

  RfidCard({
    required this.id,
    required this.uuid,
    required this.staffId,
    required this.staffName,
    required this.cardType,
    required this.isActive,
    required this.assignedAt,
    this.lastUsedAt,
    required this.schoolId,
    this.metadata,
  });

  /// Create RfidCard from Firestore document
  factory RfidCard.fromFirestore(Map<String, dynamic> data, String id) {
    return RfidCard(
      id: id,
      uuid: data['uuid'] as String? ?? '',
      staffId: data['staffId'] as String? ?? '',
      staffName: data['staffName'] as String? ?? '',
      cardType: RfidCardType.fromString(data['cardType'] as String? ?? 'primary'),
      isActive: data['isActive'] as bool? ?? true,
      assignedAt: (data['assignedAt'] as Timestamp).toDate(),
      lastUsedAt: data['lastUsedAt'] != null
          ? (data['lastUsedAt'] as Timestamp).toDate()
          : null,
      schoolId: data['schoolId'] as String? ?? '',
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'uuid': uuid,
      'staffId': staffId,
      'staffName': staffName,
      'cardType': cardType.value,
      'isActive': isActive,
      'assignedAt': Timestamp.fromDate(assignedAt),
      if (lastUsedAt != null) 'lastUsedAt': Timestamp.fromDate(lastUsedAt!),
      'schoolId': schoolId,
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// Create a copy with updated fields
  RfidCard copyWith({
    String? id,
    String? uuid,
    String? staffId,
    String? staffName,
    RfidCardType? cardType,
    bool? isActive,
    DateTime? assignedAt,
    DateTime? lastUsedAt,
    String? schoolId,
    Map<String, dynamic>? metadata,
  }) {
    return RfidCard(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      staffId: staffId ?? this.staffId,
      staffName: staffName ?? this.staffName,
      cardType: cardType ?? this.cardType,
      isActive: isActive ?? this.isActive,
      assignedAt: assignedAt ?? this.assignedAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      schoolId: schoolId ?? this.schoolId,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Enum representing the type of RFID card
enum RfidCardType {
  primary('primary'),
  backup('backup');

  final String value;
  const RfidCardType(this.value);

  /// Get enum from string value
  static RfidCardType fromString(String value) {
    return RfidCardType.values.firstWhere(
      (type) => type.value == value.toLowerCase(),
      orElse: () => RfidCardType.primary,
    );
  }

  /// Get display name
  String get displayName {
    switch (this) {
      case RfidCardType.primary:
        return 'Primary Card';
      case RfidCardType.backup:
        return 'Backup Card';
    }
  }
}
