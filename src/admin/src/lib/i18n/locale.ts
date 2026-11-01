/**
 * The languages the panel speaks. English is the **source language**: every
 * message's `defaultMessage` in the code is its English copy, and a locale
 * without a translation for a message falls back to it. There is no
 * translation yet: adding one is a locale here, a `messages/<locale>/*.json`
 * directory and the locale's entry in `scripts/i18n.mjs` and `intl.ts`.
 */
export const LOCALES = ["en"] as const;

export type Locale = (typeof LOCALES)[number];

export const DEFAULT_LOCALE: Locale = "en";

const isLocale = (value: string): value is Locale => (LOCALES as readonly string[]).includes(value);

/**
 * The locale for a browser: the first of its preferred languages
 * (`navigator.languages`, most preferred first) whose language subtag the
 * panel speaks — „en-GB" is English — or the default when none is.
 */
export const resolveLocale = (preferred: readonly string[]): Locale => {
  for (const tag of preferred) {
    const language = tag.toLowerCase().split("-")[0] ?? "";
    if (isLocale(language)) return language;
  }
  return DEFAULT_LOCALE;
};
