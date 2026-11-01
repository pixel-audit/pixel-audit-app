import type { FormEvent, ReactNode } from "react";
import { useIntl } from "react-intl";

import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { commonMessages } from "@/lib/i18n/common-messages";
import { cn } from "@/lib/utils";

/**
 * The shell of every add/edit dialog: header, a `<form>` around the fields
 * (Enter submits), and a Cancel / Submit footer. The dialog owns only the
 * chrome — the fields and the submit logic stay with the caller.
 */
export function FormDialog({
  open,
  onOpenChange,
  title,
  description,
  submitLabel,
  cancelLabel,
  saving = false,
  onSubmit,
  className,
  children,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title: ReactNode;
  description?: ReactNode;
  submitLabel: ReactNode;
  cancelLabel?: ReactNode;
  /** Disables the submit button while a request is in flight. */
  saving?: boolean;
  /** Called on submit with the default already prevented. */
  onSubmit: () => void | Promise<void>;
  /** Extra classes for the dialog content, e.g. a wider `max-w-xl`. */
  className?: string;
  children: ReactNode;
}) {
  const intl = useIntl();
  const submit = (event: FormEvent) => {
    event.preventDefault();
    void onSubmit();
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className={cn("max-h-[90vh] overflow-y-auto", className)}>
        <form onSubmit={submit} className="space-y-4">
          <DialogHeader>
            <DialogTitle className="font-serif">{title}</DialogTitle>
            {description !== undefined && <DialogDescription>{description}</DialogDescription>}
          </DialogHeader>

          {children}

          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {cancelLabel ?? intl.formatMessage(commonMessages.cancel)}
            </Button>
            <Button type="submit" disabled={saving}>
              {submitLabel}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
