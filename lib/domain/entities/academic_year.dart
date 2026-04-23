import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an academic year (May to April)
/// Example: "2024-25" runs from May 1, 2024 to April 30, 2025
class AcademicYear {
  final String id;
  final String schoolId;
  final String yearCode; // e.g., "2024-25"
  final DateTime startDate; // May 1
  final DateTime endDate; // April 30
  final bool isCurrent;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AcademicYear({
    required this.id,
    required this.schoolId,
    required this.yearCode,
    required this.startDate,
    required this.endDate,
    required this.isCurrent,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AcademicYear.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AcademicYear(
      id: doc.id,
      schoolId: data['schoolId'] as String? ?? '',
      yearCode: data['yearCode'] as String? ?? '',
      startDate: _parseDate(data['startDate']),
      endDate: _parseDate(data['endDate']),
      isCurrent: data['isCurrent'] as bool? ?? false,
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'schoolId': schoolId,
      'yearCode': yearCode,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'isCurrent': isCurrent,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  /// Creates an academic year from a starting year
  /// Example: fromYear(2024) creates "2024-25" from May 1, 2024 to April 30, 2025
  factory AcademicYear.fromYear(String schoolId, int startYear, {bool isCurrent = false}) {
    final startDate = DateTime(startYear, 5, 1); // May 1
    final endDate = DateTime(startYear + 1, 4, 30); // April 30 next year
    final yearCode = '$startYear-${(startYear + 1) % 100}';
    final now = DateTime.now();

    return AcademicYear(
      id: '',
      schoolId: schoolId,
      yearCode: yearCode,
      startDate: startDate,
      endDate: endDate,
      isCurrent: isCurrent,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Gets the current academic year based on today's date
  static String getCurrentYearCode() {
    final now = DateTime.now();
    final year = now.month >= 5 ? now.year : now.year - 1;
    return '$year-${(year + 1) % 100}';
  }

  /// Checks if a date falls within this academic year
  bool containsDate(DateTime date) {
    return date.isAfter(startDate.subtract(const Duration(days: 1))) &&
           date.isBefore(endDate.add(const Duration(days: 1)));
  }

  /// Gets the next academic year
  AcademicYear getNextYear() {
    final nextStartYear = startDate.year + 1;
    return AcademicYear.fromYear(schoolId, nextStartYear);
  }

  /// Gets the previous academic year
  AcademicYear getPreviousYear() {
    final prevStartYear = startDate.year - 1;
    return AcademicYear.fromYear(schoolId, prevStartYear);
  }

  AcademicYear copyWith({
    String? id,
    String? schoolId,
    String? yearCode,
    DateTime? startDate,
    DateTime? endDate,
    bool? isCurrent,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AcademicYear(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      yearCode: yearCode ?? this.yearCode,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isCurrent: isCurrent ?? this.isCurrent,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'AcademicYear($yearCode, current: $isCurrent)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AcademicYear && other.id == id && other.yearCode == yearCode;

  @override
  int get hashCode => id.hashCode ^ yearCode.hashCode;
}

/// Represents a fiscal year (April to March)
/// Example: "2024-25" runs from April 1, 2024 to March 31, 2025
class FiscalYear {
  final String id;
  final String schoolId;
  final String yearCode; // e.g., "2024-25"
  final DateTime startDate; // April 1
  final DateTime endDate; // March 31
  final bool isCurrent;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FiscalYear({
    required this.id,
    required this.schoolId,
    required this.yearCode,
    required this.startDate,
    required this.endDate,
    required this.isCurrent,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FiscalYear.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FiscalYear(
      id: doc.id,
      schoolId: data['schoolId'] as String? ?? '',
      yearCode: data['yearCode'] as String? ?? '',
      startDate: _parseDate(data['startDate']),
      endDate: _parseDate(data['endDate']),
      isCurrent: data['isCurrent'] as bool? ?? false,
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'schoolId': schoolId,
      'yearCode': yearCode,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'isCurrent': isCurrent,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  /// Creates a fiscal year from a starting year
  /// Example: fromYear(2024) creates "2024-25" from April 1, 2024 to March 31, 2025
  factory FiscalYear.fromYear(String schoolId, int startYear, {bool isCurrent = false}) {
    final startDate = DateTime(startYear, 4, 1); // April 1
    final endDate = DateTime(startYear + 1, 3, 31); // March 31 next year
    final yearCode = '$startYear-${(startYear + 1) % 100}';
    final now = DateTime.now();

    return FiscalYear(
      id: '',
      schoolId: schoolId,
      yearCode: yearCode,
      startDate: startDate,
      endDate: endDate,
      isCurrent: isCurrent,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Gets the current fiscal year based on today's date
  static String getCurrentYearCode() {
    final now = DateTime.now();
    final year = now.month >= 4 ? now.year : now.year - 1;
    return '$year-${(year + 1) % 100}';
  }

  /// Checks if a date falls within this fiscal year
  bool containsDate(DateTime date) {
    return date.isAfter(startDate.subtract(const Duration(days: 1))) &&
           date.isBefore(endDate.add(const Duration(days: 1)));
  }

  /// Gets the next fiscal year
  FiscalYear getNextYear() {
    final nextStartYear = startDate.year + 1;
    return FiscalYear.fromYear(schoolId, nextStartYear);
  }

  /// Gets the previous fiscal year
  FiscalYear getPreviousYear() {
    final prevStartYear = startDate.year - 1;
    return FiscalYear.fromYear(schoolId, prevStartYear);
  }

  FiscalYear copyWith({
    String? id,
    String? schoolId,
    String? yearCode,
    DateTime? startDate,
    DateTime? endDate,
    bool? isCurrent,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FiscalYear(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      yearCode: yearCode ?? this.yearCode,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isCurrent: isCurrent ?? this.isCurrent,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'FiscalYear($yearCode, current: $isCurrent)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FiscalYear && other.id == id && other.yearCode == yearCode;

  @override
  int get hashCode => id.hashCode ^ yearCode.hashCode;
}
