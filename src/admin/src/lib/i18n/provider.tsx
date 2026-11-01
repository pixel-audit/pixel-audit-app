import { useEffect, useState, type ReactNode } from "react";
import { RawIntlProvider } from "react-intl";

import { intlFor } from "@/lib/i18n/intl";
import { resolveLocale, type Locale } from "@/lib/i18n/locale";

/**
 * The language of everything on the screen: the browser's preferred language
 * that the panel speaks (`resolveLocale`), decided once at startup. One
 * `intl` per locale (`intlFor`), shared with the code outside React, so a
 * sentence is the same wherever it is formatted. The document's `lang`
 * follows, for the browser's own hyphenation and spell-checking.
 */
export function I18nProvider({ children }: { children: ReactNode }) {
  const [locale] = useState<Locale>(() => resolveLocale(navigator.languages));
  useEffect(() => {
    document.documentElement.lang = locale;
  }, [locale]);
  return <RawIntlProvider value={intlFor(locale)}>{children}</RawIntlProvider>;
}
