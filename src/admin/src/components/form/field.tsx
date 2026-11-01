import type { ReactNode } from "react";

import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { cn } from "@/lib/utils";

/** Server-side validation messages for one field (the API's 422 shape). */
export function FieldErrors({ errors }: { errors?: string[] }) {
  if (!errors || errors.length === 0) return null;
  return <p className="text-xs text-destructive">{errors.join(", ")}</p>;
}

/**
 * A labelled form control: label above, the control, an optional hint and
 * the field's validation errors below. Every dialog field is this shape —
 * write only the control itself.
 */
export function FormField({
  label,
  htmlFor,
  hint,
  errors,
  className,
  children,
}: {
  label: ReactNode;
  /** Id of the control the label points to. Omit for grouped controls. */
  htmlFor?: string;
  /** Explanatory line under the control. */
  hint?: ReactNode;
  errors?: string[];
  className?: string;
  children: ReactNode;
}) {
  return (
    <div className={cn("space-y-2", className)}>
      <Label htmlFor={htmlFor}>{label}</Label>
      {children}
      {hint !== undefined && <p className="text-xs text-muted-foreground">{hint}</p>}
      <FieldErrors errors={errors} />
    </div>
  );
}

/**
 * A boxed on/off setting: label with a one-line explanation on the left, the
 * switch on the right.
 */
export function SwitchRow({
  id,
  label,
  description,
  checked,
  onCheckedChange,
  disabled,
}: {
  id: string;
  label: ReactNode;
  description?: ReactNode;
  checked: boolean;
  onCheckedChange: (checked: boolean) => void;
  disabled?: boolean;
}) {
  return (
    <div className="flex items-center justify-between gap-4 rounded-lg border border-border p-3">
      <Label htmlFor={id} className="font-normal">
        {label}
        {description !== undefined && (
          <span className="block text-xs text-muted-foreground">{description}</span>
        )}
      </Label>
      <Switch id={id} checked={checked} onCheckedChange={onCheckedChange} disabled={disabled} />
    </div>
  );
}
