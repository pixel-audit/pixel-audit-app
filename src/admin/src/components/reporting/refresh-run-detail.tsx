import { Link } from "@tanstack/react-router";
import { defineMessage, defineMessages, useIntl } from "react-intl";

import type { RefreshRun, RefreshRunDay } from "@/api/generated/model";
import { describeRun } from "@/lib/refresh-runs";
import { ApiList } from "@/components/crud/api-list";
import { DetailField, DetailsCard } from "@/components/crud/details-card";
import { PageHeader } from "@/components/page-header";
import { kindMessages, triggerMessages } from "@/components/reporting/refresh-run-messages";
import { RefreshRunStatusBadge } from "@/components/reporting/refresh-run-status";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { useApi } from "@/lib/api";
import { formatDay, formatRange } from "@/lib/date-range";
import { cn } from "@/lib/utils";

/**
 * The run's page: what it refreshed and how it went, the whole error as
 * selectable text, and — for a daily-counts run — every step and day it
 * computed with its count or its error.
 */
export function RefreshRunDetail({ run }: { run: RefreshRun }) {
  const intl = useIntl();
  const api = useApi();
  const days = api.useAdminListRefreshRunDays(run.id, {
    query: {
      refetchInterval: run.status === "queued" || run.status === "running" ? 10_000 : false,
    },
  });

  const at = (value: string | null) =>
    value ? intl.formatDate(new Date(value), { dateStyle: "medium", timeStyle: "medium" }) : null;

  return (
    <div className="space-y-8">
      <PageHeader
        title={describeRun(run)}
        badges={
          <>
            <Badge variant="secondary">{intl.formatMessage(kindMessages[run.kind])}</Badge>
            <Badge variant="outline">{intl.formatMessage(triggerMessages[run.trigger])}</Badge>
            <RefreshRunStatusBadge status={run.status} />
          </>
        }
        description={formatRange(intl, { date_from: run.date_from, date_to: run.date_to })}
      />

      <DetailsCard title={intl.formatMessage(messages.details)} columns={3}>
        <DetailField label={intl.formatMessage(messages.funnel)}>
          {run.funnel && (
            <Link
              to="/funnels/$id"
              params={{ id: run.funnel.id }}
              className="text-primary underline-offset-2 hover:underline"
            >
              {run.funnel.name}
            </Link>
          )}
        </DetailField>
        <DetailField label={intl.formatMessage(messages.dataSource)}>
          {run.data_source && run.funnel && (
            <Link
              to="/funnels/$id/setup"
              params={{ id: run.funnel.id }}
              className="text-primary underline-offset-2 hover:underline"
            >
              {run.data_source.name}
            </Link>
          )}
        </DetailField>
        <DetailField label={intl.formatMessage(messages.connection)}>
          {run.connection && (
            <Link
              to="/settings/connections/$id"
              params={{ id: run.connection.id }}
              className="text-primary underline-offset-2 hover:underline"
            >
              {run.connection.name}
            </Link>
          )}
        </DetailField>
        <DetailField label={intl.formatMessage(messages.queuedAt)}>
          {at(run.inserted_at)}
        </DetailField>
        <DetailField label={intl.formatMessage(messages.startedAt)}>
          {at(run.started_at)}
        </DetailField>
        <DetailField label={intl.formatMessage(messages.finishedAt)}>
          {at(run.finished_at)}
        </DetailField>
        <DetailField label={intl.formatMessage(messages.error)} wide>
          {run.error && (
            <pre className="rounded-md border border-destructive/40 bg-destructive/5 p-3 font-mono text-xs break-words whitespace-pre-wrap text-destructive select-text">
              {run.error}
            </pre>
          )}
        </DetailField>
      </DetailsCard>

      {run.kind === "data_source" && (
        <Card className="shadow-none">
          <CardHeader>
            <CardTitle className="font-serif text-lg">
              {intl.formatMessage(messages.days)}
            </CardTitle>
            <p className="text-xs text-muted-foreground">{intl.formatMessage(messages.daysLead)}</p>
          </CardHeader>
          <CardContent>
            <ApiList
              query={days}
              items={(data) => data.data}
              resource="days"
              empty={intl.formatMessage(messages.noDays)}
            >
              {(rows: RefreshRunDay[]) => (
                <li className="list-none overflow-x-auto">
                  <table className="w-full text-sm">
                    <thead>
                      <tr className="text-left text-xs text-muted-foreground uppercase">
                        <th className="py-2 pr-4 font-semibold">
                          {intl.formatMessage(messages.day)}
                        </th>
                        <th className="py-2 pr-4 font-semibold">
                          {intl.formatMessage(messages.step)}
                        </th>
                        <th className="py-2 pr-4 text-right font-semibold">
                          {intl.formatMessage(messages.count)}
                        </th>
                        <th className="py-2 font-semibold">
                          {intl.formatMessage(messages.outcome)}
                        </th>
                      </tr>
                    </thead>
                    <tbody>
                      {rows.map((row) => (
                        <tr
                          key={`${row.date}-${row.step.id}`}
                          className="border-t border-border align-top"
                        >
                          <td className="py-2 pr-4 whitespace-nowrap tabular-nums">
                            {formatDay(intl, row.date)}
                          </td>
                          <td className="py-2 pr-4">{row.step.name}</td>
                          <td className="py-2 pr-4 text-right tabular-nums">
                            {row.count === null ? "—" : intl.formatNumber(row.count)}
                          </td>
                          <td
                            className={cn(
                              "py-2 text-xs",
                              row.status === "error" ? "text-destructive" : "text-success",
                            )}
                          >
                            {row.status === "error" ? (
                              <pre className="font-mono break-words whitespace-pre-wrap select-text">
                                {row.error}
                              </pre>
                            ) : (
                              intl.formatMessage(messages.ok)
                            )}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </li>
              )}
            </ApiList>
          </CardContent>
        </Card>
      )}
    </div>
  );
}

const messages = {
  ...defineMessages({
    details: { id: "refreshRun.detail.details", defaultMessage: "Run" },
    funnel: { id: "refreshRun.detail.funnel", defaultMessage: "Funnel" },
    dataSource: { id: "refreshRun.detail.dataSource", defaultMessage: "Data source" },
    connection: { id: "refreshRun.detail.connection", defaultMessage: "Connection" },
    queuedAt: { id: "refreshRun.detail.queuedAt", defaultMessage: "Queued" },
    startedAt: { id: "refreshRun.detail.startedAt", defaultMessage: "Started" },
    finishedAt: { id: "refreshRun.detail.finishedAt", defaultMessage: "Finished" },
    error: { id: "refreshRun.detail.error", defaultMessage: "Error" },
    days: { id: "refreshRun.detail.days", defaultMessage: "Days" },
    daysLead: {
      id: "refreshRun.detail.daysLead",
      defaultMessage:
        "Every step and day this run computed. A later run of the same days takes them over, so an older run may list fewer.",
    },
    noDays: {
      id: "refreshRun.detail.noDays",
      defaultMessage:
        "No days from this run are on record — it has not run yet, or a later run recomputed them.",
    },
    day: { id: "refreshRun.detail.day", defaultMessage: "Day" },
    step: { id: "refreshRun.detail.step", defaultMessage: "Step" },
    count: { id: "refreshRun.detail.count", defaultMessage: "Count" },
    outcome: { id: "refreshRun.detail.outcome", defaultMessage: "Outcome" },
    ok: { id: "refreshRun.detail.ok", defaultMessage: "Counted" },
  }),
  back: defineMessage({ id: "refreshRun.detail.back", defaultMessage: "Back to refreshes" }),
};
