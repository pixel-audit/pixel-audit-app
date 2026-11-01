import type { DataSource } from "@/api/generated/model";
import type { ShownSource, SourceMode } from "@/lib/sankey";

/**
 * How each data source is drawn on the funnel chart, as the address
 * carries it: `show=db:fill,warehouse:outline` — a source left out is
 * shown filled (the default), one named `hidden` is not drawn. Keyed by
 * the source's code, so a link stays readable.
 */
export type SourceModes = Record<string, SourceMode>;

const MODES: readonly SourceMode[] = ["fill", "outline", "hidden"];

const isMode = (value: string): value is SourceMode => (MODES as readonly string[]).includes(value);

/** The modes named by a `show` value; anything malformed is ignored. */
export function parseModes(value: unknown): SourceModes {
  if (typeof value !== "string" || value === "") return {};
  const modes: SourceModes = {};
  for (const part of value.split(",")) {
    const [code, mode] = part.split(":");
    if (code && mode && isMode(mode) && mode !== "fill") modes[code] = mode;
  }
  return modes;
}

/** The `show` value for the modes: only what differs from the default, or undefined. */
export function serializeModes(modes: SourceModes): string | undefined {
  const parts = Object.entries(modes)
    .filter(([, mode]) => mode !== "fill")
    .map(([code, mode]) => `${code}:${mode}`);
  return parts.length > 0 ? parts.join(",") : undefined;
}

export const modeOf = (modes: SourceModes, source: DataSource): SourceMode =>
  modes[source.code] ?? "fill";

/** The next mode when the control is clicked: fill → outline → hidden → fill. */
export const nextMode = (mode: SourceMode): SourceMode =>
  mode === "fill" ? "outline" : mode === "outline" ? "hidden" : "fill";

/** The sources to draw, in the funnel's order, with how. */
export function shownSources(sources: DataSource[], modes: SourceModes): ShownSource[] {
  return sources.flatMap((source) => {
    const mode = modeOf(modes, source);
    return mode === "hidden" ? [] : [{ source, mode }];
  });
}
