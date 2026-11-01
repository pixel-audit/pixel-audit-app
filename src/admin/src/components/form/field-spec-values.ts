import type { FieldSpecValues } from "@/components/form/field-spec-fields";

/**
 * The values to send: every key that was typed; on a create also every key
 * whose default the form shows but the user left alone (the API fills the
 * default itself, so these are simply left out).
 */
export function filledValues(values: FieldSpecValues): Record<string, string> {
  return Object.fromEntries(Object.entries(values).filter(([, value]) => value.trim() !== ""));
}
