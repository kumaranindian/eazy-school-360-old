import 'package:cloud_firestore/cloud_firestore.dart';

/// Holiday type enum
enum HolidayType {
  PUBLIC,    // National/Public holidays
  SCHOOL,    // School-specific holidays
  OPTIONAL,  // Optional holidays
}

/// School holiday entity (tenant-scoped)
class SchoolHoliday {
  final String id;
  final String schoolId;
  final DateTime date;
  final String title;
  final String description;
  final HolidayType type;
  final String academicYear;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final Map<String, dynamic>? metadata;

  const SchoolHoliday({
    required this.id,
    required this.schoolId,
    required this.date,
    required this.title,
    required this.description,
    required this.type,
    required this.academicYear,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.metadata,
  });

  factory SchoolHoliday.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SchoolHoliday(
      id: doc.id,
      schoolId: data['schoolId'] as String,
      date: (data['date'] as Timestamp).toDate(),
      title: data['title'] as String,
      description: data['description'] as String? ?? '',
      type: _parseHolidayType(data['type']),
      academicYear: data['academicYear'] as String,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] as String,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  static HolidayType _parseHolidayType(dynamic type) {
    if (type == null) return HolidayType.SCHOOL;
    switch (type.toString().toUpperCase()) {
      case 'PUBLIC':
        return HolidayType.PUBLIC;
      case 'SCHOOL':
        return HolidayType.SCHOOL;
      case 'OPTIONAL':
        return HolidayType.OPTIONAL;
      default:
        return HolidayType.SCHOOL;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'schoolId': schoolId,
      'date': Timestamp.fromDate(date),
      'title': title,
      'description': description,
      'type': type.name,
      'academicYear': academicYear,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
      'metadata': metadata,
    };
  }

  SchoolHoliday copyWith({
    String? id,
    String? schoolId,
    DateTime? date,
    String? title,
    String? description,
    HolidayType? type,
    String? academicYear,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    Map<String, dynamic>? metadata,
  }) {
    return SchoolHoliday(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      date: date ?? this.date,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      academicYear: academicYear ?? this.academicYear,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      metadata: metadata ?? this.metadata,
    );
  }

  String get typeDisplayName {
    switch (type) {
      case HolidayType.PUBLIC:
        return 'Public Holiday';
      case HolidayType.SCHOOL:
        return 'School Holiday';
      case HolidayType.OPTIONAL:
        return 'Optional Holiday';
    }
  }

  String get dateDisplayText {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SchoolHoliday && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'SchoolHoliday(id: $id, title: $title, date: $dateDisplayText, type: ${type.name})';
  }
}

/// Weekend configuration for a school
class WeekendConfiguration {
  final String id;
  final String schoolId;
  final List<int> weekendDays; // 1=Monday, 7=Sunday
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;

  const WeekendConfiguration({
    required this.id,
    required this.schoolId,
    required this.weekendDays,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
  });

  factory WeekendConfiguration.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WeekendConfiguration(
      id: doc.id,
      schoolId: data['schoolId'] as String,
      weekendDays: (data['weekendDays'] as List<dynamic>)
          .map((day) => (day as num).toInt())
          .toList(),
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] as String,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'schoolId': schoolId,
      'weekendDays': weekendDays,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
    };
  }

  /// Default weekend configuration (Saturday and Sunday)
  static WeekendConfiguration createDefault(String schoolId, String createdBy) {
    return WeekendConfiguration(
      id: 'default',
      schoolId: schoolId,
      weekendDays: [6, 7], // Saturday and Sunday
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: createdBy,
    );
  }

  bool isWeekend(DateTime date) {
    return weekendDays.contains(date.weekday);
  }

  List<String> get weekendDayNames {
    const dayNames = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return weekendDays.map((day) => dayNames[day]).toList();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WeekendConfiguration && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Request models for holiday management
class CreateHolidayRequest {
  final DateTime date;
  final String title;
  final String description;
  final HolidayType type;
  final String academicYear;

  const CreateHolidayRequest({
    required this.date,
    required this.title,
    required this.description,
    required this.type,
    required this.academicYear,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'title': title,
      'description': description,
      'type': type.name,
      'academicYear': academicYear,
    };
  }
}

class UpdateHolidayRequest {
  final DateTime? date;
  final String? title;
  final String? description;
  final HolidayType? type;
  final String? academicYear;
  final bool? isActive;

  const UpdateHolidayRequest({
    this.date,
    this.title,
    this.description,
    this.type,
    this.academicYear,
    this.isActive,
  });

  bool get hasChanges {
    return date != null ||
        title != null ||
        description != null ||
        type != null ||
        academicYear != null ||
        isActive != null;
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    if (date != null) map['date'] = Timestamp.fromDate(date!);
    if (title != null) map['title'] = title;
    if (description != null) map['description'] = description;
    if (type != null) map['type'] = type!.name;
    if (academicYear != null) map['academicYear'] = academicYear;
    if (isActive != null) map['isActive'] = isActive;
    map['updatedAt'] = FieldValue.serverTimestamp();
    return map;
  }
}

/// Academic year utility for holidays
class AcademicYearHelper {
  /// Get current academic year string
  static String getCurrentAcademicYear() {
    final now = DateTime.now();
    final currentYear = now.year;
    
    // Academic year starts June 1
    if (now.month < 6) {
      return '${currentYear - 1}-${currentYear.toString().substring(2)}';
    } else {
      return '$currentYear-${(currentYear + 1).toString().substring(2)}';
    }
  }

  /// Get academic year for a specific date
  static String getAcademicYearForDate(DateTime date) {
    final year = date.year;
    
    if (date.month < 6) {
      return '${year - 1}-${year.toString().substring(2)}';
    } else {
      return '$year-${(year + 1).toString().substring(2)}';
    }
  }

  /// Get start and end dates for an academic year
  static Map<String, DateTime> getAcademicYearDates(String academicYear) {
    final parts = academicYear.split('-');
    final startYear = int.parse(parts[0]);
    final endYear = startYear + 1;

    return {
      'start': DateTime(startYear, 6, 1), // June 1
      'end': DateTime(endYear, 5, 31),    // May 31
    };
  }

  /// Validate if a date falls within an academic year
  static bool isDateInAcademicYear(DateTime date, String academicYear) {
    final yearDates = getAcademicYearDates(academicYear);
    return date.isAfter(yearDates['start']!.subtract(const Duration(days: 1))) &&
           date.isBefore(yearDates['end']!.add(const Duration(days: 1)));
  }
}
