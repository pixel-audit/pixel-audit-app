import { CircleCheck, CircleX, Clock, Loader2 } from "lucide-react";
import { defineMessages, useIntl } from "react-intl";

import type { RefreshRunKind, RefreshRunStatus, RefreshRunTrigger } from "@/api/generated/model";
import { Badge } from "@/components/ui/badge";

/** A refresh run's status: an icon and a word, never the colour alone. */
export function RefreshRunStatusBadge({ status }: { status: RefreshRunStatus }) {
  const intl = useIntl();
  switch (status) {
    case "queued":
      return (
        <Badge variant="outline" className="gap-1 text-muted-foreground">
          <Clock aria-hidden className="size-3" />
          {intl.formatMessage(statusMessages.queued)}
        </Badge>
      );
    case "running":
      return (
        <Badge variant="outline" className="gap-1 text-info">
          <Loader2 aria-hidden className="size-3 animate-spin" />
          {intl.formatMessage(statusMessages.running)}
        </Badge>
      );
    case "done":
      return (
        <Badge variant="outline" className="gap-1 text-success">
          <CircleCheck aria-hidden className="size-3" />
          {intl.formatMessage(statusMessages.done)}
        </Badge>
      );
    case "failed":
      return (
        <Badge variant="outline" className="gap-1 text-destructive">
          <CircleX aria-hidden className="size-3" />
          {intl.formatMessage(statusMessages.failed)}
        </Badge>
      );
  }
}

export const statusMessages = defineMessages({
  queued: { id: "refreshRun.status.queued", defaultMessage: "Queued" },
  running: { id: "refreshRun.status.running", defaultMessage: "Running" },
  done: { id: "refreshRun.status.done", defaultMessage: "Done" },
  failed: { id: "refreshRun.status.failed", defaultMessage: "Failed" },
});

export const kindMessages: Record<RefreshRunKind, { id: string; defaultMessage: string }> =
  defineMessages({
    meta_pixel: { id: "refreshRun.kind.metaPixel", defaultMessage: "Meta pixel stats" },
    data_source: { id: "refreshRun.kind.dataSource", defaultMessage: "Daily counts" },
  });

export const triggerMessages: Record<RefreshRunTrigger, { id: string; defaultMessage: string }> =
  defineMessages({
    cron: { id: "refreshRun.trigger.cron", defaultMessage: "Scheduled" },
    manual: { id: "refreshRun.trigger.manual", defaultMessage: "Manual" },
    change: { id: "refreshRun.trigger.change", defaultMessage: "After a change" },
  });
