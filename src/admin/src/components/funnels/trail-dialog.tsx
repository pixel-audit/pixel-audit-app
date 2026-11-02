import { useQueryClient } from "@tanstack/react-query";
import { Link } from "@tanstack/react-router";
import { ChevronDown, ChevronRight, RefreshCw } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { defineMessage, defineMessages, useIntl } from "react-intl";

import type { ConnectionCall, DataSource, Step, StepDay } from "@/api/generated/model";
import { CallPayloads } from "@/components/connections/call-payloads";
import { ActionButton } from "@/components/crud/action-button";
import { okData, refusal } from "@/components/crud/api-response";
import { useApiCommand } from "@/components/crud/use-api-mutations";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { NonIdealState } from "@/components/ui/non-ideal-state";
import { Skeleton } from "@/components/ui/skeleton";
import { useApi } from "@/lib/api";
import { formatDay, formatRange, type DateRange } from "@/lib/date-range";
import { copy, formatCopy } from "@/lib/i18n/copy";
import { commonMessages } from "@/lib/i18n/common-messages";
import { cn } from "@/lib/utils";

/** Which cell of the report the trail is of. */
export type TrailCell = { source: DataSource; step: Step };

/**
 * The trail of one cell of the report — a data source's count of a step
 * over the shown range: a row per day with the count or why there is
 * none, when it was computed and by which run, and, opened, every call
 * the day rests on, whole, each block with a Copy button. Refresh queues
 * a recomputation of the one day, Refresh all of the range; while a run
 * of the data source is queued or running the dialog polls and the days
 * that change update in place.
 */
export function TrailDialog({
  funnelId,
  cell,
  range,
  onOpenChange,
}: {
  funnelId: string;
  /** Null closes the dialog. */
  cell: TrailCell | null;
  range: DateRange;
  onOpenChange: (open: boolean) => void;
}) {
  return (
    <Dialog open={cell !== null} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[90vh] max-w-4xl overflow-y-auto">
        {cell && <Trail funnelId={funnelId} cell={cell} range={range} />}
      </DialogContent>
    </Dialog>
  );
}

function Trail({ funnelId, cell, range }: { funnelId: string; cell: TrailCell; range: DateRange }) {
  const intl = useIntl();
  const api = useApi();
  const queryClient = useQueryClient();
  const [open, setOpen] = useState<Set<string>>(new Set());
  const { run: command, pending } = useApiCommand();
  const refresh = api.useAdminRefreshFunnel();

  const query = api.useAdminGetStepDays(funnelId, cell.source.id, cell.step.id, range);
  const trail = okData(query.data)?.data ?? null;

  // A run of this data source in flight: poll it, and when it ends, read everything again.
  const runs = api.useAdminListRefreshRuns(
    { data_source_id: cell.source.id, limit: 5 },
    {
      query: {
        refetchInterval: (q) => {
          const list = q.state.data?.status === 200 ? q.state.data.data.data : [];
          return list.some((r) => r.status === "queued" || r.status === "running") ? 5_000 : false;
        },
      },
    },
  );
  const active =
    runs.data?.status === 200 &&
    runs.data.data.data.some((r) => r.status === "queued" || r.status === "running");
  const wasActive = useRef(false);
  useEffect(() => {
    if (wasActive.current && !active) {
      void queryClient.invalidateQueries({
        queryKey: api.getAdminGetStepDaysQueryKey(funnelId, cell.source.id, cell.step.id),
      });
      void queryClient.invalidateQueries({
        queryKey: api.getAdminGetFunnelReportQueryKey(funnelId),
      });
      void queryClient.invalidateQueries({
        queryKey: api.getAdminGetStepReportQueryKey(funnelId, cell.step.id),
      });
    }
    wasActive.current = active;
  }, [active, api, cell.source.id, cell.step.id, funnelId, queryClient]);

  const queue = (days: DateRange) =>
    void command(
      () =>
        refresh.mutateAsync({
          funnelId,
          data: { ...days, data_source_id: cell.source.id, step_id: cell.step.id },
        }),
      {
        done: intl.formatMessage(messages.queued),
        failed: (result) =>
          formatCopy(intl, refusal(result, copy(messages.refreshFailed), messages.subject)),
        invalidate: [api.getAdminListRefreshRunsQueryKey()],
      },
    );

  const toggle = (date: string) =>
    setOpen((previous) => {
      const next = new Set(previous);
      if (next.has(date)) next.delete(date);
      else next.add(date);
      return next;
    });

  return (
    <>
      <DialogHeader>
        <DialogTitle className="font-serif">
          {intl.formatMessage(messages.title, { source: cell.source.name, step: cell.step.name })}
        </DialogTitle>
        <DialogDescription>{formatRange(intl, range)}</DialogDescription>
      </DialogHeader>

      <div className="flex items-center justify-end gap-2">
        {active && <Badge variant="secondary">{intl.formatMessage(messages.refreshing)}</Badge>}
        <ActionButton icon={RefreshCw} onClick={() => queue(range)} disabled={pending}>
          {intl.formatMessage(messages.refreshAll)}
        </ActionButton>
      </div>

      {query.isPending ? (
        <div className="space-y-2">
          <Skeleton className="h-8 w-full" />
          <Skeleton className="h-8 w-full" />
          <Skeleton className="h-8 w-full" />
        </div>
      ) : query.isError || trail === null ? (
        <NonIdealState>
          <p>
            {formatCopy(
              intl,
              refusal(query.data ?? null, copy(messages.loadFailed), messages.subject),
            )}
          </p>
          <Button variant="outline" size="sm" className="mt-3" onClick={() => void query.refetch()}>
            {intl.formatMessage(commonMessages.retry)}
          </Button>
        </NonIdealState>
      ) : (
        <table className="w-full text-sm">
          <thead>
            <tr className="text-left text-xs text-muted-foreground uppercase">
              <th className="w-6 py-2" />
              <th className="py-2 pr-2 font-semibold">{intl.formatMessage(messages.day)}</th>
              <th className="px-2 py-2 text-right font-semibold">{cell.step.name}</th>
              <th className="px-2 py-2 font-semibold">{intl.formatMessage(messages.computedAt)}</th>
              <th className="px-2 py-2 font-semibold">{intl.formatMessage(messages.run)}</th>
              <th className="w-10 py-2" />
            </tr>
          </thead>
          <tbody>
            {trail.days.map((day) => (
              <DayRows
                key={day.date}
                day={day}
                open={open.has(day.date)}
                onToggle={() => toggle(day.date)}
                onRefresh={() => queue({ date_from: day.date, date_to: day.date })}
                refreshing={pending}
                source={cell.source}
                step={cell.step}
              />
            ))}
          </tbody>
        </table>
      )}
    </>
  );
}

function DayRows({
  day,
  open,
  onToggle,
  onRefresh,
  refreshing,
  source,
  step,
}: {
  day: StepDay;
  open: boolean;
  onToggle: () => void;
  onRefresh: () => void;
  refreshing: boolean;
  source: DataSource;
  step: Step;
}) {
  const intl = useIntl();
  const Chevron = open ? ChevronDown : ChevronRight;
  return (
    <>
      <tr
        className={cn(
          "border-t border-border",
          day.status === "missing" && "text-muted-foreground",
        )}
      >
        <td className="py-2">
          <button
            type="button"
            onClick={onToggle}
            aria-expanded={open}
            aria-label={intl.formatMessage(messages.toggle, { day: formatDay(intl, day.date) })}
            className="inline-flex size-6 items-center justify-center rounded-md hover:bg-muted"
          >
            <Chevron className="size-4" />
          </button>
        </td>
        <td className="py-2 pr-2 whitespace-nowrap">{formatDay(intl, day.date)}</td>
        <td className="px-2 py-2 text-right tabular-nums">
          {day.status === "ok" && day.count !== null ? (
            <span className="font-medium text-foreground">{intl.formatNumber(day.count)}</span>
          ) : day.status === "error" ? (
            <span className="text-destructive">{intl.formatMessage(messages.failed)}</span>
          ) : (
            intl.formatMessage(messages.notComputed)
          )}
        </td>
        <td className="px-2 py-2 whitespace-nowrap">
          {day.computed_at &&
            intl.formatDate(new Date(day.computed_at), { dateStyle: "medium", timeStyle: "short" })}
        </td>
        <td className="px-2 py-2 whitespace-nowrap">
          {day.refresh_run && (
            <Link
              to="/refreshes/$id"
              params={{ id: day.refresh_run.id }}
              className="underline decoration-dotted underline-offset-2 hover:text-primary"
            >
              {intl.formatMessage(messages.runLabel, {
                trigger: day.refresh_run.trigger,
                status: day.refresh_run.status,
              })}
            </Link>
          )}
        </td>
        <td className="py-2 text-right">
          <Button
            type="button"
            variant="ghost"
            size="sm"
            className="h-7 px-2"
            onClick={onRefresh}
            disabled={refreshing}
            aria-label={intl.formatMessage(messages.refreshDay, { day: formatDay(intl, day.date) })}
          >
            <RefreshCw className="size-3.5" />
          </Button>
        </td>
      </tr>
      {open && (
        <tr className="border-t border-border/60 bg-muted/20">
          <td />
          <td colSpan={5} className="space-y-4 py-3 pr-2">
            {day.error && (
              <pre className="font-mono text-xs break-words whitespace-pre-wrap text-destructive select-text">
                {day.error}
              </pre>
            )}
            {day.calls.length === 0 ? (
              <p className="text-xs text-muted-foreground">
                {intl.formatMessage(
                  day.status === "missing" ? messages.noCallsMissing : messages.noCallsBefore,
                )}
              </p>
            ) : (
              day.calls.map((call) => (
                <TrailCall key={call.id} call={call} source={source} step={step} date={day.date} />
              ))
            )}
          </td>
        </tr>
      )}
    </>
  );
}

function TrailCall({
  call,
  source,
  step,
  date,
}: {
  call: ConnectionCall;
  source: DataSource;
  step: Step;
  date: string;
}) {
  const intl = useIntl();
  return (
    <div className="space-y-2 text-xs">
      <div className="flex flex-wrap items-center gap-2">
        <Badge variant={call.status === "ok" ? "secondary" : "destructive"}>
          {intl.formatMessage(call.status === "ok" ? messages.ok : messages.error)}
        </Badge>
        {call.connection && (
          <Link
            to="/settings/connections/$id/calls"
            params={{ id: call.connection.id }}
            search={{ data_source_id: source.id, step_id: step.id, date }}
            className="font-medium text-foreground underline decoration-dotted underline-offset-2 hover:text-primary"
          >
            {call.connection.name}
          </Link>
        )}
        <span className="text-muted-foreground">
          {intl.formatMessage(messages.when, {
            at: intl.formatDate(new Date(call.started_at), {
              dateStyle: "medium",
              timeStyle: "medium",
            }),
            duration: intl.formatNumber(call.duration_ms),
          })}
        </span>
      </div>
      {call.error && (
        <pre className="font-mono break-words whitespace-pre-wrap text-destructive select-text">
          {call.error}
        </pre>
      )}
      <CallPayloads call={call} />
    </div>
  );
}

const messages = {
  ...defineMessages({
    day: { id: "trail.day", defaultMessage: "Day" },
    computedAt: { id: "trail.computedAt", defaultMessage: "Computed" },
    run: { id: "trail.run", defaultMessage: "Refresh run" },
    refreshAll: { id: "trail.refreshAll", defaultMessage: "Refresh all" },
    refreshing: { id: "trail.refreshing", defaultMessage: "Refreshing…" },
    queued: { id: "trail.queued", defaultMessage: "Refresh queued — see Refreshes." },
    refreshFailed: {
      id: "trail.refreshFailed",
      defaultMessage: "The refresh could not be queued.",
    },
    loadFailed: { id: "trail.loadFailed", defaultMessage: "The days could not be loaded." },
    subject: { id: "trail.subject", defaultMessage: "trail" },
    failed: { id: "trail.failed", defaultMessage: "failed" },
    notComputed: { id: "trail.notComputed", defaultMessage: "not computed" },
    noCallsMissing: {
      id: "trail.noCallsMissing",
      defaultMessage: "Not computed yet: no call was made for this day.",
    },
    noCallsBefore: {
      id: "trail.noCallsBefore",
      defaultMessage: "Computed before calls were kept: refresh the day to record its call.",
    },
    ok: { id: "trail.call.ok", defaultMessage: "OK" },
    error: { id: "trail.call.error", defaultMessage: "Error" },
  }),
  title: defineMessage<{ source: string; step: string }>({
    id: "trail.title",
    defaultMessage: "{source} — {step}",
  }),
  toggle: defineMessage<{ day: string }>({
    id: "trail.toggle",
    defaultMessage: "The calls behind {day}",
  }),
  refreshDay: defineMessage<{ day: string }>({
    id: "trail.refreshDay",
    defaultMessage: "Recompute {day}",
  }),
  runLabel: defineMessage<{ trigger: string; status: string }>({
    id: "trail.runLabel",
    defaultMessage:
      "{trigger, select, cron {Scheduled} manual {Manual} change {After a change} other {{trigger}}} · {status, select, queued {queued} running {running} done {done} failed {failed} other {{status}}}",
  }),
  when: defineMessage<{ at: string; duration: string }>({
    id: "trail.call.when",
    defaultMessage: "{at} · {duration} ms",
  }),
};
