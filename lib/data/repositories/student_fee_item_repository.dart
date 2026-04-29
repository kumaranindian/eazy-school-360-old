import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/student_fee_item.dart';

/// Repository for managing student fee items (category-based fee tracking).
/// This is the new system that replaces term-based ledgers.
class StudentFeeItemRepository {
  final FirebaseFirestore _firestore;

  StudentFeeItemRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> _col(String schoolId) =>
      _firestore.collection('schools').doc(schoolId).collection('studentFeeItems');

  /// Get all fee items for a student in a specific academic year
  Future<List<StudentFeeItem>> getByStudent(
    String schoolId,
    String studentId,
    String academicYear,
  ) async {
    final snap = await _col(schoolId)
        .where('studentId', isEqualTo: studentId)
        .where('academicYear', isEqualTo: academicYear)
        .where('isActive', isEqualTo: true)
        .orderBy('dueDate')
        .get();

    return snap.docs.map((d) => StudentFeeItem.fromFirestore(d)).toList();
  }

  /// Stream fee items for a student
  Stream<List<StudentFeeItem>> streamByStudent(
    String schoolId,
    String studentId,
    String academicYear,
  ) {
    return _col(schoolId)
        .where('studentId', isEqualTo: studentId)
        .where('academicYear', isEqualTo: academicYear)
        .where('isActive', isEqualTo: true)
        .orderBy('dueDate')
        .snapshots()
        .map((snap) => snap.docs.map((d) => StudentFeeItem.fromFirestore(d)).toList());
  }

  /// Get fee items by category for a student
  Future<List<StudentFeeItem>> getByCategory(
    String schoolId,
    String studentId,
    String academicYear,
    String categoryCode,
  ) async {
    final snap = await _col(schoolId)
        .where('studentId', isEqualTo: studentId)
        .where('academicYear', isEqualTo: academicYear)
        .where('categoryCode', isEqualTo: categoryCode)
        .where('isActive', isEqualTo: true)
        .orderBy('dueDate')
        .get();

    return snap.docs.map((d) => StudentFeeItem.fromFirestore(d)).toList();
  }

  /// Get all outstanding (unpaid) fee items for a student
  Future<List<StudentFeeItem>> getOutstanding(
    String schoolId,
    String studentId,
    String academicYear,
  ) async {
    final allItems = await getByStudent(schoolId, studentId, academicYear);
    return allItems.where((item) => item.balanceAmount > 0.001).toList();
  }

  /// Create a new fee item
  Future<String> create(String schoolId, StudentFeeItem item) async {
    final data = item.toFirestore();
    data['createdAt'] = FieldValue.serverTimestamp();
    final ref = await _col(schoolId).add(data);
    return ref.id;
  }

  /// Create multiple fee items in a batch
  Future<void> createBatch(String schoolId, List<StudentFeeItem> items) async {
    final batch = _firestore.batch();
    for (final item in items) {
      final ref = _col(schoolId).doc();
      final data = item.toFirestore();
      data['createdAt'] = FieldValue.serverTimestamp();
      batch.set(ref, data);
    }
    await batch.commit();
  }

  /// Update a fee item
  Future<void> update(String schoolId, String itemId, StudentFeeItem item) async {
    await _col(schoolId).doc(itemId).update(item.toFirestore());
  }

  /// Record a payment against a fee item
  Future<void> recordPayment(
    String schoolId,
    String itemId,
    double paymentAmount,
  ) async {
    final doc = await _col(schoolId).doc(itemId).get();
    if (!doc.exists) {
      throw Exception('Fee item not found');
    }

    final item = StudentFeeItem.fromFirestore(doc);
    final updated = item.recordPayment(paymentAmount);

    await _col(schoolId).doc(itemId).update({
      'paidAmount': updated.paidAmount,
      'balanceAmount': updated.balanceAmount,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Record payments against multiple fee items in a transaction
  Future<void> recordPaymentBatch(
    String schoolId,
    Map<String, double> itemPayments, // itemId -> amount
  ) async {
    await _firestore.runTransaction((transaction) async {
      for (final entry in itemPayments.entries) {
        final itemId = entry.key;
        final amount = entry.value;

        final docRef = _col(schoolId).doc(itemId);
        final doc = await transaction.get(docRef);

        if (!doc.exists) continue;

        final item = StudentFeeItem.fromFirestore(doc);
        final updated = item.recordPayment(amount);

        transaction.update(docRef, {
          'paidAmount': updated.paidAmount,
          'balanceAmount': updated.balanceAmount,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  /// Delete a fee item (soft delete)
  Future<void> delete(String schoolId, String itemId) async {
    await _col(schoolId).doc(itemId).update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get category-wise summary for a student
  Future<Map<String, CategorySummary>> getCategorySummary(
    String schoolId,
    String studentId,
    String academicYear,
  ) async {
    final items = await getByStudent(schoolId, studentId, academicYear);
    final summary = <String, CategorySummary>{};

    for (final item in items) {
      if (!summary.containsKey(item.categoryCode)) {
        summary[item.categoryCode] = CategorySummary(
          categoryCode: item.categoryCode,
          totalAmount: 0,
          paidAmount: 0,
          balanceAmount: 0,
          itemCount: 0,
        );
      }

      final current = summary[item.categoryCode]!;
      summary[item.categoryCode] = CategorySummary(
        categoryCode: item.categoryCode,
        totalAmount: current.totalAmount + item.amount,
        paidAmount: current.paidAmount + item.paidAmount,
        balanceAmount: current.balanceAmount + item.balanceAmount,
        itemCount: current.itemCount + 1,
      );
    }

    return summary;
  }

  /// Get all fee items for a class
  Future<List<StudentFeeItem>> getByClass(
    String schoolId,
    String className,
    String academicYear,
  ) async {
    final snap = await _col(schoolId)
        .where('className', isEqualTo: className)
        .where('academicYear', isEqualTo: academicYear)
        .where('isActive', isEqualTo: true)
        .get();

    return snap.docs.map((d) => StudentFeeItem.fromFirestore(d)).toList();
  }
}

/// Category-wise fee summary
class CategorySummary {
  final String categoryCode;
  final double totalAmount;
  final double paidAmount;
  final double balanceAmount;
  final int itemCount;

  const CategorySummary({
    required this.categoryCode,
    required this.totalAmount,
    required this.paidAmount,
    required this.balanceAmount,
    required this.itemCount,
  });
}

final studentFeeItemRepositoryProvider = Provider<StudentFeeItemRepository>((ref) {
  return StudentFeeItemRepository(FirebaseFirestore.instance);
});

/// Stream provider for student fee items
final studentFeeItemsProvider = StreamProvider.family<List<StudentFeeItem>, ({String schoolId, String studentId, String academicYear})>(
  (ref, params) {
    return ref
        .watch(studentFeeItemRepositoryProvider)
        .streamByStudent(params.schoolId, params.studentId, params.academicYear);
  },
);
