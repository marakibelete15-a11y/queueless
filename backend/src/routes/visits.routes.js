/**
 * @file Visits & Triage Routes
 * Purpose: Declares endpoints for walk-in patient triage, scheduled appointment check-in, and visit completion.
 * SRS Requirements: FR-2.2 (Check-in), FR-5.1 (Walk-in Intake), SEC-2 (Staff RBAC)
 */

const express = require('express');
const visitsController = require('../controllers/visits.controller');
const { requireAuth } = require('../middleware/auth.middleware');
const { requireRoles } = require('../middleware/rbac.middleware');
const { csrfProtection } = require('../middleware/csrf.middleware');
const { validate } = require('../middleware/validate.middleware');
const { validateWalkin } = require('../validators/visit.validator');
const { requireRequestKey } = require('../middleware/requestKey.middleware');
const { ROLES } = require('../config/constants');

const router = express.Router();

router.post(
  '/walkin',
  requireAuth,
  requireRoles(ROLES.RECEPTIONIST, ROLES.ADMIN),
  csrfProtection,
  requireRequestKey,
  validate(validateWalkin),
  visitsController.registerWalkin
);
router.post(
  '/checkin',
  requireAuth,
  requireRoles(ROLES.RECEPTIONIST, ROLES.ADMIN),
  csrfProtection,
  requireRequestKey,
  visitsController.checkin
);
router.patch(
  '/:id/complete',
  requireAuth,
  requireRoles(ROLES.DOCTOR),
  csrfProtection,
  visitsController.completeVisit
);

module.exports = router;
