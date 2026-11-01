import type { ReactNode } from "react";
import { useIntl } from "react-intl";

import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { commonMessages } from "@/lib/i18n/common-messages";

/**
 * "Delete X?" confirmation. The caller keeps the item being deleted and
 * renders the copy from it. With `blocked` the action button is hidden — the
 * dialog then only explains why the item must stay.
 */
export function ConfirmDeleteDialog({
  open,
  onOpenChange,
  title,
  description,
  confirmLabel,
  cancelLabel,
  onConfirm,
  pending = false,
  blocked = false,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title: ReactNode;
  description: ReactNode;
  confirmLabel: ReactNode;
  cancelLabel?: ReactNode;
  onConfirm: () => void | Promise<void>;
  /** Disables the confirm button while the request is in flight. */
  pending?: boolean;
  /** The item cannot be deleted — show the explanation without the action. */
  blocked?: boolean;
}) {
  const intl = useIntl();
  return (
    <AlertDialog open={open} onOpenChange={onOpenChange}>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle className="font-serif">{title}</AlertDialogTitle>
          <AlertDialogDescription>{description}</AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel>
            {cancelLabel ?? intl.formatMessage(commonMessages.cancel)}
          </AlertDialogCancel>
          {!blocked && (
            <AlertDialogAction disabled={pending} onClick={() => void onConfirm()}>
              {confirmLabel}
            </AlertDialogAction>
          )}
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );
}
