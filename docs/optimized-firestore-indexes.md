# OPTIMIZED FIRESTORE INDEXES
## Multi-Tenant School Staff Leave & Permission Management System

## CRITICAL PERFORMANCE INDEXES

### **1. Leave Applications Dashboard Queries**

#### **Admin Dashboard - Pending Leaves**
```json
{
  "collectionGroup": "leaves",
  "fields": [
    {"fieldPath": "schoolId", "order": "ASCENDING"},
    {"fieldPath": "status", "order": "ASCENDING"},
    {"fieldPath": "createdAt", "order": "DESCENDING"}
  ]
}
```

#### **Staff Dashboard - Personal Leaves**
```json
{
  "collectionGroup": "leaves", 
  "fields": [
    {"fieldPath": "schoolId", "order": "ASCENDING"},
    {"fieldPath": "applicantId", "order": "ASCENDING"},
    {"fieldPath": "createdAt", "order": "DESCENDING"}
  ]
}
```

#### **Leave Type Filtering**
```json
{
  "collectionGroup": "leaves",
  "fields": [
    {"fieldPath": "schoolId", "order": "ASCENDING"},
    {"fieldPath": "leaveTypeId", "order": "ASCENDING"},
    {"fieldPath": "status", "order": "ASCENDING"},
    {"fieldPath": "startDate", "order": "DESCENDING"}
  ]
}
```

### **2. Permission Requests Dashboard Queries**

#### **Admin Dashboard - Pending Permissions**
```json
{
  "collectionGroup": "permissions",
  "fields": [
    {"fieldPath": "schoolId", "order": "ASCENDING"},
    {"fieldPath": "status", "order": "ASCENDING"},
    {"fieldPath": "createdAt", "order": "DESCENDING"}
  ]
}
```

#### **Staff Dashboard - Personal Permissions**
```json
{
  "collectionGroup": "permissions",
  "fields": [
    {"fieldPath": "schoolId", "order": "ASCENDING"},
    {"fieldPath": "applicantId", "order": "ASCENDING"},
    {"fieldPath": "requestDate", "order": "DESCENDING"}
  ]
}
```

#### **Monthly Permission Usage**
```json
{
  "collectionGroup": "monthlyPermissionUsage",
  "fields": [
    {"fieldPath": "schoolId", "order": "ASCENDING"},
    {"fieldPath": "month", "order": "ASCENDING"},
    {"fieldPath": "staffId", "order": "ASCENDING"}
  ]
}
```

### **3. Leave Cancellation Queries**

#### **Admin Cancellation Approvals**
```json
{
  "collectionGroup": "leaveCancellations",
  "fields": [
    {"fieldPath": "schoolId", "order": "ASCENDING"},
    {"fieldPath": "status", "order": "ASCENDING"},
    {"fieldPath": "requestedAt", "order": "DESCENDING"}
  ]
}
```

#### **Staff Cancellation History**
```json
{
  "collectionGroup": "leaveCancellations",
  "fields": [
    {"fieldPath": "schoolId", "order": "ASCENDING"},
    {"fieldPath": "applicantId", "order": "ASCENDING"},
    {"fieldPath": "requestedAt", "order": "DESCENDING"}
  ]
}
```

### **4. Audit Log Queries**

#### **Admin Audit Trail**
```json
{
  "collectionGroup": "auditLogs",
  "fields": [
    {"fieldPath": "schoolId", "order": "ASCENDING"},
    {"fieldPath": "actionType", "order": "ASCENDING"},
    {"fieldPath": "timestamp", "order": "DESCENDING"}
  ]
}
```

#### **User-Specific Audit Trail**
```json
{
  "collectionGroup": "auditLogs",
  "fields": [
    {"fieldPath": "schoolId", "order": "ASCENDING"},
    {"fieldPath": "actorUid", "order": "ASCENDING"},
    {"fieldPath": "timestamp", "order": "DESCENDING"}
  ]
}
```

### **5. Staff Management Queries**

#### **Active Staff Listing**
```json
{
  "collectionGroup": "staff",
  "fields": [
    {"fieldPath": "schoolId", "order": "ASCENDING"},
    {"fieldPath": "status", "order": "ASCENDING"},
    {"fieldPath": "name", "order": "ASCENDING"}
  ]
}
```

#### **Department-wise Staff**
```json
{
  "collectionGroup": "staff",
  "fields": [
    {"fieldPath": "schoolId", "order": "ASCENDING"},
    {"fieldPath": "department", "order": "ASCENDING"},
    {"fieldPath": "joiningDate", "order": "DESCENDING"}
  ]
}
```

### **6. Leave Balance Queries**

#### **Staff Leave Balance by Type**
```json
{
  "collectionGroup": "leaveBalances",
  "fields": [
    {"fieldPath": "schoolId", "order": "ASCENDING"},
    {"fieldPath": "userId", "order": "ASCENDING"},
    {"fieldPath": "leaveTypeId", "order": "ASCENDING"},
    {"fieldPath": "academicYear", "order": "DESCENDING"}
  ]
}
```

#### **Balance Mutation History**
```json
{
  "collectionGroup": "balanceMutations",
  "fields": [
    {"fieldPath": "schoolId", "order": "ASCENDING"},
    {"fieldPath": "userId", "order": "ASCENDING"},
    {"fieldPath": "createdAt", "order": "DESCENDING"}
  ]
}
```

### **7. Notification Queries**

#### **User Notifications**
```json
{
  "collectionGroup": "notifications",
  "fields": [
    {"fieldPath": "schoolId", "order": "ASCENDING"},
    {"fieldPath": "recipientUid", "order": "ASCENDING"},
    {"fieldPath": "isRead", "order": "ASCENDING"},
    {"fieldPath": "createdAt", "order": "DESCENDING"}
  ]
}
```

### **8. Holiday Management Queries**

#### **School Holidays by Academic Year**
```json
{
  "collectionGroup": "holidays",
  "fields": [
    {"fieldPath": "schoolId", "order": "ASCENDING"},
    {"fieldPath": "academicYear", "order": "ASCENDING"},
    {"fieldPath": "date", "order": "ASCENDING"}
  ]
}
```

#### **Holiday Type Filtering**
```json
{
  "collectionGroup": "holidays",
  "fields": [
    {"fieldPath": "schoolId", "order": "ASCENDING"},
    {"fieldPath": "type", "order": "ASCENDING"},
    {"fieldPath": "isActive", "order": "ASCENDING"},
    {"fieldPath": "date", "order": "ASCENDING"}
  ]
}
```

## QUERY OPTIMIZATION STRATEGIES

### **1. Pagination Implementation**

#### **Before (Unbounded Query)**
```dart
// PROBLEM: Could return thousands of documents
Stream<List<LeaveApplication>> getAllLeaves(String schoolId) {
  return _firestore
      .collection('schools')
      .doc(schoolId)
      .collection('leaves')
      .orderBy('createdAt', descending: true)
      .snapshots();
}
```

#### **After (Paginated Query)**
```dart
// SOLUTION: Paginated with limits
Stream<List<LeaveApplication>> getLeavesPaginated(
  String schoolId, {
  DocumentSnapshot? lastDocument,
  int limit = 20,
}) {
  Query query = _firestore
      .collection('schools')
      .doc(schoolId)
      .collection('leaves')
      .orderBy('createdAt', descending: true)
      .limit(limit);
      
  if (lastDocument != null) {
    query = query.startAfterDocument(lastDocument);
  }
  
  return query.snapshots().map((snapshot) => 
    snapshot.docs.map((doc) => LeaveApplication.fromFirestore(doc)).toList()
  );
}
```

### **2. Composite Index Usage**

#### **Dashboard Statistics Query**
```dart
// Optimized query using composite index
Future<Map<String, int>> getDashboardStats(String schoolId) async {
  // Uses index: schoolId + status + createdAt
  final pendingLeaves = await _firestore
      .collection('schools')
      .doc(schoolId)
      .collection('leaves')
      .where('status', isEqualTo: 'PENDING')
      .orderBy('createdAt', descending: true)
      .limit(100) // Prevent unbounded queries
      .get();
      
  return {
    'pendingLeaves': pendingLeaves.size,
    // ... other stats
  };
}
```

### **3. Avoiding N+1 Query Patterns**

#### **Before (N+1 Problem)**
```dart
// PROBLEM: Multiple individual queries
Future<List<StaffWithBalance>> getStaffWithBalances(String schoolId) async {
  final staff = await getSchoolStaff(schoolId);
  final result = <StaffWithBalance>[];
  
  for (final member in staff) {
    // N+1 queries - one per staff member
    final balance = await getLeaveBalance(member.id);
    result.add(StaffWithBalance(member, balance));
  }
  
  return result;
}
```

#### **After (Batch Query)**
```dart
// SOLUTION: Batch query with composite index
Future<List<StaffWithBalance>> getStaffWithBalances(String schoolId) async {
  // Single query using composite index: schoolId + academicYear
  final balances = await _firestore
      .collection('schools')
      .doc(schoolId)
      .collection('leaveBalances')
      .where('academicYear', isEqualTo: getCurrentAcademicYear())
      .get();
      
  // Group by userId for efficient lookup
  final balanceMap = <String, List<LeaveBalance>>{};
  for (final doc in balances.docs) {
    final balance = LeaveBalance.fromFirestore(doc);
    balanceMap.putIfAbsent(balance.userId, () => []).add(balance);
  }
  
  final staff = await getSchoolStaff(schoolId);
  return staff.map((member) => StaffWithBalance(
    member, 
    balanceMap[member.id] ?? []
  )).toList();
}
```

## PERFORMANCE MONITORING

### **Query Performance Metrics**

#### **Dashboard Load Time Targets**
- **Admin Dashboard**: < 2 seconds
- **Staff Dashboard**: < 1.5 seconds  
- **Leave Application List**: < 1 second
- **Permission History**: < 1 second

#### **Index Usage Validation**
```dart
// Monitor query performance
class QueryPerformanceMonitor {
  static Future<T> monitorQuery<T>(
    String queryName,
    Future<T> Function() query,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await query();
      stopwatch.stop();
      
      // Log slow queries
      if (stopwatch.elapsedMilliseconds > 1000) {
        print('SLOW QUERY: $queryName took ${stopwatch.elapsedMilliseconds}ms');
      }
      
      return result;
    } catch (e) {
      stopwatch.stop();
      print('QUERY ERROR: $queryName failed after ${stopwatch.elapsedMilliseconds}ms');
      rethrow;
    }
  }
}
```

### **Cost Optimization**

#### **Read Operation Limits**
```dart
// Implement query limits to control costs
class QueryLimits {
  static const int MAX_DASHBOARD_ITEMS = 50;
  static const int MAX_HISTORY_ITEMS = 100;
  static const int MAX_SEARCH_RESULTS = 25;
  
  static Query applyLimit(Query query, int limit) {
    return query.limit(math.min(limit, MAX_DASHBOARD_ITEMS));
  }
}
```

#### **Caching Strategy**
```dart
// Cache frequently accessed data
class FirestoreCache {
  static final Map<String, CachedData> _cache = {};
  static const Duration CACHE_TTL = Duration(minutes: 5);
  
  static Future<T> getCached<T>(
    String key,
    Future<T> Function() fetcher,
  ) async {
    final cached = _cache[key];
    if (cached != null && !cached.isExpired) {
      return cached.data as T;
    }
    
    final data = await fetcher();
    _cache[key] = CachedData(data, DateTime.now().add(CACHE_TTL));
    return data;
  }
}
```

## INDEX DEPLOYMENT COMMANDS

### **Firebase CLI Commands**
```bash
# Deploy all indexes
firebase deploy --only firestore:indexes

# Deploy specific index
firebase firestore:indexes

# Monitor index build status
firebase firestore:indexes --project your-project-id
```

### **Index Configuration File**
```json
{
  "indexes": [
    {
      "collectionGroup": "leaves",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        {"fieldPath": "schoolId", "order": "ASCENDING"},
        {"fieldPath": "status", "order": "ASCENDING"}, 
        {"fieldPath": "createdAt", "order": "DESCENDING"}
      ]
    }
    // ... all other indexes
  ],
  "fieldOverrides": []
}
```

These optimized indexes will significantly improve query performance and reduce costs by ensuring all dashboard and list queries use efficient composite indexes rather than full collection scans.
