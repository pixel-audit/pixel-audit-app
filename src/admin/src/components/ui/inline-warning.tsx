import { TriangleAlert } from "lucide-react";
import type { ReactNode } from "react";

import { cn } from "@/lib/utils";

/**
 * A warning inside a card or a dialog: something the person should know
 * before they go on — a save that will drop data, a setting that does not
 * take effect. Not for a failed load or an empty list (`NonIdealState`).
 */
export function InlineWarning({
  className,
  children,
}: {
  className?: string;
  children: ReactNode;
}) {
  return (
    <p
      className={cn(
        "flex gap-2 rounded-md border border-destructive/40 bg-destructive/5 p-3 text-xs text-destructive",
        className,
      )}
    >
      <TriangleAlert className="mt-0.5 size-3.5 shrink-0" />
      <span>{children}</span>
    </p>
  );
}
