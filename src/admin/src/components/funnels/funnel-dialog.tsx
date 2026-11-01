import { useEffect } from "react";
import { defineMessage, defineMessages, useIntl } from "react-intl";

import type { Funnel, FunnelParams } from "@/api/generated/model";
import { FormDialog } from "@/components/crud/form-dialog";
import { useApiSave } from "@/components/crud/use-api-mutations";
import { FormField } from "@/components/form/field";
import { useFormState } from "@/components/form/use-form-state";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { useApi } from "@/lib/api";
import { commonMessages } from "@/lib/i18n/common-messages";

type Form = { code: string; name: string; description: string };

const blank = (): Form => ({ code: "", name: "", description: "" });

/** Add or edit a funnel: its code, name and description. */
export function FunnelDialog({
  open,
  onOpenChange,
  funnel,
  onSaved,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  funnel?: Funnel;
  onSaved?: (saved: Funnel) => void;
}) {
  const intl = useIntl();
  const api = useApi();
  const { form, set, reset } = useFormState<Form>(blank());
  const editing = funnel !== undefined;

  useEffect(() => {
    if (open) {
      reset(
        funnel
          ? { code: funnel.code, name: funnel.name, description: funnel.description ?? "" }
          : blank(),
      );
    }
  }, [open, funnel, reset]);

  const { errors, setErrors, saving, save } = useApiSave<FunnelParams, FunnelParams, Funnel>({
    id: funnel?.id,
    create: api.useAdminCreateFunnel(),
    update: api.useAdminUpdateFunnel(),
    invalidate: [api.getAdminListFunnelsQueryKey()],
    saved: (params) => intl.formatMessage(messages.saved, { name: params.name ?? "" }),
    failed: intl.formatMessage(messages.failed),
  });

  useEffect(() => {
    if (open) setErrors({});
  }, [open, setErrors]);

  const submit = async () => {
    const saved = await save({
      code: form.code,
      name: form.name,
      description: form.description || null,
    });
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
    >
      <FormField
        label={intl.formatMessage(messages.code)}
        htmlFor="funnel-code"
        hint={intl.formatMessage(messages.codeHint)}
        errors={errors.code}
      >
        <Input
          id="funnel-code"
          value={form.code}
          onChange={(e) => set("code", e.target.value)}
          disabled={editing}
          autoComplete="off"
          pattern="[a-z0-9]+"
        />
      </FormField>
      <FormField
        label={intl.formatMessage(messages.name)}
        htmlFor="funnel-name"
        errors={errors.name}
      >
        <Input id="funnel-name" value={form.name} onChange={(e) => set("name", e.target.value)} />
      </FormField>
      <FormField
        label={intl.formatMessage(messages.description)}
        htmlFor="funnel-description"
        errors={errors.description}
      >
        <Textarea
          id="funnel-description"
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
    addTitle: { id: "funnels.dialog.addTitle", defaultMessage: "Add a funnel" },
    editTitle: { id: "funnels.dialog.editTitle", defaultMessage: "Edit the funnel" },
    code: { id: "funnels.dialog.code", defaultMessage: "Code" },
    codeHint: {
      id: "funnels.dialog.codeHint",
      defaultMessage: "Lowercase letters and digits. Cannot be changed later.",
    },
    name: { id: "funnels.dialog.name", defaultMessage: "Name" },
    description: { id: "funnels.dialog.description", defaultMessage: "Description" },
    failed: { id: "funnels.dialog.failed", defaultMessage: "The funnel could not be saved." },
  }),
  saved: defineMessage<{ name: string }>({
    id: "funnels.dialog.saved",
    defaultMessage: 'Funnel "{name}" saved.',
  }),
};
