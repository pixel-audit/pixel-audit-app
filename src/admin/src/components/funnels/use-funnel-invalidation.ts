import type { Funnel } from "@/api/generated/model";
import { useApi } from "@/lib/api";

/**
 * What every write to the funnel's setup refreshes: the funnel's page and
 * the list. The page's query is keyed by the funnel's id — its address.
 */
export function useFunnelInvalidation(funnel: Funnel) {
  const api = useApi();
  return [api.getAdminGetFunnelQueryKey(funnel.id), api.getAdminListFunnelsQueryKey()];
}
