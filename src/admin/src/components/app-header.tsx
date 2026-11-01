import { Link, useRouterState } from "@tanstack/react-router";
import { defineMessages, useIntl } from "react-intl";

import { SidebarTrigger } from "@/components/ui/sidebar";
import { Separator } from "@/components/ui/separator";
import { firstScreen, groupOf, isUnder, NAV_GROUPS, PLACEHOLDER_TITLE } from "@/lib/navigation";
import { cn } from "@/lib/utils";

export function AppHeader() {
  const intl = useIntl();
  const currentPath = useRouterState({ select: (r) => r.location.pathname });

  // The first level of the navigation: a tab per group, leading to the
  // group's first screen. The sidebar shows the open group's categories —
  // and only on a page inside a group, so the trigger goes with it. On a
  // wide screen the trigger lives in the sidebar's bottom corner; only the
  // phone's drawer opens from here.
  const inGroup = groupOf(currentPath) !== undefined;

  return (
    <header className="sticky top-0 z-30 flex h-16 items-center gap-3 border-b border-border bg-card px-4">
      {inGroup && (
        <div className="flex items-center gap-3 md:hidden">
          <SidebarTrigger />
          <Separator orientation="vertical" className="h-6" />
        </div>
      )}

      <Link
        to="/"
        className="shrink-0 truncate pr-2 font-serif text-lg text-foreground transition-colors hover:text-primary"
      >
        {PLACEHOLDER_TITLE}
      </Link>

      <nav
        aria-label={intl.formatMessage(messages.sections)}
        className="-my-2 flex min-w-0 flex-1 items-center gap-1 overflow-x-auto py-2"
      >
        {NAV_GROUPS.map((group) => {
          const active = isUnder(currentPath, group.url);
          return (
            <Link
              key={group.url}
              to={firstScreen(group)}
              aria-current={active ? "page" : undefined}
              className={cn(
                "shrink-0 rounded-md px-3 py-2 text-sm font-medium whitespace-nowrap transition-colors",
                active
                  ? "bg-primary/10 text-primary"
                  : "text-muted-foreground hover:bg-accent hover:text-foreground",
              )}
            >
              {intl.formatMessage(group.title)}
            </Link>
          );
        })}
      </nav>
    </header>
  );
}

const messages = defineMessages({
  sections: { id: "header.sections", defaultMessage: "Sections" },
});
