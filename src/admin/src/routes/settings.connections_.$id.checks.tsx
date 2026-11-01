import { createFileRoute } from "@tanstack/react-router";

import { ConnectionChecksCard } from "@/components/connections/connection-checks-card";
import { okData } from "@/components/crud/api-response";
import { useApi } from "@/lib/api";

/** The Checks tab: the last check. */
export const Route = createFileRoute("/settings/connections_/$id/checks")({
  component: ChecksTab,
});

function ChecksTab() {
  const { id } = Route.useParams();
  const connection = okData(useApi().useAdminGetConnection(id).data)?.data;
  if (!connection) return null;
  return <ConnectionChecksCard connection={connection} />;
}
