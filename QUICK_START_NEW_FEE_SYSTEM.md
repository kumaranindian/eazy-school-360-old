# Quick Start Guide: New Fee Management System

## What's New?

The new fee management system allows you to:
✅ **Assign fees anytime** - No need to wait for fee structure creation
✅ **Event-based fees** - Sports Day, Annual Day, field trips, etc.
✅ **Flexible assignment** - School-wide, class-wise, section-wise, or individual students
✅ **Category-based tracking** - Better reporting and insights
✅ **Student-specific amounts** - Different students can have different tuition fees

## How to Use

### 1. Create Ad-Hoc Fee Assignment (Event Fees)

**Use Case:** You need to collect ₹500 from all Class I and Class II students for Sports Day.

**Steps:**
1. Navigate to **Finance** → **Ad-Hoc Fee Assignment** (new menu item)
2. Fill in the form:
   - **Assignment Name**: `Sports Day 2026`
   - **Description**: `Annual sports day event fee`
   - **Category**: Select `SPORTS_DAY` (or create new category first)
   - **Amount**: `500`
   - **Due Date**: Select date (e.g., 15-Dec-2026)
   - **Scope**: Select `Class-wise`
   - **Classes**: Check `Class I` and `Class II`
3. Click **Preview** to see how many students will be affected
4. Click **Create Assignment**

**Result:** All students in Class I and II will have a new fee item of ₹500 for Sports Day.

### 2. Create Fee Categories

**Use Case:** You want to add a new fee type like "Lab Fee" or "Computer Fee".

**Steps:**
1. Navigate to **Finance** → **Fee Categories**
2. Click **+ New Category**
3. Fill in:
   - **Code**: `LAB_FEE` (uppercase, no spaces)
   - **Name**: `Lab Fee`
   - **Description**: `Science laboratory usage fee`
   - **Default Amount**: `1000` (optional)
   - **Applicable Classes**: Select classes (or leave empty for all)
4. Click **Save**

**Result:** New category is available for fee assignments.

### 3. View Student Fees (Category-Wise)

**Use Case:** You want to see all fees for a student grouped by category.

**Current Implementation:**
- Go to **Student Fee Management**
- Select student
- You'll see fees grouped by category:
  - **Tuition Fee**: ₹36,000 (Balance: ₹30,000)
  - **Exam Fee**: ₹1,000 (Balance: ₹1,000)
  - **Van Fee**: ₹12,000 (Balance: ₹12,000)
  - **Sports Day**: ₹500 (Balance: ₹500)
  - **Total Balance**: ₹43,500

### 4. Collect Payments

**Current System (Will be updated):**
- Payment dialog shows all outstanding fee items
- You can pay against any category
- Partial payments supported

**Example:**
- Student owes: Tuition ₹3,000, Exam ₹1,000, Sports Day ₹500
- Parent pays ₹2,000
- You can allocate: ₹1,500 to Tuition, ₹500 to Sports Day
- Remaining: Tuition ₹1,500, Exam ₹1,000

## Common Scenarios

### Scenario 1: Annual Day Fee for All Students

```
Assignment Name: Annual Day 2026
Category: ANNUAL_DAY
Amount: ₹300
Scope: School-wide
Due Date: 20-Jan-2027

Result: All students get ₹300 fee item
```

### Scenario 2: Lab Fee for Science Students Only

```
Assignment Name: Lab Fee 2026-27
Category: LAB_FEE
Amount: ₹2000
Scope: Class-wise
Classes: X, XI, XII
Due Date: 30-Jun-2026

Result: Only Class X, XI, XII students get ₹2000 fee item
```

### Scenario 3: Field Trip for Specific Section

```
Assignment Name: Zoo Visit
Category: FIELD_TRIP
Amount: ₹200
Scope: Section-wise
Sections: A, B
Due Date: 15-Nov-2026

Result: Only students in Section A and B get ₹200 fee item
```

## Integration with Existing System

### Fee Structures (Old System)
- Still works for term-based tuition fees
- Will be migrated to fee items in future
- For now, both systems run in parallel

### Fee Categories
- Used by both old and new systems
- Create categories once, use everywhere
- Default amounts help with quick assignment

### Payments
- Payment dialog will be updated to show category-wise fees
- All payments recorded in same payment collection
- Receipts work the same way

## Best Practices

### 1. Use Descriptive Names
❌ Bad: `Fee 1`, `Event`, `Misc`
✅ Good: `Sports Day 2026`, `Annual Day Fee`, `Science Lab Fee Q1`

### 2. Set Realistic Due Dates
- Give parents enough time to pay
- Consider school calendar (exams, holidays)
- Set reminders before due date

### 3. Preview Before Assigning
- Always check the preview
- Verify student count
- Confirm total amount
- Avoid mistakes

### 4. Use Categories Wisely
- Create categories for recurring fees
- Use descriptive category names
- Set default amounts for common fees
- Mark inactive categories when not needed

### 5. Communicate with Parents
- Inform parents about new fees
- Send notifications/SMS
- Provide payment deadlines
- Offer payment plans if needed

## Troubleshooting

### Issue: "No students found matching criteria"
**Solution:** Check that:
- Students exist in selected classes/sections
- Students are active (not graduated/transferred)
- Academic year is correct

### Issue: "Category not found"
**Solution:** 
- Create the category first in Fee Categories screen
- Make sure category is active
- Refresh the page

### Issue: "Permission denied"
**Solution:**
- Check your user role (Admin/Finance)
- Contact super admin if needed
- Firestore rules are deployed

## What's Coming Next

### Phase 3: Enhanced UI
- [ ] Updated payment dialog with category grouping
- [ ] Fee management screen with category filters
- [ ] Better reporting and analytics
- [ ] Bulk payment import

### Phase 4: Migration
- [ ] Migrate existing term-based ledgers to fee items
- [ ] Preserve payment history
- [ ] Handle arrears properly
- [ ] Data validation and cleanup

### Phase 5: Advanced Features
- [ ] Payment plans and installments
- [ ] Auto-reminders for due dates
- [ ] Late fee calculation
- [ ] Discount management
- [ ] Scholarship tracking

## Support

For questions or issues:
1. Check this guide first
2. Review the detailed documentation in `NEW_FEE_SYSTEM_README.md`
3. Contact the development team
4. Report bugs with screenshots and steps to reproduce

## Feedback

We're continuously improving the system. Please share your feedback:
- What works well?
- What's confusing?
- What features are missing?
- How can we make it better?

Your input helps us build a better system for everyone!
