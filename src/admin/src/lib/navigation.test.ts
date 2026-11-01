import { describe, expect, it } from "vitest";

import {
  firstScreen,
  groupOf,
  isAtScreen,
  NAV_GROUPS,
  navTrail,
  trailTitle,
} from "@/lib/navigation";

describe("the navigation tree", () => {
  it("places a page in its group", () => {
    expect(groupOf("/funnels")?.url).toBe("/funnels");
    expect(groupOf("/funnels/checkout/setup")?.url).toBe("/funnels");
    expect(groupOf("/connections/abc")?.url).toBe("/connections");
    expect(groupOf("/")).toBeUndefined();
    expect(groupOf("/funnelsx")).toBeUndefined();
  });

  it("leads a group to its first screen", () => {
    for (const group of NAV_GROUPS) expect(firstScreen(group)).toBe(group.url);
  });

  it("keeps a screen open on its item pages", () => {
    const funnels = NAV_GROUPS[0]!.categories[0]!.items[0]!;
    expect(isAtScreen("/funnels/checkout", funnels)).toBe(true);
    expect(isAtScreen("/connections", funnels)).toBe(false);
  });
});

describe("navTrail — the trail the tree knows", () => {
  it("collapses a screen named like its group into one crumb", () => {
    expect(navTrail("/funnels/checkout/setup").map((c) => [c.label.id, c.to])).toEqual([
      ["nav.funnels", "/funnels"],
    ]);
  });

  it("is empty on the dashboard", () => {
    expect(navTrail("/")).toEqual([]);
  });
});

describe("trailTitle — the document's title from the trail", () => {
  it("reads the trail from the page up and ends with the brand", () => {
    expect(trailTitle(["Dashboard", "Funnels", "Checkout"])).toBe(
      "Checkout — Funnels — PixelAudit",
    );
  });

  it("names the dashboard only when it is the page", () => {
    expect(trailTitle(["Dashboard"])).toBe("Dashboard — PixelAudit");
  });
});
