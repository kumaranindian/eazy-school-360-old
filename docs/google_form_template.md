# Google Form Template for Teacher Data Collection

## Form Title
**Staff Registration Form - [School Name]**

## Form Description
Please fill out this form to register as a staff member. Your information will be used to create your account in the Eazy School 360 system.

---

## Required Fields

### 1. Full Name *
- Type: Short answer
- Validation: Required
- Example: "John Doe"

### 2. Email Address *
- Type: Short answer
- Validation: Required, Email format
- Example: "john.doe@school.com"
- Note: This will be used for login

### 3. Phone Number *
- Type: Short answer
- Validation: Required, Phone number format
- Example: "+91 9876543210"

### 4. Role/Designation *
- Type: Dropdown
- Options:
  - Teacher
  - Senior Teacher
  - Head of Department
  - Coordinator
  - Librarian
  - Lab Assistant
  - Administrative Staff
  - Other

### 5. Department *
- Type: Dropdown
- Options:
  - Mathematics
  - Science
  - English
  - Social Studies
  - Computer Science
  - Physical Education
  - Arts
  - Music
  - Administration
  - Other

### 6. Date of Joining *
- Type: Date
- Validation: Required

---

## Optional Fields

### 7. Employee ID
- Type: Short answer
- Example: "EMP001"

### 8. Qualification
- Type: Short answer
- Example: "M.Sc., B.Ed."

### 9. Address
- Type: Paragraph
- Example: "123 Main Street, City, State - 123456"

### 10. Emergency Contact
- Type: Short answer
- Example: "+91 9876543211"

### 11. Blood Group
- Type: Dropdown
- Options: A+, A-, B+, B-, AB+, AB-, O+, O-

---

## Google Form Setup Instructions

1. Go to [Google Forms](https://forms.google.com)
2. Create a new form with the above fields
3. Enable "Collect email addresses" in Settings
4. Link the form to a Google Sheet:
   - Click "Responses" tab
   - Click the Google Sheets icon
   - Create a new spreadsheet

---

## Expected Sheet Format

When exporting to CSV/Excel for upload, the sheet should have these columns:

| Column Name | Required | Description |
|-------------|----------|-------------|
| name | Yes | Full name of the staff |
| email | Yes | Email address (used for login) |
| phone | Yes | Phone number |
| role | Yes | Role/Designation |
| department | No | Department name |
| employeeId | No | Employee ID |
| dateOfJoining | No | Date in YYYY-MM-DD format |
| qualification | No | Educational qualification |
| address | No | Full address |
| emergencyContact | No | Emergency contact number |
| bloodGroup | No | Blood group |

---

## Sample CSV Format

```csv
name,email,phone,role,department,employeeId,dateOfJoining
John Doe,john.doe@school.com,+919876543210,Teacher,Mathematics,EMP001,2024-01-15
Jane Smith,jane.smith@school.com,+919876543211,Senior Teacher,Science,EMP002,2023-06-01
```

---

## Notes

1. **Email addresses must be unique** - Each staff member needs a unique email for login
2. **Temporary passwords** will be generated automatically and sent to staff emails
3. Staff can change their password after first login
4. Accounts will be created as **inactive** by default - admin needs to activate them
