import type { MessageDescriptor } from "react-intl";

import type { Copy } from "@/lib/i18n/copy";
import { describeErrorDetail } from "@/lib/refusals";

/** The body of the 200 member of an orval status-tagged response union. */
export type OkData<R> = R extends { status: 200; data: infer D } ? D : never;

/**
 * Narrows an orval response to its 200 body, or null for any other status
 * (or no response yet). The generated unions are discriminated on `status`,
 * but TypeScript can't narrow a generic union — hence the one cast here
 * instead of one in every caller.
 */
export function okData<R extends { status: number }>(response: R | undefined): OkData<R> | null {
  if (response === undefined || response.status !== 200) return null;
  return (response as unknown as { data: OkData<R> }).data;
}

/**
 * The machine-readable `errors.detail` of an error body — the atom the API's
 * fallback controller sends (`stale_calendar`, `invalid_transition`) — or
 * null when the body has none.
 */
export function errorDetail(response: { data: unknown } | null | undefined): string | null {
  const data = response?.data;
  if (typeof data !== "object" || data === null || !("errors" in data)) return null;
  const errors = data.errors;
  if (typeof errors !== "object" || errors === null || !("detail" in errors)) return null;
  return typeof errors.detail === "string" ? errors.detail : null;
}

/**
 * A refusal in plain words: the API's `detail` when it sent one (worded for
 * `subject` — the message for "plan", "price list"), else the fallback. A
 * `Copy`: the screen that shows it formats it (`formatCopy`).
 */
export function refusal(
  result: { data: unknown } | null | undefined,
  fallback: Copy,
  subject?: MessageDescriptor,
): Copy {
  const detail = errorDetail(result);
  return detail ? describeErrorDetail(detail, subject) : fallback;
}

/** Collects changeset messages under dotted paths; false on anything that isn't one. */
function flattenErrors(value: unknown, path: string, out: Record<string, string[]>): boolean {
  if (Array.isArray(value)) {
    if (value.every((v) => typeof v === "string")) {
      if (path === "") return false;
      out[path] = value;
      return true;
    }
    return value.every((v, i) => flattenErrors(v, path === "" ? String(i) : `${path}.${i}`, out));
  }
  if (typeof value !== "object" || value === null) return false;
  return Object.entries(value).every(([key, v]) =>
    flattenErrors(v, path === "" ? key : `${path}.${key}`, out),
  );
}

/**
 * The per-field messages of a 422 changeset error (`ValidationErrors`), or
 * null when the body is something else — e.g. an `Error` with a `detail`.
 * Nested changesets are flattened to dotted paths: `covers: {from: [...]}`
 * becomes `covers.from`, a list entry `rules: [{}, {rrule: [...]}]` becomes
 * `rules.1.rrule`.
 */
export function fieldErrors(
  response: { status: number; data: unknown } | null | undefined,
): Record<string, string[]> | null {
  if (response?.status !== 422) return null;
  const data = response.data;
  if (typeof data !== "object" || data === null || !("errors" in data)) return null;
  const out: Record<string, string[]> = {};
  if (!flattenErrors(data.errors, "", out)) return null;
  return Object.keys(out).length > 0 ? out : null;
}

/**
 * The messages for one form field, gathered from every key the API may file
 * them under — its own, the nested path, the range it belongs to:
 * `errorsFor(errors, "from", "covers", "covers.from")`. Undefined when none.
 */
export function errorsFor(
  errors: Record<string, string[]>,
  ...keys: string[]
): string[] | undefined {
  const messages = keys.flatMap((key) => errors[key] ?? []);
  return messages.length > 0 ? messages : undefined;
}
