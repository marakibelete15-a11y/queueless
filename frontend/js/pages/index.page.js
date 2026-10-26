/**
 * @file Home Landing Page Controller
 * Purpose: Initializes public portal landing view, navigation links, and active language selector.
 * SRS Requirements: UI-1 (Patient Portal Navigation), SYS-I18N (Locale Switching)
 */

import { initI18n, setLocale } from '../i18n/i18n.js';
import { on, qs } from '../utils/dom.js';

document.addEventListener('DOMContentLoaded', async () => {
  await initI18n();

  const langSelect = qs('#locale-selector');
  on(langSelect, 'change', e => setLocale(e.target.value));
});
