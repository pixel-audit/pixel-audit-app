import { defineMessages, useIntl } from "react-intl";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  DATE_RANGE_PRESETS,
  presetMessages,
  presetOf,
  presetRange,
  type DateRange,
} from "@/lib/date-range";
import { cn } from "@/lib/utils";

/**
 * The days a report covers: the usual presets as buttons, and the two dates
 * for anything else. The chosen preset is highlighted when the range is
 * one. The caller keeps the range (in the address, so a reload keeps it).
 */
export function DateRangePicker({
  value,
  onChange,
}: {
  value: DateRange;
  onChange: (range: DateRange) => void;
}) {
  const intl = useIntl();
  const chosen = presetOf(value);

  return (
    <div className="flex flex-wrap items-end gap-2">
      <div
        className="flex flex-wrap gap-1"
        role="group"
        aria-label={intl.formatMessage(messages.presets)}
      >
        {DATE_RANGE_PRESETS.map((preset) => (
          <Button
            key={preset}
            type="button"
            size="sm"
            variant={chosen === preset ? "default" : "outline"}
            className={cn(chosen !== preset && "text-muted-foreground")}
            onClick={() => onChange(presetRange(preset))}
          >
            {intl.formatMessage(presetMessages[preset])}
          </Button>
        ))}
      </div>
      <div className="flex items-center gap-2">
        <Input
          type="date"
          aria-label={intl.formatMessage(messages.from)}
          value={value.date_from}
          max={value.date_to}
          className="w-40"
          onChange={(e) => e.target.value && onChange({ ...value, date_from: e.target.value })}
        />
        <span className="text-sm text-muted-foreground">–</span>
        <Input
          type="date"
          aria-label={intl.formatMessage(messages.to)}
          value={value.date_to}
          min={value.date_from}
          className="w-40"
          onChange={(e) => e.target.value && onChange({ ...value, date_to: e.target.value })}
        />
      </div>
    </div>
  );
}

const messages = defineMessages({
  presets: { id: "dateRange.presets", defaultMessage: "Range presets" },
  from: { id: "dateRange.from", defaultMessage: "From" },
  to: { id: "dateRange.to", defaultMessage: "To" },
});
