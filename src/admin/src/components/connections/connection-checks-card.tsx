import { defineMessages, useIntl } from "react-intl";

import type { Connection } from "@/api/generated/model";
import { ConnectionStatusBadge } from "@/components/connections/connection-status";
import { DetailField, DetailsCard } from "@/components/crud/details-card";

/** The Checks tab: the last check's time, outcome and error. */
export function ConnectionChecksCard({ connection }: { connection: Connection }) {
  const intl = useIntl();

  return (
    <DetailsCard title={intl.formatMessage(messages.lastCheck)}>
      <DetailField label={intl.formatMessage(messages.checkedAt)}>
        {connection.last_checked_at
          ? intl.formatDate(new Date(connection.last_checked_at), {
              dateStyle: "medium",
              timeStyle: "short",
            })
          : null}
      </DetailField>
      <DetailField label={intl.formatMessage(messages.outcome)}>
        {connection.last_check_status === null ? null : (
          <ConnectionStatusBadge connection={connection} />
        )}
      </DetailField>
      <DetailField label={intl.formatMessage(messages.error)} wide>
        {connection.last_check_error && (
          <code className="text-xs break-all text-destructive">{connection.last_check_error}</code>
        )}
      </DetailField>
    </DetailsCard>
  );
}

const messages = defineMessages({
  lastCheck: { id: "connections.detail.lastCheck", defaultMessage: "Last check" },
  checkedAt: { id: "connections.detail.checkedAt", defaultMessage: "Checked at" },
  outcome: { id: "connections.detail.outcome", defaultMessage: "Outcome" },
  error: { id: "connections.detail.error", defaultMessage: "Error" },
});
