/**
 * @file Internationalization (i18n) Engine
 * Purpose: Client-side locale loader that loads translations and applies localized strings into DOM elements.
 * SRS Requirements: SYS-I18N (Multi-language Support: en, am, om), UI-NO-HARDCODING (Locale-Only Text)
 */

let currentLocale = 'en';
let translations = {};

export async function initI18n(defaultLocale = 'en') {
  currentLocale = localStorage.getItem('ql_locale') || defaultLocale;
  await loadTranslations(currentLocale);
  applyTranslations();
}

export async function setLocale(locale) {
  currentLocale = locale;
  localStorage.setItem('ql_locale', locale);
  await loadTranslations(locale);
  applyTranslations();
}

async function loadTranslations(locale) {
  try {
    const res = await fetch(`/locales/${locale}.json`);
    translations = await res.json();
  } catch (err) {
    console.error(`Failed to load translations for ${locale}:`, err);
  }
}

export function t(keyPath, fallback = '') {
  const parts = keyPath.split('.');
  let current = translations;
  for (const part of parts) {
    if (current && typeof current === 'object' && part in current) {
      current = current[part];
    } else {
      return fallback || keyPath;
    }
  }
  return typeof current === 'string' ? current : fallback || keyPath;
}

export function applyTranslations(rootElement = document) {
  rootElement.querySelectorAll('[data-i18n]').forEach(el => {
    const key = el.getAttribute('data-i18n');
    el.textContent = t(key);
  });
  rootElement.querySelectorAll('[data-i18n-placeholder]').forEach(el => {
    const key = el.getAttribute('data-i18n-placeholder');
    el.setAttribute('placeholder', t(key));
  });
}
