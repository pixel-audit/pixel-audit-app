import { linkOptions, useNavigate, useRouterState } from "@tanstack/react-router";
import { Pencil, Trash2 } from "lucide-react";
import { useState, type ReactNode } from "react";
import { defineMessage, defineMessages, useIntl } from "react-intl";

import type { Funnel } from "@/api/generated/model";
import { ActionButton } from "@/components/crud/action-button";
import { ConfirmDeleteDialog } from "@/components/crud/confirm-delete-dialog";
import { TabsNav } from "@/components/crud/tabs-nav";
import { useApiDelete } from "@/components/crud/use-api-mutations";
import { FunnelDialog } from "@/components/funnels/funnel-dialog";
import { PageHeader } from "@/components/page-header";
import { useApi } from "@/lib/api";
import { commonMessages } from "@/lib/i18n/common-messages";

/**
 * The funnel's page frame: the header with Edit and Delete, and the two
 * tabs — View (the report) and Setup (steps, data sources, parameters) —
 * as links, since each tab is its own route. The tab's content is `children`.
 */
export function FunnelDetail({ funnel, children }: { funnel: Funnel; children: ReactNode }) {
  const intl = useIntl();
  const api = useApi();
  const navigate = useNavigate();
  const pathname = useRouterState({ select: (s) => s.location.pathname });
  const [editing, setEditing] = useState(false);
  const [deleting, setDeleting] = useState(false);

  const remove = api.useAdminDeleteFunnel();
  const { destroy, pending } = useApiDelete<Funnel>({
    remove,
    listQueryKey: api.getAdminListFunnelsQueryKey(),
    deleted: (item) => intl.formatMessage(messages.deleted, { name: item.name }),
    failed: intl.formatMessage(messages.deleteFailed),
  });

  const onSetup = pathname.endsWith("/setup");
  const params = { id: funnel.id };
  const tabs = [
    {
      link: linkOptions({ to: "/funnels/$id", params }),
      label: intl.formatMessage(messages.view),
      active: !onSetup,
    },
    {
      link: linkOptions({ to: "/funnels/$id/setup", params }),
      label: intl.formatMessage(messages.setup),
      active: onSetup,
    },
  ];

  return (
    <div className="space-y-6">
      <PageHeader
        title={funnel.name}
        description={funnel.description ?? undefined}
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

      <TabsNav label={intl.formatMessage(messages.tabs)} tabs={tabs} />

      {children}

      <FunnelDialog open={editing} onOpenChange={setEditing} funnel={funnel} />

      <ConfirmDeleteDialog
        open={deleting}
        onOpenChange={setDeleting}
        title={intl.formatMessage(messages.deleteTitle, { name: funnel.name })}
        description={intl.formatMessage(messages.deleteDescription)}
        confirmLabel={intl.formatMessage(commonMessages.delete)}
        pending={pending}
        onConfirm={async () => {
          if (await destroy(funnel)) void navigate({ to: "/funnels" });
        }}
      />
    </div>
  );
}

const messages = {
  ...defineMessages({
    view: { id: "funnels.detail.view", defaultMessage: "View" },
    setup: { id: "funnels.detail.setup", defaultMessage: "Setup" },
    tabs: { id: "funnels.detail.tabs", defaultMessage: "Funnel tabs" },
    deleteDescription: {
      id: "funnels.detail.deleteDescription",
      defaultMessage:
        "Its steps, data sources and every cached count go with it. This cannot be undone.",
    },
    deleteFailed: {
      id: "funnels.detail.deleteFailed",
      defaultMessage: "The funnel could not be deleted.",
    },
  }),
  deleteTitle: defineMessage<{ name: string }>({
    id: "funnels.detail.deleteTitle",
    defaultMessage: 'Delete the funnel "{name}"?',
  }),
  deleted: defineMessage<{ name: string }>({
    id: "funnels.detail.deleted",
    defaultMessage: 'Funnel "{name}" deleted.',
  }),
};
