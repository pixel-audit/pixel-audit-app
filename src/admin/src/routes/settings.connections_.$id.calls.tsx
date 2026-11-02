import { createFileRoute, useNavigate } from "@tanstack/react-router";

import type { AdminListConnectionCallsPurpose as CallPurpose } from "@/api/generated/model";
import {
  type CallsFilters,
  ConnectionCallsCard,
} from "@/components/connections/connection-calls-card";
import { okData } from "@/components/crud/api-response";
import { useApi } from "@/lib/api";
import { CALL_PURPOSES } from "@/lib/call-purposes";
import { isIsoDate } from "@/lib/date-range";

const isPurpose = (value: unknown): value is CallPurpose =>
  typeof value === "string" && (CALL_PURPOSES as readonly string[]).includes(value);

const isId = (value: unknown): value is string => typeof value === "string" && value !== "";

/**
 * The Queries / Calls tab: what went through the connection. The range of
 * days, the purpose, what the calls served and the page are in the address.
 */
export const Route = createFileRoute("/settings/connections_/$id/calls")({
  validateSearch: (search: Record<string, unknown>): CallsFilters => ({
    date_from: isIsoDate(search.date_from) ? search.date_from : undefined,
    date_to: isIsoDate(search.date_to) ? search.date_to : undefined,
    purpose: isPurpose(search.purpose) ? search.purpose : undefined,
    data_source_id: isId(search.data_source_id) ? search.data_source_id : undefined,
    step_id: isId(search.step_id) ? search.step_id : undefined,
    date: isIsoDate(search.date) ? search.date : undefined,
    offset:
      typeof search.offset === "number" && Number.isInteger(search.offset) && search.offset > 0
        ? search.offset
        : undefined,
  }),
  component: CallsTab,
});

function CallsTab() {
  const { id } = Route.useParams();
  const filters = Route.useSearch();
  const navigate = useNavigate({ from: Route.fullPath });
  const connection = okData(useApi().useAdminGetConnection(id).data)?.data;
  if (!connection) return null;

  return (
    <ConnectionCallsCard
      connection={connection}
      filters={filters}
      onFiltersChange={(next) => void navigate({ search: next, replace: true, resetScroll: false })}
    />
  );
}
