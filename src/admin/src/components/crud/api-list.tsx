import type { ReactNode } from "react";
import { defineMessage, useIntl } from "react-intl";

import { okData, type OkData } from "@/components/crud/api-response";
import { Button } from "@/components/ui/button";
import { NonIdealState } from "@/components/ui/non-ideal-state";
import { Skeleton } from "@/components/ui/skeleton";
import { commonMessages } from "@/lib/i18n/common-messages";

/** The slice of a TanStack query result the list state needs. */
export type ListQuery<R> = {
  isPending: boolean;
  isError: boolean;
  data: R | undefined;
  refetch: () => Promise<unknown>;
};

/**
 * Renders an API-backed list through its non-ideal states — loading, load
 * failure (with retry), empty — and hands the
 * items to `children` only when there is something to show.
 *
 * `resource` is the plural noun for the standard copy ("the venues");
 * `empty` is the one message that differs per list.
 */
export function ApiList<R extends { status: number }, T>({
  query,
  items,
  resource,
  empty,
  children,
}: {
  query: ListQuery<R>;
  /** Picks the items out of a 200 response body. */
  items: (data: OkData<R>) => T[];
  resource: string;
  empty: ReactNode;
  children: (items: T[]) => ReactNode;
}) {
  const intl = useIntl();
  if (query.isPending) {
    return (
      <div className="space-y-2">
        <Skeleton className="h-16 w-full" />
        <Skeleton className="h-16 w-full" />
      </div>
    );
  }

  const data = okData(query.data);

  if (query.isError || data === null) {
    return (
      <NonIdealState>
        <p>{intl.formatMessage(messages.loadFailed, { resource })}</p>
        <Button variant="outline" size="sm" className="mt-3" onClick={() => void query.refetch()}>
          {intl.formatMessage(commonMessages.retry)}
        </Button>
      </NonIdealState>
    );
  }

  const list = items(data);
  if (list.length === 0) return <NonIdealState>{empty}</NonIdealState>;

  return <ul className="space-y-2">{children(list)}</ul>;
}

const messages = {
  loadFailed: defineMessage<{ resource: string }>({
    id: "crud.list.loadFailed",
    defaultMessage: "Could not load the {resource}.",
  }),
};
