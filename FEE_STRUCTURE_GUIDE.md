# Fee Structure Setup Guide

## Important Concept
**One student = One fee structure per academic year**

You CANNOT assign multiple fee structures to the same student. All fees (monthly + yearly) must be in ONE structure.

## How to Add Yearly Fees

### Step 1: Edit Existing Fee Structure
1. Go to **Fee Structures** screen
2. Click on the structure (e.g., "Class I Monthly 2026-27")
3. Click **Edit**

### Step 2: Add Yearly Fee Terms
For each yearly/one-time fee, add a new term:

**Example: Adding Digital Support Fee**
- Click **"Add Term"** button
- Term Name: `Digital Support Fee`
- Category: Select `DIGITAL_SUPPORT_FEES`
- Amount: `700`
- Due Date: `30-Jun-2026` (or any date)
- Click **Save**

**Example: Adding Sports Fee**
- Click **"Add Term"** button
- Term Name: `Sports Fee`  
- Category: Select `SPORTS_FEE`
- Amount: `1000`
- Due Date: `30-Jun-2026`
- Click **Save**

### Step 3: Save Structure
- Click **Save** button
- System will ask: "Assign to students in newly added classes?"
- Click **"Assign now"** or **"Skip"**
- If you skip, manually reassign to update existing students

### Step 4: Verify
1. Go to **Student Fee Management**
2. Select a student
3. All fees should now show with correct amounts

## Example Complete Fee Structure

**Class I Monthly 2026-27**
- Type: MONTHLY
- Academic Year: 2026-27
- Total Terms: 16

| Term # | Term Name | Category | Amount | Due Date |
|--------|-----------|----------|--------|----------|
| 1 | June | TUITION | ₹3,000 | 05-Jun-2026 |
| 2 | July | TUITION | ₹3,000 | 05-Jul-2026 |
| 3 | August | TUITION | ₹3,000 | 05-Aug-2026 |
| ... | ... | TUITION | ₹3,000 | ... |
| 12 | May | TUITION | ₹3,000 | 05-May-2027 |
| 13 | **Exam Fee** | **EXAM** | **₹1,000** | **30-Jun-2026** |
| 14 | **Van Fee** | **VAN** | **₹12,000** | **30-Jun-2026** |
| 15 | **Digital Support** | **DIGITAL_SUPPORT_FEES** | **₹700** | **30-Jun-2026** |
| 16 | **Sports Fee** | **SPORTS_FEE** | **₹1,000** | **30-Jun-2026** |

**Total: ₹49,700**

## Payment Collection
- All fees (monthly + yearly) appear in the payment dialog
- You can collect any fee at any time
- Just enter the amount for that specific term

## Common Mistakes to Avoid
❌ Creating separate fee structures for yearly fees
❌ Trying to assign multiple structures to one student
❌ Not reassigning after editing a structure

✅ Add all fees as terms in ONE structure
✅ Use different categories for different fee types
✅ Reassign structure after editing to update students
