import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/expense_category_repository.dart';
import '../../domain/entities/expense_category.dart';

// Repository provider
final expenseCategoryRepositoryProvider = Provider<ExpenseCategoryRepository>((ref) {
  return ExpenseCategoryRepository();
});

// Categories stream provider for a school
final expenseCategoriesProvider = StreamProvider.family<List<ExpenseCategoryItem>, String>((ref, schoolId) {
  final repository = ref.watch(expenseCategoryRepositoryProvider);
  return repository.getCategoriesStream(schoolId);
});

// Categories future provider for a school (for one-time fetch)
final expenseCategoriesFutureProvider = FutureProvider.family<List<ExpenseCategoryItem>, String>((ref, schoolId) async {
  final repository = ref.watch(expenseCategoryRepositoryProvider);
  return repository.getCategories(schoolId);
});
