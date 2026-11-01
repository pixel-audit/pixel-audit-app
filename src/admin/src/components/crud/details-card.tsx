import type { ReactNode } from "react";
import { defineMessages, useIntl } from "react-intl";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { cn } from "@/lib/utils";

/**
 * The item page's "what this is" card: a serif title with an optional
 * description on the left, the actions (Edit, say) on the right, and the
 * item's fields below as `DetailField`s in a two-column grid.
 */
export function DetailsCard({
  title,
  description,
  actions,
  columns = 2,
  children,
}: {
  title?: ReactNode;
  description?: ReactNode;
  actions?: ReactNode;
  /** Fields per row on wide screens. */
  columns?: 1 | 2 | 3;
  children: ReactNode;
}) {
  const intl = useIntl();
  return (
    <Card className="shadow-none">
      <CardHeader className="flex flex-row items-start justify-between gap-4">
        <div>
          <CardTitle className="font-serif text-lg">
            {title ?? intl.formatMessage(messages.details)}
          </CardTitle>
          {description !== undefined && (
            <p className="mt-1 text-xs text-muted-foreground">{description}</p>
          )}
        </div>
        {actions && <div className="flex shrink-0 flex-wrap items-center gap-2">{actions}</div>}
      </CardHeader>
      <CardContent>
        <dl
          className={cn(
            "grid gap-x-6 gap-y-4",
            columns === 2 && "sm:grid-cols-2",
            columns === 3 && "sm:grid-cols-2 lg:grid-cols-3",
          )}
        >
          {children}
        </dl>
      </CardContent>
    </Card>
  );
}

/**
 * One labelled value of a `DetailsCard`. A blank value reads as a dash, so
 * an unset optional field is still visibly there. `wide` spans the whole
 * row — for an address or a description.
 */
export function DetailField({
  label,
  wide = false,
  children,
}: {
  label: ReactNode;
  wide?: boolean;
  children: ReactNode;
}) {
  const blank =
    children === null || children === undefined || children === "" || children === false;
  return (
    <div className={cn("min-w-0", wide && "sm:col-span-full")}>
      <dt className="text-[11px] font-semibold tracking-wide text-primary uppercase">{label}</dt>
      <dd className="mt-0.5 text-sm text-foreground">
        {blank ? <span className="text-muted-foreground">—</span> : children}
      </dd>
    </div>
  );
}

const messages = defineMessages({
  details: { id: "crud.details.title", defaultMessage: "Details" },
});
