import { linkOptions, useNavigate, useRouterState } from "@tanstack/react-router";
import { Pencil, PlugZap, RefreshCw, Trash2 } from "lucide-react";
import { useState, type ReactNode } from "react";
import { defineMessage, defineMessages, useIntl } from "react-intl";

import type { Connection } from "@/api/generated/model";
import { ConnectionDialog } from "@/components/connections/connection-dialog";
import { ActionButton } from "@/components/crud/action-button";
import { errorDetail, refusal } from "@/components/crud/api-response";
import { ConfirmDeleteDialog } from "@/components/crud/confirm-delete-dialog";
import { TabsNav } from "@/components/crud/tabs-nav";
import { useApiCommand, useApiDelete } from "@/components/crud/use-api-mutations";
import { PageHeader } from "@/components/page-header";
import { RefreshDialog } from "@/components/reporting/refresh-dialog";
import { useApi } from "@/lib/api";
import { copy, formatCopy } from "@/lib/i18n/copy";
import { commonMessages } from "@/lib/i18n/common-messages";

/**
 * The connection's page frame: the header with its actions, and the tabs —
 * Credentials, Checks, and Queries (a database) or Calls (an API) — as
 * links, each its own route. The tab's content is `children`.
 */
export function ConnectionDetail({
  connection,
  children,
}: {
  connection: Connection;
  children: ReactNode;
}) {
  const intl = useIntl();
  const api = useApi();
  const navigate = useNavigate();
  const pathname = useRouterState({ select: (s) => s.location.pathname });
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

  const params = { id: connection.id };
  const onChecks = pathname.endsWith("/checks");
  const onCalls = pathname.endsWith("/calls");
  const tabs = [
    {
      link: linkOptions({ to: "/settings/connections/$id", params }),
      label: intl.formatMessage(messages.credentials),
      active: !onChecks && !onCalls,
    },
    {
      link: linkOptions({ to: "/settings/connections/$id/checks", params }),
      label: intl.formatMessage(messages.checks),
      active: onChecks,
    },
    {
      link: linkOptions({ to: "/settings/connections/$id/calls", params }),
      label: intl.formatMessage(connection.type === "meta" ? messages.calls : messages.queries),
      active: onCalls,
    },
  ];

  return (
    <div className="space-y-6">
      <PageHeader
        title={connection.name}
        description={connection.description ?? undefined}
        actions={
          <>
            <ActionButton icon={PlugZap} onClick={() => void runCheck()} disabled={pending}>
              {intl.formatMessage(messages.check)}
            </ActionButton>
            {connection.type === "meta" && (
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

      <TabsNav label={intl.formatMessage(messages.tabs)} tabs={tabs} />

      {children}

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
            void navigate({ to: "/settings/connections" });
          }
        }}
      />
    </div>
  );
}

const messages = {
  ...defineMessages({
    check: { id: "connections.detail.check", defaultMessage: "Check connection" },
    refresh: { id: "connections.detail.refresh", defaultMessage: "Pull pixel stats" },
    credentials: { id: "connections.detail.credentials", defaultMessage: "Credentials" },
    checks: { id: "connections.detail.checks", defaultMessage: "Checks" },
    queries: { id: "connections.detail.queries", defaultMessage: "Queries" },
    calls: { id: "connections.detail.calls", defaultMessage: "Calls" },
    tabs: { id: "connections.detail.tabs", defaultMessage: "Connection tabs" },
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
  deleteTitle: defineMessage<{ name: string }>({
    id: "connections.detail.deleteTitle",
    defaultMessage: 'Delete "{name}"?',
  }),
  deleted: defineMessage<{ name: string }>({
    id: "connections.detail.deleted",
    defaultMessage: 'Connection "{name}" deleted.',
  }),
};
