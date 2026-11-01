import { Plus } from "lucide-react";
import type { ReactNode } from "react";

import { ActionButton } from "@/components/crud/action-button";
import { PageHeader } from "@/components/page-header";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { cn } from "@/lib/utils";

export type ActionSpec = { label: ReactNode; onClick: () => void };

/**
 * The panel's list card, in two forms.
 *
 * As a **section** of a page (the default): a serif title with a short
 * description on the left, an "Add …" button on the right, the list below —
 * all inside the card.
 *
 * As the **page** itself (`page`): the title stands over the card as the
 * page's heading, like an item's page, with the action — the same outline
 * button an item's page has — at its right; the card holds only the list.
 * No description: a list page says what it is by its title.
 *
 * Pass `action` as a label + handler for the standard button, or a node for
 * anything else; omit it to hide the action (e.g. no write permission).
 */
export function CrudCard({
  title,
  description,
  meta,
  action,
  page = false,
  contentClassName,
  children,
}: {
  title: ReactNode;
  description?: ReactNode;
  /** A fainter third header line — counts, "used in …". */
  meta?: ReactNode;
  action?: ActionSpec | ReactNode;
  /** The list is the page: heading over the card, no description. */
  page?: boolean;
  contentClassName?: string;
  children: ReactNode;
}) {
  if (page) {
    return (
      <section className="space-y-4">
        <PageHeader
          title={title}
          actions={
            isActionSpec(action) ? (
              <ActionButton icon={Plus} onClick={action.onClick}>
                {action.label}
              </ActionButton>
            ) : (
              action
            )
          }
        />
        {meta !== undefined && <p className="text-sm text-muted-foreground">{meta}</p>}
        <Card className="shadow-none">
          {/* The content's padding assumes a header above it; here the card starts with the list. */}
          <CardContent className={cn("pt-6", contentClassName)}>{children}</CardContent>
        </Card>
      </section>
    );
  }

  return (
    <Card className="shadow-none">
      <CardHeader className="flex flex-row items-start justify-between gap-4">
        <div>
          <CardTitle className="font-serif text-lg">{title}</CardTitle>
          {description !== undefined && (
            <p className="mt-1 text-xs text-muted-foreground">{description}</p>
          )}
          {meta !== undefined && <p className="mt-1 text-xs text-muted-foreground/80">{meta}</p>}
        </div>
        {isActionSpec(action) ? (
          <Button size="sm" className="shrink-0" onClick={action.onClick}>
            <Plus className="size-4" /> {action.label}
          </Button>
        ) : (
          action
        )}
      </CardHeader>

      <CardContent className={contentClassName}>{children}</CardContent>
    </Card>
  );
}

function isActionSpec(action: unknown): action is ActionSpec {
  return (
    typeof action === "object" &&
    action !== null &&
    "onClick" in action &&
    typeof action.onClick === "function"
  );
}
