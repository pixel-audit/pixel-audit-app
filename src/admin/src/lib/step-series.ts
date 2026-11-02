import type { DataSource, StepReport, StepReportPoint } from "@/api/generated/model";
import type { ShownSource } from "@/lib/sankey";

/**
 * The step chart's geometry, computed from a step's report for every data
 * source shown: the days along the x axis, one shared count scale up the
 * y axis — the largest count shown is the top of the plot — and per source
 * a line through its counts, broken where a day has none (failed, or not
 * computed yet), so a gap reads as a gap and never as a zero. A source
 * drawn filled also gets the area under each run of its line. Pure, so it
 * is tested without a DOM.
 */

export type Frame = { width: number; height: number };

/** Room for the count labels on the left and the date labels below. */
export const MARGIN = { top: 12, right: 24, bottom: 28, left: 48 };

/** A day of a source's line: where it sits, and what it says. */
export type LinePoint = {
  date: string;
  x: number;
  /** Undefined when the day has no count — the line breaks here. */
  y: number | undefined;
  count: number | null;
  status: StepReportPoint["status"];
  error: string | null;
};

export type XY = { x: number; y: number };

export type SourceLine = {
  source: DataSource;
  mode: ShownSource["mode"];
  points: LinePoint[];
  /** The runs of consecutive counted days, each a polyline. */
  runs: XY[][];
};

export type Tick = { value: number; y: number };
export type DateTick = { date: string; x: number };

export type StepSeriesLayout = {
  dates: string[];
  /** The x of each day, by its index in `dates`. */
  xs: number[];
  lines: SourceLine[];
  yTicks: Tick[];
  xTicks: DateTick[];
  /** The count at the top of the plot; 0 when nothing shown has a count. */
  yMax: number;
  plot: { x0: number; x1: number; y0: number; y1: number };
};

/** The x of day `index` of `count` days across [x0, x1]; one day sits in the middle. */
export function dayX(index: number, count: number, x0: number, x1: number): number {
  if (count <= 1) return (x0 + x1) / 2;
  return x0 + ((x1 - x0) * index) / (count - 1);
}

/**
 * Round tick values for a count axis up to `max`: 1, 2 or 5 times a power
 * of ten, so there are between about three and six of them. `[0]` when
 * there is nothing to scale.
 */
export function niceTicks(max: number, target = 5): number[] {
  if (max <= 0) return [0];
  const rough = max / target;
  const power = 10 ** Math.floor(Math.log10(rough));
  const unit = [1, 2, 5, 10].map((m) => m * power).find((candidate) => candidate >= rough)!;
  const ticks: number[] = [];
  for (let value = 0; value <= max; value += unit) ticks.push(value);
  if (ticks[ticks.length - 1]! < max) ticks.push(ticks.length * unit);
  return ticks;
}

/** Every `step`-th date, from the first, so at most about `most` labels show. */
export function pickDateTicks(dates: string[], most: number): number[] {
  if (dates.length === 0 || most <= 0) return [];
  const step = Math.max(1, Math.ceil(dates.length / most));
  const picked: number[] = [];
  for (let index = 0; index < dates.length; index += step) picked.push(index);
  return picked;
}

/** Runs of consecutive points with a y: the segments of a broken line. */
export function runsOf(points: LinePoint[]): XY[][] {
  const runs: XY[][] = [];
  let current: XY[] = [];
  for (const point of points) {
    if (point.y === undefined) {
      if (current.length > 0) runs.push(current);
      current = [];
    } else {
      current.push({ x: point.x, y: point.y });
    }
  }
  if (current.length > 0) runs.push(current);
  return runs;
}

export function stepSeriesLayout(
  report: StepReport,
  shown: ShownSource[],
  frame: Frame,
): StepSeriesLayout {
  const plot = {
    x0: MARGIN.left,
    x1: Math.max(frame.width - MARGIN.right, MARGIN.left),
    y0: MARGIN.top,
    y1: Math.max(frame.height - MARGIN.bottom, MARGIN.top),
  };
  const seriesOf = new Map(report.series.map((series) => [series.data_source_id, series]));
  const first = report.series[0];
  const dates = first ? first.points.map((point) => point.date) : [];
  const xs = dates.map((_, index) => dayX(index, dates.length, plot.x0, plot.x1));

  const drawn = shown.flatMap(({ source, mode }) => {
    const series = seriesOf.get(source.id);
    return series && series.measured ? [{ source, mode, series }] : [];
  });
  const yMax = Math.max(
    0,
    ...drawn.flatMap((d) => d.series.points.map((point) => point.count ?? 0)),
  );
  const ticks = niceTicks(yMax);
  const top = ticks[ticks.length - 1]!;
  const yOf = (count: number) =>
    top > 0 ? plot.y1 - ((plot.y1 - plot.y0) * count) / top : plot.y1;

  const lines: SourceLine[] = drawn.map(({ source, mode, series }) => {
    const points: LinePoint[] = series.points.map((point, index) => ({
      date: point.date,
      x: xs[index]!,
      y: point.count === null ? undefined : yOf(point.count),
      count: point.count,
      status: point.status,
      error: point.error,
    }));
    return { source, mode, points, runs: runsOf(points) };
  });

  const yTicks: Tick[] = yMax > 0 ? ticks.map((value) => ({ value, y: yOf(value) })) : [];
  const most = Math.max(1, Math.floor((plot.x1 - plot.x0) / 72));
  const xTicks: DateTick[] = pickDateTicks(dates, most).map((index) => ({
    date: dates[index]!,
    x: xs[index]!,
  }));

  return { dates, xs, lines, yTicks, xTicks, yMax: top, plot };
}

/** An SVG path along a run of points. */
export const linePath = (run: XY[]): string =>
  run.map((point, index) => `${index === 0 ? "M" : "L"}${point.x},${point.y}`).join(" ");

/** An SVG path of the area between a run and the baseline. */
export function areaPath(run: XY[], baseline: number): string {
  if (run.length === 0) return "";
  const first = run[0]!;
  const last = run[run.length - 1]!;
  return `${linePath(run)} L${last.x},${baseline} L${first.x},${baseline} Z`;
}

/** The day nearest to an x on the plot; undefined when there are no days. */
export function nearestDay(xs: number[], x: number): number | undefined {
  if (xs.length === 0) return undefined;
  let best = 0;
  for (let index = 1; index < xs.length; index++) {
    if (Math.abs(xs[index]! - x) < Math.abs(xs[best]! - x)) best = index;
  }
  return best;
}
