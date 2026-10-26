/**
 * @file Clinic Administration Routes
 * Purpose: Declares endpoints for clinic configuration, doctor roster administration, and outage backfill.
 * SRS Requirements: FR-6.1 (Clinic Configuration), FR-6.2 (Doctor Schedules), FR-5.1 (Outage Backfill), SEC-2 (Admin Only)
 */

const express = require('express');
const adminController = require('../controllers/admin.controller');
const { requireAuth } = require('../middleware/auth.middleware');
const { requireRoles } = require('../middleware/rbac.middleware');
const { csrfProtection } = require('../middleware/csrf.middleware');
const { validate } = require('../middleware/validate.middleware');
const { validateClinicConfig } = require('../validators/admin.validator');
const { ROLES } = require('../config/constants');

const router = express.Router();

router.use(requireAuth);
router.use(requireRoles(ROLES.ADMIN));

router.get('/clinic', adminController.getClinicConfig);
router.put(
  '/clinic',
  csrfProtection,
  validate(validateClinicConfig),
  adminController.updateClinicConfig
);
router.get('/doctors', adminController.listDoctors);
router.post('/doctors', csrfProtection, adminController.createDoctor);
router.post('/backfill', csrfProtection, adminController.submitBackfill);

module.exports = router;
