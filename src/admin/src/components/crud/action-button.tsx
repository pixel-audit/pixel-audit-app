import type { LucideIcon } from "lucide-react";
import type { ReactNode } from "react";

import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

/**
 * A labelled action on an item's page — the Edit, Delete, "Send again"
 * buttons in the page header. Outline by default so the header stays quiet;
 * `destructive` colours the one that removes the item.
 */
export function ActionButton({
  icon: Icon,
  onClick,
  disabled,
  destructive = false,
  children,
}: {
  icon: LucideIcon;
  onClick: () => void;
  disabled?: boolean;
  destructive?: boolean;
  children: ReactNode;
}) {
  return (
    <Button
      variant="outline"
      disabled={disabled}
      onClick={onClick}
      className={cn(destructive && "text-destructive hover:text-destructive")}
    >
      <Icon className="size-4" /> {children}
    </Button>
  );
}
