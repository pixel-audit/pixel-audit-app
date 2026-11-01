import { createFileRoute } from "@tanstack/react-router";

import { Page } from "@/components/page";
import { VariablesCard } from "@/components/variables/variables-card";

export const Route = createFileRoute("/settings/variables")({
  component: VariablesPage,
});

function VariablesPage() {
  return (
    <Page>
      <VariablesCard />
    </Page>
  );
}
