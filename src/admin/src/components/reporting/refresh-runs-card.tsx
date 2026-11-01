import { linkOptions } from "@tanstack/react-router";
import { Database, Facebook } from "lucide-react";
import { defineMessage, defineMessages, useIntl } from "react-intl";

import type { AdminListRefreshRunsParams, RefreshRun } from "@/api/generated/model";
import { ApiList } from "@/components/crud/api-list";
import { CrudCard } from "@/components/crud/crud-card";
import { ListRow, RowDetail } from "@/components/crud/list-row";
import { describeRun } from "@/lib/refresh-runs";
import { kindMessages, triggerMessages } from "@/components/reporting/refresh-run-messages";
import { RefreshRunStatusBadge } from "@/components/reporting/refresh-run-status";
import { Badge } from "@/components/ui/badge";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { useApi } from "@/lib/api";
import { formatRange } from "@/lib/date-range";

const STATUSES = ["queued", "running", "done", "failed"] as const;
const KINDS = ["meta_pixel", "data_source"] as const;
const ANY = "any";

/**
 * The refresh runs, newest first, with a status and a kind filter. While a
 * run is queued or running the list asks again every ten seconds, so a
 * refresh started from a funnel or a connection is seen through.
 */
export function RefreshRunsCard({
  filters,
  onFiltersChange,
  page = true,
  limit = 50,
}: {
  filters: Pick<AdminListRefreshRunsParams, "status" | "kind" | "funnel_id" | "connection_id">;
  onFiltersChange?: (filters: Pick<AdminListRefreshRunsParams, "status" | "kind">) => void;
  page?: boolean;
  limit?: number;
}) {
  const intl = useIntl();
  const api = useApi();
  const list = api.useAdminListRefreshRuns(
    { ...filters, limit },
    {
      query: {
        refetchInterval: (query) => {
          const runs = query.state.data?.status === 200 ? query.state.data.data.data : [];
          return runs.some((run) => run.status === "queued" || run.status === "running")
            ? 10_000
            : false;
        },
      },
    },
  );

  return (
    <CrudCard
      page={page}
      title={intl.formatMessage(messages.title)}
      action={
        onFiltersChange && (
          <div className="flex flex-wrap gap-2">
            <Select
              value={filters.status ?? ANY}
              onValueChange={(value) =>
                onFiltersChange({
                  ...filters,
                  status: value === ANY ? undefined : (value as (typeof STATUSES)[number]),
                })
              }
            >
              <SelectTrigger className="w-40" aria-label={intl.formatMessage(messages.status)}>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value={ANY}>{intl.formatMessage(messages.anyStatus)}</SelectItem>
                {STATUSES.map((status) => (
                  <SelectItem key={status} value={status}>
                    {intl.formatMessage(
                      {
                        queued: messages.queued,
                        running: messages.running,
                        done: messages.done,
                        failed: messages.failed,
                      }[status],
                    )}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            <Select
              value={filters.kind ?? ANY}
              onValueChange={(value) =>
                onFiltersChange({
                  ...filters,
                  kind: value === ANY ? undefined : (value as (typeof KINDS)[number]),
                })
              }
            >
              <SelectTrigger className="w-44" aria-label={intl.formatMessage(messages.kind)}>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value={ANY}>{intl.formatMessage(messages.anyKind)}</SelectItem>
                {KINDS.map((kind) => (
                  <SelectItem key={kind} value={kind}>
                    {intl.formatMessage(kindMessages[kind])}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        )
      }
    >
      <ApiList
        query={list}
        items={(data) => data.data}
        resource="refresh runs"
        empty={intl.formatMessage(messages.empty)}
      >
        {(runs: RefreshRun[]) =>
          runs.map((run) => (
            <ListRow
              key={run.id}
              icon={run.kind === "meta_pixel" ? Facebook : Database}
              title={describeRun(run)}
              link={linkOptions({ to: "/refreshes/$id", params: { id: run.id } })}
              badges={
                <>
                  <Badge variant="secondary">{intl.formatMessage(kindMessages[run.kind])}</Badge>
                  <Badge variant="outline">
                    {intl.formatMessage(triggerMessages[run.trigger])}
                  </Badge>
                  <RefreshRunStatusBadge status={run.status} />
                </>
              }
            >
              <RowDetail>
                {intl.formatMessage(messages.range, {
                  range: formatRange(intl, { date_from: run.date_from, date_to: run.date_to }),
                  queued: intl.formatDate(new Date(run.inserted_at), {
                    dateStyle: "medium",
                    timeStyle: "short",
                  }),
                })}
              </RowDetail>
              {/* The first line only; the run's page has the whole error, selectable. */}
              {run.error && (
                <RowDetail className="truncate text-destructive">
                  <code>{run.error.split("\n")[0]}</code>
                </RowDetail>
              )}
            </ListRow>
          ))
        }
      </ApiList>
    </CrudCard>
  );
}

const messages = {
  ...defineMessages({
    title: { id: "refreshRuns.list.title", defaultMessage: "Refreshes" },
    empty: { id: "refreshRuns.list.empty", defaultMessage: "No refresh runs match." },
    status: { id: "refreshRuns.list.status", defaultMessage: "Status" },
    kind: { id: "refreshRuns.list.kind", defaultMessage: "Kind" },
    anyStatus: { id: "refreshRuns.list.anyStatus", defaultMessage: "Any status" },
    anyKind: { id: "refreshRuns.list.anyKind", defaultMessage: "Any kind" },
    queued: { id: "refreshRuns.list.queued", defaultMessage: "Queued" },
    running: { id: "refreshRuns.list.running", defaultMessage: "Running" },
    done: { id: "refreshRuns.list.done", defaultMessage: "Done" },
    failed: { id: "refreshRuns.list.failed", defaultMessage: "Failed" },
  }),
  range: defineMessage<{ range: string; queued: string }>({
    id: "refreshRuns.list.range",
    defaultMessage: "{range} · queued {queued}",
  }),
};
