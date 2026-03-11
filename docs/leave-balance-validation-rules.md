# Leave Balance Validation Rules and Edge Cases

## Core Validation Rules

### 1. Balance Integrity Rules

#### Never Negative Balances
```javascript
// Rule: available >= 0 at all times
available = totalAllowed + carriedForward - used - pending
if (available < 0) {
  throw new Error('Balance cannot be negative');
}
```

#### Component Validation
```javascript
// All balance components must be non-negative
used >= 0
pending >= 0
carriedForward >= 0
totalAllowed > 0
```

#### Carry Forward Limits
```javascript
// Carried forward days cannot exceed configuration limit
if (carriedForward > leaveTypeConfig.maxCarryForwardDays) {
  throw new Error('Carry forward exceeds maximum allowed');
}

// Carry forward only allowed if configuration permits
if (carriedForward > 0 && !leaveTypeConfig.carryForwardAllowed) {
  throw new Error('Carry forward not allowed for this leave type');
}
```

### 2. Leave Request Validation

#### Sufficient Balance Check
```javascript
// Before creating leave request
if (requestedDays > currentBalance.available) {
  throw new Error('Insufficient leave balance');
}

// Before approving leave request
if (requestedDays > (currentBalance.available + currentBalance.pending)) {
  throw new Error('Cannot approve: insufficient balance including pending');
}
```

#### Maximum Days Per Request
```javascript
if (requestedDays > leaveTypeConfig.maxDaysPerRequest) {
  throw new Error(`Maximum ${leaveTypeConfig.maxDaysPerRequest} days allowed per request`);
}
```

#### Academic Year Boundary
```javascript
// Leave dates must fall within current academic year
const academicYearStart = getAcademicYearStart(currentAcademicYear);
const academicYearEnd = getAcademicYearEnd(currentAcademicYear);

for (const leaveDate of leaveDates) {
  if (leaveDate < academicYearStart || leaveDate > academicYearEnd) {
    throw new Error('Leave dates must be within current academic year');
  }
}
```

### 3. Academic Year Reset Validation

#### Timing Validation
```javascript
// Reset can only happen on June 1st
const resetDate = new Date();
if (resetDate.getMonth() !== 5 || resetDate.getDate() !== 1) {
  throw new Error('Academic year reset can only occur on June 1st');
}
```

#### Duplicate Reset Prevention
```javascript
// Check if reset already completed for the year
const academicYearRecord = await getAcademicYearRecord(schoolId, newAcademicYear);
if (academicYearRecord && academicYearRecord.resetCompleted) {
  throw new Error('Academic year reset already completed');
}
```

#### Staff Status Validation
```javascript
// Only process active staff members
if (staffData.status !== 'ACTIVE') {
  console.log(`Skipping inactive staff: ${staffId}`);
  continue;
}
```

## Edge Cases and Handling

### 1. Concurrent Leave Requests

#### Problem
Multiple leave requests submitted simultaneously for the same staff member could cause race conditions.

#### Solution
```javascript
// Use Firestore transactions for balance updates
const transaction = db.runTransaction(async (t) => {
  const balanceDoc = await t.get(balanceRef);
  const currentBalance = balanceDoc.data();
  
  // Check availability within transaction
  if (requestedDays > currentBalance.available) {
    throw new Error('Insufficient balance');
  }
  
  // Update balance atomically
  const newPending = currentBalance.pending + requestedDays;
  const newAvailable = currentBalance.available - requestedDays;
  
  t.update(balanceRef, {
    pending: newPending,
    available: newAvailable,
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });
});
```

### 2. Leave Request Cancellation After Approval

#### Problem
Staff member cancels leave after it's been approved and deducted from balance.

#### Solution
```javascript
// Return days to balance when approved leave is cancelled
if (previousStatus === 'APPROVED' && newStatus === 'CANCELLED') {
  const newUsed = Math.max(0, currentBalance.used - totalDays);
  const newAvailable = currentBalance.available + totalDays;
  
  // Create adjustment mutation
  await createBalanceMutation({
    mutationType: 'ADJUSTMENT',
    delta: totalDays,
    reason: 'Leave cancelled after approval - days returned'
  });
}
```

### 3. Staff Joining Mid-Academic Year

#### Problem
Staff joins after academic year has started - should they get full quota or prorated?

#### Solution
```javascript
// Calculate prorated balance based on joining date
function calculateProratedBalance(joiningDate, annualQuota, academicYear) {
  const academicYearStart = getAcademicYearStart(academicYear);
  const academicYearEnd = getAcademicYearEnd(academicYear);
  
  // If joined before academic year start, give full quota
  if (joiningDate <= academicYearStart) {
    return annualQuota;
  }
  
  // Calculate remaining months in academic year
  const totalMonths = 12;
  const remainingMonths = Math.ceil(
    (academicYearEnd - joiningDate) / (1000 * 60 * 60 * 24 * 30)
  );
  
  // Prorate based on remaining months (minimum 1 day)
  return Math.max(1, Math.floor((annualQuota * remainingMonths) / totalMonths));
}
```

### 4. Leave Type Configuration Changes Mid-Year

#### Problem
Admin changes leave type quota or carry forward rules during academic year.

#### Solution
```javascript
// Handle quota changes
async function handleLeaveTypeConfigUpdate(schoolId, leaveTypeId, oldConfig, newConfig) {
  if (oldConfig.annualQuota !== newConfig.annualQuota) {
    // Update all existing balances for current academic year
    const currentAcademicYear = getCurrentAcademicYear();
    const balancesQuery = db
      .collection('schools')
      .doc(schoolId)
      .collection('leaveBalances')
      .where('leaveTypeId', '==', leaveTypeId)
      .where('academicYear', '==', currentAcademicYear);
    
    const balancesSnapshot = await balancesQuery.get();
    const batch = db.batch();
    
    for (const balanceDoc of balancesSnapshot.docs) {
      const balance = balanceDoc.data();
      const quotaDifference = newConfig.annualQuota - oldConfig.annualQuota;
      
      const newTotalAllowed = newConfig.annualQuota;
      const newAvailable = balance.available + quotaDifference;
      
      // Ensure balance doesn't go negative
      if (newAvailable >= 0) {
        batch.update(balanceDoc.ref, {
          totalAllowed: newTotalAllowed,
          available: newAvailable,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        
        // Create adjustment mutation
        const mutationRef = db
          .collection('schools')
          .doc(schoolId)
          .collection('balanceMutations')
          .doc();
        
        batch.set(mutationRef, {
          // ... mutation data for quota adjustment
        });
      }
    }
    
    await batch.commit();
  }
}
```

### 5. Retroactive Leave Applications

#### Problem
Staff applies for leave for dates that have already passed.

#### Solution
```javascript
// Validate leave dates are not in the past (with grace period)
function validateLeaveDates(leaveDates, leaveTypeConfig) {
  const today = new Date();
  const gracePeriodDays = 7; // Allow 7 days grace period
  const cutoffDate = new Date(today.getTime() - (gracePeriodDays * 24 * 60 * 60 * 1000));
  
  for (const leaveDate of leaveDates) {
    if (leaveDate < cutoffDate) {
      throw new Error('Cannot apply for leave more than 7 days in the past');
    }
  }
  
  // Check advance notice requirement
  if (leaveTypeConfig.customRules?.advanceNoticeRequired) {
    const requiredNoticeDays = leaveTypeConfig.customRules.advanceNoticeRequired;
    const earliestAllowedDate = new Date(today.getTime() + (requiredNoticeDays * 24 * 60 * 60 * 1000));
    
    for (const leaveDate of leaveDates) {
      if (leaveDate < earliestAllowedDate) {
        throw new Error(`Minimum ${requiredNoticeDays} days advance notice required`);
      }
    }
  }
}
```

### 6. Academic Year Reset Failure Recovery

#### Problem
Academic year reset fails partway through, leaving some staff with balances and others without.

#### Solution
```javascript
// Idempotent reset function with recovery
async function recoverAcademicYearReset(schoolId, academicYear) {
  console.log(`Starting recovery for school ${schoolId}, year ${academicYear}`);
  
  // Get all active staff
  const staffSnapshot = await db
    .collection('schools')
    .doc(schoolId)
    .collection('staff')
    .where('status', '==', 'ACTIVE')
    .get();
  
  // Get all leave types
  const leaveTypesSnapshot = await db
    .collection('schools')
    .doc(schoolId)
    .collection('leaveTypes')
    .where('isActive', '==', true)
    .get();
  
  const batch = db.batch();
  let processedCount = 0;
  
  for (const staffDoc of staffSnapshot.docs) {
    for (const leaveTypeDoc of leaveTypesSnapshot.docs) {
      const balanceId = `${staffDoc.id}_${leaveTypeDoc.id}_${academicYear}`;
      
      // Check if balance already exists
      const existingBalance = await db
        .collection('schools')
        .doc(schoolId)
        .collection('leaveBalances')
        .doc(balanceId)
        .get();
      
      if (!existingBalance.exists) {
        // Create missing balance
        const balanceData = createBalanceData(staffDoc.data(), leaveTypeDoc.data(), academicYear);
        batch.set(existingBalance.ref, balanceData);
        processedCount++;
      }
    }
  }
  
  if (processedCount > 0) {
    await batch.commit();
    console.log(`Recovery completed: ${processedCount} balances created`);
  } else {
    console.log('No missing balances found - reset was complete');
  }
}
```

### 7. Negative Balance Prevention

#### Problem
System bugs or race conditions could cause negative balances.

#### Solution
```javascript
// Balance validation trigger
exports.validateBalanceIntegrity = functions.firestore
  .document('/schools/{schoolId}/leaveBalances/{balanceId}')
  .onWrite(async (change, context) => {
    const afterData = change.after.data();
    
    if (!afterData) return; // Document deleted
    
    // Check for negative available balance
    if (afterData.available < 0) {
      console.error(`Negative balance detected: ${context.params.balanceId}`);
      
      // Create alert for admin
      await db.collection('systemAlerts').add({
        type: 'NEGATIVE_BALANCE',
        schoolId: context.params.schoolId,
        balanceId: context.params.balanceId,
        staffId: afterData.staffId,
        available: afterData.available,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        resolved: false
      });
      
      // Optionally auto-correct by setting to 0
      if (AUTO_CORRECT_NEGATIVE_BALANCES) {
        await change.after.ref.update({
          available: 0,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
      }
    }
  });
```

## Testing Scenarios

### 1. Load Testing
- Simulate 1000+ concurrent leave requests
- Test academic year reset with 10,000+ staff members
- Verify performance under high load

### 2. Data Integrity Testing
- Force race conditions with concurrent requests
- Test partial failure scenarios
- Verify rollback mechanisms

### 3. Edge Case Testing
- Staff joining on academic year boundary dates
- Leave requests spanning academic years
- Configuration changes during active leave periods
- System clock changes and timezone issues

### 4. Security Testing
- Attempt to manipulate balances directly
- Test cross-tenant data access
- Verify audit trail completeness

## Monitoring and Alerts

### 1. Balance Anomaly Detection
```javascript
// Daily balance audit
exports.dailyBalanceAudit = functions.pubsub
  .schedule('0 2 * * *') // 2 AM daily
  .onRun(async () => {
    // Check for anomalies:
    // - Negative balances
    // - Balances exceeding quota + max carry forward
    // - Missing balances for active staff
    // - Orphaned balances for inactive staff
  });
```

### 2. Performance Monitoring
- Track Cloud Function execution times
- Monitor Firestore read/write operations
- Alert on timeout or failure rates

### 3. Business Logic Monitoring
- Track balance utilization patterns
- Monitor carry forward usage
- Alert on unusual leave request patterns
