import { Link } from "@tanstack/react-router";
import { Copy } from "lucide-react";
import { defineMessage, defineMessages, useIntl } from "react-intl";
import { toast } from "sonner";

import type { ConnectionCall } from "@/api/generated/model";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { formatDay } from "@/lib/date-range";

/**
 * A recorded call's exchange, whole: the SQL, its parameters and its
 * rows, or the request and the response — each block with a button that
 * copies its text. Shown under a call wherever one is listed: the
 * connection's Calls tab, a cell's trail.
 */
export function CallPayloads({ call }: { call: ConnectionCall }) {
  const intl = useIntl();
  return call.kind === "query" ? (
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
        value={[call.method, call.url].filter(Boolean).join(" ")}
      />
      <Payload label={intl.formatMessage(messages.requestBody)} value={call.request_body} />
      <Payload
        label={intl.formatMessage(messages.response, {
          contentType: call.response_content_type ?? "",
        })}
        value={call.response_body}
      />
    </>
  );
}

/**
 * Where a call came from and what rests on it: its purpose, the day it
 * counted, the data source and step it served, the refresh run (a link
 * to its page), and the stored values that cite it. A call recorded
 * before purposes were kept shows only what it has.
 */
export function CallProvenance({ call }: { call: ConnectionCall }) {
  const intl = useIntl();
  const counts = call.cited_by.daily_counts.length;
  const hours = call.cited_by.meta_pixel_hours;
  return (
    <div className="flex flex-wrap items-center gap-x-2 gap-y-1 text-xs text-muted-foreground">
      {call.purpose && (
        <Badge variant="outline">
          {intl.formatMessage(messages.purpose, { purpose: call.purpose })}
        </Badge>
      )}
      {call.data_source && call.step && (
        <span>
          {intl.formatMessage(messages.served, {
            source: call.data_source.name,
            step: call.step.name,
          })}
        </span>
      )}
      {call.date && <span>{formatDay(intl, call.date)}</span>}
      {call.refresh_run_id && (
        <Link
          to="/refreshes/$id"
          params={{ id: call.refresh_run_id }}
          className="underline decoration-dotted underline-offset-2 hover:text-primary"
        >
          {intl.formatMessage(messages.run)}
        </Link>
      )}
      {(counts > 0 || hours > 0) && (
        <span>{intl.formatMessage(messages.citedBy, { counts, hours })}</span>
      )}
    </div>
  );
}

function Payload({ label, value }: { label: string; value: string | null | undefined }) {
  const intl = useIntl();
  if (value === null || value === undefined || value === "") return null;
  const copy = () => {
    void navigator.clipboard
      .writeText(value)
      .then(() => toast.success(intl.formatMessage(messages.copied, { label })))
      .catch(() => toast.error(intl.formatMessage(messages.copyFailed)));
  };
  return (
    <div>
      <div className="flex items-center justify-between gap-2">
        <div className="font-semibold text-muted-foreground uppercase">{label}</div>
        <Button
          type="button"
          variant="ghost"
          size="sm"
          className="h-6 px-2 text-xs"
          onClick={copy}
          aria-label={intl.formatMessage(messages.copy, { label })}
        >
          <Copy className="size-3.5" />
          {intl.formatMessage(messages.copyShort)}
        </Button>
      </div>
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
    sql: { id: "calls.payload.sql", defaultMessage: "SQL" },
    params: { id: "calls.payload.params", defaultMessage: "Parameters" },
    result: { id: "calls.payload.result", defaultMessage: "Result" },
    requestBody: { id: "calls.payload.requestBody", defaultMessage: "Request body" },
    copyShort: { id: "calls.payload.copyShort", defaultMessage: "Copy" },
    copyFailed: { id: "calls.payload.copyFailed", defaultMessage: "Could not copy." },
    run: { id: "calls.provenance.run", defaultMessage: "Refresh run" },
  }),
  request: defineMessage<{ contentType: string }>({
    id: "calls.payload.request",
    defaultMessage: "Request {contentType}",
  }),
  response: defineMessage<{ contentType: string }>({
    id: "calls.payload.response",
    defaultMessage: "Response {contentType}",
  }),
  copy: defineMessage<{ label: string }>({
    id: "calls.payload.copy",
    defaultMessage: "Copy the {label}",
  }),
  copied: defineMessage<{ label: string }>({
    id: "calls.payload.copied",
    defaultMessage: "{label} copied.",
  }),
  purpose: defineMessage<{ purpose: string }>({
    id: "calls.provenance.purpose",
    defaultMessage:
      "{purpose, select, count {Count} meta_stats_pull {Pixel stats pull} check {Check} other {{purpose}}}",
  }),
  served: defineMessage<{ source: string; step: string }>({
    id: "calls.provenance.served",
    defaultMessage: "{source} › {step}",
  }),
  citedBy: defineMessage<{ counts: number; hours: number }>({
    id: "calls.provenance.citedBy",
    defaultMessage:
      "Cited by {counts, plural, =0 {} one {# daily count} other {# daily counts}}{counts, plural, =0 {} other {{hours, plural, =0 {} other {, }}}}{hours, plural, =0 {} one {# cached hour} other {# cached hours}}",
  }),
};
