import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/ad_hoc_fee_assignment.dart';
import '../../domain/entities/student.dart';
import '../../domain/entities/student_fee_item.dart';
import '../repositories/ad_hoc_fee_assignment_repository.dart';
import '../repositories/student_fee_item_repository.dart';
import '../repositories/student_repository.dart';

/// Service for managing ad-hoc fee assignments and bulk fee operations.
/// Handles creating event-based fees and assigning them to multiple students.
class AdHocFeeAssignmentService {
  final AdHocFeeAssignmentRepository _assignmentRepo;
  final StudentFeeItemRepository _feeItemRepo;
  final StudentRepository _studentRepo;

  AdHocFeeAssignmentService(
    this._assignmentRepo,
    this._feeItemRepo,
    this._studentRepo,
  );

  /// Create and execute an ad-hoc fee assignment
  /// Returns the assignment ID and number of students assigned
  Future<AssignmentResult> createAndAssign({
    required String schoolId,
    required String academicYear,
    required String categoryCode,
    required String assignmentName,
    required String description,
    required double amount,
    required DateTime dueDate,
    required String scope, // 'school', 'class', 'section', 'custom'
    List<String> classIds = const [],
    List<String> sections = const [],
    List<String> studentIds = const [],
    String? createdBy,
    String? notes,
  }) async {
    try {
      print('[AdHocFeeAssignment] Starting assignment creation for school: $schoolId');
      
      // Step 1: Get target students based on scope
      final targetStudents = await _getTargetStudents(
        schoolId: schoolId,
        academicYear: academicYear,
        scope: scope,
        classIds: classIds,
        sections: sections,
        studentIds: studentIds,
      );

      print('[AdHocFeeAssignment] Found ${targetStudents.length} target students');

      if (targetStudents.isEmpty) {
        throw Exception('No students found matching the criteria');
      }

      // Step 2: Create the assignment record
      final assignment = AdHocFeeAssignment(
        id: '',
        schoolId: schoolId,
        academicYear: academicYear,
        categoryCode: categoryCode,
        assignmentName: assignmentName,
        description: description,
        amount: amount,
        dueDate: dueDate,
        scope: scope,
        classIds: classIds,
        sections: sections,
        studentIds: studentIds.isEmpty ? targetStudents.map((s) => s.id).toList() : studentIds,
        studentCount: targetStudents.length,
        assignedCount: 0,
        totalAmount: amount * targetStudents.length,
        createdBy: createdBy,
        createdAt: DateTime.now(),
        status: 'active',
        notes: notes,
      );

      print('[AdHocFeeAssignment] Creating assignment record...');
      final assignmentId = await _assignmentRepo.create(schoolId, assignment);
      print('[AdHocFeeAssignment] Assignment created with ID: $assignmentId');

    // Step 3: Create fee items for each student
    final feeItems = <StudentFeeItem>[];
    for (final student in targetStudents) {
      final feeItem = StudentFeeItem(
        id: '',
        schoolId: schoolId,
        studentId: student.id,
        studentName: student.name,
        className: student.className,
        section: student.section,
        academicYear: academicYear,
        categoryCode: categoryCode,
        itemName: assignmentName,
        amount: amount,
        paidAmount: 0,
        balanceAmount: amount,
        dueDate: dueDate,
        source: scope == 'custom' ? 'ad_hoc' : 'event',
        adHocAssignmentId: assignmentId,
        assignmentLevel: scope,
        assignedBy: createdBy,
        assignedAt: DateTime.now(),
        notes: notes,
        isActive: true,
      );
      feeItems.add(feeItem);
    }

      // Step 4: Batch create fee items
      print('[AdHocFeeAssignment] Creating ${feeItems.length} fee items...');
      await _feeItemRepo.createBatch(schoolId, feeItems);
      print('[AdHocFeeAssignment] Fee items created successfully');

      // Step 5: Update assignment progress
      print('[AdHocFeeAssignment] Updating assignment progress...');
      await _assignmentRepo.updateProgress(schoolId, assignmentId, targetStudents.length);
      await _assignmentRepo.markComplete(schoolId, assignmentId);
      print('[AdHocFeeAssignment] Assignment completed successfully');

      return AssignmentResult(
        assignmentId: assignmentId,
        studentsAssigned: targetStudents.length,
        totalAmount: amount * targetStudents.length,
        success: true,
      );
    } catch (e, stackTrace) {
      print('[AdHocFeeAssignment] Error creating assignment: $e');
      print('[AdHocFeeAssignment] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get target students based on scope and filters
  Future<List<StudentInfo>> _getTargetStudents({
    required String schoolId,
    required String academicYear,
    required String scope,
    List<String> classIds = const [],
    List<String> sections = const [],
    List<String> studentIds = const [],
  }) async {
    List<Student> students = [];

    switch (scope) {
      case 'school':
        // All students in the school - get from stream and filter by academic year
        final snapshot = await _studentRepo.getStudentsStream(schoolId).first;
        students = snapshot.where((s) => s.academicYearCode == academicYear).toList();
        break;

      case 'class':
        // Students in specific classes
        for (final className in classIds) {
          final classSnapshot = await _studentRepo.getStudentsByClassStream(schoolId, className).first;
          final filtered = classSnapshot.where((s) => s.academicYearCode == academicYear).toList();
          students.addAll(filtered);
        }
        break;

      case 'section':
        // Students in specific sections - get all and filter
        final allSnapshot = await _studentRepo.getStudentsStream(schoolId).first;
        students = allSnapshot
            .where((s) => s.academicYearCode == academicYear && sections.contains(s.section))
            .toList();
        break;

      case 'custom':
        // Specific students by ID
        for (final studentId in studentIds) {
          final student = await _studentRepo.getStudentById(schoolId, studentId);
          if (student != null && student.academicYearCode == academicYear) {
            students.add(student);
          }
        }
        break;
    }

    // Convert Student entities to StudentInfo
    return students.map((s) => StudentInfo(
      id: s.id,
      name: s.name,
      className: s.className,
      section: s.section,
    )).toList();
  }

  /// Preview assignment before execution
  Future<AssignmentPreview> previewAssignment({
    required String schoolId,
    required String academicYear,
    required String scope,
    List<String> classIds = const [],
    List<String> sections = const [],
    List<String> studentIds = const [],
    required double amount,
  }) async {
    final targetStudents = await _getTargetStudents(
      schoolId: schoolId,
      academicYear: academicYear,
      scope: scope,
      classIds: classIds,
      sections: sections,
      studentIds: studentIds,
    );

    return AssignmentPreview(
      studentCount: targetStudents.length,
      totalAmount: amount * targetStudents.length,
      students: targetStudents,
    );
  }

  /// Cancel an assignment and remove associated fee items
  Future<void> cancelAssignment(
    String schoolId,
    String assignmentId,
    String reason,
  ) async {
    // Get the assignment
    final assignment = await _assignmentRepo.getById(schoolId, assignmentId);
    if (assignment == null) {
      throw Exception('Assignment not found');
    }

    // Delete all fee items associated with this assignment
    // Note: This is a simplified version. In production, you might want to
    // check if any payments have been made before deleting.
    final allItems = await _feeItemRepo.getByClass(schoolId, '', assignment.academicYear);
    final assignmentItems = allItems.where((item) => item.adHocAssignmentId == assignmentId).toList();

    for (final item in assignmentItems) {
      if (item.paidAmount > 0) {
        throw Exception('Cannot cancel assignment - some students have already paid');
      }
      await _feeItemRepo.delete(schoolId, item.id);
    }

    // Mark assignment as cancelled
    await _assignmentRepo.cancel(schoolId, assignmentId, reason);
  }
}

/// Result of an assignment operation
class AssignmentResult {
  final String assignmentId;
  final int studentsAssigned;
  final double totalAmount;
  final bool success;
  final String? error;

  const AssignmentResult({
    required this.assignmentId,
    required this.studentsAssigned,
    required this.totalAmount,
    required this.success,
    this.error,
  });
}

/// Preview of an assignment before execution
class AssignmentPreview {
  final int studentCount;
  final double totalAmount;
  final List<StudentInfo> students;

  const AssignmentPreview({
    required this.studentCount,
    required this.totalAmount,
    required this.students,
  });
}

/// Simplified student info for assignment
class StudentInfo {
  final String id;
  final String name;
  final String className;
  final String section;

  const StudentInfo({
    required this.id,
    required this.name,
    required this.className,
    required this.section,
  });
}

final adHocFeeAssignmentServiceProvider = Provider<AdHocFeeAssignmentService>((ref) {
  return AdHocFeeAssignmentService(
    ref.watch(adHocFeeAssignmentRepositoryProvider),
    ref.watch(studentFeeItemRepositoryProvider),
    ref.watch(studentRepositoryProvider),
  );
});
