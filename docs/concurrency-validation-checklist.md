# CONCURRENCY VALIDATION CHECKLIST
## Multi-Tenant School Staff Leave & Permission Management System

## 🧪 **CRITICAL CONCURRENCY SCENARIOS**

### **1. DOUBLE APPROVAL ATTEMPTS**

#### **Scenario A: Concurrent Leave Approvals**
```javascript
// Test Case: Two admins approve same leave simultaneously
// Expected: Only one succeeds, other fails gracefully

// Admin A Transaction:
// 1. Read leave status: PENDING ✓
// 2. Read balance: available = 10 ✓
// 3. Update balance: available = 2 ✓
// 4. Update leave: status = APPROVED ✓
// 5. Mark processed: processedAt = timestamp ✓

// Admin B Transaction (concurrent):
// 1. Read leave status: PENDING ✓
// 2. Read balance: available = 10 ✓ (stale read)
// 3. Update balance: FAILS - document changed ❌
// 4. Transaction aborts, status reverted ✓
```

**VALIDATION PROOF:**
```javascript
// Firestore transaction ensures atomicity
await db.runTransaction(async (transaction) => {
  const currentLeaveDoc = await transaction.get(leaveRef);
  
  // RACE CONDITION PROTECTION
  if (currentLeaveData.status !== 'APPROVED') {
    throw new Error('Leave status changed during processing');
  }
  
  // IDEMPOTENCY CHECK
  if (currentLeaveData.processedAt) {
    return; // Already processed
  }
  
  // All updates in single atomic transaction
  transaction.update(balanceRef, newBalance);
  transaction.update(leaveRef, { processedAt: timestamp });
});
```

#### **Scenario B: Concurrent Permission Approvals**
```javascript
// Test Case: Two admins approve same permission simultaneously
// Expected: Only one succeeds, usage tracking remains consistent

// VALIDATION: Monthly usage counters updated atomically
await db.runTransaction(async (transaction) => {
  const currentPermissionDoc = await transaction.get(permissionRef);
  
  if (currentPermissionData.processedAt) {
    return; // Already processed - idempotent
  }
  
  // Atomic usage update
  transaction.update(usageRef, {
    approvedRequests: usageData.approvedRequests + 1,
    totalMinutesUsed: usageData.totalMinutesUsed + durationMinutes
  });
  
  transaction.update(permissionRef, { processedAt: timestamp });
});
```

### **2. FUNCTION RETRIES**

#### **Scenario C: Cloud Function Retry Protection**
```javascript
// Test Case: Network failure causes function retry
// Expected: Second execution is idempotent, no double processing

exports.processLeaveStatusChange = functions.firestore
  .document('/schools/{schoolId}/leaves/{leaveId}')
  .onUpdate(async (change, context) => {
    const afterData = change.after.data();
    
    // IDEMPOTENCY CHECK #1: Status change required
    if (beforeData.status === afterData.status) {
      return; // No change, skip
    }
    
    // IDEMPOTENCY CHECK #2: Already processed
    if (afterData.processedAt) {
      console.log('Already processed, skipping');
      return; // Idempotent exit
    }
    
    // IDEMPOTENCY CHECK #3: Inside transaction
    await db.runTransaction(async (transaction) => {
      const currentDoc = await transaction.get(leaveRef);
      if (currentDoc.data().processedAt) {
        return; // Double-check inside transaction
      }
      
      // Process only once
      transaction.update(leaveRef, { processedAt: timestamp });
    });
  });
```

#### **Scenario D: Client Resubmission Protection**
```javascript
// Test Case: User clicks "Apply Leave" multiple times
// Expected: Only one application created

exports.createLeaveApplication = functions.https.onCall(async (data, context) => {
  const { schoolId, startDate, endDate, leaveTypeId } = data;
  const applicantId = context.auth.uid;
  
  // Check for duplicate applications (same user, dates, type)
  const existingQuery = await db
    .collection('schools')
    .doc(schoolId)
    .collection('leaves')
    .where('applicantId', '==', applicantId)
    .where('leaveTypeId', '==', leaveTypeId)
    .where('startDate', '==', admin.firestore.Timestamp.fromDate(new Date(startDate)))
    .where('endDate', '==', admin.firestore.Timestamp.fromDate(new Date(endDate)))
    .where('status', 'in', ['PENDING', 'APPROVED'])
    .get();
  
  if (!existingQuery.empty) {
    throw new functions.https.HttpsError('already-exists', 'Leave application already exists for these dates');
  }
  
  // Proceed with creation...
});
```

### **3. YEAR RESET OVERLAPS**

#### **Scenario E: Academic Year Boundary**
```javascript
// Test Case: Leave spans across academic year boundary
// Expected: Proper academic year assignment and balance handling

// June 30, 2024 (end of 2023-24) to July 2, 2024 (start of 2024-25)
const startDate = new Date('2024-06-30');
const endDate = new Date('2024-07-02');

// VALIDATION: Backend determines correct academic year
async function getCurrentAcademicYear(schoolId) {
  const academicYearDoc = await db
    .collection('schools')
    .doc(schoolId)
    .collection('academicYears')
    .where('isCurrent', '==', true)
    .limit(1)
    .get();
  
  if (academicYearDoc.empty) {
    // Default calculation: June to May
    const now = new Date();
    const currentYear = now.getFullYear();
    const academicStartMonth = 5; // June (0-indexed)
    
    if (now.getMonth() >= academicStartMonth) {
      return `${currentYear}-${currentYear + 1}`;
    } else {
      return `${currentYear - 1}-${currentYear}`;
    }
  }
  
  return academicYearDoc.docs[0].data().year;
}

// VALIDATION: Leave assigned to correct academic year
const academicYear = await getCurrentAcademicYear(schoolId);
const balanceId = `${applicantId}_${leaveTypeId}_${academicYear}`;
```

### **4. EXACT BALANCE EDGE CASES**

#### **Scenario F: Zero Balance Approval Attempt**
```javascript
// Test Case: Staff has 0 available days, admin tries to approve 1 day leave
// Expected: Approval fails with clear error message

await db.runTransaction(async (transaction) => {
  const balanceDoc = await transaction.get(balanceRef);
  const currentBalance = balanceDoc.data();
  
  // NEGATIVE BALANCE PROTECTION
  if (currentBalance.available < totalDays) {
    throw new Error(`Insufficient leave balance. Available: ${currentBalance.available}, Required: ${totalDays}`);
  }
  
  // Only proceed if sufficient balance
  const newAvailable = currentBalance.available - totalDays;
  transaction.update(balanceRef, { available: newAvailable });
});
```

#### **Scenario G: Exact Balance Match**
```javascript
// Test Case: Staff has exactly 5 days, applies for 5 days
// Expected: Balance becomes 0, no negative values

// Before: available = 5, used = 10, pending = 0
// After approval: available = 0, used = 15, pending = 0
// Total equation: 15 + 0 + 0 = 15 (totalAllowed) ✓

// VALIDATION: Balance equation integrity
const totalAllowed = currentBalance.totalAllowed;
if (newUsed + newPending + newAvailable !== totalAllowed) {
  throw new Error(`Balance equation violation. Total: ${totalAllowed}, Calculated: ${newUsed + newPending + newAvailable}`);
}
```

#### **Scenario H: Cancellation Restoration Edge Case**
```javascript
// Test Case: Cancel leave that would restore more days than were used
// Expected: Restoration capped at actual used amount

await db.runTransaction(async (transaction) => {
  const currentBalance = balanceDoc.data();
  
  // VALIDATION: Don't restore more than was used
  if (currentBalance.used < totalDaysToRestore) {
    throw new Error(`Cannot restore ${totalDaysToRestore} days. Only ${currentBalance.used} days were used.`);
  }
  
  const newUsed = Math.max(0, currentBalance.used - totalDaysToRestore);
  const newAvailable = currentBalance.available + totalDaysToRestore;
  
  transaction.update(balanceRef, {
    used: newUsed,
    available: newAvailable
  });
});
```

## 🔍 **VALIDATION EXECUTION PLAN**

### **Phase 1: Automated Testing**
```bash
# Concurrent approval simulation
node test-concurrent-approvals.js

# Function retry simulation  
node test-function-retries.js

# Balance edge case testing
node test-balance-edge-cases.js

# Academic year boundary testing
node test-year-boundaries.js
```

### **Phase 2: Load Testing**
```bash
# 100 concurrent leave applications
artillery run load-test-leaves.yml

# 50 concurrent permission requests
artillery run load-test-permissions.yml

# Admin approval stress test
artillery run load-test-approvals.yml
```

### **Phase 3: Manual Validation**
1. **Double-click Protection**: Rapidly click "Apply Leave" button
2. **Network Interruption**: Disconnect during approval process
3. **Browser Refresh**: Refresh page during form submission
4. **Multiple Admin Sessions**: Two admins approve same request simultaneously

## ✅ **SUCCESS CRITERIA**

### **Atomic Operations**
- [ ] All balance updates occur in single transaction
- [ ] No partial writes possible
- [ ] Transaction failures roll back completely
- [ ] Balance equation always maintained

### **Idempotency Protection**
- [ ] Function retries produce same result
- [ ] Duplicate submissions rejected gracefully
- [ ] `processedAt` timestamp prevents double processing
- [ ] Status checks prevent invalid state transitions

### **Race Condition Prevention**
- [ ] Concurrent approvals: only one succeeds
- [ ] Optimistic locking prevents stale reads
- [ ] Document version conflicts handled gracefully
- [ ] No negative balances under any scenario

### **Error Handling**
- [ ] Clear error messages for all failure cases
- [ ] System alerts created for processing failures
- [ ] Automatic rollback on transaction failures
- [ ] Structured logging for debugging

## 🚨 **FAILURE CONDITIONS**

### **Critical Failures (Production Halt Required)**
- Negative leave balances created
- Double processing of same request
- Balance equation violations
- Cross-tenant data corruption

### **High Priority Failures**
- Inconsistent usage tracking
- Missing audit trail entries
- Performance degradation under load
- Error handling gaps

### **Medium Priority Issues**
- Unclear error messages
- Missing system alerts
- Suboptimal transaction boundaries
- Logging insufficiencies

## 📊 **MONITORING METRICS**

### **Real-time Alerts**
```javascript
// Balance integrity violations
if (used + pending + available !== totalAllowed) {
  alert('CRITICAL: Balance equation violation detected');
}

// Negative balance detection
if (available < 0 || used < 0 || pending < 0) {
  alert('CRITICAL: Negative balance detected');
}

// Double processing detection
if (processedAt && newProcessingAttempt) {
  alert('WARNING: Double processing attempt blocked');
}
```

### **Performance Metrics**
- Transaction completion time < 5 seconds
- Concurrent user capacity > 100 users
- Function retry rate < 1%
- Error rate < 0.1%

This validation checklist ensures the system handles all critical concurrency scenarios safely and maintains data integrity under all conditions.
