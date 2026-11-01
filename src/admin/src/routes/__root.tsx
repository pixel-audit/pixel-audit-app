import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { Outlet, Link, createRootRouteWithContext, useRouter } from "@tanstack/react-router";
import { useEffect } from "react";
import { defineMessages, useIntl } from "react-intl";

import { SidebarProvider, SidebarInset } from "@/components/ui/sidebar";
import { AppSidebar } from "@/components/app-sidebar";
import { AppBreadcrumbs } from "@/components/app-breadcrumbs";
import { AppHeader } from "@/components/app-header";
import { Toaster } from "@/components/ui/sonner";

function NotFoundComponent() {
  const intl = useIntl();
  return (
    <div className="flex min-h-screen items-center justify-center bg-background px-4">
      <div className="max-w-md text-center">
        <h1 className="text-7xl font-bold text-foreground">
          {intl.formatNumber(404, { useGrouping: false })}
        </h1>
        <h2 className="mt-4 text-xl font-semibold text-foreground">
          {intl.formatMessage(messages.notFoundTitle)}
        </h2>
        <p className="mt-2 text-sm text-muted-foreground">
          {intl.formatMessage(messages.notFoundLead)}
        </p>
        <div className="mt-6">
          <Link
            to="/"
            className="inline-flex items-center justify-center rounded-md bg-primary px-4 py-2 text-sm font-medium text-primary-foreground transition-colors hover:bg-primary/90"
          >
            {intl.formatMessage(messages.backToDashboard)}
          </Link>
        </div>
      </div>
    </div>
  );
}

function ErrorComponent({ error, reset }: { error: unknown; reset: () => void }) {
  const intl = useIntl();
  const router = useRouter();
  // In an effect, not in the render body — otherwise it logs on every render
  // and twice in StrictMode.
  useEffect(() => {
    console.error(error);
  }, [error]);

  return (
    <div className="flex min-h-screen items-center justify-center bg-background px-4">
      <div className="max-w-md text-center">
        <h1 className="text-xl font-semibold tracking-tight text-foreground">
          {intl.formatMessage(messages.errorTitle)}
        </h1>
        <p className="mt-2 text-sm text-muted-foreground">
          {intl.formatMessage(messages.errorLead)}
        </p>
        <div className="mt-6 flex flex-wrap justify-center gap-2">
          <button
            onClick={() => {
              void router.invalidate();
              reset();
            }}
            className="inline-flex items-center justify-center rounded-md bg-primary px-4 py-2 text-sm font-medium text-primary-foreground transition-colors hover:bg-primary/90"
          >
            {intl.formatMessage(messages.tryAgain)}
          </button>
          {/* A hard reload, not a <Link> — after a render error the router can
              be in a state client navigation can no longer fix. BASE_URL,
              because when hosted in a subdirectory "/" leads out of the app. */}
          <a
            href={import.meta.env.BASE_URL}
            className="inline-flex items-center justify-center rounded-md border border-input bg-background px-4 py-2 text-sm font-medium text-foreground transition-colors hover:bg-accent"
          >
            {intl.formatMessage(messages.dashboard)}
          </a>
        </div>
      </div>
    </div>
  );
}

export const Route = createRootRouteWithContext<{ queryClient: QueryClient }>()({
  component: RootComponent,
  notFoundComponent: NotFoundComponent,
  errorComponent: ErrorComponent,
});

function RootComponent() {
  const { queryClient } = Route.useRouteContext();

  return (
    <QueryClientProvider client={queryClient}>
      <SidebarProvider>
        {/* The top bar spans the window; the sidebar and the page share
            what lies below it. */}
        <div className="flex min-h-screen w-full flex-col">
          <AppHeader />
          <div className="flex w-full flex-1">
            <AppSidebar />
            <SidebarInset className="min-w-0 bg-background">
              <AppBreadcrumbs />
              <main className="flex-1 p-4 md:p-6">
                <Outlet />
              </main>
            </SidebarInset>
          </div>
        </div>
        <Toaster />
      </SidebarProvider>
    </QueryClientProvider>
  );
}

const messages = defineMessages({
  notFoundTitle: { id: "app.notFoundTitle", defaultMessage: "Page not found" },
  notFoundLead: {
    id: "app.notFoundLead",
    defaultMessage: "This view does not exist or has been moved.",
  },
  backToDashboard: { id: "app.backToDashboard", defaultMessage: "Back to the dashboard" },
  errorTitle: { id: "app.errorTitle", defaultMessage: "The view could not be loaded" },
  errorLead: { id: "app.errorLead", defaultMessage: "Try again or go back to the dashboard." },
  tryAgain: { id: "app.tryAgain", defaultMessage: "Try again" },
  dashboard: { id: "app.dashboard", defaultMessage: "Dashboard" },
});
