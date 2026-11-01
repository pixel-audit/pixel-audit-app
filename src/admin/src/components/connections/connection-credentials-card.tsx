import { defineMessage, defineMessages, useIntl } from "react-intl";

import type { Connection } from "@/api/generated/model";
import { useConnectionTypes } from "@/components/connections/connection-types";
import { DetailField, DetailsCard } from "@/components/crud/details-card";

/** The Credentials tab: each credential as the API shows it — a secret as set, a URL without its password. */
export function ConnectionCredentialsCard({ connection }: { connection: Connection }) {
  const intl = useIntl();
  const type = useConnectionTypes().find((t) => t.type === connection.type);

  return (
    <DetailsCard title={intl.formatMessage(messages.credentials)} description={type?.label}>
      {(type?.credentials ?? []).map((spec) => (
        <DetailField key={spec.key} label={spec.label}>
          {connection.credentials_preview[spec.key] ??
            (connection.credential_keys.includes(spec.key)
              ? intl.formatMessage(messages.secretSet)
              : null)}
        </DetailField>
      ))}
      {connection.managed_by_env && (
        <DetailField label={intl.formatMessage(messages.source)} wide>
          {intl.formatMessage(messages.managedDetail, { name: connection.name })}
        </DetailField>
      )}
    </DetailsCard>
  );
}

const messages = {
  ...defineMessages({
    credentials: { id: "connections.detail.credentials", defaultMessage: "Credentials" },
    secretSet: { id: "connections.detail.secretSet", defaultMessage: "Set (hidden)" },
    source: { id: "connections.detail.source", defaultMessage: "Defined by" },
  }),
  managedDetail: defineMessage<{ name: string }>({
    id: "connections.detail.managedDetail",
    defaultMessage: "The CONNECTION_{name}_* environment variables, applied by the boot role.",
  }),
};
