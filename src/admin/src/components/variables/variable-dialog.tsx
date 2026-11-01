import { useEffect } from "react";
import { defineMessage, defineMessages, useIntl } from "react-intl";

import type { Variable, VariableParams } from "@/api/generated/model";
import { FormDialog } from "@/components/crud/form-dialog";
import { useApiSave } from "@/components/crud/use-api-mutations";
import { FormField } from "@/components/form/field";
import { useFormState } from "@/components/form/use-form-state";
import { InlineWarning } from "@/components/ui/inline-warning";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { useApi } from "@/lib/api";
import { commonMessages } from "@/lib/i18n/common-messages";

type Form = { key: string; value: string; description: string };

const blank = (): Form => ({ key: "", value: "", description: "" });

const fromVariable = (variable: Variable): Form => ({
  key: variable.key,
  value: variable.value,
  description: variable.description ?? "",
});

/**
 * Add or edit a variable. An environment-managed variable edits its
 * description only; the key cannot be changed once set.
 */
export function VariableDialog({
  open,
  onOpenChange,
  variable,
  onSaved,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  variable?: Variable;
  onSaved?: (saved: Variable) => void;
}) {
  const intl = useIntl();
  const api = useApi();
  const { form, set, reset } = useFormState<Form>(blank());
  const editing = variable !== undefined;
  const managed = variable?.managed_by_env === true;

  useEffect(() => {
    if (open) reset(variable ? fromVariable(variable) : blank());
  }, [open, variable, reset]);

  const { errors, setErrors, saving, save } = useApiSave<VariableParams, VariableParams, Variable>({
    id: variable?.id,
    create: api.useAdminCreateVariable(),
    update: api.useAdminUpdateVariable(),
    listQueryKey: api.getAdminListVariablesQueryKey(),
    saved: (params) => intl.formatMessage(messages.saved, { key: params.key ?? form.key }),
    failed: intl.formatMessage(messages.failed),
  });

  useEffect(() => {
    if (open) setErrors({});
  }, [open, setErrors]);

  const submit = async () => {
    const params: VariableParams = managed
      ? { description: form.description || null }
      : editing
        ? { value: form.value, description: form.description || null }
        : { key: form.key, value: form.value, description: form.description || null };
    const saved = await save(params);
    if (saved) {
      onOpenChange(false);
      onSaved?.(saved);
    }
  };

  return (
    <FormDialog
      open={open}
      onOpenChange={onOpenChange}
      title={intl.formatMessage(editing ? messages.editTitle : messages.addTitle)}
      submitLabel={intl.formatMessage(editing ? commonMessages.save : commonMessages.add)}
      saving={saving}
      onSubmit={submit}
      className="max-w-xl"
    >
      {managed && <InlineWarning>{intl.formatMessage(messages.managed)}</InlineWarning>}

      <FormField
        label={intl.formatMessage(messages.key)}
        htmlFor="variable-key"
        hint={intl.formatMessage(messages.keyHint)}
        errors={errors.key}
      >
        <Input
          id="variable-key"
          value={form.key}
          onChange={(e) => set("key", e.target.value)}
          disabled={editing}
          autoComplete="off"
          pattern="[a-zA-Z0-9]+"
          className="font-mono"
        />
      </FormField>

      <FormField
        label={intl.formatMessage(messages.value)}
        htmlFor="variable-value"
        errors={errors.value}
      >
        <Textarea
          id="variable-value"
          value={form.value}
          onChange={(e) => set("value", e.target.value)}
          disabled={managed}
          rows={3}
          className="font-mono text-xs"
          spellCheck={false}
        />
      </FormField>

      <FormField
        label={intl.formatMessage(messages.description)}
        htmlFor="variable-description"
        errors={errors.description}
      >
        <Textarea
          id="variable-description"
          value={form.description}
          onChange={(e) => set("description", e.target.value)}
          rows={2}
        />
      </FormField>
    </FormDialog>
  );
}

const messages = {
  ...defineMessages({
    addTitle: { id: "variables.dialog.addTitle", defaultMessage: "Add a variable" },
    editTitle: { id: "variables.dialog.editTitle", defaultMessage: "Edit the variable" },
    key: { id: "variables.dialog.key", defaultMessage: "Key" },
    keyHint: {
      id: "variables.dialog.keyHint",
      defaultMessage:
        "Letters and digits; the key in the VARIABLE_key_* variables. Cannot be changed later.",
    },
    value: { id: "variables.dialog.value", defaultMessage: "Value" },
    description: { id: "variables.dialog.description", defaultMessage: "Description" },
    managed: {
      id: "variables.dialog.managed",
      defaultMessage:
        "This variable is defined by the environment: its value is set at boot and cannot be edited here.",
    },
    failed: { id: "variables.dialog.failed", defaultMessage: "The variable could not be saved." },
  }),
  saved: defineMessage<{ key: string }>({
    id: "variables.dialog.saved",
    defaultMessage: 'Variable "{key}" saved.',
  }),
};
