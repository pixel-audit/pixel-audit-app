import { Database, Globe } from "lucide-react";
import { defineMessage, defineMessages, useIntl } from "react-intl";

import type {
  AdminListConnectionCallsPurpose as CallPurpose,
  Connection,
  ConnectionCall,
} from "@/api/generated/model";
import { CallPayloads, CallProvenance } from "@/components/connections/call-payloads";
import { ApiList } from "@/components/crud/api-list";
import { CrudCard } from "@/components/crud/crud-card";
import { ListRow, RowDetail } from "@/components/crud/list-row";
import { Pagination } from "@/components/crud/pagination";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { useApi } from "@/lib/api";
import { CALL_PURPOSES } from "@/lib/call-purposes";
import { formatDay } from "@/lib/date-range";

export const CALLS_PAGE = 50;

export type CallsFilters = {
  date_from?: string;
  date_to?: string;
  purpose?: CallPurpose;
  /** What the call served — set by a link from a cell's trail. */
  data_source_id?: string;
  step_id?: string;
  date?: string;
  offset?: number;
};

const ANY = "any";

/**
 * The Queries (a database connection) or Calls (an API connection) tab:
 * what went through the connection, newest first, a page at a time, with
 * an optional range of days and a purpose; a link from a cell's trail
 * narrows it to the calls that served one data source, step and day.
 * Every row says where the call came from and what cites it, and opens
 * to the whole exchange — the SQL, its parameters and rows, or the
 * request and response bodies — with a Copy button on each.
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
    purpose: filters.purpose,
    data_source_id: filters.data_source_id,
    step_id: filters.step_id,
    date: filters.date,
    limit: CALLS_PAGE,
    offset,
  });
  const total = list.data?.status === 200 ? list.data.data.total : 0;
  const narrowed = Boolean(
    filters.date_from ||
    filters.date_to ||
    filters.purpose ||
    filters.data_source_id ||
    filters.step_id ||
    filters.date,
  );

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
          <Select
            value={filters.purpose ?? ANY}
            onValueChange={(value) =>
              onFiltersChange({
                ...filters,
                purpose: value === ANY ? undefined : (value as CallPurpose),
                offset: 0,
              })
            }
          >
            <SelectTrigger className="w-40" aria-label={intl.formatMessage(messages.purpose)}>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value={ANY}>{intl.formatMessage(messages.anyPurpose)}</SelectItem>
              {CALL_PURPOSES.map((purpose) => (
                <SelectItem key={purpose} value={purpose}>
                  {intl.formatMessage(messages.purposeName, { purpose })}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          {filters.date && <Badge variant="outline">{formatDay(intl, filters.date)}</Badge>}
          {narrowed && (
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
      <div className="mt-1">
        <CallProvenance call={call} />
      </div>
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
          <CallPayloads call={call} />
        </div>
      </details>
    </ListRow>
  );
}

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
    purpose: { id: "connections.calls.purpose", defaultMessage: "Purpose" },
    anyPurpose: { id: "connections.calls.anyPurpose", defaultMessage: "Any purpose" },
  }),
  when: defineMessage<{ at: string; duration: string }>({
    id: "connections.calls.when",
    defaultMessage: "{at} · {duration} ms",
  }),
  purposeName: defineMessage<{ purpose: string }>({
    id: "connections.calls.purposeName",
    defaultMessage:
      "{purpose, select, count {Count} meta_stats_pull {Pixel stats pull} check {Check} other {{purpose}}}",
  }),
};
