import { useLayoutEffect, useRef, useState } from "react";
import { defineMessage, defineMessages, useIntl } from "react-intl";

import type { Report } from "@/api/generated/model";
import { NonIdealState } from "@/components/ui/non-ideal-state";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip";
import { funnelLayout, ribbonPath, stepStats, type ShownSource } from "@/lib/sankey";

const HEIGHT = 300;
const LABELS_HEIGHT = 20;
const FILL_OPACITY = 0.3;

/**
 * The funnel with every shown data source over one another, centred on
 * the midline: a column per step, in it one node per source as tall as its
 * count on one shared scale, and from each node a ribbon that narrows to
 * the source's next node. A source is drawn in its own colour, as a
 * translucent fill or as an outline, so two sources that agree lie on top
 * of each other and two that do not show the gap. A step the source does
 * not measure is drawn dashed at the median of the other sources.
 *
 * The step names stand over their columns; hovering one says how far the
 * sources disagree on it — the lowest and the highest count, with who
 * says so, and the average. Hovering a node or a ribbon names its source
 * and count.
 *
 * The chart's box is always there, at its fixed height, whatever is shown:
 * when every source is hidden, or the shown ones measure nothing, the
 * message sits in the box. The box is what the width is measured on, and
 * a box that came and went would be measured as nothing when it left —
 * and never again once it came back.
 */
export function FunnelSankey({ report, shown }: { report: Report; shown: ShownSource[] }) {
  const intl = useIntl();
  const containerRef = useRef<HTMLDivElement>(null);
  const [width, setWidth] = useState(0);

  useLayoutEffect(() => {
    const element = containerRef.current;
    if (!element) return;
    const observer = new ResizeObserver(([entry]) => {
      if (entry && entry.contentRect.width > 0) setWidth(Math.floor(entry.contentRect.width));
    });
    observer.observe(element);
    setWidth(Math.floor(element.getBoundingClientRect().width));
    return () => observer.disconnect();
  }, []);

  const layout =
    width > 0 && shown.length > 0 ? funnelLayout(report, shown, { width, height: HEIGHT }) : null;

  const empty =
    shown.length === 0
      ? messages.nothingShown
      : layout && layout.nodes.length === 0
        ? messages.nothingMeasured
        : null;

  return (
    <TooltipProvider delayDuration={100}>
      <div className="space-y-3">
        {/* The step names: HTML over the chart, so each can carry a tooltip. */}
        <div
          ref={containerRef}
          className="relative w-full"
          style={{ height: LABELS_HEIGHT + HEIGHT }}
        >
          <div className="relative" style={{ height: LABELS_HEIGHT }}>
            {empty === null &&
              layout?.columns.map((column, index) => {
                const first = index === 0;
                const last = index === layout.columns.length - 1;
                const stats = stepStats(report, column.step.id);
                // The first name starts at its column, the last ends at its;
                // the ones between are centred over theirs.
                const position = first
                  ? { left: column.x0 }
                  : last
                    ? { right: width - column.x1 }
                    : { left: (column.x0 + column.x1) / 2, transform: "translateX(-50%)" };
                return (
                  <Tooltip key={column.step.id}>
                    <TooltipTrigger asChild>
                      <button
                        type="button"
                        className="absolute top-0 cursor-help text-xs font-medium whitespace-nowrap text-foreground underline decoration-dotted underline-offset-2"
                        style={position}
                      >
                        {column.step.name}
                      </button>
                    </TooltipTrigger>
                    <TooltipContent className="max-w-xs">
                      {stats ? (
                        <dl className="grid grid-cols-[auto_1fr] gap-x-3 gap-y-0.5 tabular-nums">
                          <dt>{intl.formatMessage(messages.min)}</dt>
                          <dd>
                            {intl.formatMessage(messages.valueOf, {
                              count: intl.formatNumber(stats.min.count),
                              source: stats.min.source.name,
                            })}
                          </dd>
                          <dt>{intl.formatMessage(messages.max)}</dt>
                          <dd>
                            {intl.formatMessage(messages.valueOf, {
                              count: intl.formatNumber(stats.max.count),
                              source: stats.max.source.name,
                            })}
                          </dd>
                          <dt>{intl.formatMessage(messages.average)}</dt>
                          <dd>
                            {intl.formatMessage(messages.averageOf, {
                              count: intl.formatNumber(Math.round(stats.average)),
                              sources: stats.sources,
                            })}
                          </dd>
                        </dl>
                      ) : (
                        intl.formatMessage(messages.unmeasuredStep)
                      )}
                    </TooltipContent>
                  </Tooltip>
                );
              })}
          </div>
          {empty !== null ? (
            <div className="flex items-center justify-center" style={{ height: HEIGHT }}>
              <NonIdealState>{intl.formatMessage(empty)}</NonIdealState>
            </div>
          ) : (
            layout && (
              <svg
                width={width}
                height={HEIGHT}
                role="img"
                aria-label={intl.formatMessage(messages.chartLabel)}
                className="block"
              >
                {/* Ribbons under the nodes. */}
                {layout.ribbons.map((ribbon) => (
                  <path
                    key={`${ribbon.source.id}:${ribbon.from.id}:${ribbon.to.id}`}
                    d={ribbonPath(ribbon)}
                    fill={ribbon.mode === "fill" ? ribbon.source.color : "none"}
                    fillOpacity={FILL_OPACITY}
                    stroke={ribbon.source.color}
                    strokeOpacity={ribbon.mode === "outline" ? 0.9 : 0}
                    strokeWidth={1.5}
                  >
                    <title>
                      {intl.formatMessage(messages.ribbonTitle, {
                        source: ribbon.source.name,
                        from: ribbon.from.name,
                        to: ribbon.to.name,
                        fromCount: intl.formatNumber(ribbon.fromCount),
                        toCount: intl.formatNumber(ribbon.toCount),
                      })}
                    </title>
                  </path>
                ))}
                {layout.nodes.map((node) => (
                  <rect
                    key={`${node.source.id}:${node.step.id}`}
                    x={node.x0}
                    y={node.y0}
                    width={node.x1 - node.x0}
                    height={Math.max(node.y1 - node.y0, 1)}
                    rx={2}
                    fill={node.mode === "fill" && !node.estimated ? node.source.color : "none"}
                    fillOpacity={0.85}
                    stroke={node.source.color}
                    strokeWidth={node.mode === "outline" || node.estimated ? 1.5 : 0}
                    strokeDasharray={node.estimated ? "3 2" : undefined}
                  >
                    <title>
                      {intl.formatMessage(messages.nodeTitle, {
                        source: node.source.name,
                        step: node.step.name,
                        count: intl.formatNumber(node.count),
                        estimated: node.estimated ? 1 : 0,
                        partial: node.partial ? 1 : 0,
                      })}
                    </title>
                  </rect>
                ))}
              </svg>
            )
          )}
        </div>
      </div>
    </TooltipProvider>
  );
}

const messages = {
  ...defineMessages({
    nothingShown: {
      id: "sankey.nothingShown",
      defaultMessage: "Every data source is hidden — switch one on in the table below.",
    },
    nothingMeasured: {
      id: "sankey.nothingMeasured",
      defaultMessage:
        "The shown data sources measure none of the steps yet — set their parameters under Setup.",
    },
    chartLabel: {
      id: "sankey.chartLabel",
      defaultMessage: "The funnel: each data source's count per step, over one another",
    },
    min: { id: "sankey.step.min", defaultMessage: "Lowest" },
    max: { id: "sankey.step.max", defaultMessage: "Highest" },
    average: { id: "sankey.step.average", defaultMessage: "Average" },
    unmeasuredStep: {
      id: "sankey.step.unmeasured",
      defaultMessage: "No data source measures this step yet.",
    },
  }),
  valueOf: defineMessage<{ count: string; source: string }>({
    id: "sankey.step.valueOf",
    defaultMessage: "{count} ({source})",
  }),
  averageOf: defineMessage<{ count: string; sources: number }>({
    id: "sankey.step.averageOf",
    defaultMessage: "{count} over {sources, plural, one {# source} other {# sources}}",
  }),
  nodeTitle: defineMessage<{
    source: string;
    step: string;
    count: string;
    estimated: number;
    partial: number;
  }>({
    id: "sankey.nodeTitle",
    defaultMessage:
      "{source} — {step}: {count}{estimated, plural, =0 {} other { (not measured; the median of the other sources)}}{partial, plural, =0 {} other { (some days missing)}}",
  }),
  ribbonTitle: defineMessage<{
    source: string;
    from: string;
    to: string;
    fromCount: string;
    toCount: string;
  }>({
    id: "sankey.ribbonTitle",
    defaultMessage: "{source} — {from} ({fromCount}) → {to} ({toCount})",
  }),
};
