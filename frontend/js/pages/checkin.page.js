/**
 * @file Scheduled Check-in Page Controller
 * Purpose: Allows receptionists to verify arriving scheduled patients, issue queue tokens, and transition status to waiting.
 * SRS Requirements: FR-2.2 (Patient Check-in), BR-2 (Status Transition from Scheduled to Waiting)
 */

import { initI18n } from '../i18n/i18n.js';
import { apiRequest } from '../api/client.js';
import { qs, on } from '../utils/dom.js';

document.addEventListener('DOMContentLoaded', async () => {
  await initI18n();

  const form = qs('#checkin-form');
  on(form, 'submit', async e => {
    e.preventDefault();
    const reference = qs('#checkin-ref-input')?.value;

    try {
      await apiRequest('/visits/checkin', {
        method: 'POST',
        body: { reference },
      });
    } catch (err) {
      console.error('Check-in failed:', err);
    }
  });
});
