import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/fee_structure_v2.dart';
import '../../domain/entities/fee_term.dart';

final feeStructureV2RepositoryProvider = Provider<FeeStructureV2Repository>((ref) {
  return FeeStructureV2Repository();
});

/// Stream of all fee structures (v2) for a school
final feeStructuresV2Provider =
    StreamProvider.family<List<FeeStructureV2>, String>((ref, schoolId) {
  return ref.watch(feeStructureV2RepositoryProvider).watchAll(schoolId);
});

/// Single fee structure with its terms hydrated.
final feeStructureV2DetailProvider = FutureProvider.family<FeeStructureV2?,
    ({String schoolId, String structureId})>((ref, p) {
  return ref
      .watch(feeStructureV2RepositoryProvider)
      .getWithTerms(p.schoolId, p.structureId);
});

class FeeStructureV2Repository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String schoolId) => _firestore
      .collection('schools')
      .doc(schoolId)
      .collection('feeStructuresV2');

  CollectionReference<Map<String, dynamic>> _termsCol(
          String schoolId, String structureId) =>
      _col(schoolId).doc(structureId).collection('terms');

  Stream<List<FeeStructureV2>> watchAll(String schoolId) {
    return _col(schoolId)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => FeeStructureV2.fromFirestore(d)).toList());
  }

  Future<List<FeeStructureV2>> listAll(String schoolId) async {
    final snap = await _col(schoolId).orderBy('createdAt', descending: true).get();
    return snap.docs.map((d) => FeeStructureV2.fromFirestore(d)).toList();
  }

  Future<FeeStructureV2?> getWithTerms(String schoolId, String structureId) async {
    final doc = await _col(schoolId).doc(structureId).get();
    if (!doc.exists) return null;
    final termsSnap =
        await _termsCol(schoolId, structureId).orderBy('sequence').get();
    final terms = termsSnap.docs.map((d) => FeeTerm.fromFirestore(d)).toList();
    return FeeStructureV2.fromFirestore(doc, terms: terms);
  }

  /// Creates a structure plus its terms in a single batch.
  Future<String> create(
    String schoolId,
    FeeStructureV2 structure,
    List<FeeTerm> terms,
  ) async {
    final batch = _firestore.batch();
    final ref = _col(schoolId).doc();
    final total = terms.fold<double>(0, (s, t) => s + t.amount);

    batch.set(ref, {
      ...structure.toFirestore(),
      'totalAmount': total,
      'termCount': terms.length,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    for (final term in terms) {
      final termRef = ref.collection('terms').doc();
      batch.set(termRef, term.toFirestore());
    }

    await batch.commit();
    return ref.id;
  }

  /// Updates structure metadata + replaces all terms.
  Future<void> update(
    String schoolId,
    String structureId,
    FeeStructureV2 structure,
    List<FeeTerm> terms,
  ) async {
    final total = terms.fold<double>(0, (s, t) => s + t.amount);

    try {
      // 1) update parent doc
      await _col(schoolId).doc(structureId).update({
        ...structure.toFirestore(),
        'totalAmount': total,
        'termCount': terms.length,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update fee structure parent document: $e');
    }

    try {
      // 2) delete existing terms then write new ones in a batch
      final existing = await _termsCol(schoolId, structureId).get();
      final batch = _firestore.batch();
      for (final d in existing.docs) {
        batch.delete(d.reference);
      }
      for (final term in terms) {
        final ref = _termsCol(schoolId, structureId).doc();
        batch.set(ref, term.toFirestore());
      }
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to update fee structure terms (batch operation): $e');
    }
  }

  Future<void> setActive(
      String schoolId, String structureId, bool active) async {
    await _col(schoolId).doc(structureId).update({
      'isActive': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> assignClasses(
      String schoolId, String structureId, List<String> classIds) async {
    await _col(schoolId).doc(structureId).update({
      'applicableToClassIds': classIds,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
