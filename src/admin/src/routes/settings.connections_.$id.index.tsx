import { createFileRoute } from "@tanstack/react-router";

import { ConnectionCredentialsCard } from "@/components/connections/connection-credentials-card";
import { okData } from "@/components/crud/api-response";
import { useApi } from "@/lib/api";

/** The Credentials tab. */
export const Route = createFileRoute("/settings/connections_/$id/")({
  component: CredentialsTab,
});

function CredentialsTab() {
  const { id } = Route.useParams();
  const connection = okData(useApi().useAdminGetConnection(id).data)?.data;
  if (!connection) return null;
  return <ConnectionCredentialsCard connection={connection} />;
}
