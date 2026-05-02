import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/concession_category.dart';

/// Repository for managing concession categories.
class ConcessionCategoryRepository {
  final FirebaseFirestore _firestore;

  ConcessionCategoryRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> _col(String schoolId) => _firestore
      .collection('schools')
      .doc(schoolId)
      .collection('concessionCategories');

  /// Get all active concession categories for a school
  Future<List<ConcessionCategory>> getAll(String schoolId) async {
    // First, ensure default categories exist
    await _ensureDefaults(schoolId);

    print(
        '[ConcessionCategoryRepository] Fetching categories for schoolId: $schoolId');
    try {
      final snap = await _col(schoolId)
          .where('isActive', isEqualTo: true)
          .orderBy('sortOrder')
          .get();

      print(
          '[ConcessionCategoryRepository] Found ${snap.docs.length} concession categories');
      for (final doc in snap.docs) {
        final data = doc.data();
        print(
            '  - ${doc.id}: code=${data['code']}, name=${data['name']}, isDefault=${data['isDefault']}, sortOrder=${data['sortOrder']}');
      }

      return snap.docs.map((d) => ConcessionCategory.fromFirestore(d)).toList();
    } catch (e) {
      print('[ConcessionCategoryRepository] Error fetching categories: $e');
      // Check if it's an index requirement error
      if (e.toString().contains('requires an index')) {
        print(
            ' INDEX REQUIRED: A Firestore composite index is needed for this query.');
        print(
            ' Create index at: https://console.firebase.google.com/project/eazy-school-360/firestore/indexes');
      }
      rethrow;
    }
  }

  /// Stream all active concession categories
  Stream<List<ConcessionCategory>> streamAll(String schoolId) {
    return _col(schoolId)
        .where('isActive', isEqualTo: true)
        .orderBy('sortOrder')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ConcessionCategory.fromFirestore(d)).toList());
  }

  /// Create a new concession category
  Future<String> create(String schoolId, ConcessionCategory category) async {
    final data = category.toFirestore();
    data['createdAt'] = FieldValue.serverTimestamp();
    final ref = await _col(schoolId).add(data);
    return ref.id;
  }

  /// Update a concession category
  Future<void> update(
      String schoolId, String id, ConcessionCategory category) async {
    await _col(schoolId).doc(id).update(category.toFirestore());
  }

  /// Delete (soft delete) a concession category
  Future<void> delete(String schoolId, String id) async {
    await _col(schoolId).doc(id).update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Ensure default categories exist for a school
  Future<void> _ensureDefaults(String schoolId) async {
    final snap = await _col(schoolId).limit(1).get();
    if (snap.docs.isNotEmpty) {
      print(
          '[ConcessionCategoryRepository] Categories already exist for schoolId: $schoolId');
      return; // Already has categories
    }

    print(
        '[ConcessionCategoryRepository] Creating default concession categories for schoolId: $schoolId');
    // Create default categories
    final batch = _firestore.batch();
    for (final cat in ConcessionCategory.defaults) {
      final ref = _col(schoolId).doc(cat.code);
      batch.set(ref, {
        ...cat.toFirestore(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('  - Creating default category: ${cat.code} - ${cat.name}');
    }
    await batch.commit();
    print(
        '[ConcessionCategoryRepository] Default categories created successfully');
  }

  /// Get a single category by ID
  Future<ConcessionCategory?> getById(String schoolId, String id) async {
    final doc = await _col(schoolId).doc(id).get();
    if (!doc.exists) return null;
    return ConcessionCategory.fromFirestore(doc);
  }
}

/// Provider for concession category repository
final concessionCategoryRepositoryProvider =
    Provider<ConcessionCategoryRepository>((ref) {
  return ConcessionCategoryRepository(FirebaseFirestore.instance);
});

/// Provider for streaming concession categories
final concessionCategoriesProvider =
    StreamProvider.family<List<ConcessionCategory>, String>((ref, schoolId) {
  final repo = ref.watch(concessionCategoryRepositoryProvider);
  return repo.streamAll(schoolId);
});

/// Provider for fetching concession categories (future-based)
final concessionCategoriesFutureProvider =
    FutureProvider.family<List<ConcessionCategory>, String>(
        (ref, schoolId) async {
  final repo = ref.read(concessionCategoryRepositoryProvider);
  return repo.getAll(schoolId);
});
