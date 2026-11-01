import { Link, type LinkProps } from "@tanstack/react-router";

import { cn } from "@/lib/utils";

export type Tab = {
  /** The tab's route: `linkOptions({ to: "/funnels/$id/setup", params })`. */
  link: LinkProps;
  label: string;
  active: boolean;
};

/**
 * An item page's tabs, each its own route: the links in a pill bar, the
 * active one raised. The page keeps the tab's content below (an Outlet).
 */
export function TabsNav({ label, tabs }: { label: string; tabs: Tab[] }) {
  return (
    <nav
      aria-label={label}
      className="inline-flex h-9 items-center rounded-lg bg-muted p-1 text-muted-foreground"
    >
      {tabs.map((tab) => (
        <Link
          key={tab.label}
          {...tab.link}
          aria-current={tab.active ? "page" : undefined}
          className={cn(
            "inline-flex items-center rounded-md px-3 py-1 text-sm font-medium transition-colors",
            tab.active ? "bg-background text-foreground shadow" : "hover:text-foreground",
          )}
        >
          {tab.label}
        </Link>
      ))}
    </nav>
  );
}
