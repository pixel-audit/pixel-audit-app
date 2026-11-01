import { describe, expect, it } from "vitest";

import { intlFor } from "@/lib/i18n/intl";

describe("intlFor — one intl per locale", () => {
  it("is the same object on every call", () => {
    expect(intlFor("en")).toBe(intlFor("en"));
  });

  it("formats a message from the compiled English catalogue", () => {
    expect(intlFor("en").formatMessage({ id: "common.cancel", defaultMessage: "Cancel" })).toBe(
      "Cancel",
    );
  });
});
