/**
 * @file Clinic Administration Page Controller
 * Purpose: Allows clinic administrators to configure operating hours, clinic details, and doctor schedules.
 * SRS Requirements: FR-6.1 (Clinic Configuration), FR-6.2 (Doctor Roster Management)
 */

import { initI18n } from '../i18n/i18n.js';
import { apiRequest } from '../api/client.js';

document.addEventListener('DOMContentLoaded', async () => {
  await initI18n();

  try {
    await apiRequest('/admin/clinic');
  } catch (err) {
    console.error('Failed to load clinic configuration:', err);
  }
});
