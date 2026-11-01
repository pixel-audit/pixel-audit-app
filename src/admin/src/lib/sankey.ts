import type { DataSource, Report, ReportCell, Step } from "@/api/generated/model";

/**
 * The funnel chart's geometry, computed from the report for every data
 * source shown: a column per step, and in each column one node per source
 * whose height is the source's count on one scale shared by all of them —
 * the largest value shown is the full plot height — so the sources lie
 * over one another and are compared by eye. Everything is centred on the
 * plot's midline. From each node a ribbon narrows to the source's next
 * node, as tall as this step on the left and as the next on the right,
 * both edges curving in: the funnel's shape is the reduction itself.
 *
 * A step a source does not measure is drawn all the same when other
 * sources measure it: at the median of their values, marked as estimated,
 * so the source's ribbons keep their shape across it. Shown alone, a
 * source skips such a step. Pure, so it is tested without a DOM.
 */

/** How a source is drawn: a translucent fill, an outline, or not at all. */
export type SourceMode = "fill" | "outline" | "hidden";

export type ShownSource = { source: DataSource; mode: Exclude<SourceMode, "hidden"> };

export type Frame = { width: number; height: number };

export type ColumnLayout = { step: Step; x0: number; x1: number };

export type NodeLayout = {
  source: DataSource;
  mode: ShownSource["mode"];
  step: Step;
  x0: number;
  x1: number;
  y0: number;
  y1: number;
  count: number;
  /** Some days of the range failed or are not computed yet. */
  partial: boolean;
  /** Not measured by this source: the median of the other sources' counts. */
  estimated: boolean;
};

export type RibbonLayout = {
  source: DataSource;
  mode: ShownSource["mode"];
  from: Step;
  to: Step;
  /** The ribbon's left edge (the from node's right edge) and right edge. */
  x0: number;
  x1: number;
  /** The left edge spans [y0Left, y1Left], the right edge [y0Right, y1Right]; both centred. */
  y0Left: number;
  y1Left: number;
  y0Right: number;
  y1Right: number;
  fromCount: number;
  toCount: number;
};

export type FunnelLayout = {
  columns: ColumnLayout[];
  nodes: NodeLayout[];
  ribbons: RibbonLayout[];
  /** The count a full-height node stands for; 0 when nothing is shown. */
  scaleMax: number;
};

export const MARGIN = { top: 8, right: 8, bottom: 8, left: 8 };
const NODE_WIDTH = 12;

const cellOf = (report: Report, sourceId: string, stepId: string): ReportCell | undefined =>
  report.cells.find((cell) => cell.data_source_id === sourceId && cell.step_id === stepId);

/** The median of a non-empty list. */
export function median(values: number[]): number {
  const sorted = [...values].sort((a, b) => a - b);
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 1 ? sorted[middle]! : (sorted[middle - 1]! + sorted[middle]!) / 2;
}

type Counted = { step: Step; count: number; partial: boolean; estimated: boolean };

/**
 * A source's value at every step it can be drawn at: its own count, or —
 * when `fillGaps` and other sources counted the step — their median.
 */
function countedSteps(report: Report, source: DataSource, fillGaps: boolean): Counted[] {
  return report.steps.flatMap((step): Counted[] => {
    const cell = cellOf(report, source.id, step.id);
    if (cell?.count != null) {
      return [
        {
          step,
          count: cell.count,
          partial: cell.days_error > 0 || cell.days_missing > 0,
          estimated: false,
        },
      ];
    }
    if (!fillGaps) return [];
    const others = report.cells
      .filter((c) => c.step_id === step.id && c.data_source_id !== source.id && c.count != null)
      .map((c) => c.count as number);
    return others.length > 0
      ? [{ step, count: median(others), partial: false, estimated: true }]
      : [];
  });
}

export function funnelLayout(report: Report, shown: ShownSource[], frame: Frame): FunnelLayout {
  const steps = report.steps;
  const plotWidth = Math.max(frame.width - MARGIN.left - MARGIN.right, 0);
  const plotHeight = Math.max(frame.height - MARGIN.top - MARGIN.bottom, 0);
  const columnGap =
    steps.length > 1 ? (plotWidth - NODE_WIDTH) / (steps.length - 1) : plotWidth - NODE_WIDTH;

  const columns: ColumnLayout[] = steps.map((step, index) => {
    const x0 = MARGIN.left + index * columnGap;
    return { step, x0, x1: x0 + NODE_WIDTH };
  });
  const columnOf = new Map(columns.map((column) => [column.step.id, column]));

  const fillGaps = shown.length > 1;
  const counted = shown.map(({ source, mode }) => ({
    source,
    mode,
    steps: countedSteps(report, source, fillGaps),
  }));
  const scaleMax = Math.max(0, ...counted.flatMap((c) => c.steps.map((s) => s.count)));
  const scale = scaleMax > 0 ? plotHeight / scaleMax : 0;
  const middle = MARGIN.top + plotHeight / 2;
  const edges = (count: number) => {
    const half = (count * scale) / 2;
    return { y0: middle - half, y1: middle + half };
  };

  const nodes: NodeLayout[] = [];
  const ribbons: RibbonLayout[] = [];

  for (const { source, mode, steps: entries } of counted) {
    entries.forEach((entry, index) => {
      const column = columnOf.get(entry.step.id);
      if (!column) return;
      const own = edges(entry.count);
      nodes.push({
        source,
        mode,
        step: entry.step,
        x0: column.x0,
        x1: column.x1,
        y0: own.y0,
        y1: own.y1,
        count: entry.count,
        partial: entry.partial,
        estimated: entry.estimated,
      });

      const next = entries[index + 1];
      const nextColumn = next && columnOf.get(next.step.id);
      if (!next || !nextColumn) return;
      const theirs = edges(next.count);
      ribbons.push({
        source,
        mode,
        from: entry.step,
        to: next.step,
        x0: column.x1,
        x1: nextColumn.x0,
        y0Left: own.y0,
        y1Left: own.y1,
        y0Right: theirs.y0,
        y1Right: theirs.y1,
        fromCount: entry.count,
        toCount: next.count,
      });
    });
  }

  return { columns, nodes, ribbons, scaleMax };
}

/** An SVG path for a ribbon: both edges curve from the left height to the right one. */
export function ribbonPath(
  r: Pick<RibbonLayout, "x0" | "x1" | "y0Left" | "y1Left" | "y0Right" | "y1Right">,
): string {
  const cx = (r.x0 + r.x1) / 2;
  return [
    `M${r.x0},${r.y0Left}`,
    `C${cx},${r.y0Left} ${cx},${r.y0Right} ${r.x1},${r.y0Right}`,
    `L${r.x1},${r.y1Right}`,
    `C${cx},${r.y1Right} ${cx},${r.y1Left} ${r.x0},${r.y1Left}`,
    "Z",
  ].join(" ");
}

/** A source's count of a step, for the step's summary. */
export type StepValue = { source: DataSource; count: number };

export type StepStats = { min: StepValue; max: StepValue; average: number; sources: number };

/**
 * What the sources that measure a step say: the lowest and the highest
 * (with the source that says it) and the average. Over every source of
 * the report, hidden or not — the question is how far they disagree.
 * Undefined when none measures the step.
 */
export function stepStats(report: Report, stepId: string): StepStats | undefined {
  const values: StepValue[] = report.data_sources.flatMap((source) => {
    const cell = cellOf(report, source.id, stepId);
    return cell?.count != null ? [{ source, count: cell.count }] : [];
  });
  if (values.length === 0) return undefined;
  const min = values.reduce((a, b) => (b.count < a.count ? b : a));
  const max = values.reduce((a, b) => (b.count > a.count ? b : a));
  const average = values.reduce((sum, v) => sum + v.count, 0) / values.length;
  return { min, max, average, sources: values.length };
}
