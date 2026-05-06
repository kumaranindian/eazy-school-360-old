# Firestore Indexes Reference

## Recently Added Indexes (May 2026)

### RFID Card Management Indexes

#### 1. RFID Cards by Active Status and Staff
**Purpose:** Query RFID cards filtered by active status and staff, sorted by assignment date
**Use Case:** RFID card management screen, card listings

```json
{
  "collectionGroup": "rfid_cards",
  "fields": [
    { "fieldPath": "isActive", "order": "ASCENDING" },
    { "fieldPath": "staffId", "order": "ASCENDING" },
    { "fieldPath": "assignedAt", "order": "DESCENDING" },
    { "fieldPath": "__name__", "order": "DESCENDING" }
  ]
}
```

**Query Example:**
```javascript
db.collection('schools').doc(schoolId)
  .collection('rfid_cards')
  .where('isActive', '==', true)
  .orderBy('assignedAt', 'desc')
  .get();
```

#### 2. Available RFID Cards (Unassigned)
**Purpose:** Query available RFID cards (not assigned to any staff)
**Use Case:** RFID card assignment dropdown, showing available cards

```json
{
  "collectionGroup": "rfid_cards",
  "fields": [
    { "fieldPath": "isActive", "order": "ASCENDING" },
    { "fieldPath": "assignedAt", "order": "DESCENDING" }
  ]
}
```

**Query Example:**
```javascript
db.collection('schools').doc(schoolId)
  .collection('rfid_cards')
  .where('isActive', '==', true)
  .orderBy('assignedAt', 'desc')
  .get();
// Then filter client-side for staffId.isEmpty
```

#### 3. RFID Cards by Staff and Active Status
**Purpose:** Query RFID cards assigned to a specific staff member filtered by active status
**Use Case:** Check if staff already has an active card before assigning new one

```json
{
  "collectionGroup": "rfid_cards",
  "fields": [
    { "fieldPath": "staffId", "order": "ASCENDING" },
    { "fieldPath": "isActive", "order": "ASCENDING" }
  ]
}
```

**Query Example:**
```javascript
db.collection('schools').doc(schoolId)
  .collection('rfid_cards')
  .where('staffId', '==', staffId)
  .where('isActive', '==', true)
  .get();
```

#### 4. RFID Cards by Staff Ordered by Assignment Date
**Purpose:** Get all cards for a staff member ordered by when they were assigned
**Use Case:** Card history, viewing staff's cards chronologically

```json
{
  "collectionGroup": "rfid_cards",
  "fields": [
    { "fieldPath": "staffId", "order": "ASCENDING" },
    { "fieldPath": "assignedAt", "order": "DESCENDING" }
  ]
}
```

**Query Example:**
```javascript
db.collection('schools').doc(schoolId)
  .collection('rfid_cards')
  .where('staffId', '==', staffId)
  .orderBy('assignedAt', 'desc')
  .get();
```

### Staff Management Indexes

#### 1. Staff by School and Assigned Class
**Purpose:** Query staff by school and their assigned class
**Use Case:** Admin viewing staff assignments, class teacher lookups

```json
{
  "collectionGroup": "staff",
  "fields": [
    { "fieldPath": "schoolId", "order": "ASCENDING" },
    { "fieldPath": "assignedClass", "order": "ASCENDING" }
  ]
}
```

**Query Example:**
```javascript
db.collection('schools').doc(schoolId)
  .collection('staff')
  .where('schoolId', '==', schoolId)
  .where('assignedClass', '==', 'X')
  .get();
```

#### 2. Staff by Status and Name
**Purpose:** Query staff by status, sorted by name
**Use Case:** RFID card management, staff directory listings

```json
{
  "collectionGroup": "staff",
  "fields": [
    { "fieldPath": "status", "order": "ASCENDING" },
    { "fieldPath": "name", "order": "ASCENDING" },
    { "fieldPath": "__name__", "order": "ASCENDING" }
  ]
}
```

**Query Example:**
```javascript
db.collection('schools').doc(schoolId)
  .collection('staff')
  .where('status', '==', 'ACTIVE')
  .orderBy('name')
  .get();
```

### Student Management Indexes

#### 3. Students by Status and Class
**Purpose:** Query students by status and class
**Use Case:** Staff viewing their assigned class students, class-wise reports

```json
{
  "collectionGroup": "students",
  "fields": [
    { "fieldPath": "status", "order": "ASCENDING" },
    { "fieldPath": "className", "order": "ASCENDING" }
  ]
}
```

**Query Example:**
```javascript
db.collection('schools').doc(schoolId)
  .collection('students')
  .where('status', '==', 'ACTIVE')
  .where('className', '==', 'X')
  .get();
```

## Deployment Status

| Environment | Status | Date Deployed |
|-------------|--------|---------------|
| DEV | ✅ Deployed | May 7, 2026 |
| TEST | ⏳ Pending | - |
| UAT | ⏳ Pending | - |
| PROD | ⏳ Pending | - |

## Deployment Commands

### Deploy to All Environments

```bash
# DEV (Already deployed)
firebase deploy --only firestore:indexes --project eazyschool-360-dev

# TEST
firebase deploy --only firestore:indexes --project eazyschool-360-test

# UAT
firebase deploy --only firestore:indexes --project eazyschool-360-uat

# PROD
firebase deploy --only firestore:indexes --project eazy-school-360
```

### Deploy Using Scripts

```bash
# PowerShell (Windows)
.\scripts\deploy-indexes-all-env.ps1

# Batch (Windows)
.\scripts\deploy-indexes.bat
```

## Index File Location

**Correct Location:** `firebase/firestore.indexes.json`

**Note:** The `firebase.json` file points to this location:
```json
{
  "firestore": {
    "rules": "firebase/firestore.rules",
    "indexes": "firebase/firestore.indexes.json"
  }
}
```

## Related Features

### Staff Payment Due Notifications
- Uses: Staff by status+name, Students by status+className
- File: `lib/presentation/staff/screens/staff_student_ledger_screen.dart`
- Documentation: `docs/STAFF_PAYMENT_DUE_FEATURE.md`

### Admin Student Ledgers
- Uses: Students by status+className
- File: `lib/presentation/admin/screens/student_directory_with_ledger_screen.dart`
- Documentation: `docs/STUDENT_LEDGER_ADMIN_FEATURE.md`

### RFID Card Management
- Uses: Staff by status+name
- File: `lib/presentation/admin/rfid_management_screen.dart`
- Documentation: `docs/RFID_ATTENDANCE_SYSTEM.md`

## Troubleshooting

### Error: "The query requires an index"

**Solution:**
1. Copy the index URL from the error message
2. Click the link to auto-create in Firebase Console
3. OR manually add to `firebase/firestore.indexes.json`
4. Deploy using: `firebase deploy --only firestore:indexes`

### Error: "Index already exists"

**Solution:**
- Index is already deployed
- Check Firebase Console → Firestore → Indexes
- Wait for index to finish building (status: Building → Enabled)

### Error: "Failed to deploy indexes"

**Solution:**
1. Check `firebase/firestore.indexes.json` syntax (valid JSON)
2. Verify Firebase CLI is logged in: `firebase login`
3. Check project alias: `firebase use eazyschool-360-dev`
4. Retry deployment

## Index Building Time

| Collection Size | Estimated Time |
|-----------------|----------------|
| < 100 docs | Instant |
| 100-1000 docs | 1-2 minutes |
| 1000-10000 docs | 5-10 minutes |
| > 10000 docs | 15-30 minutes |

**Note:** Indexes build in the background. Your app will work once building is complete.

## Monitoring Indexes

### Check Index Status

**Firebase Console:**
1. Go to: https://console.firebase.google.com/project/eazyschool-360-dev/firestore/indexes
2. View all indexes and their status
3. Check for "Building" or "Enabled" status

**Firebase CLI:**
```bash
firebase firestore:indexes --project eazyschool-360-dev
```

## Best Practices

### 1. Always Test in DEV First
- Deploy to DEV environment first
- Test queries thoroughly
- Then deploy to TEST → UAT → PROD

### 2. Document New Indexes
- Add to this reference document
- Include use case and query example
- Link to related features

### 3. Clean Up Unused Indexes
- Review indexes periodically
- Remove indexes for deprecated features
- Keep `firestore.indexes.json` organized

### 4. Use Composite Indexes Wisely
- Only create when needed
- Single-field indexes are auto-created
- Composite indexes need manual creation

## Common Query Patterns

### Pattern 1: Filter + Sort
```javascript
// Requires composite index
.where('status', '==', 'ACTIVE')
.orderBy('name')
```

### Pattern 2: Multiple Filters
```javascript
// Requires composite index
.where('status', '==', 'ACTIVE')
.where('className', '==', 'X')
```

### Pattern 3: Filter + Sort + Pagination
```javascript
// Requires composite index with __name__
.where('status', '==', 'ACTIVE')
.orderBy('name')
.orderBy('__name__')
.startAfter(lastDoc)
.limit(20)
```

## Index Costs

**Note:** Firestore indexes consume storage and have associated costs.

- **Storage:** Each index entry = ~1KB
- **Writes:** Each document write updates all indexes
- **Reads:** Queries use indexes (no extra cost)

**Optimization Tips:**
- Avoid over-indexing
- Use collection group queries sparingly
- Consider denormalization for frequently accessed data

## Support

For index-related issues:
1. Check this reference document
2. Review Firebase Console for index status
3. Check deployment logs
4. Contact Firebase support if needed

## Change Log

| Date | Change | Author |
|------|--------|--------|
| May 7, 2026 | Added staff and student indexes for payment notifications | System |
| Previous | RFID attendance indexes | System |
| Previous | Initial indexes setup | System |
