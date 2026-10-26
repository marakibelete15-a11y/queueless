/**
 * @file Doctor Consultation Station Controller
 * Purpose: Allows doctors to call their next queued patient, start consultation, and complete visits.
 * SRS Requirements: FR-2.1 (Doctor Call-Next), BR-2 (Consultation Lifecycle Transitions)
 */

import { initI18n } from '../i18n/i18n.js';
import { apiRequest } from '../api/client.js';
import { qs, on } from '../utils/dom.js';

document.addEventListener('DOMContentLoaded', async () => {
  await initI18n();

  const callBtn = qs('#doctor-call-next-btn');
  on(callBtn, 'click', async () => {
    try {
      await apiRequest('/queue/call-next', { method: 'POST', body: {} });
    } catch (err) {
      console.error('Call next patient failed:', err);
    }
  });
});
