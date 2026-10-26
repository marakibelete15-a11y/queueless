/**
 * @file Queue Management Routes
 * Purpose: Declares endpoints for live display boards, calling next patients, and marking no-shows.
 * SRS Requirements: FR-2.1 (Queue Board), BR-1 (Priority Ordering), FR-3.1 (No-Show Transitions)
 */

const express = require('express');
const queueController = require('../controllers/queue.controller');
const { requireAuth } = require('../middleware/auth.middleware');
const { requireRoles } = require('../middleware/rbac.middleware');
const { csrfProtection } = require('../middleware/csrf.middleware');
const { validate } = require('../middleware/validate.middleware');
const { validateQueueAction } = require('../validators/queue.validator');
const { ROLES } = require('../config/constants');

const router = express.Router();

// Publicly readable display board
router.get('/board', queueController.getBoard);

// Staff-authenticated queue manipulation
router.post(
  '/call-next',
  requireAuth,
  requireRoles(ROLES.DOCTOR, ROLES.RECEPTIONIST),
  csrfProtection,
  queueController.callNext
);
router.post(
  '/mark-no-show',
  requireAuth,
  requireRoles(ROLES.DOCTOR, ROLES.RECEPTIONIST),
  csrfProtection,
  validate(validateQueueAction),
  queueController.markNoShow
);
router.post(
  '/transfer',
  requireAuth,
  requireRoles(ROLES.DOCTOR, ROLES.RECEPTIONIST),
  csrfProtection,
  validate(validateQueueAction),
  queueController.transfer
);

module.exports = router;
