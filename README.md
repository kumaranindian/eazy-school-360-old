# Eazy School 360

A multi-tenant school management system built with Flutter and Firebase.

## Features

- **Multi-Tenant Architecture**: Separate data for each school with tenant isolation
- **Role-Based Access Control**: Super Admin, Tenant Admin, and Teacher roles
- **Teacher Management**: Add, edit, and manage teachers with document uploads
- **Leave Management**: Leave types, requests, approvals, and balances
- **Payroll Management**: Salary structures, payroll generation, and payslip uploads
- **Attendance Tracking**: Daily attendance marking and reports
- **Notifications**: Real-time notifications using Firebase Cloud Messaging
- **Responsive UI**: Works on mobile, tablet, and web platforms
- Each school as a separate tenant
- Role-based access control
- Custom claims for tenant admins and teachers

### Authentication
- Tenant signup flow
- Manual activation by super admin
- Role-based login (Super Admin, Tenant Admin, Teacher)

### Teacher Management
- Complete CRUD operations
- Document management
- Employment type and details

### Leave Management
- Multiple leave types
- Leave application and approval workflow
- Leave balance tracking

### Payroll Management
- Salary structure configuration
- Allowances and deductions
- Monthly payroll generation
- Payslip management

### Attendance Module
- Basic attendance tracking
- Attendance correction requests

## Technical Stack
- Flutter 3+
- Firebase Authentication
- Cloud Firestore
- Firebase Storage
- Firebase Security Rules
- Firebase Cloud Messaging (optional)

## Project Structure
The project follows clean architecture principles with the following layers:
- Presentation (UI)
- Domain (Business Logic)
- Data (Repositories and Data Sources)
- Core (Utilities and Common Components)

## Getting Started

### Prerequisites
- Flutter SDK 3.0+
- Firebase project
- Dart SDK 2.17+

### Setup
1. Clone the repository
2. Run `flutter pub get` to install dependencies
3. Configure Firebase project
4. Run the app using `flutter run`

## License
This project is proprietary and confidential.
