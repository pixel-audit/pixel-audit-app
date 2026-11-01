import { defineMessage, type IntlShape } from "react-intl";

import type { ConnectionType } from "@/api/generated/model";
import { okData } from "@/components/crud/api-response";
import { useApi } from "@/lib/api";

/** The connection types as the API declares them, with their credential fields. */
export function useConnectionTypes(): ConnectionType[] {
  return okData(useApi().useAdminListConnectionTypes().data)?.data ?? [];
}

/** A type's label: the API's, or the raw type while the types load. */
export function connectionTypeLabel(types: ConnectionType[], type: string): string {
  return types.find((t) => t.type === type)?.label ?? type;
}

/** A connection's row subtitle: the non-secret credentials that identify it. */
export function describeCredentials(
  intl: IntlShape,
  preview: Record<string, string>,
): string | null {
  const parts = Object.entries(preview).map(([key, value]) =>
    intl.formatMessage(messages.credential, { key, value }),
  );
  return parts.length > 0 ? parts.join(" · ") : null;
}

const messages = {
  credential: defineMessage<{ key: string; value: string }>({
    id: "connections.credential",
    defaultMessage: "{key}: {value}",
  }),
};
