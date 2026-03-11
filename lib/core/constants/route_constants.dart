class RouteConstants {
  // Auth Routes
  static const String splash = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String verifyEmail = '/verify-email';
  static const String waitingActivation = '/waiting-activation';

  // Dashboard Routes
  static const String adminDashboard = '/admin/dashboard';
  static const String teacherDashboard = '/teacher/dashboard';
  static const String staffDashboard = '/staff/dashboard';
  static const String superAdminDashboard = '/super-admin/dashboard';

  // Staff Routes (for staff members)
  static const String staffProfile = '/staff/profile';
  static const String staffLeave = '/staff/leave';
  static const String staffApplyLeave = '/staff/leave/apply';
  static const String staffLeaveHistory = '/staff/leave/history';
  static const String staffPayslips = '/staff/payslips';
  static const String staffAttendance = '/staff/attendance';

  // Teacher Routes (legacy - redirect to staff)
  static const String teacherProfile = '/teacher/profile';
  static const String teacherLeave = '/teacher/leave';
  static const String teacherPayroll = '/teacher/payroll';
  static const String teacherAttendance = '/teacher/attendance';

  // Admin Routes
  static const String adminProfile = '/admin/profile';
  static const String adminSettings = '/admin/settings';
  static const String teachersList = '/admin/teachers';
  static const String teacherDetails = '/admin/teachers/:id';
  static const String addTeacher = '/admin/teachers/add';
  static const String editTeacher = '/admin/teachers/edit/:id';
  
  // Staff Management Routes
  static const String staffList = '/admin/staff';
  static const String staffDetails = '/admin/staff/:id';
  static const String addStaff = '/admin/staff/add';
  static const String editStaff = '/admin/staff/edit/:id';
  
  // Leave Management Routes
  static const String leaveManagement = '/admin/leave';
  static const String leaveRequests = '/admin/leave/requests';
  static const String leaveTypes = '/admin/leave/types';
  static const String applyLeave = '/admin/leave/apply';
  static const String leaveHistory = '/admin/leave/history';
  static const String leaveDashboard = '/admin/leave/dashboard';
  
  // Admin Provisioning Routes
  static const String adminProvisioning = '/admin/provisioning';
  static const String adminUsers = '/admin/provisioning/users';
  static const String addAdminUser = '/admin/provisioning/add';
  static const String editAdminUser = '/admin/provisioning/edit/:id';
  
  // Payroll Routes
  static const String payrollManagement = '/admin/payroll';
  static const String salaryStructure = '/admin/payroll/salary-structure';
  static const String payrollGeneration = '/admin/payroll/generate';
  static const String payrollHistory = '/admin/payroll/history';
  static const String payslipViewer = '/admin/payroll/payslip';
  static const String generatePayroll = '/admin/payroll/generate';
  
  // Attendance Routes
  static const String attendanceManagement = '/admin/attendance';
  static const String markAttendance = '/admin/attendance/mark';
  static const String attendanceReport = '/admin/attendance/report';
  static const String attendanceCalendar = '/admin/attendance/calendar';
  
  // Settings & Reports
  static const String settings = '/admin/settings';
  static const String reports = '/admin/reports';

  // Super Admin Routes
  static const String superAdminSchools = '/super-admin/schools';
  static const String superAdminSchoolDetails = '/super-admin/schools/:id';
  static const String superAdminSettings = '/super-admin/settings';
}
