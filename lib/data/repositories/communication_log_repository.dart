import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/communication_log.dart';

/// Provider for the repository
final communicationLogRepositoryProvider =
    Provider<CommunicationLogRepository>(
  (ref) => CommunicationLogRepository(FirebaseFirestore.instance),
);

/// Filter parameters for querying communication logs
class CommunicationLogFilter {
  final CommStatus? status;
  final CommPurpose? purpose;
  final CommChannel? channel;
  final RecipientType? recipientType;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? searchQuery; // Client-side search on recipientName/phone

  const CommunicationLogFilter({
    this.status,
    this.purpose,
    this.channel,
    this.recipientType,
    this.startDate,
    this.endDate,
    this.searchQuery,
  });

  bool get isEmpty =>
      status == null &&
      purpose == null &&
      channel == null &&
      recipientType == null &&
      startDate == null &&
      endDate == null &&
      (searchQuery == null || searchQuery!.isEmpty);
}

/// Result of a paginated query
class CommunicationLogPage {
  final List<CommunicationLog> logs;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;

  const CommunicationLogPage({
    required this.logs,
    required this.lastDocument,
    required this.hasMore,
  });
}

class CommunicationLogRepository {
  final FirebaseFirestore _firestore;

  CommunicationLogRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> _collection(String schoolId) =>
      _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('communicationLogs');

  /// Fetch logs with pagination + filters.
  /// [pageSize] controls how many docs are returned per call.
  /// [lastDocument] is used for pagination cursor (pass from previous page).
  Future<CommunicationLogPage> getLogs({
    required String schoolId,
    CommunicationLogFilter filter = const CommunicationLogFilter(),
    int pageSize = 25,
    DocumentSnapshot? lastDocument,
  }) async {
    Query<Map<String, dynamic>> query = _collection(schoolId);

    // Apply server-side filters (one "equals" filter + date range works with indexes).
    if (filter.status != null) {
      query = query.where('status', isEqualTo: filter.status!.name);
    }
    if (filter.purpose != null) {
      query = query.where('purpose', isEqualTo: filter.purpose!.name);
    }
    if (filter.channel != null) {
      query = query.where('channel', isEqualTo: filter.channel!.name);
    }
    if (filter.recipientType != null) {
      query =
          query.where('recipientType', isEqualTo: filter.recipientType!.name);
    }
    if (filter.startDate != null) {
      query = query.where('sentAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(filter.startDate!));
    }
    if (filter.endDate != null) {
      // Include the full end date by using the next day midnight
      final end = DateTime(
          filter.endDate!.year, filter.endDate!.month, filter.endDate!.day)
          .add(const Duration(days: 1));
      query =
          query.where('sentAt', isLessThan: Timestamp.fromDate(end));
    }

    // Always order by sentAt desc
    query = query.orderBy('sentAt', descending: true);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    // Fetch one extra to know if there are more records
    final snap = await query.limit(pageSize + 1).get();
    final docs = snap.docs;
    final hasMore = docs.length > pageSize;
    final pageDocs = hasMore ? docs.take(pageSize).toList() : docs;

    final logs = pageDocs
        .map((d) => CommunicationLog.fromFirestore(d.data(), d.id))
        .toList();

    return CommunicationLogPage(
      logs: logs,
      lastDocument: pageDocs.isEmpty ? null : pageDocs.last,
      hasMore: hasMore,
    );
  }

  /// Create a new communication log entry.
  /// Used by other features (e.g. payment-due notifications) to record outgoing messages.
  Future<String> createLog(CommunicationLog log) async {
    final docRef = await _collection(log.schoolId).add(log.toFirestore());
    return docRef.id;
  }

  /// Update status of an existing log (e.g. mark delivered/read/failed).
  Future<void> updateStatus({
    required String schoolId,
    required String logId,
    required CommStatus status,
    String? errorMessage,
  }) async {
    final updates = <String, dynamic>{
      'status': status.name,
    };
    switch (status) {
      case CommStatus.delivered:
        updates['deliveredAt'] = FieldValue.serverTimestamp();
        break;
      case CommStatus.read:
        updates['readAt'] = FieldValue.serverTimestamp();
        break;
      case CommStatus.failed:
        updates['failedAt'] = FieldValue.serverTimestamp();
        if (errorMessage != null) {
          updates['errorMessage'] = errorMessage;
        }
        break;
      default:
        break;
    }
    await _collection(schoolId).doc(logId).update(updates);
  }

  /// Get simple aggregate counts for the dashboard cards.
  /// Uses a single query scoped by date range for efficiency.
  Future<Map<CommStatus, int>> getStatusCounts({
    required String schoolId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    Query<Map<String, dynamic>> query = _collection(schoolId);
    if (startDate != null) {
      query = query.where('sentAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }
    if (endDate != null) {
      final end = DateTime(endDate.year, endDate.month, endDate.day)
          .add(const Duration(days: 1));
      query = query.where('sentAt', isLessThan: Timestamp.fromDate(end));
    }
    query = query.orderBy('sentAt', descending: true).limit(500);

    final snap = await query.get();
    final counts = <CommStatus, int>{
      for (final s in CommStatus.values) s: 0,
    };
    for (final doc in snap.docs) {
      final status = CommStatus.fromString(doc.data()['status'] as String?);
      counts[status] = (counts[status] ?? 0) + 1;
    }
    return counts;
  }
}
