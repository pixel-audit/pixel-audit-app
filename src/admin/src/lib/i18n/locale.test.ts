import { describe, expect, it } from "vitest";

import { resolveLocale } from "@/lib/i18n/locale";

describe("resolveLocale — the browser's languages, most preferred first", () => {
  it("takes the first language the panel speaks, whatever its region", () => {
    expect(resolveLocale(["en-GB", "pl"])).toBe("en");
    expect(resolveLocale(["EN"])).toBe("en");
  });

  it("skips languages it does not speak", () => {
    expect(resolveLocale(["de-DE", "en-US"])).toBe("en");
  });

  it("falls back to English", () => {
    expect(resolveLocale(["de-DE", "fr"])).toBe("en");
    expect(resolveLocale([])).toBe("en");
  });
});
