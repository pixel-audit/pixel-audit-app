import { useEffect } from "react";
import { defineMessage, defineMessages, useIntl } from "react-intl";

import type { Connection, ConnectionParams, ConnectionParamsType } from "@/api/generated/model";
import { useConnectionTypes } from "@/components/connections/connection-types";
import { FormDialog } from "@/components/crud/form-dialog";
import { useApiSave } from "@/components/crud/use-api-mutations";
import { FormField } from "@/components/form/field";
import { FieldSpecFields, type FieldSpecValues } from "@/components/form/field-spec-fields";
import { filledValues } from "@/components/form/field-spec-values";
import { useFormState } from "@/components/form/use-form-state";
import { InlineWarning } from "@/components/ui/inline-warning";
import { Input } from "@/components/ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { useApi } from "@/lib/api";
import { commonMessages } from "@/lib/i18n/common-messages";

type Form = {
  code: string;
  name: string;
  description: string;
  type: ConnectionParamsType;
  credentials: FieldSpecValues;
};

const blank = (): Form => ({
  code: "",
  name: "",
  description: "",
  type: "meta_api",
  credentials: {},
});

const fromConnection = (connection: Connection): Form => ({
  code: connection.code,
  name: connection.name,
  description: connection.description ?? "",
  type: connection.type,
  // The non-secret values are shown; a secret's box starts empty and keeps
  // the stored value unless filled in.
  credentials: { ...connection.credentials_preview },
});

/**
 * Add or edit a connection. The credential fields come from the API's
 * declaration of the chosen type (`useConnectionTypes`); on an edit only the
 * keys that were typed are sent, so an untouched secret stays as stored.
 * An environment-managed connection edits its name and description only.
 */
export function ConnectionDialog({
  open,
  onOpenChange,
  connection,
  onSaved,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  connection?: Connection;
  onSaved?: (saved: Connection) => void;
}) {
  const intl = useIntl();
  const api = useApi();
  const types = useConnectionTypes();
  const { form, set, reset } = useFormState<Form>(blank());
  const editing = connection !== undefined;
  const managed = connection?.managed_by_env === true;

  useEffect(() => {
    if (open) reset(connection ? fromConnection(connection) : blank());
  }, [open, connection, reset]);

  const { errors, setErrors, saving, save } = useApiSave<
    ConnectionParams,
    ConnectionParams,
    Connection
  >({
    id: connection?.id,
    create: api.useAdminCreateConnection(),
    update: api.useAdminUpdateConnection(),
    listQueryKey: api.getAdminListConnectionsQueryKey(),
    saved: (params) => intl.formatMessage(messages.saved, { name: params.name ?? "" }),
    failed: intl.formatMessage(messages.failed),
  });

  useEffect(() => {
    if (open) setErrors({});
  }, [open, setErrors]);

  const type = types.find((t) => t.type === form.type);

  const submit = async () => {
    const params: ConnectionParams = managed
      ? { name: form.name, description: form.description || null }
      : {
          code: form.code,
          name: form.name,
          description: form.description || null,
          type: form.type,
          credentials: filledValues(form.credentials),
        };
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
        label={intl.formatMessage(messages.code)}
        htmlFor="connection-code"
        hint={intl.formatMessage(messages.codeHint)}
        errors={errors.code}
      >
        <Input
          id="connection-code"
          value={form.code}
          onChange={(e) => set("code", e.target.value)}
          disabled={editing}
          autoComplete="off"
          pattern="[a-z0-9]+"
        />
      </FormField>

      <FormField
        label={intl.formatMessage(messages.name)}
        htmlFor="connection-name"
        errors={errors.name}
      >
        <Input
          id="connection-name"
          value={form.name}
          onChange={(e) => set("name", e.target.value)}
        />
      </FormField>

      <FormField
        label={intl.formatMessage(messages.description)}
        htmlFor="connection-description"
        errors={errors.description}
      >
        <Textarea
          id="connection-description"
          value={form.description}
          onChange={(e) => set("description", e.target.value)}
          rows={2}
        />
      </FormField>

      {!managed && (
        <>
          <FormField
            label={intl.formatMessage(messages.type)}
            htmlFor="connection-type"
            errors={errors.type}
          >
            <Select
              value={form.type}
              onValueChange={(next) => {
                set("type", next as ConnectionParamsType);
                set("credentials", {});
              }}
            >
              <SelectTrigger id="connection-type">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {types.map((t) => (
                  <SelectItem key={t.type} value={t.type}>
                    {t.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </FormField>

          {type && (
            <FieldSpecFields
              specs={type.credentials}
              values={form.credentials}
              onChange={(key, value) => set("credentials", { ...form.credentials, [key]: value })}
              errors={errors}
              errorPrefix="credentials"
              setKeys={connection?.type === form.type ? connection.credential_keys : []}
              idPrefix="connection-credential"
            />
          )}
        </>
      )}
    </FormDialog>
  );
}

const messages = {
  ...defineMessages({
    addTitle: { id: "connections.dialog.addTitle", defaultMessage: "Add a connection" },
    editTitle: { id: "connections.dialog.editTitle", defaultMessage: "Edit the connection" },
    code: { id: "connections.dialog.code", defaultMessage: "Code" },
    codeHint: {
      id: "connections.dialog.codeHint",
      defaultMessage:
        "Lowercase letters and digits; the id in the CONNECTION_code_* variables. Cannot be changed later.",
    },
    name: { id: "connections.dialog.name", defaultMessage: "Name" },
    description: { id: "connections.dialog.description", defaultMessage: "Description" },
    type: { id: "connections.dialog.type", defaultMessage: "Type" },
    managed: {
      id: "connections.dialog.managed",
      defaultMessage:
        "This connection is defined by the environment: its type and credentials are set at boot and cannot be edited here.",
    },
    failed: {
      id: "connections.dialog.failed",
      defaultMessage: "The connection could not be saved.",
    },
  }),
  saved: defineMessage<{ name: string }>({
    id: "connections.dialog.saved",
    defaultMessage: 'Connection "{name}" saved.',
  }),
};
