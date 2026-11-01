import { Link, type LinkProps } from "@tanstack/react-router";
import { ChevronRight, type LucideIcon } from "lucide-react";
import type { ReactNode } from "react";

import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

/**
 * One item of a card's list: an optional leading icon, picture or colour
 * rail, the title with its badges, secondary lines below, and the actions (switch,
 * icon buttons) on the right. Inactive items are dimmed. With `link` the
 * whole row leads to the item's own page and a chevron on the right says so.
 */
export function ListRow({
  icon: Icon,
  leading,
  accent,
  title,
  link,
  badges,
  actions,
  dimmed = false,
  className,
  children,
}: {
  /** Leading icon in a muted square. */
  icon?: LucideIcon;
  /** Something else in the icon's place — a thumbnail; wins over `icon`. */
  leading?: ReactNode;
  /** Colour rail on the left edge — a background class like `bg-primary`. */
  accent?: string;
  title: ReactNode;
  /**
   * The item's page: `linkOptions({ to: "/offer/exhibitions/venues/$id", params })` —
   * checked against the route tree at the call site.
   */
  link?: LinkProps;
  /** Badges and short notes shown inline after the title. */
  badges?: ReactNode;
  /** Right-hand controls; typically `RowActionButton`s and a `Switch`. */
  actions?: ReactNode;
  dimmed?: boolean;
  className?: string;
  /** Secondary lines under the title — usually `RowDetail`s. */
  children?: ReactNode;
}) {
  return (
    <li
      className={cn(
        "flex flex-wrap items-center gap-3 rounded-lg border border-border p-3",
        accent !== undefined && "overflow-hidden pl-0",
        dimmed && "opacity-55",
        link && "group relative transition-colors hover:border-primary/40",
        className,
      )}
    >
      {/* The whole row is the entrance to the item's page, but the actions
          must stay clickable — hence the link lies under the content and
          the actions rise above it via z-index (a button nested in an <a>
          would be invalid HTML and every click on it would navigate). The
          cost is unselectable row text; the item's page has it selectable. */}
      {link && (
        <Link
          {...link}
          className="absolute inset-0 z-0 rounded-lg outline-none focus-visible:ring-2 focus-visible:ring-ring"
        >
          <span className="sr-only">{title}</span>
        </Link>
      )}
      {accent !== undefined && (
        <span aria-hidden className={cn("h-14 w-1.5 shrink-0 rounded-r", accent)} />
      )}
      {leading !== undefined
        ? leading
        : Icon && (
            <span className="flex size-10 shrink-0 items-center justify-center rounded-md bg-muted text-muted-foreground">
              <Icon className="size-5" />
            </span>
          )}

      <div className="min-w-0 flex-1">
        {/* div, not p — Badge renders a <div>, and a <div> inside a <p>
            is invalid nesting that React yells about in dev */}
        <div className="flex flex-wrap items-center gap-2">
          <span className="font-medium text-foreground">{title}</span>
          {badges}
        </div>
        {children}
      </div>

      {actions !== undefined && actions !== false && (
        <div className="relative z-10 flex shrink-0 items-center gap-1">{actions}</div>
      )}
      {link && (
        <ChevronRight
          aria-hidden
          className="size-4 shrink-0 text-muted-foreground transition-transform group-hover:translate-x-0.5"
        />
      )}
    </li>
  );
}

/** A secondary line under a row's title. */
export function RowDetail({
  muted = false,
  className,
  children,
}: {
  /** Fainter — for the third line: counts, periods, legal bases. */
  muted?: boolean;
  className?: string;
  children: ReactNode;
}) {
  return (
    <p
      className={cn(
        "text-xs",
        muted ? "mt-0.5 text-muted-foreground/80" : "mt-1 text-muted-foreground",
        className,
      )}
    >
      {children}
    </p>
  );
}

/** An icon-only ghost button for a row's action strip. */
export function RowActionButton({
  icon: Icon,
  label,
  onClick,
  disabled,
}: {
  icon: LucideIcon;
  /** Accessible name — icon buttons have no visible text. */
  label: string;
  onClick: () => void;
  disabled?: boolean;
}) {
  return (
    <Button variant="ghost" size="icon" aria-label={label} disabled={disabled} onClick={onClick}>
      <Icon className="size-4" />
    </Button>
  );
}
