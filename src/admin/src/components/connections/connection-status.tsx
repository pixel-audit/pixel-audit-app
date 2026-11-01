import { CircleCheck, CircleX } from "lucide-react";
import { defineMessages, useIntl } from "react-intl";

import type { Connection } from "@/api/generated/model";
import { Badge } from "@/components/ui/badge";

/** The outcome of the connection's last check, as a badge — nothing before the first check. */
export function ConnectionStatusBadge({ connection }: { connection: Connection }) {
  const intl = useIntl();
  if (connection.last_check_status === "ok") {
    return (
      <Badge variant="outline" className="gap-1 text-success">
        <CircleCheck aria-hidden className="size-3" />
        {intl.formatMessage(messages.ok)}
      </Badge>
    );
  }
  if (connection.last_check_status === "error") {
    return (
      <Badge variant="outline" className="gap-1 text-destructive">
        <CircleX aria-hidden className="size-3" />
        {intl.formatMessage(messages.failed)}
      </Badge>
    );
  }
  return null;
}

const messages = defineMessages({
  ok: { id: "connections.status.ok", defaultMessage: "Check passed" },
  failed: { id: "connections.status.failed", defaultMessage: "Check failed" },
});
