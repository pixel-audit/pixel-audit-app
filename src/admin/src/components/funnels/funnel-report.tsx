import { linkOptions, type LinkProps } from "@tanstack/react-router";
import { RefreshCw } from "lucide-react";
import { useState } from "react";
import { defineMessage, defineMessages, useIntl } from "react-intl";

import type { Funnel } from "@/api/generated/model";
import { ActionButton } from "@/components/crud/action-button";
import { okData, refusal } from "@/components/crud/api-response";
import { FunnelCountsTable } from "@/components/funnels/funnel-counts-table";
import { FunnelSankey } from "@/components/funnels/funnel-sankey";
import { TrailDialog, type TrailCell } from "@/components/funnels/trail-dialog";
import { DateRangePicker } from "@/components/reporting/date-range-picker";
import { RefreshDialog } from "@/components/reporting/refresh-dialog";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { NonIdealState } from "@/components/ui/non-ideal-state";
import { Skeleton } from "@/components/ui/skeleton";
import { useApi } from "@/lib/api";
import type { DateRange } from "@/lib/date-range";
import { copy, formatCopy } from "@/lib/i18n/copy";
import { commonMessages } from "@/lib/i18n/common-messages";
import { serializeModes, shownSources, type SourceModes } from "@/lib/source-modes";

/**
 * The funnel over a date range: the range above, the chart with every
 * shown data source over one another, then the counts per data source and
 * step — where each source's toggle says whether it is drawn filled, as an
 * outline, or not at all. The range and the modes live in the address (the
 * route owns them); a refresh of the shown range is queued from here. A
 * step's name — over the chart, or at the head of its column — leads to
 * the step's own screen, its counts day by day, with the range and the
 * modes carried along; a count opens the cell's trail.
 */
export function FunnelReport({
  funnel,
  range,
  modes,
  onRangeChange,
  onModesChange,
}: {
  funnel: Funnel;
  range: DateRange;
  modes: SourceModes;
  onRangeChange: (range: DateRange) => void;
  onModesChange: (modes: SourceModes) => void;
}) {
  const intl = useIntl();
  const api = useApi();
  const [refreshing, setRefreshing] = useState(false);
  const [trail, setTrail] = useState<TrailCell | null>(null);
  const refresh = api.useAdminRefreshFunnel();

  const query = api.useAdminGetFunnelReport(funnel.id, range);
  const report = okData(query.data)?.data ?? null;

  const stepLink = (stepId: string): LinkProps =>
    linkOptions({
      to: "/funnels/$id/steps/$stepId",
      params: { id: funnel.id, stepId },
      search: { ...range, show: serializeModes(modes) },
    });

  return (
    <div className="space-y-6">
      <Card className="shadow-none">
        <CardContent className="flex flex-wrap items-end justify-between gap-4 pt-6">
          <DateRangePicker value={range} onChange={onRangeChange} />
          <ActionButton
            icon={RefreshCw}
            onClick={() => setRefreshing(true)}
            disabled={funnel.data_sources.length === 0}
          >
            {intl.formatMessage(messages.refresh)}
          </ActionButton>
        </CardContent>
      </Card>

      {funnel.steps.length === 0 || funnel.data_sources.length === 0 ? (
        <NonIdealState>{intl.formatMessage(messages.notConfigured)}</NonIdealState>
      ) : query.isPending ? (
        <div className="space-y-4">
          <Skeleton className="h-80 w-full" />
          <Skeleton className="h-32 w-full" />
        </div>
      ) : query.isError || report === null ? (
        <NonIdealState>
          <p>
            {formatCopy(
              intl,
              refusal(query.data ?? null, copy(messages.loadFailed), messages.subject),
            )}
          </p>
          <Button variant="outline" size="sm" className="mt-3" onClick={() => void query.refetch()}>
            {intl.formatMessage(commonMessages.retry)}
          </Button>
        </NonIdealState>
      ) : (
        // The chart and its table are one picture: one card, no heading.
        <Card className="shadow-none">
          <CardContent className="space-y-6 pt-6">
            <FunnelSankey
              report={report}
              shown={shownSources(report.data_sources, modes)}
              stepLink={stepLink}
            />
            <FunnelCountsTable
              report={report}
              modes={modes}
              onModesChange={onModesChange}
              stepLink={stepLink}
              onTrail={(source, step) => setTrail({ source, step })}
            />
          </CardContent>
        </Card>
      )}

      <TrailDialog
        funnelId={funnel.id}
        cell={trail}
        range={range}
        onOpenChange={(open) => !open && setTrail(null)}
      />

      <RefreshDialog
        open={refreshing}
        onOpenChange={setRefreshing}
        title={intl.formatMessage(messages.refreshTitle)}
        description={intl.formatMessage(messages.refreshDescription)}
        initial={range}
        submit={(params) => refresh.mutateAsync({ funnelId: funnel.id, data: params })}
        done={(result) =>
          intl.formatMessage(messages.refreshQueued, {
            runs: result.status === 202 ? result.data.data.length : 0,
          })
        }
        failed={(result) =>
          formatCopy(intl, refusal(result, copy(messages.refreshFailed), messages.subject))
        }
        invalidate={[
          api.getAdminListRefreshRunsQueryKey(),
          api.getAdminGetFunnelReportQueryKey(funnel.id),
        ]}
      />
    </div>
  );
}

const messages = {
  ...defineMessages({
    refresh: { id: "report.refresh", defaultMessage: "Refresh" },
    notConfigured: {
      id: "report.notConfigured",
      defaultMessage: "Give the funnel steps and a data source under Setup to see its report.",
    },
    loadFailed: { id: "report.loadFailed", defaultMessage: "The report could not be loaded." },
    subject: { id: "report.subject", defaultMessage: "report" },
    refreshTitle: { id: "report.refreshTitle", defaultMessage: "Recompute the funnel" },
    refreshDescription: {
      id: "report.refreshDescription",
      defaultMessage:
        "Every data source counts every day of the range again, in the background. Meta sources pull the pixel's stats first — Meta serves about the last seven days.",
    },
    refreshFailed: {
      id: "report.refreshFailed",
      defaultMessage: "The refresh could not be queued.",
    },
  }),
  refreshQueued: defineMessage<{ runs: number }>({
    id: "report.refreshQueued",
    defaultMessage:
      "{runs, plural, one {# refresh run} other {# refresh runs}} queued — see Refreshes.",
  }),
};
