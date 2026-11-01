import { useMatches, useRouterState } from "@tanstack/react-router";
import { Home } from "lucide-react";
import { useEffect } from "react";
import { useIntl } from "react-intl";

import { Crumbs, type Crumb } from "@/components/crumbs";
import {
  DASHBOARD,
  navTrail,
  PLACEHOLDER_TITLE,
  trailTitle,
  type NavCrumb,
} from "@/lib/navigation";

declare module "@tanstack/react-router" {
  interface StaticDataRouteOption {
    /**
     * A hook returning the crumbs the page adds after the navigation tree's
     * section and item — an item's name on its own page, say. It runs in the
     * breadcrumb bar while the route is matched, so it may read the route's
     * params and the same queries the page does.
     */
    crumbs?: () => Crumb[];
  }
}

const useNoCrumbs = (): Crumb[] => [];

/**
 * The bar under the top bar: where the user is, as a trail from the
 * dashboard through the section and the list down to the item. The section
 * and the list come from the navigation tree (the sidebar's), the item from
 * the route's `staticData.crumbs`. Sticky like the top bar, so the trail
 * stays in view on a long page.
 *
 * The same trail is the page's `<title>`, read from the other end. On the
 * dashboard itself there is no bar — it is where the trail starts — but the
 * title still names it.
 */
export function AppBreadcrumbs() {
  const pathname = useRouterState({ select: (s) => s.location.pathname });
  const matches = useMatches();
  // The deepest matched route that adds crumbs of its own.
  const leaf = [...matches].reverse().find((match) => match.staticData.crumbs !== undefined);

  return (
    // Keyed by the route, so a different page's hook never continues the
    // previous one's hook order.
    <Trail
      key={leaf?.id ?? ""}
      base={navTrail(pathname)}
      useLeaf={leaf?.staticData.crumbs ?? useNoCrumbs}
      showCrumbs={pathname !== DASHBOARD.url}
    />
  );
}

function Trail({
  base,
  useLeaf,
  showCrumbs,
}: {
  base: NavCrumb[];
  useLeaf: () => Crumb[];
  showCrumbs: boolean;
}) {
  const intl = useIntl();
  const leaf = useLeaf();
  // The dashboard, as the trail's first step — an icon, so a long trail
  // keeps its room.
  const home: Crumb = {
    label: intl.formatMessage(DASHBOARD.title),
    icon: <Home aria-hidden className="size-4" />,
    to: DASHBOARD.url,
  };
  const named: Crumb[] = base.map((crumb) => ({
    label: intl.formatMessage(crumb.label),
    to: crumb.to,
  }));
  const trail = [home, ...named, ...leaf];
  useDocumentTitle(trail);
  if (!showCrumbs) return null;
  return (
    <div className="sticky top-16 z-20 flex min-h-11 items-center border-b border-border bg-background/95 px-4 py-2 backdrop-blur supports-[backdrop-filter]:bg-background/80 md:px-6">
      <Crumbs items={trail} />
    </div>
  );
}

/** The trail as the document's title (`trailTitle`); back to the placeholder when the trail goes. */
function useDocumentTitle(trail: Crumb[]) {
  const title = trailTitle(trail.map((step) => step.label));

  useEffect(() => {
    document.title = title;
    return () => {
      document.title = PLACEHOLDER_TITLE;
    };
  }, [title]);
}
