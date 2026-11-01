import { createFileRoute, useNavigate } from "@tanstack/react-router";

import type { AdminListRefreshRunsKind, AdminListRefreshRunsStatus } from "@/api/generated/model";
import { Page } from "@/components/page";
import { RefreshRunsCard } from "@/components/reporting/refresh-runs-card";

const STATUSES = ["queued", "running", "done", "failed"];
const KINDS = ["meta_pixel", "data_source"];

type Search = { status?: AdminListRefreshRunsStatus; kind?: AdminListRefreshRunsKind };

/** Every refresh run, with its filters in the address. */
export const Route = createFileRoute("/refreshes")({
  validateSearch: (search: Record<string, unknown>): Search => ({
    status:
      typeof search.status === "string" && STATUSES.includes(search.status)
        ? (search.status as AdminListRefreshRunsStatus)
        : undefined,
    kind:
      typeof search.kind === "string" && KINDS.includes(search.kind)
        ? (search.kind as AdminListRefreshRunsKind)
        : undefined,
  }),
  component: RefreshesPage,
});

function RefreshesPage() {
  const search = Route.useSearch();
  const navigate = useNavigate({ from: Route.fullPath });

  return (
    <Page>
      <RefreshRunsCard
        filters={search}
        onFiltersChange={(filters) => void navigate({ search: filters, replace: true })}
      />
    </Page>
  );
}
