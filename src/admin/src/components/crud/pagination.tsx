import { ChevronLeft, ChevronRight } from "lucide-react";
import { defineMessage, defineMessages, useIntl } from "react-intl";

import { Button } from "@/components/ui/button";

/**
 * Offset pagination under a list: which items of how many are shown, and
 * a page back and forward. The caller keeps the offset (in the address).
 */
export function Pagination({
  offset,
  limit,
  total,
  onOffsetChange,
}: {
  offset: number;
  limit: number;
  total: number;
  onOffsetChange: (offset: number) => void;
}) {
  const intl = useIntl();
  if (total <= limit && offset === 0) return null;
  const from = Math.min(offset + 1, total);
  const to = Math.min(offset + limit, total);

  return (
    <div className="flex items-center justify-between gap-4 pt-2 text-sm text-muted-foreground">
      <span>{intl.formatMessage(messages.shown, { from, to, total })}</span>
      <div className="flex gap-1">
        <Button
          type="button"
          size="sm"
          variant="outline"
          disabled={offset === 0}
          onClick={() => onOffsetChange(Math.max(0, offset - limit))}
          aria-label={intl.formatMessage(messages.previous)}
        >
          <ChevronLeft />
        </Button>
        <Button
          type="button"
          size="sm"
          variant="outline"
          disabled={offset + limit >= total}
          onClick={() => onOffsetChange(offset + limit)}
          aria-label={intl.formatMessage(messages.next)}
        >
          <ChevronRight />
        </Button>
      </div>
    </div>
  );
}

const messages = {
  ...defineMessages({
    previous: { id: "pagination.previous", defaultMessage: "Previous page" },
    next: { id: "pagination.next", defaultMessage: "Next page" },
  }),
  shown: defineMessage<{ from: number; to: number; total: number }>({
    id: "pagination.shown",
    defaultMessage: "{from}–{to} of {total}",
  }),
};
