/**
 * @file Walk-in Registration Page Controller
 * Purpose: Allows reception staff to quickly ingest unscheduled walk-in patients into the queue with priority tagging.
 * SRS Requirements: FR-5.1 (Walk-in Intake), BR-1 (Priority Matrix), FR-2.1 (Queue Entry Creation)
 */

import { initI18n } from '../i18n/i18n.js';
import { apiRequest } from '../api/client.js';
import { qs, on } from '../utils/dom.js';

document.addEventListener('DOMContentLoaded', async () => {
  await initI18n();

  const form = qs('#walkin-registration-form');
  on(form, 'submit', async e => {
    e.preventDefault();
    const doctorId = qs('#walkin-doctor-select')?.value;
    const priority = qs('#walkin-priority-select')?.value;

    try {
      await apiRequest('/visits/walkin', {
        method: 'POST',
        body: { doctorId, priority },
      });
    } catch (err) {
      console.error('Walk-in intake error:', err);
    }
  });
});
