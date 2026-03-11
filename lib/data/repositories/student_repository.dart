import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/student.dart';

final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  return StudentRepository();
});

// Provider to get all students for a school
final schoolStudentsProvider = StreamProvider.family<List<Student>, String>((ref, schoolId) {
  final repo = ref.watch(studentRepositoryProvider);
  return repo.getStudentsStream(schoolId);
});

// Provider to get students by class
final studentsByClassProvider = StreamProvider.family<List<Student>, ({String schoolId, String className})>((ref, params) {
  final repo = ref.watch(studentRepositoryProvider);
  return repo.getStudentsByClassStream(params.schoolId, params.className);
});

// Provider to get a single student
final studentByIdProvider = FutureProvider.family<Student?, ({String schoolId, String studentId})>((ref, params) {
  final repo = ref.watch(studentRepositoryProvider);
  return repo.getStudentById(params.schoolId, params.studentId);
});

// Provider to get next student ID
final nextStudentIdProvider = FutureProvider.family<int, String>((ref, schoolId) {
  final repo = ref.watch(studentRepositoryProvider);
  return repo.getNextStudentId(schoolId);
});

class StudentRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _studentsCollection(String schoolId) {
    return _firestore.collection('schools').doc(schoolId).collection('students');
  }

  // Get all students for a school
  Stream<List<Student>> getStudentsStream(String schoolId) {
    return _studentsCollection(schoolId)
        .where('status', isEqualTo: 'ACTIVE')
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) => Student.fromFirestore(doc)).toList();
          list.sort((a, b) {
            final c = a.className.compareTo(b.className);
            return c != 0 ? c : a.name.compareTo(b.name);
          });
          return list;
        });
  }

  // Get students by class
  Stream<List<Student>> getStudentsByClassStream(String schoolId, String className) {
    return _studentsCollection(schoolId)
        .where('className', isEqualTo: className)
        .where('status', isEqualTo: 'ACTIVE')
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) => Student.fromFirestore(doc)).toList();
          list.sort((a, b) => a.name.compareTo(b.name));
          return list;
        });
  }

  // Get a single student by ID
  Future<Student?> getStudentById(String schoolId, String studentId) async {
    final doc = await _studentsCollection(schoolId).doc(studentId).get();
    if (!doc.exists) return null;
    return Student.fromFirestore(doc);
  }

  // Get student by numeric student ID
  Future<Student?> getStudentByNumericId(String schoolId, int numericId) async {
    final snapshot = await _studentsCollection(schoolId)
        .where('studentId', isEqualTo: numericId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return Student.fromFirestore(snapshot.docs.first);
  }

  // Get next student ID (auto-increment)
  Future<int> getNextStudentId(String schoolId) async {
    final snapshot = await _studentsCollection(schoolId)
        .orderBy('studentId', descending: true)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return 1;
    final lastId = (snapshot.docs.first.data()['studentId'] as num?)?.toInt() ?? 0;
    return lastId + 1;
  }

  // Create a new student
  Future<String> createStudent(String schoolId, Student student) async {
    final docRef = await _studentsCollection(schoolId).add(student.toFirestore());
    return docRef.id;
  }

  // Update a student
  Future<void> updateStudent(String schoolId, String studentId, Student student) async {
    await _studentsCollection(schoolId).doc(studentId).update({
      ...student.toFirestore(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Delete (soft delete) a student
  Future<void> deleteStudent(String schoolId, String studentId) async {
    await _studentsCollection(schoolId).doc(studentId).update({
      'status': StudentStatus.INACTIVE.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Get all classes for a school
  Future<List<String>> getClasses(String schoolId) async {
    final snapshot = await _studentsCollection(schoolId)
        .where('status', isEqualTo: 'ACTIVE')
        .get();
    final classes = snapshot.docs
        .map((doc) => doc.data()['className'] as String?)
        .where((c) => c != null && c.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    classes.sort();
    return classes;
  }

  // Get all sections for a class
  Future<List<String>> getSections(String schoolId, String className) async {
    final snapshot = await _studentsCollection(schoolId)
        .where('className', isEqualTo: className)
        .where('status', isEqualTo: 'ACTIVE')
        .get();
    final sections = snapshot.docs
        .map((doc) => doc.data()['section'] as String?)
        .where((s) => s != null && s.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    sections.sort();
    return sections;
  }

  // Search students
  Future<List<Student>> searchStudents(String schoolId, String query) async {
    final queryLower = query.toLowerCase();
    final snapshot = await _studentsCollection(schoolId)
        .where('status', isEqualTo: 'ACTIVE')
        .get();
    return snapshot.docs
        .map((doc) => Student.fromFirestore(doc))
        .where((student) =>
            student.name.toLowerCase().contains(queryLower) ||
            student.studentId.toString().contains(queryLower) ||
            (student.phoneNumber?.contains(query) ?? false))
        .toList();
  }

  // Get student count by class
  Future<Map<String, int>> getStudentCountByClass(String schoolId) async {
    final snapshot = await _studentsCollection(schoolId)
        .where('status', isEqualTo: 'ACTIVE')
        .get();
    final countMap = <String, int>{};
    for (final doc in snapshot.docs) {
      final className = doc.data()['className'] as String? ?? 'Unknown';
      countMap[className] = (countMap[className] ?? 0) + 1;
    }
    return countMap;
  }

  // Bulk import students
  Future<void> bulkImportStudents(String schoolId, List<Student> students) async {
    final batch = _firestore.batch();
    for (final student in students) {
      final docRef = _studentsCollection(schoolId).doc();
      batch.set(docRef, student.toFirestore());
    }
    await batch.commit();
  }
}
