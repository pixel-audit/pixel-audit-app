import { useLayoutEffect, useRef, useState } from "react";
import { defineMessage, defineMessages, useIntl, type IntlShape } from "react-intl";

import type { StepReport } from "@/api/generated/model";
import { NonIdealState } from "@/components/ui/non-ideal-state";
import { formatDay } from "@/lib/date-range";
import type { ShownSource } from "@/lib/sankey";
import {
  areaPath,
  linePath,
  nearestDay,
  stepSeriesLayout,
  type SourceLine,
} from "@/lib/step-series";

const HEIGHT = 300;
const FILL_OPACITY = 0.15;

/**
 * One step day by day: a line per shown data source through its daily
 * counts, in the source's colour — with the area under it when drawn
 * filled, the line alone as an outline — all on one count scale, the days
 * along the bottom. A day a source failed on or has not computed yet
 * breaks its line. Moving over the chart raises a hairline at the nearest
 * day and a readout of every shown source's count that day.
 *
 * The chart's box is always there, at its fixed height, whatever is shown
 * — the box is what the width is measured on.
 */
export function StepChart({ report, shown }: { report: StepReport; shown: ShownSource[] }) {
  const intl = useIntl();
  const containerRef = useRef<HTMLDivElement>(null);
  const [width, setWidth] = useState(0);
  const [hovered, setHovered] = useState<number | undefined>(undefined);

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

  const layout = width > 0 ? stepSeriesLayout(report, shown, { width, height: HEIGHT }) : null;

  const empty =
    shown.length === 0
      ? messages.nothingShown
      : layout && layout.lines.length === 0
        ? messages.nothingMeasured
        : null;

  const day = hovered !== undefined && layout ? layout.dates[hovered] : undefined;
  const hoverX = hovered !== undefined && layout ? layout.xs[hovered] : undefined;
  // The readout sits to the right of the hairline, or to the left past the middle.
  const readoutOnLeft = layout !== null && hoverX !== undefined && hoverX > width / 2;

  return (
    <div ref={containerRef} className="relative w-full" style={{ height: HEIGHT }}>
      {empty !== null ? (
        <div className="flex h-full items-center justify-center">
          <NonIdealState>{intl.formatMessage(empty)}</NonIdealState>
        </div>
      ) : (
        layout && (
          <>
            <svg
              width={width}
              height={HEIGHT}
              role="img"
              aria-label={intl.formatMessage(messages.chartLabel, { step: report.step.name })}
              className="block"
              onPointerMove={(event) => {
                const box = event.currentTarget.getBoundingClientRect();
                setHovered(nearestDay(layout.xs, event.clientX - box.left));
              }}
              onPointerLeave={() => setHovered(undefined)}
            >
              {/* The grid and the count labels. */}
              {layout.yTicks.map((tick) => (
                <g key={tick.value}>
                  <line
                    x1={layout.plot.x0}
                    x2={layout.plot.x1}
                    y1={tick.y}
                    y2={tick.y}
                    stroke="var(--border)"
                    strokeWidth={1}
                  />
                  <text
                    x={layout.plot.x0 - 8}
                    y={tick.y}
                    textAnchor="end"
                    dominantBaseline="middle"
                    className="fill-muted-foreground text-[11px] tabular-nums"
                  >
                    {intl.formatNumber(tick.value, { notation: "compact" })}
                  </text>
                </g>
              ))}
              {layout.yTicks.length === 0 && (
                <line
                  x1={layout.plot.x0}
                  x2={layout.plot.x1}
                  y1={layout.plot.y1}
                  y2={layout.plot.y1}
                  stroke="var(--border)"
                  strokeWidth={1}
                />
              )}
              {/* The dates. */}
              {layout.xTicks.map((tick) => (
                <text
                  key={tick.date}
                  x={tick.x}
                  y={layout.plot.y1 + 18}
                  textAnchor="middle"
                  className="fill-muted-foreground text-[11px]"
                >
                  {formatShortDay(intl, tick.date)}
                </text>
              ))}
              {/* The areas under the lines, then the lines over them. */}
              {layout.lines.map(
                (line) =>
                  line.mode === "fill" &&
                  line.runs.map((run, index) => (
                    <path
                      key={`${line.source.id}:${index}`}
                      d={areaPath(run, layout.plot.y1)}
                      fill={line.source.color}
                      fillOpacity={FILL_OPACITY}
                      stroke="none"
                    />
                  )),
              )}
              {layout.lines.map((line) =>
                line.runs.map((run, index) => (
                  <path
                    key={`${line.source.id}:${index}`}
                    d={linePath(run)}
                    fill="none"
                    stroke={line.source.color}
                    strokeWidth={2}
                    strokeLinejoin="round"
                    strokeLinecap="round"
                  />
                )),
              )}
              {/* A lone counted day has no line to show it: a dot. */}
              {layout.lines.map((line) =>
                line.runs
                  .filter((run) => run.length === 1)
                  .map((run, index) => (
                    <circle
                      key={`${line.source.id}:dot:${index}`}
                      cx={run[0]!.x}
                      cy={run[0]!.y}
                      r={3}
                      fill={line.source.color}
                    />
                  )),
              )}
              {/* The hairline at the hovered day, and a marker on each line there. */}
              {hoverX !== undefined && (
                <g pointerEvents="none">
                  <line
                    x1={hoverX}
                    x2={hoverX}
                    y1={layout.plot.y0}
                    y2={layout.plot.y1}
                    stroke="var(--muted-foreground)"
                    strokeWidth={1}
                    strokeDasharray="3 3"
                  />
                  {layout.lines.map((line) => {
                    const point = line.points[hovered!];
                    return point?.y === undefined ? null : (
                      <circle
                        key={line.source.id}
                        cx={point.x}
                        cy={point.y}
                        r={4}
                        fill={line.source.color}
                        stroke="var(--card)"
                        strokeWidth={2}
                      />
                    );
                  })}
                </g>
              )}
            </svg>
            {day !== undefined && hoverX !== undefined && hovered !== undefined && (
              <div
                className="pointer-events-none absolute top-2 z-10 rounded-md border bg-popover px-3 py-2 text-xs text-popover-foreground shadow-md"
                style={readoutOnLeft ? { right: width - hoverX + 8 } : { left: hoverX + 8 }}
              >
                <p className="mb-1 font-medium">{formatDay(intl, day)}</p>
                <dl className="grid grid-cols-[auto_1fr] items-center gap-x-2 gap-y-0.5">
                  {layout.lines.map((line) => (
                    <Readout key={line.source.id} line={line} index={hovered} />
                  ))}
                </dl>
              </div>
            )}
          </>
        )
      )}
    </div>
  );
}

/** One source's row of the readout: the value in bold, the name after it. */
function Readout({ line, index }: { line: SourceLine; index: number }) {
  const intl = useIntl();
  const point = line.points[index];
  if (!point) return null;
  const value =
    point.count !== null
      ? intl.formatNumber(point.count)
      : point.status === "error"
        ? intl.formatMessage(messages.failed)
        : intl.formatMessage(messages.notComputed);
  return (
    <>
      <dt className="flex items-center gap-2">
        <span
          aria-hidden
          className="inline-block h-0.5 w-3 rounded-full"
          style={{ backgroundColor: line.source.color }}
        />
        <span className={point.count !== null ? "font-semibold tabular-nums" : "italic"}>
          {value}
        </span>
      </dt>
      <dd className="text-muted-foreground">{line.source.name}</dd>
    </>
  );
}

/** "1 Oct": a date label on the axis, in UTC like every day of the API. */
const formatShortDay = (intl: IntlShape, date: string): string =>
  intl.formatDate(new Date(date), { day: "numeric", month: "short", timeZone: "UTC" });

const messages = {
  ...defineMessages({
    nothingShown: {
      id: "stepChart.nothingShown",
      defaultMessage: "Every data source is hidden — switch one on in the table below.",
    },
    nothingMeasured: {
      id: "stepChart.nothingMeasured",
      defaultMessage:
        "The shown data sources do not measure this step yet — set their parameters under Setup.",
    },
    failed: { id: "stepChart.failed", defaultMessage: "failed" },
    notComputed: { id: "stepChart.notComputed", defaultMessage: "not computed" },
  }),
  chartLabel: defineMessage<{ step: string }>({
    id: "stepChart.chartLabel",
    defaultMessage: "{step}: each data source's count per day",
  }),
};
