import { describe, expect, it } from "vitest";

import type { DataSource, StepReport, StepReportPoint } from "@/api/generated/model";
import {
  areaPath,
  dayX,
  linePath,
  MARGIN,
  nearestDay,
  niceTicks,
  pickDateTicks,
  stepSeriesLayout,
} from "@/lib/step-series";

const source = (id: string): DataSource => ({
  id,
  name: id,
  description: null,
  type: "postgres_query",
  connection_id: "c",
  connection: { id: "c", name: "c", type: "postgres" },
  settings: {},
  position: 0,
  color: "#123456",
  step_parameters: [],
});

const day = (date: string, count: number | null, status: StepReportPoint["status"] = "ok") => ({
  date,
  count,
  status: count === null && status === "ok" ? "missing" : status,
  error: null,
});

const report = (
  series: Array<{ id: string; measured?: boolean; counts: Array<number | null> }>,
): StepReport => ({
  funnel_id: "f",
  step: { id: "s", name: "Visit", description: null, position: 0 },
  date_from: "2026-10-01",
  date_to: "2026-10-03",
  days: 3,
  data_sources: series.map((s) => source(s.id)),
  series: series.map((s) => ({
    data_source_id: s.id,
    measured: s.measured ?? true,
    points: s.counts.map((count, index) => day(`2026-10-0${index + 1}`, count)),
  })),
});

const frame = { width: 400, height: 200 };

describe("the count axis", () => {
  it("picks round ticks that cover the maximum", () => {
    expect(niceTicks(0)).toEqual([0]);
    expect(niceTicks(7)).toEqual([0, 2, 4, 6, 8]);
    expect(niceTicks(100)).toEqual([0, 20, 40, 60, 80, 100]);
    expect(niceTicks(1234)).toEqual([0, 500, 1000, 1500]);
  });
});

describe("the date axis", () => {
  it("spaces the days across the plot, one day in the middle", () => {
    expect(dayX(0, 3, 0, 100)).toBe(0);
    expect(dayX(1, 3, 0, 100)).toBe(50);
    expect(dayX(2, 3, 0, 100)).toBe(100);
    expect(dayX(0, 1, 0, 100)).toBe(50);
  });

  it("labels every k-th day so at most about `most` show", () => {
    const dates = Array.from({ length: 30 }, (_, i) => `d${i}`);
    expect(pickDateTicks(dates, 5)).toEqual([0, 6, 12, 18, 24]);
    expect(pickDateTicks(dates.slice(0, 3), 10)).toEqual([0, 1, 2]);
    expect(pickDateTicks([], 5)).toEqual([]);
  });

  it("finds the nearest day to an x", () => {
    expect(nearestDay([0, 50, 100], 30)).toBe(1);
    expect(nearestDay([0, 50, 100], 24)).toBe(0);
    expect(nearestDay([], 24)).toBeUndefined();
  });
});

describe("stepSeriesLayout", () => {
  it("scales every shown source on one axis and breaks a line at a day without a count", () => {
    const layout = stepSeriesLayout(
      report([
        { id: "a", counts: [10, null, 30] },
        { id: "b", counts: [5, 5, 5] },
      ]),
      [
        { source: source("a"), mode: "fill" },
        { source: source("b"), mode: "outline" },
      ],
      frame,
    );
    expect(layout.dates).toEqual(["2026-10-01", "2026-10-02", "2026-10-03"]);
    expect(layout.yMax).toBe(30);
    expect(layout.plot.y0).toBe(MARGIN.top);

    const [a, b] = layout.lines;
    expect(a!.runs.map((run) => run.length)).toEqual([1, 1]);
    expect(b!.runs.map((run) => run.length)).toEqual([3]);
    // The top of the plot is the largest count; the baseline is zero.
    expect(a!.points[2]!.y).toBe(layout.plot.y0);
    expect(b!.points[0]!.y).toBeCloseTo(layout.plot.y1 - (layout.plot.y1 - layout.plot.y0) / 6);
    expect(layout.yTicks.map((t) => t.value)).toEqual([0, 10, 20, 30]);
  });

  it("leaves out a source that does not measure the step, and one not shown", () => {
    const layout = stepSeriesLayout(
      report([
        { id: "a", counts: [10, 20, 30] },
        { id: "b", measured: false, counts: [null, null, null] },
      ]),
      [{ source: source("b"), mode: "fill" }],
      frame,
    );
    expect(layout.lines).toEqual([]);
    expect(layout.yMax).toBe(0);
    expect(layout.yTicks).toEqual([]);
  });

  it("draws paths through the runs", () => {
    expect(
      linePath([
        { x: 0, y: 1 },
        { x: 2, y: 3 },
      ]),
    ).toBe("M0,1 L2,3");
    expect(
      areaPath(
        [
          { x: 0, y: 1 },
          { x: 2, y: 3 },
        ],
        10,
      ),
    ).toBe("M0,1 L2,3 L2,10 L0,10 Z");
    expect(areaPath([], 10)).toBe("");
  });
});
