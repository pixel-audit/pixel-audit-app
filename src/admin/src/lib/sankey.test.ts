import { describe, expect, it } from "vitest";

import type { DataSource, Report } from "@/api/generated/model";
import { funnelLayout, MARGIN, median, ribbonPath, stepStats } from "@/lib/sankey";

const step = (id: string, position: number) => ({
  id,
  name: id,
  description: null,
  position,
});

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

const cell = (
  data_source_id: string,
  step_id: string,
  count: number | null,
  extra: Partial<{ days_error: number; days_missing: number }> = {},
) => ({
  data_source_id,
  step_id,
  count,
  days_ok: count === null ? 0 : 3,
  days_error: 0,
  days_missing: 0,
  last_error: null,
  ...extra,
});

const report = (cells: Report["cells"]): Report => ({
  funnel_id: "f",
  date_from: "2026-10-01",
  date_to: "2026-10-03",
  days: 3,
  steps: [step("visit", 0), step("cart", 1), step("purchase", 2)],
  data_sources: [],
  cells,
  conversions: [],
});

// A plot 100px tall, so a count of N on a scale whose max is 100 is N px.
const frame = { width: 416, height: MARGIN.top + 100 + MARGIN.bottom };

describe("funnelLayout — the sources over one another on one scale", () => {
  it("scales every node by the largest count shown, top-aligned", () => {
    const layout = funnelLayout(
      report([
        cell("a", "visit", 100),
        cell("a", "cart", 40),
        cell("a", "purchase", 10),
        cell("b", "visit", 50),
        cell("b", "cart", 25),
        cell("b", "purchase", 5),
      ]),
      [
        { source: source("a"), mode: "fill" },
        { source: source("b"), mode: "outline" },
      ],
      frame,
    );

    expect(layout.scaleMax).toBe(100);
    expect(layout.columns.map((c) => c.step.name)).toEqual(["visit", "cart", "purchase"]);
    expect(layout.nodes.map((n) => [n.source.id, n.step.name, n.y1 - n.y0])).toEqual([
      ["a", "visit", 100],
      ["a", "cart", 40],
      ["a", "purchase", 10],
      ["b", "visit", 50],
      ["b", "cart", 25],
      ["b", "purchase", 5],
    ]);
    // Centred on the midline: a node of 40 sits 30 below the top of a 100 plot.
    const middle = MARGIN.top + 50;
    expect(layout.nodes.every((n) => Math.abs((n.y0 + n.y1) / 2 - middle) < 1e-9)).toBe(true);
    expect(layout.nodes[1]?.y0).toBe(middle - 20);
    expect(layout.nodes.find((n) => n.source.id === "b")?.mode).toBe("outline");
  });

  it("narrows each ribbon from this step's height to the next one's", () => {
    const layout = funnelLayout(
      report([cell("a", "visit", 100), cell("a", "cart", 40)]),
      [{ source: source("a"), mode: "fill" }],
      frame,
    );

    expect(layout.ribbons).toHaveLength(1);
    const ribbon = layout.ribbons[0]!;
    expect([ribbon.from.name, ribbon.to.name]).toEqual(["visit", "cart"]);
    expect([ribbon.y1Left - ribbon.y0Left, ribbon.y1Right - ribbon.y0Right]).toEqual([100, 40]);
    expect((ribbon.y0Right + ribbon.y1Right) / 2).toBe((ribbon.y0Left + ribbon.y1Left) / 2);
    expect([ribbon.fromCount, ribbon.toCount]).toEqual([100, 40]);
  });

  it("draws an unmeasured step at the median of the other sources", () => {
    const layout = funnelLayout(
      report([
        cell("a", "visit", 100),
        cell("a", "purchase", 10),
        cell("b", "visit", 90),
        cell("b", "cart", 30),
        cell("b", "purchase", 8),
        cell("c", "visit", 80),
        cell("c", "cart", 50),
        cell("c", "purchase", 6),
      ]),
      [
        { source: source("a"), mode: "fill" },
        { source: source("b"), mode: "fill" },
        { source: source("c"), mode: "fill" },
      ],
      frame,
    );

    const cart = layout.nodes.find((n) => n.source.id === "a" && n.step.name === "cart");
    expect(cart).toMatchObject({ count: 40, estimated: true });
    expect(
      layout.ribbons.filter((r) => r.source.id === "a").map((r) => [r.from.name, r.to.name]),
    ).toEqual([
      ["visit", "cart"],
      ["cart", "purchase"],
    ]);
  });

  it("takes the other sources' values even when they are hidden", () => {
    const layout = funnelLayout(
      report([cell("a", "visit", 100), cell("b", "visit", 90), cell("b", "cart", 30)]),
      [
        { source: source("a"), mode: "fill" },
        { source: source("c"), mode: "fill" },
      ],
      frame,
    );
    expect(layout.nodes.find((n) => n.source.id === "a" && n.step.name === "cart")?.count).toBe(30);
  });

  it("skips an unmeasured step when the source is shown alone", () => {
    const layout = funnelLayout(
      report([cell("a", "visit", 100), cell("a", "purchase", 10), cell("b", "cart", 30)]),
      [{ source: source("a"), mode: "fill" }],
      frame,
    );

    expect(layout.nodes.map((n) => n.step.name)).toEqual(["visit", "purchase"]);
    expect(layout.ribbons.map((r) => [r.from.name, r.to.name])).toEqual([["visit", "purchase"]]);
  });

  it("marks a node whose days are incomplete", () => {
    const layout = funnelLayout(
      report([cell("a", "visit", 100, { days_error: 1 })]),
      [{ source: source("a"), mode: "fill" }],
      frame,
    );
    expect(layout.nodes[0]?.partial).toBe(true);
  });

  it("is empty with nothing shown", () => {
    const layout = funnelLayout(report([cell("a", "visit", 100)]), [], frame);
    expect(layout.nodes).toEqual([]);
    expect(layout.scaleMax).toBe(0);
  });
});

describe("median", () => {
  it("takes the middle value, or the mean of the two middle ones", () => {
    expect(median([30, 10, 20])).toBe(20);
    expect(median([30, 50])).toBe(40);
    expect(median([7])).toBe(7);
  });
});

describe("ribbonPath", () => {
  it("starts at the left edge and closes", () => {
    const path = ribbonPath({ x0: 10, x1: 50, y0Left: 0, y1Left: 20, y0Right: 5, y1Right: 15 });
    expect(path.startsWith("M10,0")).toBe(true);
    expect(path.endsWith("Z")).toBe(true);
  });
});

describe("stepStats — how far the sources disagree on a step", () => {
  it("names the lowest and the highest and averages them all", () => {
    const r = report([cell("a", "visit", 100), cell("b", "visit", 70), cell("c", "visit", 85)]);
    r.data_sources = [source("a"), source("b"), source("c")];
    const stats = stepStats(r, "visit");
    expect(stats?.min).toMatchObject({ count: 70, source: { id: "b" } });
    expect(stats?.max).toMatchObject({ count: 100, source: { id: "a" } });
    expect(stats?.average).toBe(85);
    expect(stats?.sources).toBe(3);
    expect(stepStats(r, "cart")).toBeUndefined();
  });
});
