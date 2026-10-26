/**
 * @file Receptionist Dashboard Controller
 * Purpose: Manages live clinic queue, walk-in patient triage, scheduled check-in, and calling next tokens.
 * SRS Requirements: FR-2.1 (Queue Management), FR-2.2 (Patient Check-in), FR-5.1 (Walk-in Intake)
 */

import { initI18n } from '../i18n/i18n.js';
import { apiRequest } from '../api/client.js';
import { startPolling } from '../utils/polling.js';

document.addEventListener('DOMContentLoaded', async () => {
  await initI18n();

  startPolling(() => apiRequest('/queue/active'), {
    intervalMs: 5000,
    onData: _queue => {
      // Placeholder: Render waiting queue list
    },
    onError: err => console.error('Receptionist queue refresh failed:', err),
  });
});
