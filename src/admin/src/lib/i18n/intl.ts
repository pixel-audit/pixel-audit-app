import { createIntl, createIntlCache, ReactIntlErrorCode, type IntlShape } from "react-intl";

import en from "@/lib/i18n/compiled/en.json";
import type { Locale } from "@/lib/i18n/locale";

/** Each locale's catalogue, compiled by `npm run i18n:extract` (scripts/i18n.mjs). */
const CATALOGUES: Record<Locale, Record<string, string>> = { en };

const cache = createIntlCache();
const made = new Map<Locale, IntlShape>();

/**
 * The one `intl` of a locale — what `I18nProvider` hands to React, what a
 * leaf module or a test formats with, and what code outside React is given.
 * Created once per locale.
 *
 * A message missing from a catalogue is not an error here: English is the
 * source, and a message not yet translated reads its English
 * `defaultMessage`. `npm run i18n:check` is where a missing translation fails.
 */
export const intlFor = (locale: Locale): IntlShape => {
  const existing = made.get(locale);
  if (existing) return existing;
  const intl = createIntl(
    {
      locale,
      messages: CATALOGUES[locale],
      onError: (error) => {
        if (error.code !== ReactIntlErrorCode.MISSING_TRANSLATION) console.error(error);
      },
    },
    cache,
  );
  made.set(locale, intl);
  return intl;
};
