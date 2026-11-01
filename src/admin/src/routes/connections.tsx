import { createFileRoute } from "@tanstack/react-router";

import { ConnectionsCard } from "@/components/connections/connections-card";
import { Page } from "@/components/page";

export const Route = createFileRoute("/connections")({
  component: ConnectionsPage,
});

function ConnectionsPage() {
  return (
    <Page>
      <ConnectionsCard />
    </Page>
  );
}
