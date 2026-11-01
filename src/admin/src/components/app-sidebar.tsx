import { Link, useRouterState } from "@tanstack/react-router";
import { ChevronRight, Filter, Globe, Plug, RefreshCw } from "lucide-react";
import { useState } from "react";
import { type MessageDescriptor, useIntl } from "react-intl";

import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarGroup,
  SidebarGroupContent,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  SidebarTrigger,
  useSidebar,
} from "@/components/ui/sidebar";
import { SidebarAbout } from "@/components/sidebar-about";
import { groupOf, isAtScreen } from "@/lib/navigation";
import { cn } from "@/lib/utils";

type Icon = typeof Globe;

/** The sidebar's own contribution to the navigation tree: an icon per screen. */
const ICONS: Record<string, Icon> = {
  "/funnels": Filter,
  "/connections": Plug,
  "/refreshes": RefreshCw,
};

/**
 * The second level of the navigation: the categories and screens of the
 * group the current page lies in (the top bar picks the group). A page
 * outside every group — the dashboard, the account — has no sidebar.
 *
 * A category folds and unfolds; every one starts open, and stays as the user
 * left it while they move around. Folded to icons, the sidebar has no room
 * for the headers and shows every screen's icon.
 *
 * Categories, and the screens within each, are sorted alphabetically by
 * their titles in the panel's language.
 *
 * The fold/unfold toggle sits in the bottom-left corner; on a phone the
 * sidebar is a drawer, opened from the top bar instead.
 */
export function AppSidebar() {
  const intl = useIntl();
  const { state, isMobile } = useSidebar();
  const iconsOnly = state === "collapsed" && !isMobile;
  const currentPath = useRouterState({ select: (r) => r.location.pathname });

  const [folded, setFolded] = useState<Record<string, boolean>>({});
  const isOpen = (url: string) => iconsOnly || !folded[url];
  const toggle = (url: string) => setFolded({ ...folded, [url]: !folded[url] });

  const group = groupOf(currentPath);
  if (!group) return null;

  const collator = new Intl.Collator(intl.locale);
  const byTitle = <T extends { title?: MessageDescriptor }>(a: T, b: T) =>
    collator.compare(
      a.title ? intl.formatMessage(a.title) : "",
      b.title ? intl.formatMessage(b.title) : "",
    );
  const categories = group.categories
    .map((category) => ({ ...category, items: [...category.items].sort(byTitle) }))
    .sort(byTitle);

  return (
    <Sidebar collapsible="icon" className="top-16! h-[calc(100svh-4rem)]! border-sidebar-border">
      <SidebarContent className="gap-1 py-2">
        {categories.map((category) => {
          const open = category.title === undefined || isOpen(category.url);
          return (
            <SidebarGroup key={category.url} className="py-1">
              {category.title && !iconsOnly && (
                <button
                  type="button"
                  aria-expanded={open}
                  onClick={() => toggle(category.url)}
                  className="flex h-9 w-full items-center gap-2 rounded-md px-2 text-left text-xs font-semibold tracking-wider text-sidebar-foreground uppercase transition-colors hover:bg-sidebar-accent"
                >
                  <span className="flex-1 truncate">{intl.formatMessage(category.title)}</span>
                  <ChevronRight
                    className={cn(
                      "size-4 text-sidebar-foreground/60 transition-transform",
                      open && "rotate-90",
                    )}
                  />
                </button>
              )}
              {open && (
                <SidebarGroupContent>
                  <SidebarMenu>
                    {category.items.map((item) => {
                      const ItemIcon = ICONS[item.url] ?? Globe;
                      return (
                        <SidebarMenuItem key={item.url}>
                          <SidebarMenuButton
                            asChild
                            isActive={isAtScreen(currentPath, item)}
                            tooltip={intl.formatMessage(item.title)}
                          >
                            <Link to={item.url}>
                              <ItemIcon className="size-4" />
                              <span>{intl.formatMessage(item.title)}</span>
                            </Link>
                          </SidebarMenuButton>
                        </SidebarMenuItem>
                      );
                    })}
                  </SidebarMenu>
                </SidebarGroupContent>
              )}
            </SidebarGroup>
          );
        })}
      </SidebarContent>
      {/* The fold toggle, and beside it the licence sentence (the source and
          the build linked inside it). The foot's height is fixed, so the
          toggle stays put while the sidebar animates and the text clips
          instead of wrapping the box taller; folded to icons only the
          toggle is left. */}
      <SidebarFooter className="h-12 shrink-0 flex-row items-center gap-2 border-t border-sidebar-border">
        {!isMobile && <SidebarTrigger className="size-8 shrink-0" />}
        {!iconsOnly && <SidebarAbout />}
      </SidebarFooter>
    </Sidebar>
  );
}
