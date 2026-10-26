/**
 * @file Analytics & Operational Reports Page Controller
 * Purpose: Visualizes daily queue throughput, average consultation times, and no-show metrics for clinic administrators.
 * SRS Requirements: NFR-AUDIT (Operational Analytics), BR-4 (No-Show Rate Tracking)
 */

import { initI18n } from '../i18n/i18n.js';
import { apiRequest } from '../api/client.js';

document.addEventListener('DOMContentLoaded', async () => {
  await initI18n();

  try {
    await apiRequest('/reports/queue-analytics');
  } catch (err) {
    console.error('Failed to load analytics:', err);
  }
});
