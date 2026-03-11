import 'package:cloud_firestore/cloud_firestore.dart';

/// Leave cancellation request status enum
enum LeaveCancellationStatus {
  PENDING,
  APPROVED,
  REJECTED,
}

/// Leave cancellation request entity
class LeaveCancellationRequest {
  final String id;
  final String schoolId;
  final String leaveApplicationId;
  final String applicantId; // User ID of the staff requesting cancellation
  final String staffId; // Staff profile ID
  final String leaveTypeId;
  final String leaveTypeCode;
  final String academicYear;
  final int totalDaysToRestore; // Days to restore to balance
  final String cancellationReason;
  final LeaveCancellationStatus status;
  final DateTime requestedAt;
  final DateTime updatedAt;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final String? adminRemarks;
  final Map<String, dynamic>? metadata;

  const LeaveCancellationRequest({
    required this.id,
    required this.schoolId,
    required this.leaveApplicationId,
    required this.applicantId,
    required this.staffId,
    required this.leaveTypeId,
    required this.leaveTypeCode,
    required this.academicYear,
    required this.totalDaysToRestore,
    required this.cancellationReason,
    required this.status,
    required this.requestedAt,
    required this.updatedAt,
    this.approvedBy,
    this.approvedAt,
    this.rejectionReason,
    this.adminRemarks,
    this.metadata,
  });

  factory LeaveCancellationRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LeaveCancellationRequest(
      id: doc.id,
      schoolId: data['schoolId'] as String,
      leaveApplicationId: data['leaveApplicationId'] as String,
      applicantId: data['applicantId'] as String,
      staffId: data['staffId'] as String,
      leaveTypeId: data['leaveTypeId'] as String,
      leaveTypeCode: data['leaveTypeCode'] as String,
      academicYear: data['academicYear'] as String,
      totalDaysToRestore: (data['totalDaysToRestore'] as num).toInt(),
      cancellationReason: data['cancellationReason'] as String,
      status: _parseStatus(data['status']),
      requestedAt: (data['requestedAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      approvedBy: data['approvedBy'] as String?,
      approvedAt: data['approvedAt'] != null 
          ? (data['approvedAt'] as Timestamp).toDate() 
          : null,
      rejectionReason: data['rejectionReason'] as String?,
      adminRemarks: data['adminRemarks'] as String?,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  static LeaveCancellationStatus _parseStatus(dynamic status) {
    if (status == null) return LeaveCancellationStatus.PENDING;
    switch (status.toString().toUpperCase()) {
      case 'PENDING':
        return LeaveCancellationStatus.PENDING;
      case 'APPROVED':
        return LeaveCancellationStatus.APPROVED;
      case 'REJECTED':
        return LeaveCancellationStatus.REJECTED;
      default:
        return LeaveCancellationStatus.PENDING;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'schoolId': schoolId,
      'leaveApplicationId': leaveApplicationId,
      'applicantId': applicantId,
      'staffId': staffId,
      'leaveTypeId': leaveTypeId,
      'leaveTypeCode': leaveTypeCode,
      'academicYear': academicYear,
      'totalDaysToRestore': totalDaysToRestore,
      'cancellationReason': cancellationReason,
      'status': status.name,
      'requestedAt': Timestamp.fromDate(requestedAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'approvedBy': approvedBy,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'rejectionReason': rejectionReason,
      'adminRemarks': adminRemarks,
      'metadata': metadata,
    };
  }

  bool get isPending => status == LeaveCancellationStatus.PENDING;
  bool get isApproved => status == LeaveCancellationStatus.APPROVED;
  bool get isRejected => status == LeaveCancellationStatus.REJECTED;
  bool get canBeApproved => status == LeaveCancellationStatus.PENDING;

  String get statusDisplayName {
    switch (status) {
      case LeaveCancellationStatus.PENDING:
        return 'Pending';
      case LeaveCancellationStatus.APPROVED:
        return 'Approved';
      case LeaveCancellationStatus.REJECTED:
        return 'Rejected';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LeaveCancellationRequest && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'LeaveCancellationRequest(id: $id, leaveApplicationId: $leaveApplicationId, status: $status)';
  }
}

/// Request model for creating leave cancellation request
class CreateLeaveCancellationRequest {
  final String leaveApplicationId;
  final String cancellationReason;

  const CreateLeaveCancellationRequest({
    required this.leaveApplicationId,
    required this.cancellationReason,
  });

  Map<String, dynamic> toMap() {
    return {
      'leaveApplicationId': leaveApplicationId,
      'cancellationReason': cancellationReason,
    };
  }
}

/// Request model for approving/rejecting leave cancellation
class LeaveCancellationApprovalRequest {
  final LeaveCancellationStatus status;
  final String? rejectionReason;
  final String? adminRemarks;

  const LeaveCancellationApprovalRequest({
    required this.status,
    this.rejectionReason,
    this.adminRemarks,
  });

  Map<String, dynamic> toMap() {
    return {
      'status': status.name,
      'rejectionReason': rejectionReason,
      'adminRemarks': adminRemarks,
    };
  }
}
