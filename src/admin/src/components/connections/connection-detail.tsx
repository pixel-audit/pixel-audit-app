import { useNavigate } from "@tanstack/react-router";
import { Pencil, PlugZap, RefreshCw, Trash2 } from "lucide-react";
import { useState } from "react";
import { defineMessage, defineMessages, useIntl } from "react-intl";

import type { Connection } from "@/api/generated/model";
import { ConnectionDialog } from "@/components/connections/connection-dialog";
import { ConnectionStatusBadge } from "@/components/connections/connection-status";
import { connectionTypeLabel, useConnectionTypes } from "@/components/connections/connection-types";
import { ActionButton } from "@/components/crud/action-button";
import { errorDetail, refusal } from "@/components/crud/api-response";
import { ConfirmDeleteDialog } from "@/components/crud/confirm-delete-dialog";
import { DetailField, DetailsCard } from "@/components/crud/details-card";
import { useApiCommand, useApiDelete } from "@/components/crud/use-api-mutations";
import { PageHeader } from "@/components/page-header";
import { RefreshDialog } from "@/components/reporting/refresh-dialog";
import { Badge } from "@/components/ui/badge";
import { useApi } from "@/lib/api";
import { copy, formatCopy } from "@/lib/i18n/copy";
import { commonMessages } from "@/lib/i18n/common-messages";

/** The connection's page: what it is, its last check, and its actions. */
export function ConnectionDetail({ connection }: { connection: Connection }) {
  const intl = useIntl();
  const api = useApi();
  const navigate = useNavigate();
  const types = useConnectionTypes();
  const type = types.find((t) => t.type === connection.type);
  const [editing, setEditing] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [deleteBlocked, setDeleteBlocked] = useState(false);

  const { run, pending } = useApiCommand();
  const check = api.useAdminCheckConnection();
  const refresh = api.useAdminRefreshConnection();
  const remove = api.useAdminDeleteConnection();

  const { destroy, pending: deletePending } = useApiDelete<Connection>({
    remove: {
      mutateAsync: async (variables) => {
        const result = await remove.mutateAsync(variables);
        if (result.status === 409) setDeleteBlocked(true);
        return result;
      },
      isPending: remove.isPending,
    },
    listQueryKey: api.getAdminListConnectionsQueryKey(),
    deleted: (item) => intl.formatMessage(messages.deleted, { name: item.name }),
    failed: intl.formatMessage(messages.deleteFailed),
  });

  const runCheck = () =>
    run(() => check.mutateAsync({ id: connection.id }), {
      done: (result) =>
        result.status !== 200
          ? null
          : result.data.data.last_check_status === "ok"
            ? intl.formatMessage(messages.checkOk)
            : intl.formatMessage(messages.checkFailed, {
                error: result.data.data.last_check_error ?? "",
              }),
      failed: () => intl.formatMessage(messages.checkError),
      invalidate: [
        api.getAdminListConnectionsQueryKey(),
        api.getAdminGetConnectionQueryKey(connection.id),
      ],
    });

  const secretKeys = connection.credential_keys.filter(
    (key) => !(key in connection.credentials_preview),
  );

  return (
    <div className="space-y-8">
      <PageHeader
        title={connection.name}
        badges={
          <>
            <Badge variant="secondary">{connectionTypeLabel(types, connection.type)}</Badge>
            {connection.managed_by_env && (
              <Badge variant="secondary">{intl.formatMessage(messages.managed)}</Badge>
            )}
            <ConnectionStatusBadge connection={connection} />
          </>
        }
        description={connection.description ?? undefined}
        actions={
          <>
            <ActionButton icon={PlugZap} onClick={() => void runCheck()} disabled={pending}>
              {intl.formatMessage(messages.check)}
            </ActionButton>
            {connection.type === "meta_api" && (
              <ActionButton icon={RefreshCw} onClick={() => setRefreshing(true)}>
                {intl.formatMessage(messages.refresh)}
              </ActionButton>
            )}
            <ActionButton icon={Pencil} onClick={() => setEditing(true)}>
              {intl.formatMessage(commonMessages.edit)}
            </ActionButton>
            <ActionButton
              icon={Trash2}
              destructive
              onClick={() => {
                setDeleteBlocked(false);
                setDeleting(true);
              }}
            >
              {intl.formatMessage(commonMessages.delete)}
            </ActionButton>
          </>
        }
      />

      <DetailsCard title={intl.formatMessage(messages.credentials)} description={type?.label}>
        {(type?.credentials ?? []).map((spec) => (
          <DetailField key={spec.key} label={spec.label}>
            {spec.kind === "secret"
              ? secretKeys.includes(spec.key)
                ? intl.formatMessage(messages.secretSet)
                : null
              : connection.credentials_preview[spec.key]}
          </DetailField>
        ))}
        {connection.managed_by_env && (
          <DetailField label={intl.formatMessage(messages.source)} wide>
            {intl.formatMessage(messages.managedDetail, { code: connection.code })}
          </DetailField>
        )}
      </DetailsCard>

      <DetailsCard title={intl.formatMessage(messages.lastCheck)}>
        <DetailField label={intl.formatMessage(messages.checkedAt)}>
          {connection.last_checked_at
            ? intl.formatDate(new Date(connection.last_checked_at), {
                dateStyle: "medium",
                timeStyle: "short",
              })
            : null}
        </DetailField>
        <DetailField label={intl.formatMessage(messages.outcome)}>
          {connection.last_check_status === null ? null : (
            <ConnectionStatusBadge connection={connection} />
          )}
        </DetailField>
        <DetailField label={intl.formatMessage(messages.error)} wide>
          {connection.last_check_error && (
            <code className="text-xs break-all text-destructive">
              {connection.last_check_error}
            </code>
          )}
        </DetailField>
      </DetailsCard>

      <ConnectionDialog open={editing} onOpenChange={setEditing} connection={connection} />

      <RefreshDialog
        open={refreshing}
        onOpenChange={setRefreshing}
        title={intl.formatMessage(messages.refreshTitle)}
        description={intl.formatMessage(messages.refreshDescription)}
        submit={(range) => refresh.mutateAsync({ id: connection.id, data: range })}
        done={() => intl.formatMessage(messages.refreshQueued)}
        failed={(result) =>
          formatCopy(intl, refusal(result, copy(messages.refreshFailed), messages.subject))
        }
        invalidate={[api.getAdminListRefreshRunsQueryKey()]}
      />

      <ConfirmDeleteDialog
        open={deleting}
        onOpenChange={setDeleting}
        title={intl.formatMessage(messages.deleteTitle, { name: connection.name })}
        description={intl.formatMessage(
          deleteBlocked ? messages.deleteBlocked : messages.deleteDescription,
        )}
        confirmLabel={intl.formatMessage(commonMessages.delete)}
        pending={deletePending}
        blocked={deleteBlocked}
        onConfirm={async () => {
          const result = await remove.mutateAsync({ id: connection.id });
          if (result.status === 409 && errorDetail(result) === "connection_in_use") {
            setDeleteBlocked(true);
            return;
          }
          // A second call for the toasts and the invalidation would delete
          // twice; destroy() is wired to the same mutation above, so route
          // the outcome through it only on success.
          if (result.status === 204 && (await destroy(connection))) {
            void navigate({ to: "/connections" });
          }
        }}
      />
    </div>
  );
}

const messages = {
  ...defineMessages({
    managed: { id: "connections.detail.managed", defaultMessage: "From environment" },
    check: { id: "connections.detail.check", defaultMessage: "Check connection" },
    refresh: { id: "connections.detail.refresh", defaultMessage: "Pull pixel stats" },
    credentials: { id: "connections.detail.credentials", defaultMessage: "Credentials" },
    secretSet: { id: "connections.detail.secretSet", defaultMessage: "Set (hidden)" },
    source: { id: "connections.detail.source", defaultMessage: "Defined by" },
    lastCheck: { id: "connections.detail.lastCheck", defaultMessage: "Last check" },
    checkedAt: { id: "connections.detail.checkedAt", defaultMessage: "Checked at" },
    outcome: { id: "connections.detail.outcome", defaultMessage: "Outcome" },
    error: { id: "connections.detail.error", defaultMessage: "Error" },
    checkOk: { id: "connections.detail.checkOk", defaultMessage: "The connection works." },
    checkError: {
      id: "connections.detail.checkError",
      defaultMessage: "The check could not be run.",
    },
    refreshTitle: {
      id: "connections.detail.refreshTitle",
      defaultMessage: "Pull the pixel's stats",
    },
    refreshDescription: {
      id: "connections.detail.refreshDescription",
      defaultMessage:
        "Meta serves about the last seven days of hourly stats; days older than that come back empty. The pull is queued and listed under Refreshes.",
    },
    refreshQueued: {
      id: "connections.detail.refreshQueued",
      defaultMessage: "The pull is queued.",
    },
    refreshFailed: {
      id: "connections.detail.refreshFailed",
      defaultMessage: "The pull could not be queued.",
    },
    subject: { id: "connections.detail.subject", defaultMessage: "connection" },
    deleteDescription: {
      id: "connections.detail.deleteDescription",
      defaultMessage: "Its cached pixel stats go with it. This cannot be undone.",
    },
    deleteBlocked: {
      id: "connections.detail.deleteBlocked",
      defaultMessage:
        "A data source still reads through this connection. Point it at another connection or delete it first.",
    },
    deleteFailed: {
      id: "connections.detail.deleteFailed",
      defaultMessage: "The connection could not be deleted.",
    },
  }),
  checkFailed: defineMessage<{ error: string }>({
    id: "connections.detail.checkFailed",
    defaultMessage: "The check failed: {error}",
  }),
  managedDetail: defineMessage<{ code: string }>({
    id: "connections.detail.managedDetail",
    defaultMessage: "The CONNECTION_{code}_* environment variables, applied by the boot role.",
  }),
  deleteTitle: defineMessage<{ name: string }>({
    id: "connections.detail.deleteTitle",
    defaultMessage: 'Delete "{name}"?',
  }),
  deleted: defineMessage<{ name: string }>({
    id: "connections.detail.deleted",
    defaultMessage: 'Connection "{name}" deleted.',
  }),
};
