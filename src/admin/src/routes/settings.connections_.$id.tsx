import { createFileRoute, linkOptions, Outlet } from "@tanstack/react-router";
import { defineMessages, useIntl } from "react-intl";

import { ConnectionDetail } from "@/components/connections/connection-detail";
import { ApiItem } from "@/components/crud/api-item";
import { okData } from "@/components/crud/api-response";
import type { Crumb } from "@/components/crumbs";
import { Page } from "@/components/page";
import { useApi } from "@/lib/api";

export const Route = createFileRoute("/settings/connections_/$id")({
  staticData: { crumbs: useConnectionCrumbs },
  component: ConnectionPage,
});

const BACK_LINK = linkOptions({ to: "/settings/connections" });

function useConnectionCrumbs(): Crumb[] {
  const { id } = Route.useParams();
  const connection = okData(useApi().useAdminGetConnection(id).data)?.data;
  return connection ? [{ label: connection.name }] : [];
}

function ConnectionPage() {
  const intl = useIntl();
  const { id } = Route.useParams();
  const query = useApi().useAdminGetConnection(id);

  return (
    <Page>
      <ApiItem
        query={query}
        item={(data) => data.data}
        resource="connection"
        back={{ label: intl.formatMessage(messages.back), link: BACK_LINK }}
      >
        {(connection) => (
          <ConnectionDetail connection={connection}>
            <Outlet />
          </ConnectionDetail>
        )}
      </ApiItem>
    </Page>
  );
}

const messages = defineMessages({
  back: { id: "routes.back.connections", defaultMessage: "Back to connections" },
});
