/**
 * @file Booking Cancellation Page Controller
 * Purpose: Handles patient self-service appointment cancellation using booking reference and verification code.
 * SRS Requirements: FR-1.5 (Appointment Cancellation), BR-3 (Slot Release)
 */

import { initI18n } from '../i18n/i18n.js';
import { apiRequest } from '../api/client.js';
import { qs, on } from '../utils/dom.js';

document.addEventListener('DOMContentLoaded', async () => {
  await initI18n();

  const cancelForm = qs('#cancel-form');
  on(cancelForm, 'submit', async e => {
    e.preventDefault();
    try {
      await apiRequest('/public/cancel', {
        method: 'POST',
        body: { reference: qs('#ref-input')?.value },
      });
    } catch (err) {
      console.error('Cancellation failed:', err);
    }
  });
});
