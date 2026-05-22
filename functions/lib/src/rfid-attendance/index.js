const functions = require('firebase-functions/v1').region('asia-south1');
const admin = require('firebase-admin');
const express = require('express');
const cors = require('cors');

// Initialize if not already done
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

// Import controllers
const { registerRfidCard, unmapRfidCard } = require('./controllers/rfidController');
const { markAttendance } = require('./controllers/attendanceController');
const { registerDevice } = require('./controllers/deviceController');

// Import middleware
const { validateDeviceKey } = require('./middleware/deviceAuth');
const { validateRequest } = require('./middleware/validation');
const { logger } = require('./utils/logger');

// Initialize Express app
const app = express();

// Middleware
app.use(cors({ origin: true }));
app.use(express.json());
app.use(logger);

// Routes
app.post('/register-device', validateRequest, registerDevice);
app.post('/register-rfid', validateRequest, validateDeviceKey, registerRfidCard);
app.post('/unmap-rfid', validateRequest, validateDeviceKey, unmapRfidCard);
app.post('/mark-attendance', validateRequest, validateDeviceKey, markAttendance);

// Export HTTP function
exports.api = functions.https.onRequest(app);

// Export Firestore triggers
const { onAttendanceCreate } = require('./triggers/attendanceTrigger');
exports.onAttendanceCreate = onAttendanceCreate;
