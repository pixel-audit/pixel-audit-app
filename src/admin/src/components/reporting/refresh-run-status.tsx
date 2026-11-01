import { CircleCheck, CircleX, Clock, Loader2 } from "lucide-react";
import { useIntl } from "react-intl";

import type { RefreshRunStatus } from "@/api/generated/model";
import { statusMessages } from "@/components/reporting/refresh-run-messages";
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
