# RFID Implementation Summary

## Overview
Complete RFID attendance system with device registration, card management, and attendance tracking.

## Architecture

### Backend (Firebase Cloud Functions)
All RFID operations use Cloud Functions instead of direct Firestore SDK calls for:
- Security and validation
- Business logic centralization
- Consistent error handling

### Components

#### 1. Device Management
**Endpoint:** `POST /rfidApi/register-device`
- **Auth:** No device key required (initial registration)
- **Purpose:** Register new RFID reader devices
- **Returns:** Device ID and device key (store securely)

#### 2. RFID Card Registration
**Endpoint:** `POST /rfidApi/register-rfid`
- **Auth:** Device key required
- **Purpose:** Register RFID cards (unassigned)
- **Body:** `{ schoolId, rfidTag }`

#### 3. RFID Card Mapping (Admin Only)
**Functions:** Callable Cloud Functions
- `listRfidCards` - List all RFID cards with assignment status
- `mapRfidToStaff` - Map card to staff member
- `mapRfidToStudent` - Map card to student (uses same function with studentId)
- `unmapRfidCard` - Remove card assignment

**Auth:** Firebase Auth (admin role required)

#### 4. Attendance Marking
**Endpoint:** `POST /rfidApi/mark-attendance`
- **Auth:** Device key required
- **Body:** `{ schoolId, rfidTag, timestamp }`
- **Process:**
  1. Validates RFID card exists
  2. Checks card is assigned
  3. Looks up staff/student mapping
  4. Prevents duplicate scans (5-minute window)
  5. Creates attendance record

## Data Flow

```
1. Device Registration (One-time)
   Hardware → register-device → Get device key

2. Card Registration (Per card)
   Hardware → register-rfid → Card registered (unassigned)

3. Card Mapping (Admin UI)
   Admin → listRfidCards → Select card
   Admin → mapRfidToStaff → Card assigned

4. Attendance (Daily)
   Hardware → mark-attendance → Attendance recorded
```

## Firestore Structure

```
schools/{schoolId}/
  ├── devices/{deviceId}
  │   ├── deviceName
  │   ├── deviceKey (hashed)
  │   ├── isActive
  │   └── createdAt
  │
  ├── rfid_cards/{rfidTag}
  │   ├── schoolId
  │   ├── isAssigned
  │   ├── staffId (optional)
  │   ├── studentId (optional)
  │   ├── assignedAt
  │   └── registeredAt
  │
  ├── attendance/{attendanceId}
  │   ├── schoolId
  │   ├── rfidTag
  │   ├── staffId
  │   ├── studentId
  │   ├── deviceId
  │   ├── scannedAt
  │   └── status
  │
  ├── staff/{staffId}
  └── students/{studentId}
```

## Firestore Indexes

All required indexes have been deployed:

### RFID Cards
- `schoolId + isActive + registeredAt`
- `schoolId + isAssigned`
- `schoolId + staffId`
- `schoolId + studentId`

### Devices
- `schoolId + isActive`
- `schoolId + deviceKey`

### Attendance
- `schoolId + rfidTag + scannedAt`
- `schoolId + staffId + scannedAt`
- `schoolId + studentId + scannedAt`
- `rfidTag + scannedAt`

### Student Fee Items (Fixed)
- `isActive + updatedAt + __name__`

## Flutter Implementation

### Repository Pattern
`lib/data/repositories/rfid_repository.dart` uses Cloud Functions:
- `listRfidCards()` - Calls `listRfidCards` function
- `mapRfidToStaff()` - Calls `mapRfidToStaff` function
- `mapRfidToStudent()` - Calls `mapRfidToStaff` function with studentId
- `unmapRfidCard()` - Calls `unmapRfidCard` function

### UI Screen
`lib/presentation/admin/rfid_management_screen.dart`
- Lists all RFID cards
- Shows assignment status
- Allows mapping/unmapping
- Integrated in admin dashboard

### Navigation
Admin Dashboard → Quick Actions → "RFID Cards" (green card icon)

## Security

### Device Authentication
- Device key generated on registration (SHA-256 hash)
- Required for card registration and attendance marking
- Stored securely, never shown again after registration

### Admin Authentication
- Firebase Auth required for mapping functions
- Role check: admin only
- Prevents unauthorized card assignments

### Validation
- All inputs validated
- Duplicate scan prevention (5-minute window)
- Card must be assigned before attendance
- Device must be active

## Testing with Postman

Collection includes all endpoints:
1. **Register Device** - Get device key
2. **Register RFID Card** - Register unassigned card
3. **List RFID Cards** - View all cards (requires auth)
4. **Map to Staff** - Assign card (requires auth)
5. **Map to Student** - Assign card (requires auth)
6. **Unmap Card** - Remove assignment (requires auth)
7. **Mark Attendance** - Record attendance

## Deployment

```bash
# Deploy indexes
firebase deploy --only firestore:indexes

# Deploy functions
firebase deploy --only functions
```

## Error Handling

### Common Errors
- `RFID_NOT_FOUND` - Card not registered
- `RFID_UNASSIGNED` - Card not mapped to person
- `DEVICE_NOT_FOUND` - Invalid device
- `DUPLICATE_SCAN` - Scanned within 5 minutes
- `FORBIDDEN` - Invalid device key
- `permission-denied` - Not admin

### Resolution
1. Register device first
2. Register RFID cards
3. Map cards to staff/students (admin)
4. Mark attendance

## Next Steps

1. ✅ Indexes deployed
2. ✅ Functions deployed
3. ✅ Flutter UI implemented
4. ✅ Admin dashboard integrated
5. 🔄 Hardware integration (ESP32/Arduino)
6. 🔄 Real-time attendance dashboard
7. 🔄 Attendance reports
