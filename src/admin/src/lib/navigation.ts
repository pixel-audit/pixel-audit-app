import { defineMessages, type MessageDescriptor } from "react-intl";

/**
 * The panel's navigation tree — one source for the top bar, the sidebar and
 * the breadcrumb bar. Two levels: a group is a tab in the top bar, and the
 * open group's categories and their screens fill the sidebar. The address
 * follows the tree: `/group/category/screen`, then the item and the tab
 * (`/funnels/$code/setup`). A group whose screens need no grouping has one
 * untitled category at the group's own address.
 *
 * A screen of tab routes at sibling addresses names the other tabs in
 * `also`, so it stays the open screen on each. The dashboard lies outside
 * the tree.
 *
 * Icons stay with the sidebar (the only place that draws them), keyed by the
 * screen's `url`. A title is a message: the bars format it.
 */
export type NavItem = {
  title: MessageDescriptor;
  url: string;
  also?: readonly string[];
};

export type NavCategory = { title?: MessageDescriptor; url: string; items: NavItem[] };

export type NavGroup = { title: MessageDescriptor; url: string; categories: NavCategory[] };

const navMessages = defineMessages({
  dashboard: { id: "nav.dashboard", defaultMessage: "Dashboard" },
  funnels: { id: "nav.funnels", defaultMessage: "Funnels" },
  connections: { id: "nav.connections", defaultMessage: "Connections" },
  refreshes: { id: "nav.refreshes", defaultMessage: "Refreshes" },
});

export const DASHBOARD = { title: navMessages.dashboard, url: "/" };

export const NAV_GROUPS: NavGroup[] = [
  {
    title: navMessages.funnels,
    url: "/funnels",
    categories: [
      {
        url: "/funnels",
        items: [{ title: navMessages.funnels, url: "/funnels" }],
      },
    ],
  },
  {
    title: navMessages.connections,
    url: "/connections",
    categories: [
      {
        url: "/connections",
        items: [{ title: navMessages.connections, url: "/connections" }],
      },
    ],
  },
  {
    title: navMessages.refreshes,
    url: "/refreshes",
    categories: [
      {
        url: "/refreshes",
        items: [{ title: navMessages.refreshes, url: "/refreshes" }],
      },
    ],
  },
];

/** Whether `path` is `url` itself or a page beneath it. */
export const isUnder = (path: string, url: string) => path === url || path.startsWith(`${url}/`);

/** Whether `path` is the screen's page, one of its other tabs', or a page beneath one. */
export const isAtScreen = (path: string, item: NavItem) =>
  [item.url, ...(item.also ?? [])].some((url) => isUnder(path, url));

/** The group the path lies in, if any — the dashboard lies in none. */
export const groupOf = (path: string) => NAV_GROUPS.find((group) => isUnder(path, group.url));

/** Where a group or a category leads: its first screen. */
export function firstScreen(entry: NavGroup | NavCategory): string {
  const category = "categories" in entry ? entry.categories[0] : entry;
  return category?.items[0]?.url ?? entry.url;
}

/** One step of the breadcrumb trail: a label, and where it leads when it isn't the last. */
export type NavCrumb = { label: MessageDescriptor; to: string };

/**
 * The part of the breadcrumb trail the navigation tree knows: the group, the
 * category and the screen the path lies under. A page deeper than that (an
 * item's own page) adds its crumbs itself; the dashboard, outside the tree,
 * has none. A group and a category have no page of their own and lead to
 * their first screen. A category and a screen of the same name, or a
 * screen named like its group, collapse into the one above.
 */
export function navTrail(pathname: string): NavCrumb[] {
  const group = groupOf(pathname);
  if (!group) return [];
  const trail: NavCrumb[] = [{ label: group.title, to: firstScreen(group) }];

  // The most specific category: a group's untitled one sits at the group's own
  // address and would otherwise claim every titled one's screens too.
  const category = group.categories
    .filter((c) => isUnder(pathname, c.url))
    .sort((a, b) => b.url.length - a.url.length)[0];
  if (!category) return trail;
  if (category.title) trail.push({ label: category.title, to: firstScreen(category) });

  const item = category.items.find((i) => isAtScreen(pathname, i));
  const last = trail[trail.length - 1];
  if (!item || item.title.id === last?.label.id) return trail;
  return [...trail, { label: item.title, to: item.url }];
}

/** The document's title while no trail sets one — index.html's, too. */
export const PLACEHOLDER_TITLE = "PixelAudit";

/**
 * A breadcrumb trail (its labels, from the dashboard down) as the document's
 * title: the page first, up to its section, then the placeholder —
 * „Checkout — Funnels — PixelAudit". The dashboard is named only when it is
 * the page.
 */
export function trailTitle(labels: readonly string[]): string {
  const steps = labels.length > 1 ? labels.slice(1) : labels;
  return [...steps].reverse().concat(PLACEHOLDER_TITLE).join(" — ");
}
