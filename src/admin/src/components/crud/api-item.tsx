import { Link, type LinkProps } from "@tanstack/react-router";
import type { ReactNode } from "react";
import { defineMessage, useIntl } from "react-intl";

import type { ListQuery } from "@/components/crud/api-list";
import { okData, type OkData } from "@/components/crud/api-response";
import { Button } from "@/components/ui/button";
import { NonIdealState } from "@/components/ui/non-ideal-state";
import { Skeleton } from "@/components/ui/skeleton";
import { commonMessages } from "@/lib/i18n/common-messages";

/**
 * The item's page counterpart of `ApiList`: renders one API-backed item
 * through its non-ideal states — loading, load failure (with retry),
 * no such item — and hands the item to `children`
 * only when there is one to show.
 *
 * Most lists have no "get one" endpoint, so `item` usually finds the item in
 * the list response by the address's id; the list query is shared with the
 * list page and the breadcrumb, so nothing loads twice.
 *
 * `resource` is the singular noun for the standard copy ("the venue");
 * `back` is the list to return to when the item is gone.
 */
export function ApiItem<R extends { status: number }, T>({
  query,
  item,
  resource,
  back,
  children,
}: {
  query: ListQuery<R>;
  /** Picks the item out of a 200 response body; undefined when it isn't there. */
  item: (data: OkData<R>) => T | undefined;
  resource: string;
  back: { label: ReactNode; link: LinkProps };
  children: (item: T) => ReactNode;
}) {
  const intl = useIntl();
  if (query.isPending) {
    return (
      <div className="space-y-8">
        <div className="space-y-2">
          <Skeleton className="h-8 w-64" />
          <Skeleton className="h-4 w-96 max-w-full" />
        </div>
        <Skeleton className="h-48 w-full" />
      </div>
    );
  }

  const data = okData(query.data);

  // A 404 is not a failure to load: the item is gone (or the address names
  // nothing), and retrying would not bring it back.
  if (query.data?.status === 404) {
    return <Gone resource={resource} back={back} />;
  }

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

  const found = item(data);
  if (found === undefined) return <Gone resource={resource} back={back} />;

  return children(found);
}

function Gone({
  resource,
  back,
}: {
  resource: string;
  back: { label: ReactNode; link: LinkProps };
}) {
  const intl = useIntl();
  return (
    <NonIdealState>
      <p>{intl.formatMessage(messages.gone, { resource })}</p>
      <Button asChild variant="outline" size="sm" className="mt-3">
        <Link {...back.link}>{back.label}</Link>
      </Button>
    </NonIdealState>
  );
}

const messages = {
  loadFailed: defineMessage<{ resource: string }>({
    id: "crud.item.loadFailed",
    defaultMessage: "Could not load the {resource}.",
  }),
  gone: defineMessage<{ resource: string }>({
    id: "crud.item.gone",
    defaultMessage: "This {resource} doesn't exist or has been deleted.",
  }),
};
