import type { ReactNode } from "react";

import { cn } from "@/lib/utils";

/**
 * The panel's standard non-ideal state: an empty list, a failed load, a
 * missing permission — a dashed, muted box in place of the real content.
 * Content is arbitrary (text, or text plus a retry button); tweak spacing
 * or alignment via `className`.
 */
export function NonIdealState({
  className,
  children,
}: {
  className?: string;
  children: ReactNode;
}) {
  return (
    <div
      className={cn(
        "rounded-lg border border-dashed border-border bg-muted/50 p-4 text-sm text-muted-foreground",
        className,
      )}
    >
      {children}
    </div>
  );
}
