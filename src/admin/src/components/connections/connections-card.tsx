import { linkOptions } from "@tanstack/react-router";
import { Plug } from "lucide-react";
import { useState } from "react";
import { defineMessages, useIntl } from "react-intl";

import type { Connection } from "@/api/generated/model";
import { ConnectionDialog } from "@/components/connections/connection-dialog";
import { ConnectionStatusBadge } from "@/components/connections/connection-status";
import {
  connectionTypeLabel,
  describeCredentials,
  useConnectionTypes,
} from "@/components/connections/connection-types";
import { ApiList } from "@/components/crud/api-list";
import { CrudCard } from "@/components/crud/crud-card";
import { ListRow, RowDetail } from "@/components/crud/list-row";
import { Badge } from "@/components/ui/badge";
import { useApi } from "@/lib/api";

/** The connections list: every connection, by code, leading to its page. */
export function ConnectionsCard() {
  const intl = useIntl();
  const api = useApi();
  const types = useConnectionTypes();
  const list = api.useAdminListConnections();
  const [adding, setAdding] = useState(false);

  return (
    <>
      <CrudCard
        page
        title={intl.formatMessage(messages.title)}
        action={{ label: intl.formatMessage(messages.add), onClick: () => setAdding(true) }}
      >
        <ApiList
          query={list}
          items={(data) => data.data}
          resource="connections"
          empty={intl.formatMessage(messages.empty)}
        >
          {(connections: Connection[]) =>
            connections.map((connection) => (
              <ListRow
                key={connection.id}
                icon={Plug}
                title={connection.name}
                link={linkOptions({ to: "/connections/$id", params: { id: connection.id } })}
                badges={
                  <>
                    <Badge variant="secondary">{connectionTypeLabel(types, connection.type)}</Badge>
                    {connection.managed_by_env && (
                      <Badge variant="secondary">{intl.formatMessage(messages.managed)}</Badge>
                    )}
                    <ConnectionStatusBadge connection={connection} />
                  </>
                }
              >
                <RowDetail>
                  {describeCredentials(intl, connection.credentials_preview) ??
                    connection.description ??
                    intl.formatMessage(messages.noPreview)}
                </RowDetail>
              </ListRow>
            ))
          }
        </ApiList>
      </CrudCard>
      <ConnectionDialog open={adding} onOpenChange={setAdding} />
    </>
  );
}

const messages = defineMessages({
  title: { id: "connections.list.title", defaultMessage: "Connections" },
  add: { id: "connections.list.add", defaultMessage: "Add connection" },
  empty: {
    id: "connections.list.empty",
    defaultMessage:
      "No connections yet. Add one here, or define it with CONNECTION_* variables and run the boot role.",
  },
  managed: { id: "connections.list.managed", defaultMessage: "From environment" },
  noPreview: { id: "connections.list.noPreview", defaultMessage: "Credentials set" },
});
