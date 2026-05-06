# RFID Card Assignment UI Update

## Overview
Updated the RFID Card Management screen to show available (unassigned) RFID cards in a dropdown, making it easier for admins to assign cards to staff for attendance tracking.

## Changes Made

### File Modified:
`lib/presentation/admin/screens/rfid_card_management_screen.dart`

### 1. Added Available Cards List
**New State Variables:**
```dart
List<RfidCard> _availableCards = [];
String? _selectedPrimaryCardUuid;
String? _selectedBackupCardUuid;
```

### 2. Load Available Cards Method
**New Method:** `_loadAvailableCards()`

**Query:**
```dart
.where('isActive', isEqualTo: true)
.where('staffId', isEqualTo: null)
.orderBy('assignedAt', descending: true)
```

**Purpose:** Fetches all active RFID cards that are not assigned to any staff member

### 3. Updated UI

#### Before:
- Manual text input for RFID card UUID
- No visibility of available cards
- Error-prone (typos, wrong UUID)

#### After:
- **Dropdown showing available cards** (if any exist)
- Shows count: "X available card(s)"
- Each card displays: `UUID... (ID: cardId)`
- **Fallback to manual entry** if no available cards
- Card icon prefix for better UX

### 4. UI Components

#### Available Cards Dropdown:
```dart
DropdownButtonFormField<String>(
  decoration: InputDecoration(
    hintText: 'Select Available Card',
    prefixIcon: Icon(Icons.credit_card, color: blue),
  ),
  items: _availableCards.map((card) {
    return DropdownMenuItem(
      value: card.uuid,
      child: Text('${card.uuid.substring(0, 12)}... (ID: ${card.id.substring(0, 8)})'),
    );
  }).toList(),
)
```

#### Available Cards Counter:
```dart
Text('${_availableCards.length} available card(s)')
```

#### Manual Entry Fallback:
```dart
if (_availableCards.isEmpty)
  TextField(
    decoration: InputDecoration(
      hintText: 'Enter RFID Card UUID (No available cards)',
      prefixIcon: Icon(Icons.edit),
    ),
  )
```

### 5. Assignment Logic Update

**Smart Assignment:**
```dart
if (_availableCards.isNotEmpty) {
  // Use selected card from dropdown
  uuidToAssign = cardType == RfidCardType.primary
      ? _selectedPrimaryCardUuid
      : _selectedBackupCardUuid;
} else {
  // Use manual entry
  uuidToAssign = controller.text.trim();
}
```

**Validation:**
- If dropdown mode: Ensures a card is selected
- If manual mode: Ensures UUID is entered
- Shows appropriate error messages

### 6. Auto-Refresh After Actions

**After Assignment:**
```dart
await _loadStaffCards(_selectedStaffId!);
await _loadAvailableCards(); // Refresh available list
```

**After Deactivation:**
```dart
await _loadStaffCards(_selectedStaffId!);
await _loadAvailableCards(); // Card becomes available again
```

## User Experience

### Workflow:

1. **Admin selects staff member**
2. **System shows:**
   - Current assigned cards (if any)
   - Available cards count
   - Dropdown with available cards OR manual entry field

3. **Admin assigns card:**
   - **Option A:** Select from dropdown (if cards available)
   - **Option B:** Enter UUID manually (if no cards available)

4. **Click "Assign Card"**
5. **System:**
   - Assigns card to staff
   - Refreshes both lists
   - Shows success message
   - Card removed from available list

### Benefits:

✅ **Easier Assignment** - Select from list instead of typing UUIDs
✅ **Fewer Errors** - No typos, wrong UUIDs
✅ **Better Visibility** - See all available cards at a glance
✅ **Flexible** - Still allows manual entry when needed
✅ **Auto-Refresh** - Lists update automatically
✅ **User-Friendly** - Clear visual feedback

## Database Query

### Firestore Query:
```javascript
schools/{schoolId}/rfid_cards
  .where('isActive', '==', true)
  .where('staffId', '==', null)
  .orderBy('assignedAt', 'desc')
```

### Index Required:
Already exists from previous deployment:
```json
{
  "collectionGroup": "rfid_cards",
  "fields": [
    { "fieldPath": "isActive", "order": "ASCENDING" },
    { "fieldPath": "staffId", "order": "ASCENDING" },
    { "fieldPath": "assignedAt", "order": "DESCENDING" }
  ]
}
```

**Status:** ✅ Index already deployed

## Testing

### Test Scenarios:

#### 1. With Available Cards
- ✅ Dropdown shows list of cards
- ✅ Counter shows correct count
- ✅ Can select and assign
- ✅ List refreshes after assignment

#### 2. No Available Cards
- ✅ Shows manual entry field
- ✅ Message: "No available cards"
- ✅ Can still enter UUID manually
- ✅ Works as before

#### 3. After Deactivation
- ✅ Deactivated card appears in available list
- ✅ Can be reassigned to same or different staff
- ✅ Lists refresh correctly

## Screenshots

### Before:
```
┌────────────────────────────────┐
│ Primary Card                   │
│ [Enter RFID Card UUID_______]  │
│ [Assign Card]                  │
└────────────────────────────────┘
```

### After (With Available Cards):
```
┌────────────────────────────────┐
│ Primary Card                   │
│ 5 available card(s)            │
│ 💳 [Select Available Card ▼]   │
│    - ABC123DEF456... (ID: 1a2b)│
│    - DEF456GHI789... (ID: 3c4d)│
│    - GHI789JKL012... (ID: 5e6f)│
│ [Assign Card]                  │
└────────────────────────────────┘
```

### After (No Available Cards):
```
┌────────────────────────────────┐
│ Primary Card                   │
│ ✏️ [Enter RFID Card UUID      │
│     (No available cards)___]   │
│ [Assign Card]                  │
└────────────────────────────────┘
```

## Related Features

- **RFID Attendance System** - Uses assigned cards for tracking
- **Staff Management** - Links cards to staff members
- **Card History** - Tracks assignment/deactivation

## Future Enhancements

### Possible Improvements:
1. **Card Details in Dropdown** - Show more info (last used, etc.)
2. **Search/Filter** - For large card lists
3. **Bulk Assignment** - Assign multiple cards at once
4. **Card Status Indicators** - Visual status (new, used, etc.)
5. **Assignment History** - Show previous assignments

## Summary

**The RFID Card Management screen now shows available unassigned cards in a dropdown, making it much easier and faster to assign cards to staff for attendance tracking. The system automatically refreshes the available cards list after assignments and deactivations.**

**No new indexes required - feature is ready to use!** 🎉
