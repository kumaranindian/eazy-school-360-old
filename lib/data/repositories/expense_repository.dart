import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/expense.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository();
});

// Expense Providers
final expensesProvider = StreamProvider.family<List<Expense>, String>((ref, schoolId) {
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.getExpensesStream(schoolId);
});

final expensesByDateRangeProvider = FutureProvider.family<List<Expense>, ({String schoolId, DateTime startDate, DateTime endDate})>((ref, params) {
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.getExpensesByDateRange(params.schoolId, params.startDate, params.endDate);
});

final expenseSummaryProvider = FutureProvider.family<ExpenseSummary, String>((ref, schoolId) {
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.getExpenseSummary(schoolId);
});

final todayExpensesProvider = FutureProvider.family<double, String>((ref, schoolId) {
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.getTodayExpenses(schoolId);
});

class ExpenseSummary {
  final double totalExpenses;
  final int expenseCount;
  final Map<String, double> categoryWise;
  final double todayExpenses;

  const ExpenseSummary({
    this.totalExpenses = 0.0,
    this.expenseCount = 0,
    this.categoryWise = const {},
    this.todayExpenses = 0.0,
  });
}

class ExpenseRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _billsCollection(String schoolId) {
    return _firestore.collection('schools').doc(schoolId).collection('bills');
  }

  // Get all expenses stream
  Stream<List<Expense>> getExpensesStream(String schoolId) {
    return _billsCollection(schoolId)
        .where('billType', isEqualTo: 'Expense')
        .where('isDeleted', isEqualTo: false)
        .orderBy('billDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Expense.fromFirestore(doc)).toList());
  }

  // Get expenses by date range
  Future<List<Expense>> getExpensesByDateRange(String schoolId, DateTime startDate, DateTime endDate) async {
    final snapshot = await _billsCollection(schoolId)
        .where('billType', isEqualTo: 'Expense')
        .where('isDeleted', isEqualTo: false)
        .where('billDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('billDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('billDate', descending: true)
        .get();
    return snapshot.docs.map((doc) => Expense.fromFirestore(doc)).toList();
  }

  // Get expenses by category
  Future<List<Expense>> getExpensesByCategory(String schoolId, String category) async {
    final snapshot = await _billsCollection(schoolId)
        .where('billType', isEqualTo: 'Expense')
        .where('expenseType', isEqualTo: category)
        .where('isDeleted', isEqualTo: false)
        .orderBy('billDate', descending: true)
        .get();
    return snapshot.docs.map((doc) => Expense.fromFirestore(doc)).toList();
  }

  /// Returns a unique, monotonically-increasing bill ID for this school,
  /// shared across both revenue (fee) and expense bills since both are
  /// stored in the same `bills` collection (see the identical method in
  /// fee_repository.dart, which this mirrors exactly since fee_repository
  /// and this class point at the same underlying collection and previously
  /// had the same collision-prone max-query implementation). Uses a
  /// transactional counter document rather than reading the current max
  /// `billId` and adding one. The counter is seeded from the current max
  /// the first time it's used, so it continues the existing sequence
  /// rather than colliding with bills created before this fix; Firestore's
  /// automatic transaction retry makes the seeding step race-safe even if
  /// this and fee_repository.dart's getNextBillId are called concurrently
  /// for the same school on the very first use.
  Future<int> getNextBillId(String schoolId) async {
    final counterRef = _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('financeSettings')
        .doc('billCounter');

    final existingSnap = await _billsCollection(schoolId)
        .orderBy('billId', descending: true)
        .limit(1)
        .get();
    final seed = existingSnap.docs.isEmpty
        ? 0
        : (existingSnap.docs.first.data()['billId'] as num?)?.toInt() ?? 0;

    return _firestore.runTransaction<int>((transaction) async {
      final counterSnap = await transaction.get(counterRef);
      final base = counterSnap.exists
          ? (counterSnap.data()?['value'] as num?)?.toInt() ?? seed
          : seed;
      final next = base + 1;
      transaction.set(
        counterRef,
        {'value': next, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      return next;
    });
  }

  // Create a new expense
  Future<String> createExpense(String schoolId, Expense expense) async {
    final docRef = await _billsCollection(schoolId).add(expense.toFirestore());
    return docRef.id;
  }

  // Update an expense
  Future<void> updateExpense(String schoolId, String expenseId, Expense expense) async {
    await _billsCollection(schoolId).doc(expenseId).update({
      ...expense.toFirestore(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Delete (soft delete) an expense
  Future<void> deleteExpense(String schoolId, String expenseId, String reason) async {
    await _billsCollection(schoolId).doc(expenseId).update({
      'isDeleted': true,
      'isBillDeleted': true,
      'deletionReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Get expense summary
  Future<ExpenseSummary> getExpenseSummary(String schoolId) async {
    final snapshot = await _billsCollection(schoolId)
        .where('billType', isEqualTo: 'Expense')
        .where('isDeleted', isEqualTo: false)
        .get();

    double totalExpenses = 0.0;
    final categoryWise = <String, double>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final amount = (data['expenseAmount'] as num?)?.toDouble() ?? 0.0;
      final category = data['expenseType'] as String? ?? 'Other';

      totalExpenses += amount;
      categoryWise[category] = (categoryWise[category] ?? 0.0) + amount;
    }

    final todayExpenses = await getTodayExpenses(schoolId);

    return ExpenseSummary(
      totalExpenses: totalExpenses,
      expenseCount: snapshot.docs.length,
      categoryWise: categoryWise,
      todayExpenses: todayExpenses,
    );
  }

  // Get today's expenses
  Future<double> getTodayExpenses(String schoolId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await _billsCollection(schoolId)
        .where('billType', isEqualTo: 'Expense')
        .where('isDeleted', isEqualTo: false)
        .where('billDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('billDate', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    double total = 0.0;
    for (final doc in snapshot.docs) {
      total += (doc.data()['expenseAmount'] as num?)?.toDouble() ?? 0.0;
    }
    return total;
  }

  // Get monthly expenses for a year
  Future<Map<String, double>> getMonthlyExpenses(String schoolId, int year) async {
    final startOfYear = DateTime(year, 1, 1);
    final endOfYear = DateTime(year + 1, 1, 1);

    final snapshot = await _billsCollection(schoolId)
        .where('billType', isEqualTo: 'Expense')
        .where('isDeleted', isEqualTo: false)
        .where('billDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfYear))
        .where('billDate', isLessThan: Timestamp.fromDate(endOfYear))
        .get();

    final monthlyExpenses = <String, double>{};
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    for (final month in months) {
      monthlyExpenses[month] = 0.0;
    }

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final billDate = (data['billDate'] as Timestamp?)?.toDate();
      if (billDate != null) {
        final monthName = months[billDate.month - 1];
        final amount = (data['expenseAmount'] as num?)?.toDouble() ?? 0.0;
        monthlyExpenses[monthName] = (monthlyExpenses[monthName] ?? 0.0) + amount;
      }
    }

    return monthlyExpenses;
  }

  /// Get monthly expense totals for a date range (aggregated by month key 'YYYY-MM')
  Future<Map<String, double>> getMonthlyExpensesByRange(String schoolId, DateTime startDate, DateTime endDate) async {
    final snapshot = await _billsCollection(schoolId)
        .where('billType', isEqualTo: 'Expense')
        .where('isDeleted', isEqualTo: false)
        .where('billDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('billDate', isLessThan: Timestamp.fromDate(endDate))
        .get();

    final monthly = <String, double>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final billDate = (data['billDate'] as Timestamp?)?.toDate();
      if (billDate != null) {
        final key = '${billDate.year}-${billDate.month.toString().padLeft(2, '0')}';
        final amount = (data['expenseAmount'] as num?)?.toDouble() ?? 0.0;
        monthly[key] = (monthly[key] ?? 0.0) + amount;
      }
    }
    return monthly;
  }
}
