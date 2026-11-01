import { defineMessages } from "react-intl";

import type { RefreshRunKind, RefreshRunTrigger } from "@/api/generated/model";

/** The words for a run's status, kind and trigger — shared by the badge, the list and the page. */
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
