import { Database, Globe } from "lucide-react";
import { defineMessage, defineMessages, useIntl } from "react-intl";

import type { Connection, ConnectionCall } from "@/api/generated/model";
import { ApiList } from "@/components/crud/api-list";
import { CrudCard } from "@/components/crud/crud-card";
import { ListRow, RowDetail } from "@/components/crud/list-row";
import { Pagination } from "@/components/crud/pagination";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useApi } from "@/lib/api";

export const CALLS_PAGE = 50;

export type CallsFilters = { date_from?: string; date_to?: string; offset?: number };

/**
 * The Queries (a database connection) or Calls (an API connection) tab:
 * what went through the connection, newest first, a page at a time, with
 * an optional range of days. A row opens to the whole exchange — the SQL,
 * its parameters and rows, or the request and response bodies.
 */
export function ConnectionCallsCard({
  connection,
  filters,
  onFiltersChange,
}: {
  connection: Connection;
  filters: CallsFilters;
  onFiltersChange: (filters: CallsFilters) => void;
}) {
  const intl = useIntl();
  const api = useApi();
  const queries = connection.type !== "meta";
  const offset = filters.offset ?? 0;
  const list = api.useAdminListConnectionCalls(connection.id, {
    date_from: filters.date_from,
    date_to: filters.date_to,
    limit: CALLS_PAGE,
    offset,
  });
  const total = list.data?.status === 200 ? list.data.data.total : 0;

  return (
    <CrudCard
      title={intl.formatMessage(queries ? messages.queries : messages.calls)}
      action={
        <div className="flex flex-wrap items-center gap-2">
          <Input
            type="date"
            aria-label={intl.formatMessage(messages.from)}
            value={filters.date_from ?? ""}
            max={filters.date_to}
            className="w-40"
            onChange={(e) =>
              onFiltersChange({ ...filters, date_from: e.target.value || undefined, offset: 0 })
            }
          />
          <Input
            type="date"
            aria-label={intl.formatMessage(messages.to)}
            value={filters.date_to ?? ""}
            min={filters.date_from}
            className="w-40"
            onChange={(e) =>
              onFiltersChange({ ...filters, date_to: e.target.value || undefined, offset: 0 })
            }
          />
          {(filters.date_from || filters.date_to) && (
            <Button
              type="button"
              size="sm"
              variant="ghost"
              onClick={() => onFiltersChange({ offset: 0 })}
            >
              {intl.formatMessage(messages.clear)}
            </Button>
          )}
        </div>
      }
    >
      <ApiList
        query={list}
        items={(data) => data.data}
        resource={queries ? "queries" : "calls"}
        empty={intl.formatMessage(queries ? messages.noQueries : messages.noCalls)}
      >
        {(calls: ConnectionCall[]) => calls.map((call) => <CallRow key={call.id} call={call} />)}
      </ApiList>
      <Pagination
        offset={offset}
        limit={CALLS_PAGE}
        total={total}
        onOffsetChange={(next) => onFiltersChange({ ...filters, offset: next || undefined })}
      />
    </CrudCard>
  );
}

function CallRow({ call }: { call: ConnectionCall }) {
  const intl = useIntl();
  const query = call.kind === "query";
  const title = query ? (call.sql ?? "").split("\n")[0] : `${call.method ?? ""} ${call.url ?? ""}`;

  return (
    <ListRow
      icon={query ? Database : Globe}
      title={<code className="font-mono text-sm break-all">{title}</code>}
      badges={
        <>
          <Badge variant={call.status === "ok" ? "secondary" : "destructive"}>
            {intl.formatMessage(call.status === "ok" ? messages.ok : messages.error)}
          </Badge>
          {call.response_status !== null && (
            <Badge variant="outline">{intl.formatNumber(call.response_status)}</Badge>
          )}
        </>
      }
    >
      <RowDetail>
        {intl.formatMessage(messages.when, {
          at: intl.formatDate(new Date(call.started_at), {
            dateStyle: "medium",
            timeStyle: "medium",
          }),
          duration: intl.formatNumber(call.duration_ms),
        })}
      </RowDetail>
      {call.error && (
        <RowDetail className="text-destructive">
          <code className="break-all">{call.error.split("\n")[0]}</code>
        </RowDetail>
      )}
      <details className="w-full text-xs">
        <summary className="cursor-pointer text-muted-foreground select-none">
          {intl.formatMessage(messages.details)}
        </summary>
        <div className="mt-2 space-y-2">
          {query ? (
            <>
              <Payload label={intl.formatMessage(messages.sql)} value={call.sql} />
              <Payload label={intl.formatMessage(messages.params)} value={json(call.params)} />
              <Payload label={intl.formatMessage(messages.result)} value={json(call.result)} />
            </>
          ) : (
            <>
              <Payload
                label={intl.formatMessage(messages.request, {
                  contentType: call.request_content_type ?? "",
                })}
                value={call.request_body}
              />
              <Payload
                label={intl.formatMessage(messages.response, {
                  contentType: call.response_content_type ?? "",
                })}
                value={call.response_body}
              />
            </>
          )}
        </div>
      </details>
    </ListRow>
  );
}

function Payload({ label, value }: { label: string; value: string | null | undefined }) {
  if (value === null || value === undefined || value === "") return null;
  return (
    <div>
      <div className="font-semibold text-muted-foreground uppercase">{label}</div>
      <pre className="mt-1 max-h-80 overflow-auto rounded-md border border-border bg-muted/40 p-2 font-mono break-words whitespace-pre-wrap select-text">
        {value}
      </pre>
    </div>
  );
}

const json = (value: unknown): string | null =>
  value === null || value === undefined ? null : JSON.stringify(value, null, 2);

const messages = {
  ...defineMessages({
    queries: { id: "connections.calls.queries", defaultMessage: "Queries" },
    calls: { id: "connections.calls.calls", defaultMessage: "Calls" },
    noQueries: {
      id: "connections.calls.noQueries",
      defaultMessage: "No queries were made through this connection in the range.",
    },
    noCalls: {
      id: "connections.calls.noCalls",
      defaultMessage: "No calls were made through this connection in the range.",
    },
    from: { id: "connections.calls.from", defaultMessage: "From" },
    to: { id: "connections.calls.to", defaultMessage: "To" },
    clear: { id: "connections.calls.clear", defaultMessage: "Clear" },
    ok: { id: "connections.calls.ok", defaultMessage: "OK" },
    error: { id: "connections.calls.error", defaultMessage: "Error" },
    details: { id: "connections.calls.details", defaultMessage: "Details" },
    sql: { id: "connections.calls.sql", defaultMessage: "SQL" },
    params: { id: "connections.calls.params", defaultMessage: "Parameters" },
    result: { id: "connections.calls.result", defaultMessage: "Result" },
  }),
  when: defineMessage<{ at: string; duration: string }>({
    id: "connections.calls.when",
    defaultMessage: "{at} · {duration} ms",
  }),
  request: defineMessage<{ contentType: string }>({
    id: "connections.calls.request",
    defaultMessage: "Request {contentType}",
  }),
  response: defineMessage<{ contentType: string }>({
    id: "connections.calls.response",
    defaultMessage: "Response {contentType}",
  }),
};
