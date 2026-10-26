/**
 * @file Schema Validation Middleware
 * Purpose: Validates incoming request parameters and body payloads against declared validator rules.
 * SRS Requirements: SEC-7 (Input Sanitization & Validation), REL-1 (Request Integrity)
 */

function validate(validatorFn) {
  return (req, res, next) => {
    const { error, value } = validatorFn(req.body, req.params, req.query);
    if (error) {
      return res.status(400).json({
        success: false,
        error: { code: 'VALIDATION_ERROR', message: error.message || 'Invalid request payload' },
        timestamp: new Date().toISOString(),
      });
    }
    req.validated = value;
    next();
  };
}

module.exports = { validate };
