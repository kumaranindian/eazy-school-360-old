const functions = require('firebase-functions');
const admin = require('firebase-admin');
const db = admin.firestore();
exports.assignRfidCard = functions.https.onCall(async (data, context) => {
    console.log('[AssignRfidCard] Function called with data:', JSON.stringify(data));
    if (!context.auth) {
        console.error('[AssignRfidCard] Unauthenticated request');
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    const { schoolId, uuid, staffId, staffName, cardType } = data;
    console.log('[AssignRfidCard] User:', context.auth.uid, 'Email:', context.auth.token.email);
    console.log('[AssignRfidCard] Params:', { schoolId, uuid, staffId, staffName, cardType });
    if (!schoolId || !uuid || !staffId || !staffName || !cardType) {
        console.error('[AssignRfidCard] Missing required parameters');
        throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters: schoolId, uuid, staffId, staffName, cardType');
    }
    if (!['primary', 'backup'].includes(cardType)) {
        console.error('[AssignRfidCard] Invalid card type:', cardType);
        throw new functions.https.HttpsError('invalid-argument', 'Card type must be either "primary" or "backup"');
    }
    try {
        // Verify user has admin access
        const userDoc = await db.collection('users').doc(context.auth.uid).get();
        if (!userDoc.exists) {
            console.error('[AssignRfidCard] User document not found:', context.auth.uid);
            throw new functions.https.HttpsError('not-found', 'User document not found');
        }
        const userData = userDoc.data();
        console.log('[AssignRfidCard] User data:', { role: userData.role, schoolId: userData.schoolId });
        const isAdmin = ['ADMIN', 'admin', 'TENANT_ADMIN', 'tenant_admin', 'SUPER_ADMIN', 'super_admin'].includes(userData.role);
        const belongsToSchool = userData.schoolId === schoolId;
        if (!isAdmin || !belongsToSchool) {
            console.error('[AssignRfidCard] Permission denied. IsAdmin:', isAdmin, 'BelongsToSchool:', belongsToSchool);
            throw new functions.https.HttpsError('permission-denied', 'Only admins from the same school can assign RFID cards');
        }
        const rfidCardsRef = db.collection('schools').doc(schoolId).collection('rfid_cards');
        // Check if UUID is already assigned to another staff member
        console.log('[AssignRfidCard] Checking for existing UUID:', uuid);
        const existingQuery = await rfidCardsRef
            .where('uuid', '==', uuid)
            .where('isActive', '==', true)
            .limit(1)
            .get();
        if (!existingQuery.empty) {
            const existingCard = existingQuery.docs[0].data();
            if (existingCard.staffId && existingCard.staffId !== staffId) {
                console.error('[AssignRfidCard] UUID already assigned to:', existingCard.staffId);
                throw new functions.https.HttpsError('already-exists', `UUID ${uuid} is already assigned to another staff member`);
            }
        }
        // Check if staff already has a card of this type
        console.log('[AssignRfidCard] Checking for existing staff cards:', staffId);
        const staffCardsQuery = await rfidCardsRef
            .where('staffId', '==', staffId)
            .where('cardType', '==', cardType)
            .where('isActive', '==', true)
            .limit(1)
            .get();
        if (!staffCardsQuery.empty) {
            console.error('[AssignRfidCard] Staff already has active card of type:', cardType);
            throw new functions.https.HttpsError('already-exists', `Staff already has an active ${cardType} card. Deactivate the existing card first.`);
        }
        // If card exists but is unassigned, update it
        if (!existingQuery.empty) {
            const existingCard = existingQuery.docs[0];
            const existingData = existingCard.data();
            if (!existingData.staffId) {
                console.log('[AssignRfidCard] Updating existing unassigned card:', existingCard.id);
                await existingCard.ref.update({
                    staffId,
                    staffName,
                    cardType,
                    isActive: true,
                    assignedAt: admin.firestore.FieldValue.serverTimestamp(),
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
                console.log('[AssignRfidCard] Successfully updated card:', existingCard.id);
                return {
                    success: true,
                    cardId: existingCard.id,
                    message: 'RFID card assigned successfully',
                };
            }
        }
        // Create new card
        console.log('[AssignRfidCard] Creating new card');
        const newCard = {
            uuid: uuid.trim(),
            staffId,
            staffName,
            cardType,
            isActive: true,
            schoolId,
            assignedAt: admin.firestore.FieldValue.serverTimestamp(),
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        const docRef = await rfidCardsRef.add(newCard);
        console.log('[AssignRfidCard] Successfully created card:', docRef.id);
        return {
            success: true,
            cardId: docRef.id,
            message: 'RFID card assigned successfully',
        };
    }
    catch (error) {
        console.error('[AssignRfidCard] Error:', error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', `Failed to assign RFID card: ${error.message}`);
    }
});
exports.deactivateRfidCard = functions.https.onCall(async (data, context) => {
    console.log('[DeactivateRfidCard] Function called with data:', JSON.stringify(data));
    if (!context.auth) {
        console.error('[DeactivateRfidCard] Unauthenticated request');
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    const { schoolId, cardId } = data;
    console.log('[DeactivateRfidCard] User:', context.auth.uid);
    console.log('[DeactivateRfidCard] Params:', { schoolId, cardId });
    if (!schoolId || !cardId) {
        console.error('[DeactivateRfidCard] Missing required parameters');
        throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters: schoolId, cardId');
    }
    try {
        // Verify user has admin access
        const userDoc = await db.collection('users').doc(context.auth.uid).get();
        if (!userDoc.exists) {
            console.error('[DeactivateRfidCard] User document not found');
            throw new functions.https.HttpsError('not-found', 'User document not found');
        }
        const userData = userDoc.data();
        const isAdmin = ['ADMIN', 'admin', 'TENANT_ADMIN', 'tenant_admin', 'SUPER_ADMIN', 'super_admin'].includes(userData.role);
        const belongsToSchool = userData.schoolId === schoolId;
        if (!isAdmin || !belongsToSchool) {
            console.error('[DeactivateRfidCard] Permission denied');
            throw new functions.https.HttpsError('permission-denied', 'Only admins from the same school can deactivate RFID cards');
        }
        const cardRef = db.collection('schools').doc(schoolId).collection('rfid_cards').doc(cardId);
        const cardDoc = await cardRef.get();
        if (!cardDoc.exists) {
            console.error('[DeactivateRfidCard] Card not found:', cardId);
            throw new functions.https.HttpsError('not-found', 'RFID card not found');
        }
        console.log('[DeactivateRfidCard] Deactivating card:', cardId);
        await cardRef.update({
            isActive: false,
            deactivatedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log('[DeactivateRfidCard] Successfully deactivated card:', cardId);
        return {
            success: true,
            message: 'RFID card deactivated successfully',
        };
    }
    catch (error) {
        console.error('[DeactivateRfidCard] Error:', error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', `Failed to deactivate RFID card: ${error.message}`);
    }
});
//# sourceMappingURL=rfid-card-management.js.map