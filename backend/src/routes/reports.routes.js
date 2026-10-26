/**
 * @file Reports & Audit Logs Routes
 * Purpose: Declares endpoints for operational throughput reports and sanitized audit activity inspection.
 * SRS Requirements: NFR-AUDIT (Audit Trail View), SEC-2 (Admin & Receptionist Access), SEC-4 (Sanitized Reports)
 */

const express = require('express');
const reportsController = require('../controllers/reports.controller');
const { requireAuth } = require('../middleware/auth.middleware');
const { requireRoles } = require('../middleware/rbac.middleware');
const { ROLES } = require('../config/constants');

const router = express.Router();

router.use(requireAuth);
router.use(requireRoles(ROLES.ADMIN, ROLES.RECEPTIONIST));

router.get('/queue-analytics', reportsController.getQueueAnalytics);
router.get('/activity-log', reportsController.getActivityLog);

module.exports = router;
