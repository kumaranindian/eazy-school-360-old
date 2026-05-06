"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.processRfidSwipe = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const db = admin.firestore();
/**
 * Process RFID swipe and update/create attendance record
 * Triggered when a new RFID swipe is written to Firestore
 */
exports.processRfidSwipe = functions
    .region('asia-south1')
    .firestore
    .document('schools/{schoolId}/rfidSwipes/{swipeId}')
    .onCreate(async (snapshot, context) => {
    const schoolId = context.params.schoolId;
    const swipeData = snapshot.data();
    try {
        const cardUuid = swipeData.cardUuid || swipeData.uuid;
        const timestamp = swipeData.timestamp.toDate();
        const swipeDate = new Date(timestamp.getFullYear(), timestamp.getMonth(), timestamp.getDate());
        // Find staff by RFID card
        const cardSnapshot = await db
            .collection('schools')
            .doc(schoolId)
            .collection('rfidCards')
            .where('uuid', '==', cardUuid)
            .where('isActive', '==', true)
            .limit(1)
            .get();
        if (cardSnapshot.empty) {
            console.warn(`No active RFID card found for UUID: ${cardUuid}`);
            return null;
        }
        const cardData = cardSnapshot.docs[0].data();
        const staffId = cardData.staffId;
        const staffName = cardData.staffName;
        // Update card last used time
        await cardSnapshot.docs[0].ref.update({
            lastUsedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        // Get or create attendance record for this staff and date
        const attendanceId = `${staffId}_${swipeDate.toISOString().split('T')[0]}`;
        const attendanceRef = db
            .collection('schools')
            .doc(schoolId)
            .collection('staffAttendance')
            .doc(attendanceId);
        const attendanceDoc = await attendanceRef.get();
        const swipeRecord = {
            cardUuid,
            timestamp: admin.firestore.Timestamp.fromDate(timestamp),
            deviceId: swipeData.deviceId,
            metadata: swipeData.metadata,
        };
        if (!attendanceDoc.exists) {
            // Create new attendance record
            await attendanceRef.set({
                schoolId,
                staffId,
                staffName,
                date: admin.firestore.Timestamp.fromDate(swipeDate),
                status: 'PARTIAL',
                loginTime: admin.firestore.Timestamp.fromDate(timestamp),
                logoutTime: null,
                isLate: false,
                swipes: [swipeRecord],
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
        else {
            // Update existing attendance record
            const existingData = attendanceDoc.data();
            const existingSwipes = existingData.swipes || [];
            // Add new swipe
            existingSwipes.push(swipeRecord);
            // Sort swipes by timestamp
            existingSwipes.sort((a, b) => a.timestamp.toMillis() - b.timestamp.toMillis());
            // First swipe = login, last swipe = logout
            const loginTime = existingSwipes[0].timestamp.toDate();
            const logoutTime = existingSwipes[existingSwipes.length - 1].timestamp.toDate();
            // Calculate if late
            const config = await getAttendanceConfig(schoolId);
            const { isLate, lateByMinutes } = calculateLateStatus(loginTime, swipeDate, config);
            // Calculate working minutes
            const workingMinutes = Math.floor((logoutTime.getTime() - loginTime.getTime()) / (1000 * 60));
            await attendanceRef.update({
                loginTime: admin.firestore.Timestamp.fromDate(loginTime),
                logoutTime: admin.firestore.Timestamp.fromDate(logoutTime),
                isLate,
                lateByMinutes: isLate ? lateByMinutes : null,
                workingMinutes,
                status: existingSwipes.length === 1 ? 'PARTIAL' : 'PRESENT',
                swipes: existingSwipes.map(s => ({
                    cardUuid: s.cardUuid,
                    timestamp: s.timestamp,
                    deviceId: s.deviceId,
                    metadata: s.metadata,
                })),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
        console.log(`Processed RFID swipe for staff ${staffId} at ${timestamp}`);
        return null;
    }
    catch (error) {
        console.error('Error processing RFID swipe:', error);
        throw error;
    }
});
/**
 * Daily Attendance Finalizer
 * Marks absent, applies leave/permission, calculates LOP
 * DISABLED - Now handled by combined-daily-jobs.js to reduce costs
 */
/*
export const dailyAttendanceFinalizer = functions
  .region('asia-south1')
  .pubsub
  .schedule('0 23 * * *') // Run at 11 PM daily
  .timeZone('Asia/Kolkata')
  .onRun(async (context) => {
    try {
      const today = new Date();
      const todayDate = new Date(today.getFullYear(), today.getMonth(), today.getDate());
      const todayStr = todayDate.toISOString().split('T')[0];

      console.log(`Running daily attendance finalizer for ${todayStr}`);

      // Get all schools
      const schoolsSnapshot = await db.collection('schools').get();

      for (const schoolDoc of schoolsSnapshot.docs) {
        const schoolId = schoolDoc.id;
        
        try {
          await finalizeSchoolAttendance(schoolId, todayDate);
        } catch (error) {
          console.error(`Error finalizing attendance for school ${schoolId}:`, error);
        }
      }

      console.log('Daily attendance finalization completed');
      return null;
    } catch (error) {
      console.error('Error in daily attendance finalizer:', error);
      throw error;
    }
  });
*/
/**
 * Get attendance configuration for a school
 */
async function getAttendanceConfig(schoolId) {
    const configDoc = await db
        .collection('schools')
        .doc(schoolId)
        .collection('attendanceConfig')
        .doc('default')
        .get();
    if (!configDoc.exists) {
        // Return default config
        return {
            lateThresholdTime: '09:30',
            lateGraceMinutes: 5,
            workingDays: ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY'],
            autoMarkAbsent: true,
            requireBothSwipes: true,
        };
    }
    return configDoc.data();
}
/**
 * Calculate if login is late
 */
function calculateLateStatus(loginTime, date, config) {
    const [hours, minutes] = config.lateThresholdTime.split(':').map(Number);
    const threshold = new Date(date.getFullYear(), date.getMonth(), date.getDate(), hours, minutes);
    threshold.setMinutes(threshold.getMinutes() + config.lateGraceMinutes);
    if (loginTime > threshold) {
        const lateByMinutes = Math.floor((loginTime.getTime() - threshold.getTime()) / (1000 * 60));
        return { isLate: true, lateByMinutes };
    }
    return { isLate: false, lateByMinutes: 0 };
}
/**
 * Check if date is a holiday
 * DISABLED - Only used by disabled dailyAttendanceFinalizer
 */
/*
async function checkIfHoliday(schoolId: string, date: Date): Promise<boolean> {
  const dateOnly = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  
  const holidaySnapshot = await db
    .collection('schools')
    .doc(schoolId)
    .collection('holidays')
    .where('date', '==', admin.firestore.Timestamp.fromDate(dateOnly))
    .where('isActive', '==', true)
    .limit(1)
    .get();

  return !holidaySnapshot.empty;
}
*/
/**
 * Mark all staff as holiday
 * DISABLED - Only used by disabled dailyAttendanceFinalizer
 */
/*
async function markAllStaffAsHoliday(schoolId: string, date: Date): Promise<void> {
  const staffSnapshot = await db
    .collection('schools')
    .doc(schoolId)
    .collection('staffProfiles')
    .where('isActive', '==', true)
    .get();

  const batch = db.batch();
  const dateStr = date.toISOString().split('T')[0];

  for (const staffDoc of staffSnapshot.docs) {
    const staffId = staffDoc.id;
    const staffData = staffDoc.data();
    const attendanceId = `${staffId}_${dateStr}`;
    const attendanceRef = db
      .collection('schools')
      .doc(schoolId)
      .collection('staffAttendance')
      .doc(attendanceId);

    batch.set(attendanceRef, {
      schoolId,
      staffId,
      staffName: staffData.name || staffData.fullName || '',
      date: admin.firestore.Timestamp.fromDate(date),
      status: 'HOLIDAY',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  }

  await batch.commit();
}
*/
/**
 * Get approved leaves for a specific date
 * DISABLED - Only used by disabled dailyAttendanceFinalizer
 */
/*
async function getApprovedLeavesForDate(
  schoolId: string,
  date: Date
): Promise<Map<string, LeaveApplication>> {
  const leavesMap = new Map<string, LeaveApplication>();
  const dateTimestamp = admin.firestore.Timestamp.fromDate(date);

  const leavesSnapshot = await db
    .collection('schools')
    .doc(schoolId)
    .collection('leaveApplications')
    .where('status', '==', 'APPROVED')
    .where('leaveDates', 'array-contains', dateTimestamp)
    .get();

  for (const leaveDoc of leavesSnapshot.docs) {
    const leaveData = leaveDoc.data() as LeaveApplication;
    leavesMap.set(leaveData.staffId, { ...leaveData, id: leaveDoc.id });
  }

  return leavesMap;
}
*/
/**
 * Get approved permissions for a specific date
 * DISABLED - Only used by disabled dailyAttendanceFinalizer
 */
/*
async function getApprovedPermissionsForDate(
  schoolId: string,
  date: Date
): Promise<Map<string, PermissionRequest>> {
  const permissionsMap = new Map<string, PermissionRequest>();
  const dateOnly = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  const dateTimestamp = admin.firestore.Timestamp.fromDate(dateOnly);

  const permissionsSnapshot = await db
    .collection('schools')
    .doc(schoolId)
    .collection('permissionRequests')
    .where('status', '==', 'APPROVED')
    .where('requestDate', '==', dateTimestamp)
    .get();

  for (const permissionDoc of permissionsSnapshot.docs) {
    const permissionData = permissionDoc.data() as PermissionRequest;
    permissionsMap.set(permissionData.staffId, { ...permissionData, id: permissionDoc.id });
  }

  return permissionsMap;
}
*/
/**
 * Check if absence should be marked as LOP (Loss of Pay)
 * DISABLED - Only used by disabled dailyAttendanceFinalizer
 */
/*
async function checkIfLOP(schoolId: string, staffId: string, date: Date): Promise<boolean> {
  // Get current academic year
  const academicYear = getAcademicYear(date);

  // Get leave balance
  const balanceDoc = await db
    .collection('schools')
    .doc(schoolId)
    .collection('leaveBalances')
    .doc(`${staffId}_${academicYear}`)
    .get();

  if (!balanceDoc.exists) {
    return false; // No balance record, don't mark as LOP
  }

  const balanceData = balanceDoc.data()!;
  
  // Check if any leave type has remaining balance
  const leaveTypes = balanceData.leaveTypes || {};
  for (const leaveType of Object.values(leaveTypes) as any[]) {
    if (leaveType.remaining > 0) {
      return false; // Has remaining leave balance
    }
  }

  return true; // No remaining balance, mark as LOP
}
*/
/**
 * Get academic year for a date
 * DISABLED - Only used by disabled dailyAttendanceFinalizer
 */
/*
function getAcademicYear(date: Date): string {
  const year = date.getFullYear();
  const month = date.getMonth() + 1;
  
  // Assuming academic year starts in June
  if (month >= 6) {
    return `${year}-${year + 1}`;
  } else {
    return `${year - 1}-${year}`;
  }
}
*/
/**
 * Get day name from day number
 * DISABLED - Only used by disabled dailyAttendanceFinalizer
 */
/*
function getDayName(day: number): string {
  const days = ['SUNDAY', 'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY'];
  return days[day];
}
*/
//# sourceMappingURL=attendanceProcessor.js.map