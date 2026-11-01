import { describe, expect, it } from "vitest";

import { nextMode, parseModes, serializeModes } from "@/lib/source-modes";

describe("the source modes in the address", () => {
  it("reads what differs from the default and ignores the rest", () => {
    expect(parseModes("db:outline,warehouse:hidden,fb:fill,bogus,x:nope")).toEqual({
      db: "outline",
      warehouse: "hidden",
    });
    expect(parseModes(undefined)).toEqual({});
    expect(parseModes("")).toEqual({});
  });

  it("writes only what differs from the default", () => {
    expect(serializeModes({ db: "fill", warehouse: "outline" })).toBe("warehouse:outline");
    expect(serializeModes({ db: "fill" })).toBeUndefined();
  });

  it("cycles fill → outline → hidden → fill", () => {
    expect(nextMode("fill")).toBe("outline");
    expect(nextMode("outline")).toBe("hidden");
    expect(nextMode("hidden")).toBe("fill");
  });
});
