import { useNavigate } from "@tanstack/react-router";
import { Pencil, Trash2 } from "lucide-react";
import { useState } from "react";
import { defineMessage, defineMessages, useIntl } from "react-intl";

import type { Variable } from "@/api/generated/model";
import { ActionButton } from "@/components/crud/action-button";
import { ConfirmDeleteDialog } from "@/components/crud/confirm-delete-dialog";
import { DetailField, DetailsCard } from "@/components/crud/details-card";
import { useApiDelete } from "@/components/crud/use-api-mutations";
import { PageHeader } from "@/components/page-header";
import { VariableDialog } from "@/components/variables/variable-dialog";
import { useApi } from "@/lib/api";
import { commonMessages } from "@/lib/i18n/common-messages";

/** The variable's page: its value and description, and its actions. */
export function VariableDetail({ variable }: { variable: Variable }) {
  const intl = useIntl();
  const api = useApi();
  const navigate = useNavigate();
  const [editing, setEditing] = useState(false);
  const [deleting, setDeleting] = useState(false);

  const { destroy, pending } = useApiDelete<Variable>({
    remove: api.useAdminDeleteVariable(),
    listQueryKey: api.getAdminListVariablesQueryKey(),
    deleted: (item) => intl.formatMessage(messages.deleted, { key: item.key }),
    failed: intl.formatMessage(messages.deleteFailed),
  });

  return (
    <div className="space-y-8">
      <PageHeader
        title={<code className="font-mono">{variable.key}</code>}
        description={variable.description ?? undefined}
        actions={
          <>
            <ActionButton icon={Pencil} onClick={() => setEditing(true)}>
              {intl.formatMessage(commonMessages.edit)}
            </ActionButton>
            <ActionButton icon={Trash2} destructive onClick={() => setDeleting(true)}>
              {intl.formatMessage(commonMessages.delete)}
            </ActionButton>
          </>
        }
      />

      <DetailsCard title={intl.formatMessage(messages.value)}>
        <DetailField label={intl.formatMessage(messages.value)} wide>
          <code className="text-xs break-all whitespace-pre-wrap">{variable.value}</code>
        </DetailField>
        {variable.managed_by_env && (
          <DetailField label={intl.formatMessage(messages.source)} wide>
            {intl.formatMessage(messages.managedDetail, { key: variable.key })}
          </DetailField>
        )}
      </DetailsCard>

      <VariableDialog open={editing} onOpenChange={setEditing} variable={variable} />

      <ConfirmDeleteDialog
        open={deleting}
        onOpenChange={setDeleting}
        title={intl.formatMessage(messages.deleteTitle, { key: variable.key })}
        description={intl.formatMessage(messages.deleteDescription)}
        confirmLabel={intl.formatMessage(commonMessages.delete)}
        pending={pending}
        onConfirm={async () => {
          if (await destroy(variable)) void navigate({ to: "/settings/variables" });
        }}
      />
    </div>
  );
}

const messages = {
  ...defineMessages({
    value: { id: "variables.detail.value", defaultMessage: "Value" },
    source: { id: "variables.detail.source", defaultMessage: "Defined by" },
    deleteDescription: {
      id: "variables.detail.deleteDescription",
      defaultMessage:
        "The variable is removed. One defined by the environment comes back at the next boot.",
    },
    deleteFailed: {
      id: "variables.detail.deleteFailed",
      defaultMessage: "The variable could not be deleted.",
    },
  }),
  managedDetail: defineMessage<{ key: string }>({
    id: "variables.detail.managedDetail",
    defaultMessage: "VARIABLE_{key}_VALUE in the environment, applied by the boot role.",
  }),
  deleteTitle: defineMessage<{ key: string }>({
    id: "variables.detail.deleteTitle",
    defaultMessage: 'Delete variable "{key}"?',
  }),
  deleted: defineMessage<{ key: string }>({
    id: "variables.detail.deleted",
    defaultMessage: 'Variable "{key}" deleted.',
  }),
};
