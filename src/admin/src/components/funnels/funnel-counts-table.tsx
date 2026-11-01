import { TriangleAlert } from "lucide-react";
import { defineMessage, defineMessages, useIntl } from "react-intl";

import type { Report, ReportCell } from "@/api/generated/model";
import { SourceModeToggle } from "@/components/funnels/source-mode-toggle";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip";
import { allModes, commonMode, modeOf, type SourceModes } from "@/lib/source-modes";
import { cn } from "@/lib/utils";

/**
 * The counts: a row per data source, a column per step, aligned with the
 * chart's columns. Each row starts with the source's three-state toggle in
 * its colour (filled, outlined, hidden on the chart); the header's toggle
 * puts every source in one state. Each cell carries the count, and a
 * warning when some of the range's days failed or are not computed yet
 * (the tooltip says how many, and the last error).
 */
export function FunnelCountsTable({
  report,
  modes,
  onModesChange,
}: {
  report: Report;
  modes: SourceModes;
  onModesChange: (modes: SourceModes) => void;
}) {
  const intl = useIntl();

  const cellOf = (sourceId: string, stepId: string): ReportCell | undefined =>
    report.cells.find((c) => c.data_source_id === sourceId && c.step_id === stepId);

  return (
    <TooltipProvider delayDuration={100}>
      <div className="overflow-x-auto">
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
              {report.steps.map((step) => (
                <th key={step.id} className="px-2 py-2 text-right font-semibold">
                  {step.name}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {report.data_sources.map((source) => {
              const mode = modeOf(modes, source);
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
                  {report.steps.map((step) => {
                    const cell = cellOf(source.id, step.id);
                    const incomplete =
                      cell !== undefined && (cell.days_error > 0 || cell.days_missing > 0);
                    const measured = source.step_parameters.some((p) => p.step_id === step.id);
                    return (
                      <td key={step.id} className="px-2 py-2 text-right tabular-nums">
                        {!measured ? (
                          <span className="text-muted-foreground">
                            {intl.formatMessage(messages.notMeasured)}
                          </span>
                        ) : (
                          <span className="inline-flex items-center gap-1 font-medium text-foreground">
                            {incomplete && cell && (
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
                                      ok: cell.days_ok,
                                      error: cell.days_error,
                                      missing: cell.days_missing,
                                      days: report.days,
                                    })}
                                  </p>
                                  {cell.last_error && (
                                    <p className="mt-1 font-mono text-[11px] break-all">
                                      {cell.last_error}
                                    </p>
                                  )}
                                </TooltipContent>
                              </Tooltip>
                            )}
                            {cell?.count === null || cell === undefined
                              ? intl.formatMessage(messages.noCount)
                              : intl.formatNumber(cell.count)}
                          </span>
                        )}
                      </td>
                    );
                  })}
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </TooltipProvider>
  );
}

const messages = {
  ...defineMessages({
    source: { id: "counts.table.source", defaultMessage: "Data source" },
    allSources: { id: "counts.table.allSources", defaultMessage: "All data sources" },
    notMeasured: { id: "counts.table.notMeasured", defaultMessage: "—" },
    noCount: { id: "counts.table.noCount", defaultMessage: "…" },
    incompleteLabel: { id: "counts.table.incompleteLabel", defaultMessage: "Incomplete" },
  }),
  incomplete: defineMessage<{ ok: number; error: number; missing: number; days: number }>({
    id: "counts.table.incomplete",
    defaultMessage:
      "{ok} of {days} days counted; {error, plural, =0 {none} one {# day} other {# days}} failed, {missing, plural, =0 {none} one {# day} other {# days}} not computed yet.",
  }),
};
