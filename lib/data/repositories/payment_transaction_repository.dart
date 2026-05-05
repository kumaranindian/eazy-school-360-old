import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/payment_transaction.dart';

final paymentTransactionRepositoryProvider = Provider<PaymentTransactionRepository>((ref) {
  return PaymentTransactionRepository();
});

final transactionsBySchoolProvider = StreamProvider.family<List<PaymentTransaction>, String>((ref, schoolId) {
  return ref.watch(paymentTransactionRepositoryProvider).watchBySchool(schoolId);
});

final transactionsByStudentProvider = StreamProvider.family<List<PaymentTransaction>, ({String schoolId, String studentId})>((ref, params) {
  return ref.watch(paymentTransactionRepositoryProvider).watchByStudent(params.schoolId, params.studentId);
});

class PaymentTransactionRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference _getCollection(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('payment_transactions');
  }

  Future<PaymentTransaction?> getById(String schoolId, String transactionId) async {
    try {
      final doc = await _getCollection(schoolId).doc(transactionId).get();
      if (!doc.exists) return null;
      return PaymentTransaction.fromFirestore(doc);
    } catch (e) {
      print('[TransactionRepo] Error getting transaction: $e');
      return null;
    }
  }

  Stream<List<PaymentTransaction>> watchBySchool(String schoolId, {
    int limit = 100,
    PaymentStatus? status,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    try {
      Query query = _getCollection(schoolId)
          .orderBy('createdAt', descending: true);

      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }

      if (startDate != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      query = query.limit(limit);

      return query.snapshots().map((snapshot) {
        return snapshot.docs
            .map((doc) => PaymentTransaction.fromFirestore(doc))
            .toList();
      });
    } catch (e) {
      print('[TransactionRepo] Error watching transactions: $e');
      return Stream.value([]);
    }
  }

  Stream<List<PaymentTransaction>> watchByStudent(String schoolId, String studentId) {
    try {
      return _getCollection(schoolId)
          .where('studentId', isEqualTo: studentId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => PaymentTransaction.fromFirestore(doc))
            .toList();
      });
    } catch (e) {
      print('[TransactionRepo] Error watching student transactions: $e');
      return Stream.value([]);
    }
  }

  Future<List<PaymentTransaction>> getByDateRange(
    String schoolId,
    DateTime startDate,
    DateTime endDate, {
    PaymentStatus? status,
  }) async {
    try {
      Query query = _getCollection(schoolId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('createdAt', descending: true);

      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => PaymentTransaction.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('[TransactionRepo] Error getting transactions by date range: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getTransactionStats(
    String schoolId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final transactions = await getByDateRange(schoolId, startDate, endDate);

      final successful = transactions.where((t) => t.status == PaymentStatus.SUCCESS).toList();
      final failed = transactions.where((t) => t.status == PaymentStatus.FAILED).toList();
      final pending = transactions.where((t) => t.status == PaymentStatus.PENDING).toList();

      final totalAmount = successful.fold<double>(0, (sum, t) => sum + t.amount);
      final razorpayAmount = successful
          .where((t) => t.gateway == PaymentGateway.RAZORPAY)
          .fold<double>(0, (sum, t) => sum + t.amount);
      final manualAmount = successful
          .where((t) => t.gateway == PaymentGateway.MANUAL)
          .fold<double>(0, (sum, t) => sum + t.amount);

      final methodBreakdown = <String, double>{};
      for (final transaction in successful) {
        final method = transaction.method.name;
        methodBreakdown[method] = (methodBreakdown[method] ?? 0) + transaction.amount;
      }

      return {
        'totalTransactions': transactions.length,
        'successfulTransactions': successful.length,
        'failedTransactions': failed.length,
        'pendingTransactions': pending.length,
        'totalAmount': totalAmount,
        'razorpayAmount': razorpayAmount,
        'manualAmount': manualAmount,
        'methodBreakdown': methodBreakdown,
        'successRate': transactions.isEmpty ? 0.0 : (successful.length / transactions.length) * 100,
      };
    } catch (e) {
      print('[TransactionRepo] Error getting transaction stats: $e');
      return {};
    }
  }

  Future<void> create(String schoolId, PaymentTransaction transaction) async {
    try {
      await _getCollection(schoolId)
          .doc(transaction.id)
          .set(transaction.toFirestore());
      print('[TransactionRepo] Transaction created: ${transaction.id}');
    } catch (e) {
      print('[TransactionRepo] Error creating transaction: $e');
      rethrow;
    }
  }

  Future<void> update(String schoolId, String transactionId, Map<String, dynamic> updates) async {
    try {
      await _getCollection(schoolId).doc(transactionId).update(updates);
      print('[TransactionRepo] Transaction updated: $transactionId');
    } catch (e) {
      print('[TransactionRepo] Error updating transaction: $e');
      rethrow;
    }
  }

  Future<void> delete(String schoolId, String transactionId) async {
    try {
      await _getCollection(schoolId).doc(transactionId).delete();
      print('[TransactionRepo] Transaction deleted: $transactionId');
    } catch (e) {
      print('[TransactionRepo] Error deleting transaction: $e');
      rethrow;
    }
  }
}
