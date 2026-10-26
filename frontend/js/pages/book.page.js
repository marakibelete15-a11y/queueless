/**
 * @file Appointment Booking Page Controller
 * Purpose: Handles doctor selection, slot browsing, phone number verification hold, and booking confirmation.
 * SRS Requirements: FR-1.1 (Slot Query), FR-1.2 (Appointment Booking), FR-1.3 (Booking Reference Confirmation)
 */

import { initI18n } from '../i18n/i18n.js';
import { apiRequest } from '../api/client.js';

document.addEventListener('DOMContentLoaded', async () => {
  await initI18n();

  // Placeholder: Fetch active doctors and wire up slot date-picker
  try {
    await apiRequest('/public/doctors');
  } catch (err) {
    console.error('Failed to load doctors:', err);
  }
});
