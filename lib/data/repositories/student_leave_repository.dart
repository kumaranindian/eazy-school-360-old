import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/student_leave.dart';

final studentLeaveRepositoryProvider = Provider<StudentLeaveRepository>((ref) {
  return StudentLeaveRepository();
});

/// Provider: all student leave requests for a school (admin view)
final schoolStudentLeavesProvider = StreamProvider.family<List<StudentLeaveRequest>, String>((ref, schoolId) {
  final repo = ref.watch(studentLeaveRepositoryProvider);
  return repo.getSchoolStudentLeaves(schoolId);
});

/// Provider: pending student leave requests for admin approval
final pendingStudentLeavesProvider = StreamProvider.family<List<StudentLeaveRequest>, String>((ref, schoolId) {
  final repo = ref.watch(studentLeaveRepositoryProvider);
  return repo.getPendingStudentLeaves(schoolId);
});

/// Provider: leave requests for a specific student (parent view)
final studentLeavesProvider = StreamProvider.family<List<StudentLeaveRequest>,
    ({String schoolId, String studentId})>((ref, params) {
  final repo = ref.watch(studentLeaveRepositoryProvider);
  return repo.getStudentLeaves(params.schoolId, params.studentId);
});

/// Provider: student leave requests filtered by class & section (class teacher view)
final classStudentLeavesProvider = StreamProvider.family<List<StudentLeaveRequest>,
    ({String schoolId, String className, String section})>((ref, params) {
  final repo = ref.watch(studentLeaveRepositoryProvider);
  return repo.getClassStudentLeaves(params.schoolId, params.className, params.section);
});

class StudentLeaveRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _leavesCollection(String schoolId) {
    return _firestore.collection('schools').doc(schoolId).collection('studentLeaves');
  }

  /// Get all student leave requests for a school (ordered by creation date)
  Stream<List<StudentLeaveRequest>> getSchoolStudentLeaves(String schoolId) {
    return _leavesCollection(schoolId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => StudentLeaveRequest.fromFirestore(doc))
            .toList());
  }

  /// Get pending student leave requests
  Stream<List<StudentLeaveRequest>> getPendingStudentLeaves(String schoolId) {
    return _leavesCollection(schoolId)
        .where('status', isEqualTo: 'PENDING')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => StudentLeaveRequest.fromFirestore(doc))
            .toList());
  }

  /// Get leave requests filtered by class & section (class teacher view)
  Stream<List<StudentLeaveRequest>> getClassStudentLeaves(String schoolId, String className, String section) {
    return _leavesCollection(schoolId)
        .where('className', isEqualTo: className)
        .where('section', isEqualTo: section)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => StudentLeaveRequest.fromFirestore(doc))
            .toList());
  }

  /// Get leave requests for a specific student
  Stream<List<StudentLeaveRequest>> getStudentLeaves(String schoolId, String studentId) {
    return _leavesCollection(schoolId)
        .where('studentId', isEqualTo: studentId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => StudentLeaveRequest.fromFirestore(doc))
            .toList());
  }

  /// Apply for leave (parent submits)
  Future<String> applyLeave(String schoolId, StudentLeaveRequest request) async {
    final docRef = await _leavesCollection(schoolId).add(request.toFirestore());
    return docRef.id;
  }

  /// Approve a leave request
  Future<void> approveLeave(String schoolId, String leaveId, String approvedBy) async {
    await _leavesCollection(schoolId).doc(leaveId).update({
      'status': StudentLeaveStatus.APPROVED.name,
      'approvedBy': approvedBy,
      'approvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Reject a leave request
  Future<void> rejectLeave(String schoolId, String leaveId, String rejectedBy, String reason) async {
    await _leavesCollection(schoolId).doc(leaveId).update({
      'status': StudentLeaveStatus.REJECTED.name,
      'approvedBy': rejectedBy,
      'rejectionReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Cancel a leave request (by parent)
  Future<void> cancelLeave(String schoolId, String leaveId) async {
    await _leavesCollection(schoolId).doc(leaveId).update({
      'status': StudentLeaveStatus.CANCELLED.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
