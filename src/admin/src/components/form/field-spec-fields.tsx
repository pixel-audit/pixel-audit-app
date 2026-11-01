import { useIntl } from "react-intl";

import type { FieldSpec } from "@/api/generated/model";
import { errorsFor } from "@/components/crud/api-response";
import { FormField } from "@/components/form/field";
import { Input } from "@/components/ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { commonMessages } from "@/lib/i18n/common-messages";

/** The values of a declared field set, by key; a key left out is "unchanged" on an update. */
export type FieldSpecValues = Record<string, string>;

/**
 * The form for a set of fields the API declares (`FieldSpec`): a
 * connection type's credentials, a data source type's settings, a step's
 * parameters. Each kind renders as its control — a secret as a password
 * box, SQL as a monospace textarea, a select from its options — and the
 * API's 422 errors land under their field (`<prefix>.<key>`).
 *
 * A secret already set is not shown (the API never sends it): the box is
 * empty with a hint that leaving it empty keeps the stored value, and the
 * caller sends only the keys that were filled in.
 */
export function FieldSpecFields({
  specs,
  values,
  onChange,
  errors,
  errorPrefix,
  setKeys,
  idPrefix,
}: {
  specs: FieldSpec[];
  values: FieldSpecValues;
  onChange: (key: string, value: string) => void;
  errors: Record<string, string[]>;
  /** The API's prefix for these fields' errors: "credentials", "settings", "parameters". */
  errorPrefix: string;
  /** The keys the item already has a value for — a secret among them shows as kept. */
  setKeys?: readonly string[];
  idPrefix: string;
}) {
  const intl = useIntl();
  return (
    <>
      {specs.map((spec) => {
        const id = `${idPrefix}-${spec.key}`;
        const value = values[spec.key] ?? "";
        const kept = spec.kind === "secret" && setKeys?.includes(spec.key) === true;
        const hint = [
          spec.description,
          kept ? intl.formatMessage(messages.secretKept) : undefined,
          spec.default !== null && spec.kind !== "select"
            ? intl.formatMessage(messages.defaultValue, { value: spec.default })
            : undefined,
        ]
          .filter((part): part is string => typeof part === "string" && part !== "")
          .join(" ");
        return (
          <FormField
            key={spec.key}
            label={
              spec.required
                ? spec.label
                : intl.formatMessage(messages.optional, { label: spec.label })
            }
            htmlFor={id}
            hint={hint === "" ? undefined : hint}
            errors={errorsFor(errors, `${errorPrefix}.${spec.key}`)}
          >
            {spec.kind === "select" ? (
              <Select
                value={value === "" ? (spec.default ?? "") : value}
                onValueChange={(next) => onChange(spec.key, next)}
              >
                <SelectTrigger id={id}>
                  <SelectValue placeholder={intl.formatMessage(commonMessages.notSet)} />
                </SelectTrigger>
                <SelectContent>
                  {(spec.options ?? []).map((option) => (
                    <SelectItem key={option} value={option}>
                      {option}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            ) : spec.kind === "sql" || spec.kind === "text" ? (
              <Textarea
                id={id}
                value={value}
                onChange={(event) => onChange(spec.key, event.target.value)}
                rows={spec.kind === "sql" ? 6 : 3}
                className={spec.kind === "sql" ? "font-mono text-xs" : undefined}
                spellCheck={false}
              />
            ) : (
              <Input
                id={id}
                type={spec.kind === "secret" ? "password" : "text"}
                autoComplete={spec.kind === "secret" ? "new-password" : "off"}
                value={value}
                placeholder={kept ? "••••••••" : (spec.default ?? undefined)}
                onChange={(event) => onChange(spec.key, event.target.value)}
              />
            )}
          </FormField>
        );
      })}
    </>
  );
}

const messages = {
  secretKept: {
    id: "fieldSpec.secretKept",
    defaultMessage: "A value is stored; leave empty to keep it.",
  },
  defaultValue: { id: "fieldSpec.default", defaultMessage: "Default: {value}." },
  optional: { id: "fieldSpec.optional", defaultMessage: "{label} (optional)" },
};
