# RFID Card Unmap API

## Overview
Cloud Function endpoint to unmap (unassign) an RFID card from a staff member, setting `staffId` and `staffName` back to `null`.

## Endpoint

**URL:** `POST /unmap-rfid`

**Full URL:** `https://asia-south1-eazyschool-360-dev.cloudfunctions.net/rfidApi/unmap-rfid`

**Authentication:** Requires device key in header

## Request

### Headers
```
Content-Type: application/json
x-device-key: YOUR_DEVICE_KEY
```

### Body
```json
{
  "schoolId": "BQs5pYYblCCD0H72v9JS",
  "rfidTag": "TAG1234567890"
}
```

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `schoolId` | string | Yes | School document ID |
| `rfidTag` | string | Yes | RFID card UUID/tag to unmap |

## Response

### Success Response (200 OK)

```json
{
  "success": true,
  "message": "RFID card unmapped successfully",
  "data": {
    "rfidTag": "TAG1234567890",
    "schoolId": "BQs5pYYblCCD0H72v9JS",
    "previousStaffId": "staff_abc123",
    "previousStaffName": "John Doe",
    "unmappedAt": "2026-05-07T01:05:00.000Z"
  }
}
```

### Error Responses

#### 400 Bad Request - Missing Parameters
```json
{
  "success": false,
  "error": "BAD_REQUEST",
  "message": "schoolId and rfidTag are required"
}
```

#### 400 Bad Request - Already Unassigned
```json
{
  "success": false,
  "error": "ALREADY_UNASSIGNED",
  "message": "RFID card is already unassigned"
}
```

#### 404 Not Found
```json
{
  "success": false,
  "error": "NOT_FOUND",
  "message": "RFID card not found"
}
```

#### 401 Unauthorized
```json
{
  "success": false,
  "error": "UNAUTHORIZED",
  "message": "Invalid or missing device key"
}
```

#### 500 Internal Server Error
```json
{
  "success": false,
  "error": "INTERNAL_ERROR",
  "message": "Failed to unmap RFID card"
}
```

## Firestore Changes

### Before Unmap
```javascript
schools/{schoolId}/rfid_cards/{rfidTag}
{
  uuid: "TAG1234567890",
  staffId: "staff_abc123",
  staffName: "John Doe",
  cardType: "primary",
  isActive: true,
  isAssigned: true,
  assignedAt: Timestamp,
  // ...
}
```

### After Unmap
```javascript
schools/{schoolId}/rfid_cards/{rfidTag}
{
  uuid: "TAG1234567890",
  staffId: null,  // ✅ Set to null
  staffName: null,  // ✅ Set to null
  cardType: "primary",
  isActive: true,
  isAssigned: false,  // ✅ Set to false
  assignedAt: Timestamp,
  unmappedAt: Timestamp,  // ✅ New field
  unmappedBy: "device-id",  // ✅ New field
  metadata: {
    // ... existing metadata
    lastUnmappedDevice: "RFID Reader 1",  // ✅ Added
    lastUnmappedDeviceId: "nmhss-device-1"  // ✅ Added
  }
}
```

## cURL Example

```bash
curl --location 'https://asia-south1-eazyschool-360-dev.cloudfunctions.net/rfidApi/unmap-rfid' \
--header 'Content-Type: application/json' \
--header 'x-device-key: fe0f3b44d1fb9bc6f488f2cdce49b13e03bdb0efcd8401a2367f46b266f33273' \
--data '{
  "schoolId": "BQs5pYYblCCD0H72v9JS",
  "rfidTag": "TAG1234567890"
}'
```

## Postman Example

### Request
```
POST https://asia-south1-eazyschool-360-dev.cloudfunctions.net/rfidApi/unmap-rfid
```

### Headers
```
Content-Type: application/json
x-device-key: fe0f3b44d1fb9bc6f488f2cdce49b13e03bdb0efcd8401a2367f46b266f33273
```

### Body (raw JSON)
```json
{
  "schoolId": "BQs5pYYblCCD0H72v9JS",
  "rfidTag": "TAG1234567890"
}
```

## Use Cases

### 1. Staff Leaving/Transfer
When a staff member leaves or transfers, unmap their RFID card so it can be reassigned to someone else.

```bash
# Unmap card from leaving staff
curl --location 'https://asia-south1-eazyschool-360-dev.cloudfunctions.net/rfidApi/unmap-rfid' \
--header 'x-device-key: YOUR_KEY' \
--header 'Content-Type: application/json' \
--data '{
  "schoolId": "BQs5pYYblCCD0H72v9JS",
  "rfidTag": "STAFF_CARD_001"
}'

# Card is now available for reassignment
```

### 2. Card Replacement
When replacing a damaged or lost card:

```bash
# Unmap old card
curl ... --data '{"schoolId": "...", "rfidTag": "OLD_CARD"}'

# Register new card
curl ... --data '{"schoolId": "...", "rfidTag": "NEW_CARD"}'

# Assign new card to same staff (via Flutter UI)
```

### 3. Card Pool Management
Maintain a pool of available cards:

```bash
# Unmap cards from inactive staff
for tag in CARD1 CARD2 CARD3; do
  curl ... --data "{\"schoolId\": \"...\", \"rfidTag\": \"$tag\"}"
done

# Cards return to available pool
```

## Integration with Flutter

### After Unmapping
The card will automatically appear in the "Available Cards" dropdown in the Flutter app:

```dart
// In RFID Card Management screen
// Card with staffId: null will be filtered as available
_availableCards = cards.where((card) => card.staffId == null).toList();
```

### Workflow
1. **Unmap via API** → Card `staffId` set to `null`
2. **Flutter refreshes** → Card appears in available list
3. **Admin assigns** → Card assigned to new staff

## Security

### Device Key Required
- Only authenticated devices can unmap cards
- Device key must be registered via `/register-device`
- Key is validated on every request

### Audit Trail
- `unmappedAt` timestamp recorded
- `unmappedBy` device ID recorded
- Previous staff info returned in response
- Metadata tracks unmapping device

## Error Handling

### Validation Checks
1. ✅ Required parameters present
2. ✅ Card exists in Firestore
3. ✅ Card is currently assigned
4. ✅ Device key is valid

### Idempotency
- Unmapping an already unmapped card returns error
- Prevents accidental duplicate operations
- Clear error message for debugging

## Logging

### Console Logs
```
🔓 [UNMAP_RFID] Unmapping RFID card from staff
   School: BQs5pYYblCCD0H72v9JS
   RFID Tag: TAG1234567890
   Device: RFID Reader 1 (nmhss-device-1)
```

### Success Log
```javascript
{
  operation: 'UNMAP_RFID',
  rfidTag: 'TAG1234567890',
  schoolId: 'BQs5pYYblCCD0H72v9JS',
  previousStaffId: 'staff_abc123'
}
```

### Error Log
```javascript
{
  operation: 'UNMAP_RFID',
  error: Error,
  body: { schoolId, rfidTag }
}
```

## Testing

### Test Scenario 1: Successful Unmap
```bash
# 1. Verify card is assigned
# Check Firestore: staffId should have value

# 2. Unmap the card
curl ... --data '{"schoolId": "...", "rfidTag": "TEST123"}'

# 3. Verify response
# Should return 200 with previousStaffId

# 4. Check Firestore
# staffId should be null
# isAssigned should be false
# unmappedAt should be set
```

### Test Scenario 2: Already Unassigned
```bash
# 1. Unmap card (first time)
curl ... --data '{"schoolId": "...", "rfidTag": "TEST123"}'
# Returns 200 OK

# 2. Try to unmap again
curl ... --data '{"schoolId": "...", "rfidTag": "TEST123"}'
# Returns 400 ALREADY_UNASSIGNED
```

### Test Scenario 3: Card Not Found
```bash
curl ... --data '{"schoolId": "...", "rfidTag": "NONEXISTENT"}'
# Returns 404 NOT_FOUND
```

## Related Endpoints

### Register RFID Card
`POST /register-rfid` - Register new unassigned card

### Mark Attendance
`POST /mark-attendance` - Record attendance using RFID card

### Register Device
`POST /register-device` - Register device and get device key

## Summary

**Endpoint:** `POST /unmap-rfid`

**Purpose:** Unassign RFID card from staff member

**Authentication:** Device key required

**Result:**
- `staffId` → `null`
- `staffName` → `null`
- `isAssigned` → `false`
- Card becomes available for reassignment

**Use Cases:**
- Staff leaving/transfer
- Card replacement
- Card pool management

**Deployed:** ✅ Available in `eazyschool-360-dev`
