import 'package:cloud_functions/cloud_functions.dart';
import '../models/rfid_card.dart';

class RfidRepository {
  final FirebaseFunctions _functions;

  RfidRepository(this._functions);

  /// List all RFID cards for a school
  Future<RfidCardsResponse> listRfidCards(String schoolId) async {
    try {
      final result = await _functions.httpsCallable('listRfidCards').call({
        'schoolId': schoolId,
      });

      final data = result.data as Map<String, dynamic>;
      return RfidCardsResponse.fromJson(data);
    } catch (e) {
      print('❌ [RFID_REPO] Error listing RFID cards: $e');
      rethrow;
    }
  }

  /// Map RFID card to staff
  Future<MapRfidResponse> mapRfidToStaff({
    required String schoolId,
    required String rfidTag,
    required String staffId,
  }) async {
    try {
      final result = await _functions.httpsCallable('mapRfidToStaff').call({
        'schoolId': schoolId,
        'rfidTag': rfidTag,
        'staffId': staffId,
      });

      final data = result.data as Map<String, dynamic>;
      return MapRfidResponse.fromJson(data);
    } catch (e) {
      print('❌ [RFID_REPO] Error mapping RFID to staff: $e');
      rethrow;
    }
  }

  /// Map RFID card to student
  Future<MapRfidResponse> mapRfidToStudent({
    required String schoolId,
    required String rfidTag,
    required String studentId,
  }) async {
    try {
      final result = await _functions.httpsCallable('mapRfidToStaff').call({
        'schoolId': schoolId,
        'rfidTag': rfidTag,
        'studentId': studentId,
      });

      final data = result.data as Map<String, dynamic>;
      return MapRfidResponse.fromJson(data);
    } catch (e) {
      print('❌ [RFID_REPO] Error mapping RFID to student: $e');
      rethrow;
    }
  }

  /// Unmap RFID card
  Future<UnmapRfidResponse> unmapRfidCard({
    required String schoolId,
    required String rfidTag,
  }) async {
    try {
      final result = await _functions.httpsCallable('unmapRfidCard').call({
        'schoolId': schoolId,
        'rfidTag': rfidTag,
      });

      final data = result.data as Map<String, dynamic>;
      return UnmapRfidResponse.fromJson(data);
    } catch (e) {
      print('❌ [RFID_REPO] Error unmapping RFID card: $e');
      rethrow;
    }
  }
}

// Response models
class RfidCardsResponse {
  final bool success;
  final String? message;
  final RfidCardsData? data;

  RfidCardsResponse({
    required this.success,
    this.message,
    this.data,
  });

  factory RfidCardsResponse.fromJson(Map<String, dynamic> json) {
    return RfidCardsResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String?,
      data: json['data'] != null ? RfidCardsData.fromJson(json['data'] as Map<String, dynamic>) : null,
    );
  }
}

class RfidCardsData {
  final String schoolId;
  final int totalCards;
  final int assignedCards;
  final int unassignedCards;
  final List<RfidCard> cards;

  RfidCardsData({
    required this.schoolId,
    required this.totalCards,
    required this.assignedCards,
    required this.unassignedCards,
    required this.cards,
  });

  factory RfidCardsData.fromJson(Map<String, dynamic> json) {
    return RfidCardsData(
      schoolId: json['schoolId'] as String,
      totalCards: json['totalCards'] as int? ?? 0,
      assignedCards: json['assignedCards'] as int? ?? 0,
      unassignedCards: json['unassignedCards'] as int? ?? 0,
      cards: (json['cards'] as List<dynamic>?)
              ?.map((e) => RfidCard.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class MapRfidResponse {
  final bool success;
  final String? message;
  final MapRfidData? data;

  MapRfidResponse({
    required this.success,
    this.message,
    this.data,
  });

  factory MapRfidResponse.fromJson(Map<String, dynamic> json) {
    return MapRfidResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String?,
      data: json['data'] != null ? MapRfidData.fromJson(json['data'] as Map<String, dynamic>) : null,
    );
  }
}

class MapRfidData {
  final String rfidTag;
  final String schoolId;
  final String? staffId;
  final String? studentId;
  final bool isAssigned;
  final String? assignedAt;

  MapRfidData({
    required this.rfidTag,
    required this.schoolId,
    this.staffId,
    this.studentId,
    required this.isAssigned,
    this.assignedAt,
  });

  factory MapRfidData.fromJson(Map<String, dynamic> json) {
    return MapRfidData(
      rfidTag: json['rfidTag'] as String,
      schoolId: json['schoolId'] as String,
      staffId: json['staffId'] as String?,
      studentId: json['studentId'] as String?,
      isAssigned: json['isAssigned'] as bool? ?? false,
      assignedAt: json['assignedAt'] as String?,
    );
  }
}

class UnmapRfidResponse {
  final bool success;
  final String? message;
  final UnmapRfidData? data;

  UnmapRfidResponse({
    required this.success,
    this.message,
    this.data,
  });

  factory UnmapRfidResponse.fromJson(Map<String, dynamic> json) {
    return UnmapRfidResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String?,
      data: json['data'] != null ? UnmapRfidData.fromJson(json['data'] as Map<String, dynamic>) : null,
    );
  }
}

class UnmapRfidData {
  final String rfidTag;
  final String schoolId;
  final bool isAssigned;
  final String? unassignedAt;

  UnmapRfidData({
    required this.rfidTag,
    required this.schoolId,
    required this.isAssigned,
    this.unassignedAt,
  });

  factory UnmapRfidData.fromJson(Map<String, dynamic> json) {
    return UnmapRfidData(
      rfidTag: json['rfidTag'] as String,
      schoolId: json['schoolId'] as String,
      isAssigned: json['isAssigned'] as bool? ?? false,
      unassignedAt: json['unassignedAt'] as String?,
    );
  }
}
