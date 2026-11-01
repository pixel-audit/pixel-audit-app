import { createFileRoute } from "@tanstack/react-router";

import { FunnelsCard } from "@/components/funnels/funnels-card";
import { Page } from "@/components/page";

export const Route = createFileRoute("/funnels")({
  component: FunnelsPage,
});

function FunnelsPage() {
  return (
    <Page>
      <FunnelsCard />
    </Page>
  );
}
