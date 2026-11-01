import { createFileRoute } from "@tanstack/react-router";

import { okData } from "@/components/crud/api-response";
import { DataSourcesCard } from "@/components/funnels/data-sources-card";
import { ParametersCard } from "@/components/funnels/parameters-card";
import { StepsCard } from "@/components/funnels/steps-card";
import { useApi } from "@/lib/api";

/** The Setup tab: the steps, the data sources, and what each source needs per step. */
export const Route = createFileRoute("/funnels_/$id/setup")({
  component: FunnelSetupTab,
});

function FunnelSetupTab() {
  const { id } = Route.useParams();
  const funnel = okData(useApi().useAdminGetFunnel(id).data)?.data;
  if (!funnel) return null;

  return (
    <div className="space-y-6">
      <StepsCard funnel={funnel} />
      <DataSourcesCard funnel={funnel} />
      <ParametersCard funnel={funnel} />
    </div>
  );
}
