import { describe, expect, it } from "vitest";

import type { DataSource } from "@/api/generated/model";
import { allModes, commonMode, nextMode, parseModes, serializeModes } from "@/lib/source-modes";

const source = (id: string) => ({ id }) as DataSource;

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

  it("knows the mode all sources share", () => {
    const sources = [source("db"), source("warehouse")];
    expect(commonMode(sources, {})).toBe("fill");
    expect(commonMode(sources, { db: "hidden", warehouse: "hidden" })).toBe("hidden");
    expect(commonMode(sources, { db: "outline" })).toBe("mixed");
  });

  it("puts every source in one mode", () => {
    expect(allModes([source("db"), source("warehouse")], "outline")).toEqual({
      db: "outline",
      warehouse: "outline",
    });
  });
});
