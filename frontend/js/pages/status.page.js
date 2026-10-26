/**
 * @file Public Queue Status Page Controller
 * Purpose: Allows patients to look up their current queue position and dynamic wait time via booking reference.
 * SRS Requirements: FR-2.3 (Wait Time Estimation), REL-3 (Self-service Status Query)
 */

import { initI18n } from '../i18n/i18n.js';
import { apiRequest } from '../api/client.js';
import { qs, on } from '../utils/dom.js';

document.addEventListener('DOMContentLoaded', async () => {
  await initI18n();

  const searchForm = qs('#status-search-form');
  on(searchForm, 'submit', async e => {
    e.preventDefault();
    const ref = qs('#booking-ref-input').value.trim();
    if (!ref) return;

    try {
      await apiRequest(`/public/status/${encodeURIComponent(ref)}`);
    } catch (err) {
      console.error('Failed to query status:', err);
    }
  });
});
