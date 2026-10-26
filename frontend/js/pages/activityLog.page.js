/**
 * @file Append-Only Activity Log Page Controller
 * Purpose: Allows authorized administrators to inspect sanitized system activity logs without exposing patient PII.
 * SRS Requirements: NFR-AUDIT (Audit Trail Viewer), SEC-4 (Sanitized Activity Log Inspection)
 */

import { initI18n } from '../i18n/i18n.js';
import { apiRequest } from '../api/client.js';

document.addEventListener('DOMContentLoaded', async () => {
  await initI18n();

  try {
    await apiRequest('/reports/activity-log');
  } catch (err) {
    console.error('Failed to load activity logs:', err);
  }
});
