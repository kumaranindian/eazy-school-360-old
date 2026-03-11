import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eazy_school_360/domain/entities/school_holiday.dart';

/// Repository for managing school holidays and weekend configuration
class HolidayRepository {
  final FirebaseFirestore _firestore;

  HolidayRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ============ HOLIDAY CRUD OPERATIONS ============

  /// Get all holidays for a school
  Stream<List<SchoolHoliday>> getHolidaysStream(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('holidays')
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => SchoolHoliday.fromFirestore(doc)).toList());
  }

  /// Get holidays for a specific academic year
  Stream<List<SchoolHoliday>> getHolidaysByAcademicYear(String schoolId, String academicYear) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('holidays')
        .where('academicYear', isEqualTo: academicYear)
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => SchoolHoliday.fromFirestore(doc)).toList());
  }

  /// Get active holidays within a date range (for leave calculation)
  Future<List<SchoolHoliday>> getActiveHolidaysInRange(
    String schoolId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final snapshot = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('holidays')
        .where('isActive', isEqualTo: true)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();

    return snapshot.docs.map((doc) => SchoolHoliday.fromFirestore(doc)).toList();
  }

  /// Get upcoming holidays (next 30 days by default)
  Future<List<SchoolHoliday>> getUpcomingHolidays(String schoolId, {int days = 30}) async {
    final now = DateTime.now();
    final endDate = now.add(Duration(days: days));

    final snapshot = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('holidays')
        .where('isActive', isEqualTo: true)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('date', descending: false)
        .get();

    return snapshot.docs.map((doc) => SchoolHoliday.fromFirestore(doc)).toList();
  }

  /// Create a new holiday
  Future<SchoolHoliday> createHoliday(
    String schoolId,
    CreateHolidayRequest request,
    String createdBy,
  ) async {
    final now = DateTime.now();
    final docRef = _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('holidays')
        .doc();

    final holiday = SchoolHoliday(
      id: docRef.id,
      schoolId: schoolId,
      date: request.date,
      title: request.title,
      description: request.description,
      type: request.type,
      academicYear: request.academicYear,
      isActive: true,
      createdAt: now,
      updatedAt: now,
      createdBy: createdBy,
    );

    await docRef.set(holiday.toFirestore());
    return holiday;
  }

  /// Update an existing holiday
  Future<void> updateHoliday(
    String schoolId,
    String holidayId,
    UpdateHolidayRequest request,
  ) async {
    if (!request.hasChanges) return;

    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('holidays')
        .doc(holidayId)
        .update(request.toMap());
  }

  /// Delete a holiday
  Future<void> deleteHoliday(String schoolId, String holidayId) async {
    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('holidays')
        .doc(holidayId)
        .delete();
  }

  /// Toggle holiday active status
  Future<void> toggleHolidayStatus(String schoolId, String holidayId, bool isActive) async {
    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('holidays')
        .doc(holidayId)
        .update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============ WEEKEND CONFIGURATION ============

  /// Get weekend configuration for a school
  Stream<WeekendConfiguration?> getWeekendConfigStream(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('settings')
        .doc('weekendConfig')
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return WeekendConfiguration.fromFirestore(doc);
    });
  }

  /// Get weekend configuration (one-time fetch)
  Future<WeekendConfiguration> getWeekendConfig(String schoolId) async {
    final doc = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('settings')
        .doc('weekendConfig')
        .get();

    if (!doc.exists) {
      // Return default configuration if none exists
      return WeekendConfiguration(
        id: 'weekendConfig',
        schoolId: schoolId,
        weekendDays: [7], // Sunday only by default
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: 'system',
      );
    }

    return WeekendConfiguration.fromFirestore(doc);
  }

  /// Save weekend configuration
  Future<void> saveWeekendConfig(
    String schoolId,
    List<int> weekendDays,
    String updatedBy,
  ) async {
    final now = DateTime.now();
    final docRef = _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('settings')
        .doc('weekendConfig');

    final doc = await docRef.get();

    if (doc.exists) {
      await docRef.update({
        'weekendDays': weekendDays,
        'updatedAt': Timestamp.fromDate(now),
      });
    } else {
      final config = WeekendConfiguration(
        id: 'weekendConfig',
        schoolId: schoolId,
        weekendDays: weekendDays,
        isActive: true,
        createdAt: now,
        updatedAt: now,
        createdBy: updatedBy,
      );
      await docRef.set(config.toFirestore());
    }
  }

  /// Create holidays for every day in a date range (bulk leave configuration)
  Future<int> createBulkHolidays(
    String schoolId,
    DateTime startDate,
    DateTime endDate,
    String title,
    String description,
    HolidayType type,
    String academicYear,
    String createdBy, {
    List<int> skipWeekdays = const [], // weekday numbers to skip (1=Mon..7=Sun)
  }) async {
    // Fetch existing holiday dates to avoid duplicates
    final existingSnap = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('holidays')
        .where('academicYear', isEqualTo: academicYear)
        .get();

    final existingDates = existingSnap.docs
        .map((doc) => (doc.data()['date'] as Timestamp).toDate())
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet();

    final batch = _firestore.batch();
    var addedCount = 0;
    final now = DateTime.now();

    var current = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    while (!current.isAfter(end)) {
      if (!skipWeekdays.contains(current.weekday) && !existingDates.contains(current)) {
        final docRef = _firestore
            .collection('schools')
            .doc(schoolId)
            .collection('holidays')
            .doc();

        final holiday = SchoolHoliday(
          id: docRef.id,
          schoolId: schoolId,
          date: current,
          title: title,
          description: description,
          type: type,
          academicYear: academicYear,
          isActive: true,
          createdAt: now,
          updatedAt: now,
          createdBy: createdBy,
          metadata: {'bulkCreated': true},
        );

        batch.set(docRef, holiday.toFirestore());
        addedCount++;

        if (addedCount % 450 == 0) {
          await batch.commit();
        }
      }
      current = current.add(const Duration(days: 1));
    }

    if (addedCount % 450 != 0) {
      await batch.commit();
    }

    return addedCount;
  }

  // ============ BULK OPERATIONS ============

  /// Generate Sundays for an academic year
  Future<int> generateSundaysForYear(
    String schoolId,
    String academicYear,
    String createdBy,
  ) async {
    final yearDates = AcademicYearHelper.getAcademicYearDates(academicYear);
    final startDate = yearDates['start']!;
    final endDate = yearDates['end']!;

    // Find all Sundays in the academic year
    final sundays = <DateTime>[];
    var currentDate = startDate;
    while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
      if (currentDate.weekday == DateTime.sunday) {
        sundays.add(currentDate);
      }
      currentDate = currentDate.add(const Duration(days: 1));
    }

    // Check existing Sunday holidays to avoid duplicates
    final existingHolidays = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('holidays')
        .where('academicYear', isEqualTo: academicYear)
        .get();

    final existingDates = existingHolidays.docs
        .map((doc) => (doc.data()['date'] as Timestamp).toDate())
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet();

    // Create batch for bulk insert
    final batch = _firestore.batch();
    var addedCount = 0;
    final now = DateTime.now();

    for (final sunday in sundays) {
      final normalizedSunday = DateTime(sunday.year, sunday.month, sunday.day);
      if (!existingDates.contains(normalizedSunday)) {
        final docRef = _firestore
            .collection('schools')
            .doc(schoolId)
            .collection('holidays')
            .doc();

        final holiday = SchoolHoliday(
          id: docRef.id,
          schoolId: schoolId,
          date: sunday,
          title: 'Sunday',
          description: 'Weekly off',
          type: HolidayType.SCHOOL,
          academicYear: academicYear,
          isActive: true,
          createdAt: now,
          updatedAt: now,
          createdBy: createdBy,
          metadata: {'autoGenerated': true, 'dayType': 'SUNDAY'},
        );

        batch.set(docRef, holiday.toFirestore());
        addedCount++;

        // Firestore batch limit is 500
        if (addedCount % 450 == 0) {
          await batch.commit();
        }
      }
    }

    if (addedCount % 450 != 0) {
      await batch.commit();
    }

    return addedCount;
  }

  /// Delete all auto-generated Sunday holidays for an academic year
  Future<int> removeSundaysForYear(String schoolId, String academicYear) async {
    final snapshot = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('holidays')
        .where('academicYear', isEqualTo: academicYear)
        .where('metadata.dayType', isEqualTo: 'SUNDAY')
        .get();

    final batch = _firestore.batch();
    var deletedCount = 0;

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
      deletedCount++;

      if (deletedCount % 450 == 0) {
        await batch.commit();
      }
    }

    if (deletedCount % 450 != 0) {
      await batch.commit();
    }

    return deletedCount;
  }

  // ============ LEAVE CALCULATION HELPERS ============

  /// Calculate working days excluding weekends and holidays
  Future<LeaveCalculationResult> calculateLeaveDays(
    String schoolId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final weekendConfig = await getWeekendConfig(schoolId);
    final holidays = await getActiveHolidaysInRange(schoolId, startDate, endDate);

    final holidayDates = holidays
        .map((h) => DateTime(h.date.year, h.date.month, h.date.day))
        .toSet();

    final workingDays = <DateTime>[];
    final excludedHolidays = <SchoolHoliday>[];
    final excludedWeekends = <DateTime>[];

    var currentDate = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    while (currentDate.isBefore(end) || currentDate.isAtSameMomentAs(end)) {
      final isWeekend = weekendConfig.weekendDays.contains(currentDate.weekday);
      final isHoliday = holidayDates.contains(currentDate);

      if (isWeekend) {
        excludedWeekends.add(currentDate);
      } else if (isHoliday) {
        final holiday = holidays.firstWhere(
          (h) => DateTime(h.date.year, h.date.month, h.date.day) == currentDate,
        );
        excludedHolidays.add(holiday);
      } else {
        workingDays.add(currentDate);
      }

      currentDate = currentDate.add(const Duration(days: 1));
    }

    return LeaveCalculationResult(
      workingDays: workingDays,
      excludedHolidays: excludedHolidays,
      excludedWeekends: excludedWeekends,
      totalDays: workingDays.length,
    );
  }
}

/// Result of leave day calculation
class LeaveCalculationResult {
  final List<DateTime> workingDays;
  final List<SchoolHoliday> excludedHolidays;
  final List<DateTime> excludedWeekends;
  final int totalDays;

  const LeaveCalculationResult({
    required this.workingDays,
    required this.excludedHolidays,
    required this.excludedWeekends,
    required this.totalDays,
  });

  int get totalExcludedDays => excludedHolidays.length + excludedWeekends.length;
}

// ============ RIVERPOD PROVIDERS ============

final holidayRepositoryProvider = Provider<HolidayRepository>((ref) {
  return HolidayRepository();
});

/// Stream provider for all holidays
final schoolHolidaysStreamProvider =
    StreamProvider.family<List<SchoolHoliday>, String>((ref, schoolId) {
  final repository = ref.watch(holidayRepositoryProvider);
  return repository.getHolidaysStream(schoolId);
});

/// Stream provider for holidays by academic year
final holidaysByAcademicYearProvider = StreamProvider.family<List<SchoolHoliday>,
    ({String schoolId, String academicYear})>((ref, params) {
  final repository = ref.watch(holidayRepositoryProvider);
  return repository.getHolidaysByAcademicYear(params.schoolId, params.academicYear);
});

/// Stream provider for weekend configuration
final weekendConfigStreamProvider =
    StreamProvider.family<WeekendConfiguration?, String>((ref, schoolId) {
  final repository = ref.watch(holidayRepositoryProvider);
  return repository.getWeekendConfigStream(schoolId);
});

/// Future provider for weekend configuration
final weekendConfigProvider =
    FutureProvider.family<WeekendConfiguration, String>((ref, schoolId) {
  final repository = ref.watch(holidayRepositoryProvider);
  return repository.getWeekendConfig(schoolId);
});

/// Future provider for upcoming holidays
final upcomingHolidaysProvider =
    FutureProvider.family<List<SchoolHoliday>, ({String schoolId, int days})>((ref, params) {
  final repository = ref.watch(holidayRepositoryProvider);
  return repository.getUpcomingHolidays(params.schoolId, days: params.days);
});

/// Future provider for leave calculation
final leaveCalculationProvider = FutureProvider.family<LeaveCalculationResult,
    ({String schoolId, DateTime startDate, DateTime endDate})>((ref, params) {
  final repository = ref.watch(holidayRepositoryProvider);
  return repository.calculateLeaveDays(params.schoolId, params.startDate, params.endDate);
});
