/**
 * @file Staff Authentication Routes
 * Purpose: Declares endpoints for staff login, logout, and credential verification.
 * SRS Requirements: FR-4.1 (Staff Login), SEC-1 (Credential Authentication), SEC-5 (Brute Force Rate Limiting)
 */

const express = require('express');
const authController = require('../controllers/auth.controller');
const { rateLimit } = require('../middleware/rateLimit.middleware');
const { validate } = require('../middleware/validate.middleware');
const { validateLogin } = require('../validators/auth.validator');
const { requireAuth } = require('../middleware/auth.middleware');

const router = express.Router();

router.post(
  '/login',
  rateLimit({ windowMs: 15 * 60 * 1000, max: 10 }),
  validate(validateLogin),
  authController.login
);
router.post('/logout', requireAuth, authController.logout);
router.get('/me', requireAuth, authController.me);

module.exports = router;
