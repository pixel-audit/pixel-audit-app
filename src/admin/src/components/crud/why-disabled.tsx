import type { ReactNode } from "react";

import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip";

/**
 * Says why a disabled control is disabled, on hover. A disabled button takes
 * no pointer events (so no `title` shows); this wraps it in a span that
 * carries the tooltip instead. With no `reason` the control renders as it is.
 */
export function WhyDisabled({ reason, children }: { reason?: string | null; children: ReactNode }) {
  if (!reason) return children;
  return (
    <TooltipProvider delayDuration={0}>
      <Tooltip>
        <TooltipTrigger asChild>
          <span className="inline-flex shrink-0 cursor-not-allowed">{children}</span>
        </TooltipTrigger>
        <TooltipContent className="max-w-xs">{reason}</TooltipContent>
      </Tooltip>
    </TooltipProvider>
  );
}
