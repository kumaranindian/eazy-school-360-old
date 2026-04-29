import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/fee_category.dart';

/// Repository for the per-school fee-category catalog. Custom categories are
/// stored at `schools/{schoolId}/feeCategories/{code}`. The four standard
/// categories (ADMISSION, TUITION, EXAM, VAN) are seeded automatically the
/// first time the catalog is read so the UI is never empty.
class FeeCategoryRepository {
  final FirebaseFirestore _firestore;
  FeeCategoryRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> _col(String schoolId) =>
      _firestore.collection('schools').doc(schoolId).collection('feeCategories');

  /// Streams the active categories for a school, sorted by [sortOrder]. Seeds
  /// the standard categories on the first read so the catalog always has the
  /// four built-in entries.
  Stream<List<FeeCategory>> streamCategories(String schoolId) async* {
    await _ensureDefaults(schoolId);
    yield* _col(schoolId).orderBy('sortOrder').snapshots().map((snap) =>
        snap.docs.map((d) => FeeCategory.fromFirestore(d)).toList());
  }

  /// One-shot fetch (used by services that don't need a stream).
  Future<List<FeeCategory>> listCategories(String schoolId) async {
    await _ensureDefaults(schoolId);
    final snap = await _col(schoolId).orderBy('sortOrder').get();
    return snap.docs.map((d) => FeeCategory.fromFirestore(d)).toList();
  }

  Future<void> upsert(String schoolId, FeeCategory category) async {
    try {
      final ref = _col(schoolId).doc(category.code);
      final exists = (await ref.get()).exists;
      final data = category.toFirestore();
      if (!exists) data['createdAt'] = FieldValue.serverTimestamp();
      await ref.set(data, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to upsert fee category "${category.code}": $e');
    }
  }

  /// Soft-delete: standard categories cannot be deleted, only deactivated.
  Future<void> deactivate(String schoolId, String code) async {
    try {
      await _col(schoolId).doc(code).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to deactivate fee category "$code": $e');
    }
  }

  Future<void> activate(String schoolId, String code) async {
    try {
      await _col(schoolId).doc(code).update({
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to activate fee category "$code": $e');
    }
  }

  /// Hard-delete a custom category. Throws if the category is standard.
  Future<void> delete(String schoolId, String code) async {
    try {
      final ref = _col(schoolId).doc(code);
      final snap = await ref.get();
      if (!snap.exists) return;
      final cat = FeeCategory.fromFirestore(snap);
      if (cat.isStandard) {
        throw StateError('Standard fee categories cannot be deleted.');
      }
      await ref.delete();
    } catch (e) {
      if (e is StateError) rethrow;
      throw Exception('Failed to delete fee category "$code": $e');
    }
  }

  /// Seeds the four standard categories the first time the catalog is read.
  Future<void> _ensureDefaults(String schoolId) async {
    final col = _col(schoolId);
    final batch = _firestore.batch();
    bool wrote = false;
    for (final def in FeeCategory.defaults) {
      final doc = col.doc(def.code);
      final exists = (await doc.get()).exists;
      if (!exists) {
        batch.set(doc, {
          ...def.toFirestore(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        wrote = true;
      }
    }
    if (wrote) await batch.commit();
  }
}

final feeCategoryRepositoryProvider = Provider<FeeCategoryRepository>((ref) {
  return FeeCategoryRepository(FirebaseFirestore.instance);
});

/// Streams all categories for a school (active + inactive).
final feeCategoriesProvider =
    StreamProvider.family<List<FeeCategory>, String>((ref, schoolId) {
  return ref.watch(feeCategoryRepositoryProvider).streamCategories(schoolId);
});
