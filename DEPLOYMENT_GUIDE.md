# Eazy School 360 - Deployment Guide

## Pre-Application Setup Steps

### 1. Firebase Project Setup

#### Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project" or "Add project"
3. Enter project name: `eazy-school-360`
4. Enable Google Analytics (optional)
5. Create project

#### Enable Authentication
1. In Firebase Console, go to **Authentication** > **Sign-in method**
2. Enable **Email/Password** provider
3. Configure authorized domains if needed

#### Setup Firestore Database
1. Go to **Firestore Database**
2. Click **Create database**
3. Choose **Start in production mode**
4. Select location (choose closest to your users)
5. Create database

#### Configure Security Rules
1. In Firestore Database, go to **Rules** tab
2. Replace default rules with content from `firestore.rules`
3. Publish rules

#### Setup Firebase Storage (Optional)
1. Go to **Storage**
2. Click **Get started**
3. Use default security rules for now
4. Choose same location as Firestore

### 2. Flutter Web Configuration

#### Update Firebase Config
1. In Firebase Console, go to **Project Settings** > **General**
2. Scroll to **Your apps** section
3. Click **Add app** > **Web** (</>) 
4. Register app with nickname: `eazy-school-360-web`
5. Copy the Firebase configuration
6. Update `web/index.html` with your Firebase config:

```html
<script type="module">
  import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.7.0/firebase-app.js';
  import { getAuth } from 'https://www.gstatic.com/firebasejs/10.7.0/firebase-auth.js';
  import { getFirestore } from 'https://www.gstatic.com/firebasejs/10.7.0/firebase-firestore.js';

  const firebaseConfig = {
    apiKey: "your-api-key",
    authDomain: "your-project.firebaseapp.com",
    projectId: "your-project-id",
    storageBucket: "your-project.appspot.com",
    messagingSenderId: "123456789",
    appId: "your-app-id"
  };

  window.firebaseApp = initializeApp(firebaseConfig);
  window.firebaseAuth = getAuth();
  window.firebaseFirestore = getFirestore();
</script>
```

### 3. Cloud Functions Setup (Optional)

#### Install Firebase CLI
```bash
npm install -g firebase-tools
```

#### Initialize Functions
```bash
cd d:/workspace/eazy-school-360
firebase login
firebase init functions
```

#### Deploy Functions
```bash
cd functions
npm install
firebase deploy --only functions
```

### 4. Initial Data Setup

#### Create Super Admin User
1. Run the Flutter app locally
2. Use the signup screen to create first admin account
3. Manually update the user document in Firestore:
   - Set `role: "SUPER_ADMIN"`
   - Set `isActive: true`
   - Set `status: "ACTIVE"`

#### Create Sample School Data
```javascript
// Add to Firestore manually or via script
{
  "schools": {
    "school1": {
      "name": "Demo School",
      "address": "123 School Street",
      "phone": "+1234567890",
      "email": "admin@demoschool.edu",
      "isActive": true,
      "createdAt": "2024-01-01T00:00:00Z"
    }
  }
}
```

## Deployment Steps

### 1. Local Development

#### Prerequisites
- Flutter SDK (3.16.0 or later)
- Dart SDK (3.2.0 or later)
- Chrome browser for web testing

#### Setup
```bash
cd d:/workspace/eazy-school-360
flutter pub get
flutter run -d chrome
```

### 2. Firebase Hosting Deployment

#### Enable Hosting
1. In Firebase Console, go to **Hosting**
2. Click **Get started**
3. Follow setup instructions

#### Build and Deploy
```bash
# Build for web
flutter build web --release

# Initialize Firebase Hosting (if not done)
firebase init hosting

# Configure firebase.json
{
  "hosting": {
    "public": "build/web",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ]
  }
}

# Deploy to Firebase Hosting
firebase deploy --only hosting
```

### 3. Production Environment Setup

#### Environment Configuration
1. Create `.env` files for different environments
2. Configure API endpoints
3. Set up proper error logging
4. Configure analytics (optional)

#### Security Checklist
- ✅ Firestore Security Rules deployed
- ✅ Authentication providers configured
- ✅ CORS settings configured
- ✅ API keys restricted (if applicable)
- ✅ HTTPS enforced
- ✅ Content Security Policy configured

### 4. Domain Configuration (Optional)

#### Custom Domain Setup
1. In Firebase Console, go to **Hosting**
2. Click **Add custom domain**
3. Enter your domain name
4. Follow DNS configuration instructions
5. Wait for SSL certificate provisioning

## Application Architecture

### Role-Based Access Control (RBAC)
- **SUPER_ADMIN**: System-wide access, school management
- **ADMIN**: School-level management, staff oversight
- **STAFF**: Personal data access, leave/permission requests

### Security Features
- ✅ Multi-layer authentication
- ✅ Role-based UI rendering
- ✅ Backend action validation
- ✅ Tenant-scoped data access
- ✅ Audit logging
- ✅ Session management

### Key Components
- **Authentication**: Firebase Auth with custom user profiles
- **Database**: Firestore with security rules
- **Frontend**: Flutter Web with Riverpod state management
- **Backend**: Cloud Functions for business logic
- **Security**: Comprehensive RBAC implementation

## Troubleshooting

### Common Issues

#### 1. Firebase Connection Issues
```bash
# Check Firebase configuration
flutter doctor
firebase projects:list
```

#### 2. Authentication Problems
- Verify Firebase Auth is enabled
- Check authorized domains
- Ensure proper user document structure

#### 3. Permission Errors
- Verify Firestore security rules
- Check user role assignments
- Validate session initialization

#### 4. Build Issues
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter build web --release
```

### Debug Mode
```bash
# Run with debug logging
flutter run -d chrome --debug
```

### Performance Monitoring
- Enable Firebase Performance Monitoring
- Set up error reporting with Crashlytics
- Monitor Firestore usage and costs

## Maintenance

### Regular Tasks
1. **Security Updates**: Keep Flutter and dependencies updated
2. **Backup**: Regular Firestore exports
3. **Monitoring**: Check error logs and performance metrics
4. **User Management**: Review and manage user accounts

### Scaling Considerations
- Firestore read/write limits
- Cloud Functions execution limits
- Firebase Hosting bandwidth
- User authentication limits

## Support

### Documentation
- [Flutter Web Documentation](https://flutter.dev/web)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Firestore Security Rules](https://firebase.google.com/docs/firestore/security/get-started)

### Contact
For technical support or questions about this deployment:
- Review the RBAC documentation in `lib/core/security/rbac_documentation.md`
- Check Firebase Console for error logs
- Verify security rules and user permissions

---

**Note**: This application implements comprehensive Role-Based Access Control (RBAC). Ensure all security configurations are properly set up before deploying to production.
