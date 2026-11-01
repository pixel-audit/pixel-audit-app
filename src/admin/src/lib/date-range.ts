import { defineMessages, type IntlShape, type MessageDescriptor } from "react-intl";

/** A closed range of calendar days, as the API takes it: "YYYY-MM-DD" both ends. */
export type DateRange = { date_from: string; date_to: string };

const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;

/** "YYYY-MM-DD" of a UTC calendar day. */
export const isoDate = (date: Date): string => date.toISOString().slice(0, 10);

/** Whether the string is a plausible calendar day. */
export const isIsoDate = (value: unknown): value is string =>
  typeof value === "string" && ISO_DATE.test(value) && !Number.isNaN(Date.parse(value));

/** A calendar day shifted by `days`, in UTC so no timezone moves it. */
export function addDays(date: string, days: number): string {
  const at = new Date(date);
  at.setUTCDate(at.getUTCDate() + days);
  return isoDate(at);
}

/** How many days a closed range holds; 0 when inverted. */
export function daysIn(range: DateRange): number {
  const days =
    Math.round((Date.parse(range.date_to) - Date.parse(range.date_from)) / 86_400_000) + 1;
  return days > 0 ? days : 0;
}

/**
 * The ranges a report is usually looked at over, relative to `today` (a
 * UTC calendar day — the API's days are UTC too).
 */
export type DateRangePreset = "last7" | "last30" | "last90" | "thisMonth" | "previousMonth";

export const DATE_RANGE_PRESETS: readonly DateRangePreset[] = [
  "last7",
  "last30",
  "last90",
  "thisMonth",
  "previousMonth",
];

export function presetRange(
  preset: DateRangePreset,
  today: string = isoDate(new Date()),
): DateRange {
  const at = new Date(today);
  const year = at.getUTCFullYear();
  const month = at.getUTCMonth();
  switch (preset) {
    case "last7":
      return { date_from: addDays(today, -6), date_to: today };
    case "last30":
      return { date_from: addDays(today, -29), date_to: today };
    case "last90":
      return { date_from: addDays(today, -89), date_to: today };
    case "thisMonth":
      return { date_from: isoDate(new Date(Date.UTC(year, month, 1))), date_to: today };
    case "previousMonth":
      return {
        date_from: isoDate(new Date(Date.UTC(year, month - 1, 1))),
        date_to: isoDate(new Date(Date.UTC(year, month, 0))),
      };
  }
}

/** The preset the range is, if it is one — for highlighting the chosen button. */
export function presetOf(range: DateRange, today?: string): DateRangePreset | undefined {
  return DATE_RANGE_PRESETS.find((preset) => {
    const candidate = presetRange(preset, today);
    return candidate.date_from === range.date_from && candidate.date_to === range.date_to;
  });
}

/** The default range of a report: the last 30 days. */
export const defaultRange = (today?: string): DateRange => presetRange("last30", today);

/** The range read from a search object, or the default when it is missing or invalid. */
export function rangeFromSearch(search: Record<string, unknown>, today?: string): DateRange {
  const from = search.date_from;
  const to = search.date_to;
  if (isIsoDate(from) && isIsoDate(to) && from <= to) return { date_from: from, date_to: to };
  return defaultRange(today);
}

/** A calendar date formatted in UTC, so it never shifts by a day in negative-offset timezones. */
export const formatDay = (intl: IntlShape, date: string): string =>
  intl.formatDate(new Date(date), { dateStyle: "medium", timeZone: "UTC" });

/** "1 Oct – 31 Oct 2026". */
export const formatRange = (intl: IntlShape, range: DateRange): string =>
  intl.formatDateTimeRange(new Date(range.date_from), new Date(range.date_to), {
    dateStyle: "medium",
    timeZone: "UTC",
  });

export const presetMessages: Record<DateRangePreset, MessageDescriptor> = defineMessages({
  last7: { id: "dateRange.last7", defaultMessage: "Last 7 days" },
  last30: { id: "dateRange.last30", defaultMessage: "Last 30 days" },
  last90: { id: "dateRange.last90", defaultMessage: "Last 90 days" },
  thisMonth: { id: "dateRange.thisMonth", defaultMessage: "This month" },
  previousMonth: { id: "dateRange.previousMonth", defaultMessage: "Previous month" },
});
