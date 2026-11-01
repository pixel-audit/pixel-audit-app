import type { ReactNode } from "react";

import { cn } from "@/lib/utils";

/**
 * A page's body: centred, capped in width, its blocks spaced apart. Every
 * route renders inside one — a list section's layout wraps its `<Outlet />`,
 * an item's page wraps its content. `wide` is for pages built around a
 * calendar or a table that need the room.
 */
export function Page({
  wide = false,
  className,
  children,
}: {
  wide?: boolean;
  className?: string;
  children: ReactNode;
}) {
  return (
    <div className={cn("mx-auto space-y-8", wide ? "max-w-7xl" : "max-w-6xl", className)}>
      {children}
    </div>
  );
}
