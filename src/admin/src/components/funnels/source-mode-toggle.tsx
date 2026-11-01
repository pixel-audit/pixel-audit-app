import { Check, Minus } from "lucide-react";
import { defineMessage, useIntl } from "react-intl";

import { nextMode } from "@/lib/source-modes";
import type { SourceMode } from "@/lib/sankey";
import { cn } from "@/lib/utils";

/**
 * A three-state checkbox in the given colour: checked — drawn filled; a
 * dash — drawn as an outline; empty — not drawn. A click moves to the next
 * state. `mixed` (a dashed border) is for a control that stands for several
 * sources that differ; a click then fills them all.
 */
export function SourceModeToggle({
  name,
  color,
  mode,
  onChange,
}: {
  /** Whose mode this is — a data source's name, or what stands for all of them. */
  name: string;
  color: string;
  mode: SourceMode | "mixed";
  onChange: (mode: SourceMode) => void;
}) {
  const intl = useIntl();
  const label = intl.formatMessage(messages.label, { name, mode });
  return (
    <button
      type="button"
      role="checkbox"
      aria-checked={mode === "fill" ? true : mode === "hidden" ? false : "mixed"}
      aria-label={label}
      title={label}
      onClick={() => onChange(mode === "mixed" ? "fill" : nextMode(mode))}
      className={cn(
        "inline-flex size-5 shrink-0 items-center justify-center rounded-sm border-2 transition-colors",
        "focus-visible:ring-2 focus-visible:ring-ring focus-visible:outline-none",
        mode === "mixed" && "border-dashed",
      )}
      style={{
        borderColor: color,
        backgroundColor: mode === "fill" ? color : "transparent",
        color: mode === "fill" ? "white" : color,
      }}
    >
      {mode === "fill" && <Check aria-hidden className="size-3.5" strokeWidth={3} />}
      {mode === "outline" && <Minus aria-hidden className="size-3.5" strokeWidth={3} />}
    </button>
  );
}

const messages = {
  label: defineMessage<{ name: string; mode: string }>({
    id: "sourceMode.label",
    defaultMessage:
      "{name}: {mode, select, fill {drawn filled} outline {drawn as an outline} mixed {drawn differently} other {hidden}} — click to change",
  }),
};
