class AppConstants {
  // App Info
  static const String appName = 'EazySchool 360';
  static const String appTagline = 'Complete School Management';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'A multi-tenant school management system';
  static const String appDeveloper = 'EazySchool 360 Team';
  static const String appWebsite = 'https://eazyschool360.com';
  static const String appSupportEmail = 'support@eazyschool360.com';
  
  // Firebase Collections
  static const String usersCollection = 'users';
  static const String schoolsCollection = 'schools';
  static const String teachersCollection = 'teachers';
  static const String staffCollection = 'staff';
  static const String adminUsersCollection = 'adminUsers';
  static const String staffRolesCollection = 'staffRoles';
  static const String leavesCollection = 'leaves';
  static const String leaveRequestsCollection = 'leaveRequests';
  static const String leaveTypesCollection = 'leaveTypes';
  static const String leaveBalancesCollection = 'leaveBalances';
  static const String permissionSettingsCollection = 'permissionSettings';
  static const String permissionRequestsCollection = 'permissionRequests';
  static const String salaryStructuresCollection = 'salaryStructures';
  static const String payrollCollection = 'payroll';
  static const String attendanceCollection = 'attendance';
  static const String settingsCollection = 'settings';
  static const String notificationsCollection = 'notifications';
  
  // Firebase Storage Paths
  static const String teacherDocumentsPath = 'teacher_documents';
  static const String leaveAttachmentsPath = 'leave_attachments';
  static const String payslipsPath = 'payslips';
  static const String schoolLogosPath = 'school_logos';
  static const String userAvatarsPath = 'user_avatars';
  
  // Custom Claims
  static const String roleClaimKey = 'role';
  static const String schoolIdClaimKey = 'schoolId';
  static const String isActiveClaimKey = 'isActive';
  
  // User Roles
  static const String superAdminRole = 'super_admin';
  static const String tenantAdminRole = 'tenant_admin';
  static const String teacherRole = 'teacher';
  
  // Staff Roles (for staff members, not admins)
  static const String staffRoleTeacher = 'teacher';
  static const String staffRoleNonTeaching = 'non_teaching_staff';
  static const String staffRoleOfficeStaff = 'office_staff';
  
  // Admin Roles (for admin provisioning)
  static const String adminRoleSuperAdmin = 'super_admin';
  static const String adminRoleHrAdmin = 'hr_admin';
  static const String adminRolePayrollAdmin = 'payroll_admin';
  static const String adminRoleAttendanceAdmin = 'attendance_admin';
  static const String adminRoleAcademicAdmin = 'academic_admin';
  static const String adminRoleTenantAdmin = 'tenant_admin';
  
  // Employment Types
  static const String fullTimeEmployment = 'Full-Time';
  static const String partTimeEmployment = 'Part-Time';
  static const String contractEmployment = 'Contract';
  
  // Leave Status
  static const String pendingStatus = 'pending';
  static const String approvedStatus = 'approved';
  static const String rejectedStatus = 'rejected';
  static const String cancelledStatus = 'cancelled';
  
  // Payroll Status
  static const String paidStatus = 'paid';
  static const String unpaidStatus = 'unpaid';
  
  // Shared Preferences Keys
  static const String authTokenKey = 'auth_token';
  static const String userRoleKey = 'user_role';
  static const String schoolIdKey = 'school_id';
  static const String userIdKey = 'user_id';
  static const String userNameKey = 'user_name';
  static const String userEmailKey = 'user_email';
  static const String darkModeKey = 'dark_mode';
  
  // Error Messages
  static const String genericErrorMessage = 'Something went wrong. Please try again.';
  static const String networkErrorMessage = 'Network error. Please check your connection.';
  static const String authErrorMessage = 'Authentication failed. Please check your credentials.';
  static const String permissionErrorMessage = 'You do not have permission to perform this action.';
  static const String schoolInactiveMessage = 'Your school account is pending activation. Please contact support.';
  
  // Success Messages
  static const String loginSuccessMessage = 'Login successful!';
  static const String signupSuccessMessage = 'Signup successful! Please wait for account activation.';
  static const String teacherAddedMessage = 'Teacher added successfully!';
  static const String teacherUpdatedMessage = 'Teacher updated successfully!';
  static const String leaveAppliedMessage = 'Leave applied successfully!';
  static const String leaveApprovedMessage = 'Leave approved successfully!';
  static const String leaveRejectedMessage = 'Leave rejected successfully!';
  static const String payrollGeneratedMessage = 'Payroll generated successfully!';
  static const String payrollUpdatedMessage = 'Payroll updated successfully!';
}
