import { createFileRoute, Link } from "@tanstack/react-router";
import { defineMessage, defineMessages, useIntl } from "react-intl";

import { okData } from "@/components/crud/api-response";
import { Page } from "@/components/page";
import { PageHeader } from "@/components/page-header";
import { RefreshRunsCard } from "@/components/reporting/refresh-runs-card";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { NonIdealState } from "@/components/ui/non-ideal-state";
import { useApi } from "@/lib/api";

export const Route = createFileRoute("/")({
  component: DashboardPage,
});

/** The front page: a card per funnel, and the latest refresh runs. */
function DashboardPage() {
  const intl = useIntl();
  const api = useApi();
  const funnels = okData(api.useAdminListFunnels().data)?.data;

  return (
    <Page>
      <PageHeader
        title={intl.formatMessage(messages.title)}
        description={intl.formatMessage(messages.lead)}
      />

      {funnels !== undefined && funnels.length === 0 ? (
        <NonIdealState>
          {intl.formatMessage(messages.noFunnels)}{" "}
          <Link to="/funnels" className="text-primary underline-offset-2 hover:underline">
            {intl.formatMessage(messages.addFirst)}
          </Link>
        </NonIdealState>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {(funnels ?? []).map((funnel) => (
            <Link
              key={funnel.id}
              to="/funnels/$code"
              params={{ code: funnel.code }}
              className="group"
            >
              <Card className="h-full shadow-none transition-colors group-hover:border-primary/40">
                <CardHeader>
                  <CardTitle className="font-serif text-lg">{funnel.name}</CardTitle>
                </CardHeader>
                <CardContent className="space-y-1 text-sm text-muted-foreground">
                  <p>
                    {intl.formatMessage(messages.steps, {
                      steps: funnel.steps.length,
                      names: funnel.steps.map((s) => s.name).join(" → "),
                    })}
                  </p>
                  <p>
                    {intl.formatMessage(messages.sources, {
                      sources: funnel.data_sources.length,
                      names: funnel.data_sources.map((s) => s.name).join(", "),
                    })}
                  </p>
                </CardContent>
              </Card>
            </Link>
          ))}
        </div>
      )}

      <RefreshRunsCard filters={{}} page={false} limit={10} />
    </Page>
  );
}

const messages = {
  ...defineMessages({
    title: { id: "dashboard.title", defaultMessage: "Dashboard" },
    lead: {
      id: "dashboard.lead",
      defaultMessage: "The funnels and what was refreshed last.",
    },
    noFunnels: { id: "dashboard.noFunnels", defaultMessage: "No funnels yet." },
    addFirst: { id: "dashboard.addFirst", defaultMessage: "Add the first one." },
  }),
  steps: defineMessage<{ steps: number; names: string }>({
    id: "dashboard.steps",
    defaultMessage:
      "{steps, plural, =0 {No steps yet} one {# step: {names}} other {# steps: {names}}}",
  }),
  sources: defineMessage<{ sources: number; names: string }>({
    id: "dashboard.sources",
    defaultMessage:
      "{sources, plural, =0 {No data sources yet} one {# data source: {names}} other {# data sources: {names}}}",
  }),
};
