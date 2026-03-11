import 'package:cloud_firestore/cloud_firestore.dart';

enum ExpenseCategory {
  ACCOUNTING_EXPENSES,
  ADVERTISEMENT,
  BOOKS_NOTEBOOKS,
  BUILDING_CONSTRUCTIONS,
  CARTAGE,
  COMPUTER_MAINTENANCE,
  EB_CHARGES,
  EPF,
  ESI,
  EXAM_EXP,
  FUNCTION_CELEBRATION,
  FURNITURE_FITTINGS,
  INSURANCE,
  LAB_EQUIPMENTS,
  LIBRARY_BOOKS,
  MASTER_APP,
  MEDICAL_EXPENSE,
  MISCELLANEOUS,
  NEWSPAPER,
  NON_TEACHING_SALARY,
  PLUMBING_ELECTRICAL,
  POOJA_EXPENSES,
  POSTAGE_COURIER,
  PRINTING_STATIONARY,
  PROPERTY_TAX,
  REPAIR_MAINTENANCE,
  SANITATION,
  SCHOOL_MAINTENANCE,
  SPORTS_EXPENSES,
  STAFF_SALARY,
  STAFF_UNIFORM,
  TELEPHONE,
  TRAVELING,
  VEHICLE_FUEL,
  VEHICLE_MAINTENANCE,
  WATER_CHARGE,
  OTHER,
}

class Expense {
  final String id;
  final String schoolId;
  final int billId;
  final ExpenseCategory category;
  final String categoryName;
  final double amount;
  final String description;
  final String pointOfContact;
  final DateTime expenseDate;
  final bool isMissedExpense;
  final String? remarks;
  final String cashierName;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;

  const Expense({
    required this.id,
    required this.schoolId,
    required this.billId,
    required this.category,
    required this.categoryName,
    required this.amount,
    required this.description,
    required this.pointOfContact,
    required this.expenseDate,
    this.isMissedExpense = false,
    this.remarks,
    required this.cashierName,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
  });

  factory Expense.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Expense(
      id: doc.id,
      schoolId: data['schoolId'] as String? ?? '',
      billId: (data['billId'] as num?)?.toInt() ?? 0,
      category: _parseCategory(data['category'] ?? data['expenseType']),
      categoryName: (data['categoryName'] ?? data['expenseType'])?.toString() ?? '',
      amount: ((data['amount'] ?? data['expenseAmount']) as num?)?.toDouble() ?? 0.0,
      description: (data['description'] ?? data['expenseDesc'])?.toString() ?? '',
      pointOfContact: (data['pointOfContact'] ?? data['expensePOC'])?.toString() ?? '',
      expenseDate: _parseDateTime(data['expenseDate'] ?? data['billDate']) ?? DateTime.now(),
      isMissedExpense: data['isMissedExpense'] == 'Yes' || data['isMissedExpense'] == true,
      remarks: data['remarks'] as String?,
      cashierName: (data['cashierName'] ?? data['billCashierName'])?.toString() ?? '',
      isDeleted: (data['isDeleted'] ?? data['isBillDeleted']) == true,
      createdAt: _parseDateTime(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(data['updatedAt']) ?? DateTime.now(),
      createdBy: data['createdBy'] as String?,
    );
  }

  static ExpenseCategory _parseCategory(dynamic category) {
    if (category == null) return ExpenseCategory.OTHER;
    final categoryStr = category.toString().toUpperCase().replaceAll(' ', '_').replaceAll('&', '_');
    try {
      return ExpenseCategory.values.firstWhere(
        (e) => e.name == categoryStr,
        orElse: () => ExpenseCategory.OTHER,
      );
    } catch (_) {
      return ExpenseCategory.OTHER;
    }
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
      'billId': billId,
      'billType': 'Expense',
      'category': category.name,
      'categoryName': categoryName,
      'amount': amount,
      'expenseAmount': amount,
      'expenseType': categoryName,
      'description': description,
      'expenseDesc': description,
      'pointOfContact': pointOfContact,
      'expensePOC': pointOfContact,
      'expenseDate': Timestamp.fromDate(expenseDate),
      'billDate': Timestamp.fromDate(expenseDate),
      'isMissedExpense': isMissedExpense ? 'Yes' : 'No',
      'remarks': remarks,
      'cashierName': cashierName,
      'billCashierName': cashierName,
      'isDeleted': isDeleted,
      'isBillDeleted': isDeleted,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
      // Revenue fields (zero for expenses)
      'revenueType': '',
      'revenueAmount': 0.0,
      'stuId': '',
      'stuName': '',
    };
  }

  Expense copyWith({
    String? id,
    String? schoolId,
    int? billId,
    ExpenseCategory? category,
    String? categoryName,
    double? amount,
    String? description,
    String? pointOfContact,
    DateTime? expenseDate,
    bool? isMissedExpense,
    String? remarks,
    String? cashierName,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return Expense(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      billId: billId ?? this.billId,
      category: category ?? this.category,
      categoryName: categoryName ?? this.categoryName,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      pointOfContact: pointOfContact ?? this.pointOfContact,
      expenseDate: expenseDate ?? this.expenseDate,
      isMissedExpense: isMissedExpense ?? this.isMissedExpense,
      remarks: remarks ?? this.remarks,
      cashierName: cashierName ?? this.cashierName,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  static String getCategoryDisplayName(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.ACCOUNTING_EXPENSES: return 'Accounting Expenses';
      case ExpenseCategory.ADVERTISEMENT: return 'Advertisement';
      case ExpenseCategory.BOOKS_NOTEBOOKS: return 'Books & Notebooks';
      case ExpenseCategory.BUILDING_CONSTRUCTIONS: return 'Building Constructions';
      case ExpenseCategory.CARTAGE: return 'Cartage';
      case ExpenseCategory.COMPUTER_MAINTENANCE: return 'Computer Maintenance';
      case ExpenseCategory.EB_CHARGES: return 'EB Charges';
      case ExpenseCategory.EPF: return 'EPF';
      case ExpenseCategory.ESI: return 'ESI';
      case ExpenseCategory.EXAM_EXP: return 'Exam Expenses';
      case ExpenseCategory.FUNCTION_CELEBRATION: return 'Function & Celebration';
      case ExpenseCategory.FURNITURE_FITTINGS: return 'Furniture & Fittings';
      case ExpenseCategory.INSURANCE: return 'Insurance';
      case ExpenseCategory.LAB_EQUIPMENTS: return 'Lab Equipments';
      case ExpenseCategory.LIBRARY_BOOKS: return 'Library Books';
      case ExpenseCategory.MASTER_APP: return 'Master App';
      case ExpenseCategory.MEDICAL_EXPENSE: return 'Medical Expense';
      case ExpenseCategory.MISCELLANEOUS: return 'Miscellaneous Expenses';
      case ExpenseCategory.NEWSPAPER: return 'Newspaper';
      case ExpenseCategory.NON_TEACHING_SALARY: return 'Non Teaching Staff Salary';
      case ExpenseCategory.PLUMBING_ELECTRICAL: return 'Plumbing & Electrical';
      case ExpenseCategory.POOJA_EXPENSES: return 'Pooja Expenses';
      case ExpenseCategory.POSTAGE_COURIER: return 'Postage & Courier';
      case ExpenseCategory.PRINTING_STATIONARY: return 'Printing & Stationary';
      case ExpenseCategory.PROPERTY_TAX: return 'Property Tax';
      case ExpenseCategory.REPAIR_MAINTENANCE: return 'Repair & Maintenance';
      case ExpenseCategory.SANITATION: return 'Sanitation Expenses';
      case ExpenseCategory.SCHOOL_MAINTENANCE: return 'School Maintenance';
      case ExpenseCategory.SPORTS_EXPENSES: return 'Sports Expenses';
      case ExpenseCategory.STAFF_SALARY: return 'Staff Salary';
      case ExpenseCategory.STAFF_UNIFORM: return 'Staff Uniform';
      case ExpenseCategory.TELEPHONE: return 'Telephone Expense';
      case ExpenseCategory.TRAVELING: return 'Traveling Expense';
      case ExpenseCategory.VEHICLE_FUEL: return 'Vehicle Fuel';
      case ExpenseCategory.VEHICLE_MAINTENANCE: return 'Vehicle Maintenance';
      case ExpenseCategory.WATER_CHARGE: return 'Water Charge';
      case ExpenseCategory.OTHER: return 'Other';
    }
  }

  static List<String> getAllCategoryNames() {
    return ExpenseCategory.values.map((e) => getCategoryDisplayName(e)).toList();
  }
}
