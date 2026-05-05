import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/rfid_card.dart';

/// Repository for managing RFID card operations
class RfidCardRepository {
  final FirebaseFirestore _firestore;

  RfidCardRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Get the collection reference for RFID cards
  CollectionReference<Map<String, dynamic>> _getCollection(String schoolId) {
    return _firestore.collection('schools').doc(schoolId).collection('rfid_cards');
  }

  /// Assign a new RFID card to a staff member
  /// Returns the document ID of the created card
  Future<String> assignCard({
    required String schoolId,
    required String uuid,
    required String staffId,
    required String staffName,
    required RfidCardType cardType,
    Map<String, dynamic>? metadata,
  }) async {
    // Check if UUID is already assigned
    final existing = await getCardByUuid(schoolId, uuid);
    if (existing != null) {
      throw Exception('UUID $uuid is already assigned to another staff member');
    }

    // Check if staff already has a card of this type
    final existingStaffCards = await getCardsByStaff(schoolId, staffId);
    final hasSameType = existingStaffCards.any(
      (card) => card.cardType == cardType && card.isActive,
    );
    if (hasSameType) {
      throw Exception(
        'Staff already has an active ${cardType.displayName}. '
        'Deactivate the existing card first.',
      );
    }

    final card = RfidCard(
      id: '', // Will be set by Firestore
      uuid: uuid,
      staffId: staffId,
      staffName: staffName,
      cardType: cardType,
      isActive: true,
      assignedAt: DateTime.now(),
      schoolId: schoolId,
      metadata: metadata,
    );

    final docRef = await _getCollection(schoolId).add(card.toFirestore());
    return docRef.id;
  }

  /// Update an existing RFID card
  Future<void> updateCard(
    String schoolId,
    String cardId,
    Map<String, dynamic> updates,
  ) async {
    await _getCollection(schoolId).doc(cardId).update(updates);
  }

  /// Deactivate an RFID card
  Future<void> deactivateCard(String schoolId, String cardId) async {
    await _getCollection(schoolId).doc(cardId).update({
      'isActive': false,
      'deactivatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get a card by its UUID
  Future<RfidCard?> getCardByUuid(String schoolId, String uuid) async {
    final query = await _getCollection(schoolId)
        .where('uuid', isEqualTo: uuid)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    final doc = query.docs.first;
    return RfidCard.fromFirestore(doc.data(), doc.id);
  }

  /// Get all cards for a specific staff member
  Future<List<RfidCard>> getCardsByStaff(String schoolId, String staffId) async {
    final query = await _getCollection(schoolId)
        .where('staffId', isEqualTo: staffId)
        .orderBy('assignedAt', descending: true)
        .get();

    return query.docs.map((doc) {
      return RfidCard.fromFirestore(doc.data(), doc.id);
    }).toList();
  }

  /// Get active cards for a specific staff member
  Future<List<RfidCard>> getActiveCardsByStaff(
    String schoolId,
    String staffId,
  ) async {
    final query = await _getCollection(schoolId)
        .where('staffId', isEqualTo: staffId)
        .where('isActive', isEqualTo: true)
        .orderBy('assignedAt', descending: true)
        .get();

    return query.docs.map((doc) {
      return RfidCard.fromFirestore(doc.data(), doc.id);
    }).toList();
  }

  /// Delete an RFID card permanently
  Future<void> deleteCard(String schoolId, String cardId) async {
    await _getCollection(schoolId).doc(cardId).delete();
  }

  /// Check if a UUID is available (not assigned to any active card)
  Future<bool> isUuidAvailable(String schoolId, String uuid) async {
    final card = await getCardByUuid(schoolId, uuid);
    return card == null;
  }

  /// Check if a staff can add a card of a specific type
  /// Returns true if they don't already have an active card of that type
  Future<bool> canStaffAddCard(
    String schoolId,
    String staffId,
    RfidCardType cardType,
  ) async {
    final activeCards = await getActiveCardsByStaff(schoolId, staffId);
    return !activeCards.any((card) => card.cardType == cardType);
  }

  /// Update the last used timestamp for a card
  Future<void> updateLastUsed(String schoolId, String cardId) async {
    await _getCollection(schoolId).doc(cardId).update({
      'lastUsedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get all RFID cards for a school (for admin view)
  Future<List<RfidCard>> getAllCards(String schoolId) async {
    final query = await _getCollection(schoolId)
        .orderBy('assignedAt', descending: true)
        .get();

    return query.docs.map((doc) {
      return RfidCard.fromFirestore(doc.data(), doc.id);
    }).toList();
  }

  /// Get card by document ID
  Future<RfidCard?> getCardById(String schoolId, String cardId) async {
    final doc = await _getCollection(schoolId).doc(cardId).get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    return RfidCard.fromFirestore(data, doc.id);
  }
}
