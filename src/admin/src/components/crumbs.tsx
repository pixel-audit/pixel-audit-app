import { Link } from "@tanstack/react-router";
import { ChevronRight } from "lucide-react";
import type { ReactNode } from "react";
import { defineMessages, useIntl } from "react-intl";

/**
 * One step of a trail. The label is text, because the same trail is also the
 * page's title (`AppBreadcrumbs`); a crumb with an icon shows the icon and
 * keeps the label for screen readers.
 */
export type Crumb = {
  label: string;
  icon?: ReactNode;
  to?: string;
  params?: Record<string, string>;
};

/**
 * A breadcrumb trail: every crumb but the last links to its page, the last
 * names the page the user is on. The bar under the top bar (`AppBreadcrumbs`)
 * assembles the crumbs and renders them through this.
 */
export function Crumbs({ items }: { items: Crumb[] }) {
  const intl = useIntl();
  return (
    <nav aria-label={intl.formatMessage(messages.trail)} className="min-w-0 text-sm">
      <ol className="flex flex-wrap items-center gap-1">
        {items.map((c, i) => {
          const last = i === items.length - 1;
          const label = c.icon ? (
            <>
              {c.icon}
              <span className="sr-only">{c.label}</span>
            </>
          ) : (
            c.label
          );
          return (
            <li key={i} className="flex min-w-0 items-center gap-1">
              {c.to && !last ? (
                <Link
                  to={c.to}
                  params={c.params as never}
                  // Only the last crumb is the current page; without this the
                  // router would mark every ancestor's link as current too.
                  activeOptions={{ exact: true }}
                  className="inline-flex min-w-0 items-center truncate text-muted-foreground transition-colors hover:text-primary"
                >
                  {label}
                </Link>
              ) : (
                <span
                  aria-current={last ? "page" : undefined}
                  className={
                    last ? "truncate font-medium text-foreground" : "truncate text-muted-foreground"
                  }
                >
                  {label}
                </span>
              )}
              {!last && (
                <ChevronRight aria-hidden className="size-3.5 shrink-0 text-muted-foreground/60" />
              )}
            </li>
          );
        })}
      </ol>
    </nav>
  );
}

const messages = defineMessages({
  trail: { id: "breadcrumbs.trail", defaultMessage: "Breadcrumbs" },
});
