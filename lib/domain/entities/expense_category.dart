import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseCategoryItem {
  final String id;
  final String schoolId;
  final String name;
  final String code;
  final bool isDefault;
  final int order;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ExpenseCategoryItem({
    required this.id,
    required this.schoolId,
    required this.name,
    required this.code,
    this.isDefault = false,
    this.order = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ExpenseCategoryItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExpenseCategoryItem(
      id: doc.id,
      schoolId: data['schoolId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      code: data['code'] as String? ?? '',
      isDefault: data['isDefault'] as bool? ?? false,
      order: (data['order'] as num?)?.toInt() ?? 0,
      createdAt: _parseDateTime(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(data['updatedAt']) ?? DateTime.now(),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'schoolId': schoolId,
      'name': name,
      'code': code,
      'isDefault': isDefault,
      'order': order,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  ExpenseCategoryItem copyWith({
    String? id,
    String? schoolId,
    String? name,
    String? code,
    bool? isDefault,
    int? order,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExpenseCategoryItem(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      name: name ?? this.name,
      code: code ?? this.code,
      isDefault: isDefault ?? this.isDefault,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Default categories that can be fed into Firestore
  static const List<Map<String, dynamic>> defaultCategories = [
    {'name': 'Accounting Expenses', 'code': 'ACCOUNTING_EXPENSES'},
    {'name': 'Advertisement', 'code': 'ADVERTISEMENT'},
    {'name': 'Books & Notebooks', 'code': 'BOOKS_NOTEBOOKS'},
    {'name': 'Building Constructions', 'code': 'BUILDING_CONSTRUCTIONS'},
    {'name': 'Cartage', 'code': 'CARTAGE'},
    {'name': 'Computer Maintenance', 'code': 'COMPUTER_MAINTENANCE'},
    {'name': 'EB Charges', 'code': 'EB_CHARGES'},
    {'name': 'EPF', 'code': 'EPF'},
    {'name': 'ESI', 'code': 'ESI'},
    {'name': 'Exam Expenses', 'code': 'EXAM_EXP'},
    {'name': 'Function & Celebration', 'code': 'FUNCTION_CELEBRATION'},
    {'name': 'Furniture & Fittings', 'code': 'FURNITURE_FITTINGS'},
    {'name': 'Insurance', 'code': 'INSURANCE'},
    {'name': 'Lab Equipments', 'code': 'LAB_EQUIPMENTS'},
    {'name': 'Library Books', 'code': 'LIBRARY_BOOKS'},
    {'name': 'Master App', 'code': 'MASTER_APP'},
    {'name': 'Medical Expense', 'code': 'MEDICAL_EXPENSE'},
    {'name': 'Miscellaneous Expenses', 'code': 'MISCELLANEOUS'},
    {'name': 'Newspaper', 'code': 'NEWSPAPER'},
    {'name': 'Non Teaching Staff Salary', 'code': 'NON_TEACHING_SALARY'},
    {'name': 'Plumbing & Electrical', 'code': 'PLUMBING_ELECTRICAL'},
    {'name': 'Pooja Expenses', 'code': 'POOJA_EXPENSES'},
    {'name': 'Postage & Courier', 'code': 'POSTAGE_COURIER'},
    {'name': 'Printing & Stationary', 'code': 'PRINTING_STATIONARY'},
    {'name': 'Property Tax', 'code': 'PROPERTY_TAX'},
    {'name': 'Repair & Maintenance', 'code': 'REPAIR_MAINTENANCE'},
    {'name': 'Sanitation Expenses', 'code': 'SANITATION'},
    {'name': 'School Maintenance', 'code': 'SCHOOL_MAINTENANCE'},
    {'name': 'Sports Expenses', 'code': 'SPORTS_EXPENSES'},
    {'name': 'Staff Salary', 'code': 'STAFF_SALARY'},
    {'name': 'Staff Uniform', 'code': 'STAFF_UNIFORM'},
    {'name': 'Telephone Expense', 'code': 'TELEPHONE'},
    {'name': 'Traveling Expense', 'code': 'TRAVELING'},
    {'name': 'Vehicle Fuel', 'code': 'VEHICLE_FUEL'},
    {'name': 'Vehicle Maintenance', 'code': 'VEHICLE_MAINTENANCE'},
    {'name': 'Water Charge', 'code': 'WATER_CHARGE'},
    {'name': 'Other', 'code': 'OTHER'},
  ];
}
