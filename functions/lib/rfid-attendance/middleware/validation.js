/**
 * Validate request body structure and required fields
 */
const validateRequest = (req, res, next) => {
    try {
        // Check if body exists
        if (!req.body || Object.keys(req.body).length === 0) {
            return res.status(400).json({
                success: false,
                error: 'BAD_REQUEST',
                message: 'Request body is required'
            });
        }
        // Validate Content-Type
        if (!req.is('json')) {
            return res.status(400).json({
                success: false,
                error: 'BAD_REQUEST',
                message: 'Content-Type must be application/json'
            });
        }
        next();
    }
    catch (error) {
        console.error('❌ [VALIDATION] Error:', error);
        return res.status(500).json({
            success: false,
            error: 'INTERNAL_ERROR',
            message: 'Validation failed'
        });
    }
};
/**
 * Validate specific fields based on endpoint
 */
const validateFields = (requiredFields) => {
    return (req, res, next) => {
        const missingFields = requiredFields.filter(field => !req.body[field]);
        if (missingFields.length > 0) {
            return res.status(400).json({
                success: false,
                error: 'BAD_REQUEST',
                message: `Missing required fields: ${missingFields.join(', ')}`
            });
        }
        next();
    };
};
module.exports = { validateRequest, validateFields };
//# sourceMappingURL=validation.js.map