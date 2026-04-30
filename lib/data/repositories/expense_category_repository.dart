import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/expense_category.dart';

class ExpenseCategoryRepository {
  final FirebaseFirestore _firestore;

  ExpenseCategoryRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference _getCollection(String schoolId) {
    return _firestore.collection('schools').doc(schoolId).collection('expenseCategories');
  }

  // Get all categories for a school
  Future<List<ExpenseCategoryItem>> getCategories(String schoolId) async {
    final snap = await _getCollection(schoolId).orderBy('order').get();
    return snap.docs.map((doc) => ExpenseCategoryItem.fromFirestore(doc)).toList();
  }

  // Get all categories as a stream
  Stream<List<ExpenseCategoryItem>> getCategoriesStream(String schoolId) {
    return _getCollection(schoolId).orderBy('order').snapshots().map((snap) {
      return snap.docs.map((doc) => ExpenseCategoryItem.fromFirestore(doc)).toList();
    });
  }

  // Feed default categories
  Future<void> feedDefaultCategories(String schoolId) async {
    final batch = _firestore.batch();
    final now = DateTime.now();
    final collection = _getCollection(schoolId);

    // Get existing default categories to avoid duplicates
    final existingSnap = await collection.where('isDefault', isEqualTo: true).get();
    final existingCodes = existingSnap.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return '';
      return data['code'] as String? ?? '';
    }).toSet();

    for (var i = 0; i < ExpenseCategoryItem.defaultCategories.length; i++) {
      final cat = ExpenseCategoryItem.defaultCategories[i];
      final code = cat['code'] as String;
      
      // Skip if already exists
      if (existingCodes.contains(code)) continue;

      final docRef = collection.doc();
      final category = ExpenseCategoryItem(
        id: docRef.id,
        schoolId: schoolId,
        name: cat['name'] as String,
        code: code,
        isDefault: true,
        order: i,
        createdAt: now,
        updatedAt: now,
      );
      batch.set(docRef, category.toFirestore());
    }

    await batch.commit();
  }

  // Add a single custom category
  Future<void> addCategory(String schoolId, String name, String code) async {
    final collection = _getCollection(schoolId);
    
    // Get the highest order value
    final snap = await collection.orderBy('order', descending: true).limit(1).get();
    final maxOrder = snap.docs.isEmpty ? 0 : (snap.docs.first.data() as Map<String, dynamic>?)?['order'] as num? ?? 0;
    
    final docRef = collection.doc();
    final now = DateTime.now();
    final category = ExpenseCategoryItem(
      id: docRef.id,
      schoolId: schoolId,
      name: name,
      code: code,
      isDefault: false,
      order: maxOrder.toInt() + 1,
      createdAt: now,
      updatedAt: now,
    );
    
    await docRef.set(category.toFirestore());
  }

  // Add multiple custom categories at once
  Future<void> addCategories(String schoolId, List<Map<String, String>> categories) async {
    final batch = _firestore.batch();
    final collection = _getCollection(schoolId);
    
    // Get the highest order value
    final snap = await collection.orderBy('order', descending: true).limit(1).get();
    final maxOrder = snap.docs.isEmpty ? 0 : (snap.docs.first.data() as Map<String, dynamic>?)?['order'] as num? ?? 0;
    
    final now = DateTime.now();
    for (var i = 0; i < categories.length; i++) {
      final cat = categories[i];
      final docRef = collection.doc();
      final category = ExpenseCategoryItem(
        id: docRef.id,
        schoolId: schoolId,
        name: cat['name'] ?? '',
        code: cat['code'] ?? '',
        isDefault: false,
        order: maxOrder.toInt() + i + 1,
        createdAt: now,
        updatedAt: now,
      );
      batch.set(docRef, category.toFirestore());
    }
    
    await batch.commit();
  }

  // Delete a category
  Future<void> deleteCategory(String schoolId, String categoryId) async {
    await _getCollection(schoolId).doc(categoryId).delete();
  }

  // Update a category
  Future<void> updateCategory(String schoolId, ExpenseCategoryItem category) async {
    await _getCollection(schoolId).doc(category.id).update(category.copyWith(
      updatedAt: DateTime.now(),
    ).toFirestore());
  }
}
