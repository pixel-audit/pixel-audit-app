import { TriangleAlert } from "lucide-react";
import { defineMessage, defineMessages, useIntl } from "react-intl";

import type { Funnel, Step, StepReport as StepReportData } from "@/api/generated/model";
import { okData, refusal } from "@/components/crud/api-response";
import { SourceModeToggle } from "@/components/funnels/source-mode-toggle";
import { StepChart } from "@/components/funnels/step-chart";
import { DateRangePicker } from "@/components/reporting/date-range-picker";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { NonIdealState } from "@/components/ui/non-ideal-state";
import { Skeleton } from "@/components/ui/skeleton";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip";
import { useApi } from "@/lib/api";
import type { DateRange } from "@/lib/date-range";
import { copy, formatCopy } from "@/lib/i18n/copy";
import { commonMessages } from "@/lib/i18n/common-messages";
import { allModes, commonMode, modeOf, shownSources, type SourceModes } from "@/lib/source-modes";
import { cn } from "@/lib/utils";

/**
 * One step of the funnel over a date range: the range above, the chart
 * with every shown data source's daily counts over one another, then a
 * row per data source with its total over the range — where each source's
 * toggle says whether it is drawn filled, as a line, or not at all. The
 * range and the modes live in the address (the route owns them), the same
 * way as on the funnel's report, so the two screens share them.
 */
export function StepReport({
  funnel,
  step,
  range,
  modes,
  onRangeChange,
  onModesChange,
}: {
  funnel: Funnel;
  step: Step;
  range: DateRange;
  modes: SourceModes;
  onRangeChange: (range: DateRange) => void;
  onModesChange: (modes: SourceModes) => void;
}) {
  const intl = useIntl();
  const query = useApi().useAdminGetStepReport(funnel.id, step.id, range);
  const report = okData(query.data)?.data ?? null;

  return (
    <div className="space-y-6">
      <Card className="shadow-none">
        <CardContent className="pt-6">
          <DateRangePicker value={range} onChange={onRangeChange} />
        </CardContent>
      </Card>

      {funnel.data_sources.length === 0 ? (
        <NonIdealState>{intl.formatMessage(messages.notConfigured)}</NonIdealState>
      ) : query.isPending ? (
        <div className="space-y-4">
          <Skeleton className="h-80 w-full" />
          <Skeleton className="h-24 w-full" />
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
        <Card className="shadow-none">
          <CardContent className="space-y-6 pt-6">
            <StepChart report={report} shown={shownSources(report.data_sources, modes)} />
            <StepTotalsTable report={report} modes={modes} onModesChange={onModesChange} />
          </CardContent>
        </Card>
      )}
    </div>
  );
}

/**
 * A row per data source: its three-state toggle in its colour and its
 * name, then its total of the step over the range — with a warning when
 * some of the range's days failed or are not computed yet. The header's
 * toggle puts every source in one state.
 */
function StepTotalsTable({
  report,
  modes,
  onModesChange,
}: {
  report: StepReportData;
  modes: SourceModes;
  onModesChange: (modes: SourceModes) => void;
}) {
  const intl = useIntl();
  const seriesOf = new Map(report.series.map((series) => [series.data_source_id, series]));

  return (
    <TooltipProvider delayDuration={100}>
      <table className="w-full text-sm">
        <thead>
          <tr className="text-left text-xs text-muted-foreground uppercase">
            <th className="py-2 pr-4 font-semibold">
              <span className="inline-flex items-center gap-2">
                <SourceModeToggle
                  name={intl.formatMessage(messages.allSources)}
                  color="var(--muted-foreground)"
                  mode={commonMode(report.data_sources, modes)}
                  onChange={(next) => onModesChange(allModes(report.data_sources, next))}
                />
                {intl.formatMessage(messages.source)}
              </span>
            </th>
            <th className="px-2 py-2 text-right font-semibold">{report.step.name}</th>
          </tr>
        </thead>
        <tbody>
          {report.data_sources.map((source) => {
            const mode = modeOf(modes, source);
            const series = seriesOf.get(source.id);
            const points = series?.points ?? [];
            const ok = points.filter((point) => point.status === "ok");
            const error = points.filter((point) => point.status === "error").length;
            const missing = points.filter((point) => point.status === "missing").length;
            const total = ok.reduce((sum, point) => sum + (point.count ?? 0), 0);
            const lastError = [...points].reverse().find((point) => point.error)?.error;
            return (
              <tr
                key={source.id}
                className={cn("border-t border-border", mode === "hidden" && "opacity-60")}
              >
                <th scope="row" className="py-2 pr-4 text-left font-medium text-foreground">
                  <span className="inline-flex items-center gap-2">
                    <SourceModeToggle
                      name={source.name}
                      color={source.color}
                      mode={mode}
                      onChange={(next) => onModesChange({ ...modes, [source.id]: next })}
                    />
                    {source.name}
                  </span>
                </th>
                <td className="px-2 py-2 text-right tabular-nums">
                  {!series?.measured ? (
                    <span className="text-muted-foreground">
                      {intl.formatMessage(messages.notMeasured)}
                    </span>
                  ) : (
                    <span className="inline-flex items-center gap-1 font-medium text-foreground">
                      {(error > 0 || missing > 0) && (
                        <Tooltip>
                          <TooltipTrigger asChild>
                            <span
                              aria-label={intl.formatMessage(messages.incompleteLabel)}
                              className="text-warning"
                            >
                              <TriangleAlert className="size-3.5" />
                            </span>
                          </TooltipTrigger>
                          <TooltipContent className="max-w-xs">
                            <p>
                              {intl.formatMessage(messages.incomplete, {
                                ok: ok.length,
                                error,
                                missing,
                                days: report.days,
                              })}
                            </p>
                            {lastError && (
                              <p className="mt-1 font-mono text-[11px] break-all">{lastError}</p>
                            )}
                          </TooltipContent>
                        </Tooltip>
                      )}
                      {ok.length === 0
                        ? intl.formatMessage(messages.noCount)
                        : intl.formatNumber(total)}
                    </span>
                  )}
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </TooltipProvider>
  );
}

const messages = {
  ...defineMessages({
    notConfigured: {
      id: "stepReport.notConfigured",
      defaultMessage: "Give the funnel a data source under Setup to see the step's counts.",
    },
    loadFailed: {
      id: "stepReport.loadFailed",
      defaultMessage: "The step's counts could not be loaded.",
    },
    subject: { id: "stepReport.subject", defaultMessage: "step report" },
    source: { id: "stepReport.table.source", defaultMessage: "Data source" },
    allSources: { id: "stepReport.table.allSources", defaultMessage: "All data sources" },
    notMeasured: { id: "stepReport.table.notMeasured", defaultMessage: "—" },
    noCount: { id: "stepReport.table.noCount", defaultMessage: "…" },
    incompleteLabel: { id: "stepReport.table.incompleteLabel", defaultMessage: "Incomplete" },
  }),
  incomplete: defineMessage<{ ok: number; error: number; missing: number; days: number }>({
    id: "stepReport.table.incomplete",
    defaultMessage:
      "{ok} of {days} days counted; {error, plural, =0 {none} one {# day} other {# days}} failed, {missing, plural, =0 {none} one {# day} other {# days}} not computed yet.",
  }),
};
