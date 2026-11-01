import type { QueryKey } from "@tanstack/react-query";
import { useEffect, type ReactNode } from "react";
import { defineMessages, useIntl } from "react-intl";

import type { RefreshRangeParams } from "@/api/generated/model";
import { FormDialog } from "@/components/crud/form-dialog";
import { useApiCommand, type ApiResponse } from "@/components/crud/use-api-mutations";
import { FormField } from "@/components/form/field";
import { useFormState } from "@/components/form/use-form-state";
import { Input } from "@/components/ui/input";
import { defaultRange, type DateRange } from "@/lib/date-range";

/**
 * "Refresh these days": a date range and a submit. Shared by a funnel's
 * manual recomputation and a Meta connection's pull; the caller supplies
 * the call and the wording. The range starts as the one the caller shows.
 */
export function RefreshDialog<R extends ApiResponse>({
  open,
  onOpenChange,
  title,
  description,
  initial,
  submit,
  done,
  failed,
  invalidate,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title: ReactNode;
  description?: ReactNode;
  initial?: DateRange;
  submit: (range: RefreshRangeParams) => Promise<R>;
  done: (result: R) => string;
  failed: (result: R | null) => string;
  invalidate: QueryKey[];
}) {
  const intl = useIntl();
  const { form, set, reset } = useFormState<DateRange>(initial ?? defaultRange());
  const { run, pending } = useApiCommand();

  useEffect(() => {
    if (open) reset(initial ?? defaultRange());
  }, [open, initial, reset]);

  const onSubmit = async () => {
    const result = await run(() => submit(form), { done, failed, invalidate });
    if (result) onOpenChange(false);
  };

  return (
    <FormDialog
      open={open}
      onOpenChange={onOpenChange}
      title={title}
      description={description}
      submitLabel={intl.formatMessage(messages.submit)}
      saving={pending}
      onSubmit={onSubmit}
    >
      <div className="grid gap-4 sm:grid-cols-2">
        <FormField label={intl.formatMessage(messages.from)} htmlFor="refresh-from">
          <Input
            id="refresh-from"
            type="date"
            value={form.date_from}
            max={form.date_to}
            onChange={(e) => set("date_from", e.target.value)}
            required
          />
        </FormField>
        <FormField label={intl.formatMessage(messages.to)} htmlFor="refresh-to">
          <Input
            id="refresh-to"
            type="date"
            value={form.date_to}
            min={form.date_from}
            onChange={(e) => set("date_to", e.target.value)}
            required
          />
        </FormField>
      </div>
    </FormDialog>
  );
}

const messages = defineMessages({
  submit: { id: "refresh.dialog.submit", defaultMessage: "Refresh" },
  from: { id: "refresh.dialog.from", defaultMessage: "From" },
  to: { id: "refresh.dialog.to", defaultMessage: "To" },
});
