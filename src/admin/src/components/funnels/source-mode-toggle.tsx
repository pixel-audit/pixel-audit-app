import { Check, Minus } from "lucide-react";
import { defineMessage, useIntl } from "react-intl";

import type { DataSource } from "@/api/generated/model";
import { nextMode } from "@/lib/source-modes";
import type { SourceMode } from "@/lib/sankey";
import { cn } from "@/lib/utils";

/**
 * A three-state checkbox in the data source's colour: checked — the source
 * is drawn filled; a dash — drawn as an outline; empty — not drawn. A
 * click moves to the next state.
 */
export function SourceModeToggle({
  source,
  mode,
  onChange,
}: {
  source: DataSource;
  mode: SourceMode;
  onChange: (mode: SourceMode) => void;
}) {
  const intl = useIntl();
  const label = intl.formatMessage(messages.label, {
    source: source.name,
    mode,
  });
  return (
    <button
      type="button"
      role="checkbox"
      aria-checked={mode === "fill" ? true : mode === "outline" ? "mixed" : false}
      aria-label={label}
      title={label}
      onClick={() => onChange(nextMode(mode))}
      className={cn(
        "inline-flex size-5 shrink-0 items-center justify-center rounded-sm border-2 transition-colors",
        "focus-visible:ring-2 focus-visible:ring-ring focus-visible:outline-none",
      )}
      style={{
        borderColor: source.color,
        backgroundColor: mode === "fill" ? source.color : "transparent",
        color: mode === "fill" ? "white" : source.color,
      }}
    >
      {mode === "fill" && <Check aria-hidden className="size-3.5" strokeWidth={3} />}
      {mode === "outline" && <Minus aria-hidden className="size-3.5" strokeWidth={3} />}
    </button>
  );
}

const messages = {
  label: defineMessage<{ source: string; mode: string }>({
    id: "sourceMode.label",
    defaultMessage:
      "{source}: {mode, select, fill {drawn filled} outline {drawn as an outline} other {hidden}} — click to change",
  }),
};
