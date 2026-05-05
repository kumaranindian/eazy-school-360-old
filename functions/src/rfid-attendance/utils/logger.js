/**
 * Logger middleware for API calls
 * Logs request details with schoolId, deviceId, uid
 */
const logger = (req, res, next) => {
  const startTime = Date.now();
  const { schoolId, deviceId, uid } = req.body;
  const method = req.method;
  const path = req.path;

  console.log('📡 [API_REQUEST] ==================================');
  console.log(`📍 Path: ${method} ${path}`);
  console.log(`🏫 School: ${schoolId || 'N/A'}`);
  console.log(`🔌 Device: ${deviceId || 'N/A'}`);
  console.log(`🆔 UID: ${uid || 'N/A'}`);
  console.log(`⏰ Timestamp: ${new Date().toISOString()}`);
  console.log('==============================================');

  // Log response when finished
  const originalSend = res.send;
  res.send = function (data) {
    const duration = Date.now() - startTime;
    console.log(`✅ [API_RESPONSE] ${method} ${path} - ${res.statusCode} (${duration}ms)`);
    console.log('==============================================');
    originalSend.call(this, data);
  };

  next();
};

/**
 * Log error with context
 */
const logError = (context, error, additionalInfo = {}) => {
  console.error(`❌ [ERROR] ${context}`);
  console.error('   Error:', error.message);
  if (error.stack) {
    console.error('   Stack:', error.stack);
  }
  if (Object.keys(additionalInfo).length > 0) {
    console.error('   Context:', additionalInfo);
  }
};

/**
 * Log success with context
 */
const logSuccess = (context, data = {}) => {
  console.log(`✅ [SUCCESS] ${context}`);
  if (Object.keys(data).length > 0) {
    console.log('   Data:', data);
  }
};

/**
 * Log warning with context
 */
const logWarning = (context, message) => {
  console.warn(`⚠️  [WARNING] ${context}: ${message}`);
};

module.exports = { logger, logError, logSuccess, logWarning };
