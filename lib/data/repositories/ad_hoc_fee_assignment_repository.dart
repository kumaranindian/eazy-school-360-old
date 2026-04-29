import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/ad_hoc_fee_assignment.dart';

/// Repository for managing ad-hoc fee assignments (event-based fees, bulk assignments).
class AdHocFeeAssignmentRepository {
  final FirebaseFirestore _firestore;

  AdHocFeeAssignmentRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> _col(String schoolId) =>
      _firestore.collection('schools').doc(schoolId).collection('adHocFeeAssignments');

  /// Get all assignments for a school
  Future<List<AdHocFeeAssignment>> getAll(String schoolId, String academicYear) async {
    final snap = await _col(schoolId)
        .where('academicYear', isEqualTo: academicYear)
        .orderBy('createdAt', descending: true)
        .get();

    return snap.docs.map((d) => AdHocFeeAssignment.fromFirestore(d)).toList();
  }

  /// Stream assignments
  Stream<List<AdHocFeeAssignment>> streamAll(String schoolId, String academicYear) {
    return _col(schoolId)
        .where('academicYear', isEqualTo: academicYear)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => AdHocFeeAssignment.fromFirestore(d)).toList());
  }

  /// Get a single assignment
  Future<AdHocFeeAssignment?> getById(String schoolId, String assignmentId) async {
    final doc = await _col(schoolId).doc(assignmentId).get();
    if (!doc.exists) return null;
    return AdHocFeeAssignment.fromFirestore(doc);
  }

  /// Create a new assignment
  Future<String> create(String schoolId, AdHocFeeAssignment assignment) async {
    final data = assignment.toFirestore();
    data['createdAt'] = FieldValue.serverTimestamp();
    final ref = await _col(schoolId).add(data);
    return ref.id;
  }

  /// Update an assignment
  Future<void> update(String schoolId, String assignmentId, AdHocFeeAssignment assignment) async {
    await _col(schoolId).doc(assignmentId).update(assignment.toFirestore());
  }

  /// Update assignment progress
  Future<void> updateProgress(
    String schoolId,
    String assignmentId,
    int assignedCount,
  ) async {
    await _col(schoolId).doc(assignmentId).update({
      'assignedCount': assignedCount,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Mark assignment as complete
  Future<void> markComplete(String schoolId, String assignmentId) async {
    await _col(schoolId).doc(assignmentId).update({
      'status': 'completed',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Cancel an assignment
  Future<void> cancel(String schoolId, String assignmentId, String reason) async {
    await _col(schoolId).doc(assignmentId).update({
      'status': 'cancelled',
      'notes': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete an assignment
  Future<void> delete(String schoolId, String assignmentId) async {
    await _col(schoolId).doc(assignmentId).delete();
  }
}

final adHocFeeAssignmentRepositoryProvider = Provider<AdHocFeeAssignmentRepository>((ref) {
  return AdHocFeeAssignmentRepository(FirebaseFirestore.instance);
});

/// Stream provider for ad-hoc assignments
final adHocFeeAssignmentsProvider = StreamProvider.family<List<AdHocFeeAssignment>, ({String schoolId, String academicYear})>(
  (ref, params) {
    return ref
        .watch(adHocFeeAssignmentRepositoryProvider)
        .streamAll(params.schoolId, params.academicYear);
  },
);
