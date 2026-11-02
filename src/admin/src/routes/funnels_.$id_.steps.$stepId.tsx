import { createFileRoute, linkOptions, useNavigate } from "@tanstack/react-router";
import { defineMessages, useIntl } from "react-intl";

import { ApiItem } from "@/components/crud/api-item";
import { okData } from "@/components/crud/api-response";
import type { Crumb } from "@/components/crumbs";
import { StepReport } from "@/components/funnels/step-report";
import { Page } from "@/components/page";
import { PageHeader } from "@/components/page-header";
import { useApi } from "@/lib/api";
import { isIsoDate, rangeFromSearch, type DateRange } from "@/lib/date-range";
import { parseModes, serializeModes } from "@/lib/source-modes";

type StepSearch = Partial<DateRange> & { show?: string };

/**
 * A step's own page, escaped from the funnel's frame: the step's name as
 * the title, and its counts day by day, per data source. The range and
 * how each data source is drawn are in the address, in the same words as
 * on the funnel's report, so a step link carries the report's range and
 * modes along and a reload keeps them.
 */
export const Route = createFileRoute("/funnels_/$id_/steps/$stepId")({
  validateSearch: (search: Record<string, unknown>): StepSearch => ({
    date_from: isIsoDate(search.date_from) ? search.date_from : undefined,
    date_to: isIsoDate(search.date_to) ? search.date_to : undefined,
    show: serializeModes(parseModes(search.show)),
  }),
  staticData: { crumbs: useStepCrumbs },
  component: FunnelStepPage,
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

function FunnelStepPage() {
  const intl = useIntl();
  const { id, stepId } = Route.useParams();
  const search = Route.useSearch();
  const navigate = useNavigate({ from: Route.fullPath });
  const query = useApi().useAdminGetFunnel(id);

  return (
    <Page wide>
      <ApiItem
        query={query}
        item={(data) => {
          const step = data.data.steps.find((candidate) => candidate.id === stepId);
          return step ? { funnel: data.data, step } : undefined;
        }}
        resource="step"
        back={{
          label: intl.formatMessage(messages.back),
          link: linkOptions({ to: "/funnels/$id", params: { id } }),
        }}
      >
        {({ funnel, step }) => (
          <div className="space-y-6">
            <PageHeader title={step.name} description={step.description ?? undefined} />
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
          </div>
        )}
      </ApiItem>
    </Page>
  );
}

const messages = defineMessages({
  back: { id: "routes.back.funnel", defaultMessage: "Back to the funnel" },
});
