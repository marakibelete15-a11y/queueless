/**
 * @file Public Waiting Room Display Page Controller
 * Purpose: Manages large-screen queue board display with adaptive polling for now-serving tokens and doctor rooms.
 * SRS Requirements: FR-2.1 (Queue Display Feed), SYS-PERF (Adaptive Backoff Polling)
 */

import { initI18n } from '../i18n/i18n.js';
import { apiRequest } from '../api/client.js';
import { startPolling } from '../utils/polling.js';

document.addEventListener('DOMContentLoaded', async () => {
  await initI18n();

  startPolling(() => apiRequest('/queue/board'), {
    intervalMs: 5000,
    onData: _data => {
      // Placeholder: Re-render now-serving tokens in the DOM
    },
    onError: err => console.error('Display board update error:', err),
  });
});
