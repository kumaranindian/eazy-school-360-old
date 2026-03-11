const admin = require('firebase-admin');
const functions = require('firebase-functions');

/**
 * Backend Authorization Service
 * Enforces role-based access control for all Cloud Functions
 */
class BackendAuthorization {
  
  /**
   * Role definitions matching frontend
   */
  static ROLES = {
    SUPER_ADMIN: 'SUPER_ADMIN',
    ADMIN: 'ADMIN', 
    STAFF: 'STAFF'
  };

  /**
   * Backend action permissions by role
   */
  static ROLE_PERMISSIONS = {
    [this.ROLES.SUPER_ADMIN]: new Set([
      // School Management
      'createSchool', 'updateSchool', 'deleteSchool', 'viewAllSchools',
      // User Management  
      'assignAdmin', 'revokeAdmin', 'viewAllUsers', 'activateUser', 'deactivateUser',
      // System Operations
      'viewSystemMetrics', 'configureSystemSettings', 'viewAuditLogs', 'exportSystemData'
    ]),
    
    [this.ROLES.ADMIN]: new Set([
      // Staff Management (Own School Only)
      'createStaff', 'updateStaff', 'viewSchoolStaff', 'activateStaff', 'deactivateStaff',
      // Leave Management
      'approveLeave', 'rejectLeave', 'viewLeaveRequests', 'configureLeaveTypes', 'viewLeaveReports',
      // Permission Management
      'approvePermission', 'rejectPermission', 'viewPermissionRequests', 'configurePermissionTypes',
      // School Configuration
      'configureHolidays', 'configureWeekends', 'viewSchoolReports', 'exportSchoolData'
    ]),
    
    [this.ROLES.STAFF]: new Set([
      // Leave Operations
      'applyLeave', 'cancelOwnLeave', 'viewOwnLeaves',
      // Permission Operations  
      'applyPermission', 'cancelOwnPermission', 'viewOwnPermissions',
      // Profile Operations
      'viewOwnProfile', 'updateOwnProfile', 'viewOwnBalance', 'viewOwnHistory'
    ])
  };

  /**
   * Validate user authentication and authorization
   */
  static async validateRequest(context, requiredAction, options = {}) {
    try {
      // Check authentication
      if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
      }

      const uid = context.auth.uid;
      
      // Fetch user data from Firestore
      const userDoc = await admin.firestore().collection('users').doc(uid).get();
      
      if (!userDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'User profile not found');
      }

      const userData = userDoc.data();
      
      // Validate user is active
      if (userData.status !== 'ACTIVE') {
        throw new functions.https.HttpsError('permission-denied', 'User account is not active');
      }

      // Validate role permissions
      const userRole = userData.role;
      if (!this.canPerformAction(userRole, requiredAction)) {
        await this.logSecurityViolation(uid, requiredAction, 'Insufficient permissions', {
          userRole,
          requiredAction,
          timestamp: admin.firestore.FieldValue.serverTimestamp()
        });
        
        throw new functions.https.HttpsError(
          'permission-denied', 
          `Role ${userRole} cannot perform action ${requiredAction}`
        );
      }

      // Validate school access if required
      if (options.targetSchoolId && !this.canAccessSchool(userRole, userData.schoolId, options.targetSchoolId)) {
        await this.logSecurityViolation(uid, requiredAction, 'School access denied', {
          userSchoolId: userData.schoolId,
          targetSchoolId: options.targetSchoolId,
          timestamp: admin.firestore.FieldValue.serverTimestamp()
        });
        
        throw new functions.https.HttpsError(
          'permission-denied', 
          'Cannot access data for specified school'
        );
      }

      // Validate user data access if required
      if (options.targetUserId && !this.canAccessUserData(userRole, uid, options.targetUserId)) {
        await this.logSecurityViolation(uid, requiredAction, 'User data access denied', {
          targetUserId: options.targetUserId,
          timestamp: admin.firestore.FieldValue.serverTimestamp()
        });
        
        throw new functions.https.HttpsError(
          'permission-denied', 
          'Cannot access data for specified user'
        );
      }

      // Return validated user context
      return {
        uid,
        role: userRole,
        schoolId: userData.schoolId,
        email: userData.email,
        displayName: userData.displayName
      };

    } catch (error) {
      console.error('Authorization validation failed:', error);
      
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      
      throw new functions.https.HttpsError('internal', 'Authorization validation failed');
    }
  }

  /**
   * Check if role can perform action
   */
  static canPerformAction(role, action) {
    const permissions = this.ROLE_PERMISSIONS[role];
    return permissions ? permissions.has(action) : false;
  }

  /**
   * Check if role can access school data
   */
  static canAccessSchool(userRole, userSchoolId, targetSchoolId) {
    switch (userRole) {
      case this.ROLES.SUPER_ADMIN:
        // Super admin can access any school
        return true;
      case this.ROLES.ADMIN:
      case this.ROLES.STAFF:
        // Admin and Staff can only access their own school
        return userSchoolId === targetSchoolId;
      default:
        return false;
    }
  }

  /**
   * Check if role can access user data
   */
  static canAccessUserData(userRole, currentUserId, targetUserId) {
    switch (userRole) {
      case this.ROLES.SUPER_ADMIN:
        // Super admin can access any user data
        return true;
      case this.ROLES.ADMIN:
        // Admin can access staff data in their school (handled by school scoping)
        return true;
      case this.ROLES.STAFF:
        // Staff can only access their own data
        return currentUserId === targetUserId;
      default:
        return false;
    }
  }

  /**
   * Create tenant-safe query constraints
   */
  static createTenantSafeQuery(userRole, userSchoolId, collection) {
    const db = admin.firestore();
    let query = db.collection(collection);

    switch (userRole) {
      case this.ROLES.SUPER_ADMIN:
        // Super admin can query all data
        return query;
      
      case this.ROLES.ADMIN:
      case this.ROLES.STAFF:
        // Admin and Staff queries must be scoped to their school
        if (!userSchoolId) {
          throw new functions.https.HttpsError('permission-denied', 'User has no school association');
        }
        return query.where('schoolId', '==', userSchoolId);
      
      default:
        throw new functions.https.HttpsError('permission-denied', 'Invalid user role');
    }
  }

  /**
   * Create user-scoped query for staff
   */
  static createUserScopedQuery(userRole, userId, collection, userSchoolId) {
    const db = admin.firestore();
    let query = db.collection(collection);

    switch (userRole) {
      case this.ROLES.SUPER_ADMIN:
        // Super admin can query all data
        return query;
      
      case this.ROLES.ADMIN:
        // Admin can query all data in their school
        if (!userSchoolId) {
          throw new functions.https.HttpsError('permission-denied', 'Admin has no school association');
        }
        return query.where('schoolId', '==', userSchoolId);
      
      case this.ROLES.STAFF:
        // Staff can only query their own data
        return query
          .where('schoolId', '==', userSchoolId)
          .where('applicantId', '==', userId);
      
      default:
        throw new functions.https.HttpsError('permission-denied', 'Invalid user role');
    }
  }

  /**
   * Log security violations to audit trail
   */
  static async logSecurityViolation(uid, action, reason, metadata = {}) {
    try {
      await admin.firestore().collection('securityAuditLogs').add({
        uid,
        action,
        reason,
        metadata,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        severity: 'HIGH',
        type: 'AUTHORIZATION_VIOLATION'
      });
    } catch (error) {
      console.error('Failed to log security violation:', error);
    }
  }

  /**
   * Create audit log entry for successful actions
   */
  static async logSuccessfulAction(uid, action, targetResource, metadata = {}) {
    try {
      await admin.firestore().collection('auditLogs').add({
        uid,
        action,
        targetResource,
        metadata,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        type: 'ACTION_SUCCESS'
      });
    } catch (error) {
      console.error('Failed to log successful action:', error);
    }
  }

  /**
   * Validate data modification permissions
   */
  static validateDataModification(userRole, userSchoolId, targetData) {
    // Ensure data being modified belongs to user's school
    if (userRole !== this.ROLES.SUPER_ADMIN) {
      if (!targetData.schoolId || targetData.schoolId !== userSchoolId) {
        throw new functions.https.HttpsError(
          'permission-denied', 
          'Cannot modify data outside of user school'
        );
      }
    }

    // Additional validation can be added here
    return true;
  }

  /**
   * Create authorization middleware for Cloud Functions
   */
  static createAuthMiddleware(requiredAction, options = {}) {
    return async (data, context) => {
      const userContext = await this.validateRequest(context, requiredAction, {
        targetSchoolId: options.extractSchoolId ? options.extractSchoolId(data) : null,
        targetUserId: options.extractUserId ? options.extractUserId(data) : null,
        ...options
      });

      // Log successful authorization
      await this.logSuccessfulAction(
        userContext.uid, 
        requiredAction, 
        options.resourceType || 'unknown',
        { data: options.logData ? data : 'redacted' }
      );

      return userContext;
    };
  }
}

module.exports = BackendAuthorization;
