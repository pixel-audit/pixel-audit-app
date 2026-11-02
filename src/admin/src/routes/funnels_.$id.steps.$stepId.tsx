import { createFileRoute, useNavigate } from "@tanstack/react-router";

import { okData } from "@/components/crud/api-response";
import type { Crumb } from "@/components/crumbs";
import { StepReport } from "@/components/funnels/step-report";
import { useApi } from "@/lib/api";
import { isIsoDate, rangeFromSearch, type DateRange } from "@/lib/date-range";
import { parseModes, serializeModes } from "@/lib/source-modes";

type StepSearch = Partial<DateRange> & { show?: string };

/**
 * One step's screen under the View tab: its counts day by day, per data
 * source. The range and how each data source is drawn are in the address,
 * in the same words as on the funnel's report, so a step link carries the
 * report's range and modes along and a reload keeps them.
 */
export const Route = createFileRoute("/funnels_/$id/steps/$stepId")({
  validateSearch: (search: Record<string, unknown>): StepSearch => ({
    date_from: isIsoDate(search.date_from) ? search.date_from : undefined,
    date_to: isIsoDate(search.date_to) ? search.date_to : undefined,
    show: serializeModes(parseModes(search.show)),
  }),
  staticData: { crumbs: useStepCrumbs },
  component: FunnelStepScreen,
});

function useStepCrumbs(): Crumb[] {
  const { id, stepId } = Route.useParams();
  const funnel = okData(useApi().useAdminGetFunnel(id).data)?.data;
  if (!funnel) return [];
  const step = funnel.steps.find((candidate) => candidate.id === stepId);
  return [
    { label: funnel.name, to: "/funnels/$id", params: { id } },
    ...(step ? [{ label: step.name }] : []),
  ];
}

function FunnelStepScreen() {
  const { id, stepId } = Route.useParams();
  const search = Route.useSearch();
  const navigate = useNavigate({ from: Route.fullPath });
  const funnel = okData(useApi().useAdminGetFunnel(id).data)?.data;
  if (!funnel) return null;
  const step = funnel.steps.find((candidate) => candidate.id === stepId);
  if (!step) return null;

  return (
    <StepReport
      funnel={funnel}
      step={step}
      range={rangeFromSearch(search)}
      modes={parseModes(search.show)}
      onRangeChange={(next) =>
        void navigate({
          search: (previous) => ({ ...previous, ...next }),
          replace: true,
          resetScroll: false,
        })
      }
      onModesChange={(next) =>
        void navigate({
          search: (previous) => ({ ...previous, show: serializeModes(next) }),
          replace: true,
          resetScroll: false,
        })
      }
    />
  );
}
