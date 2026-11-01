import { describe, expect, it } from "vitest";

import { addDays, daysIn, presetOf, presetRange, rangeFromSearch } from "@/lib/date-range";

describe("presetRange — the usual report ranges, relative to today", () => {
  const today = "2026-11-01";

  it("counts back from today, today included", () => {
    expect(presetRange("last7", today)).toEqual({ date_from: "2026-10-26", date_to: "2026-11-01" });
    expect(presetRange("last30", today)).toEqual({
      date_from: "2026-10-03",
      date_to: "2026-11-01",
    });
  });

  it("takes the calendar months", () => {
    expect(presetRange("thisMonth", today)).toEqual({
      date_from: "2026-11-01",
      date_to: "2026-11-01",
    });
    expect(presetRange("previousMonth", today)).toEqual({
      date_from: "2026-10-01",
      date_to: "2026-10-31",
    });
    expect(presetRange("previousMonth", "2026-01-15")).toEqual({
      date_from: "2025-12-01",
      date_to: "2025-12-31",
    });
  });

  it("recognises a range that is a preset", () => {
    expect(presetOf({ date_from: "2026-10-01", date_to: "2026-10-31" }, today)).toBe(
      "previousMonth",
    );
    expect(presetOf({ date_from: "2026-10-02", date_to: "2026-10-31" }, today)).toBeUndefined();
  });
});

describe("the calendar arithmetic", () => {
  it("adds days across month and year ends", () => {
    expect(addDays("2026-12-31", 1)).toBe("2027-01-01");
    expect(addDays("2026-03-01", -1)).toBe("2026-02-28");
  });

  it("counts the days of a closed range", () => {
    expect(daysIn({ date_from: "2026-10-01", date_to: "2026-10-31" })).toBe(31);
    expect(daysIn({ date_from: "2026-10-01", date_to: "2026-10-01" })).toBe(1);
    expect(daysIn({ date_from: "2026-10-02", date_to: "2026-10-01" })).toBe(0);
  });
});

describe("rangeFromSearch — the range the address carries", () => {
  it("reads a valid pair and falls back on anything else", () => {
    expect(rangeFromSearch({ date_from: "2026-10-01", date_to: "2026-10-05" })).toEqual({
      date_from: "2026-10-01",
      date_to: "2026-10-05",
    });
    expect(
      rangeFromSearch({ date_from: "2026-10-05", date_to: "2026-10-01" }, "2026-11-01"),
    ).toEqual(presetRange("last30", "2026-11-01"));
    expect(rangeFromSearch({ date_from: "yesterday" }, "2026-11-01")).toEqual(
      presetRange("last30", "2026-11-01"),
    );
  });
});
