import { Check, ChevronDown } from "lucide-react";
import { useState, type ReactNode } from "react";

import { Button } from "@/components/ui/button";
import {
  Command,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
} from "@/components/ui/command";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { cn } from "@/lib/utils";

/** One choice of a `Combobox`. */
export type ComboboxOption = {
  /** What is chosen — and what the search matches, besides `keywords`. */
  value: string;
  /** How the choice reads; the value itself when omitted. */
  label?: ReactNode;
  /** A note shown on the right of the choice, in small type — an offset, a code. */
  description?: ReactNode;
  /** More words the search should find the choice by. */
  keywords?: string[];
  /** A pill on the far right of the choice — a status. */
  badge?: ReactNode;
  /** A second line under the choice, in the list only — a period, a note. */
  detail?: ReactNode;
};

/**
 * A select with a search box: a button showing the chosen option, opening
 * a filtered list. For lists too long to scroll through — time zones,
 * currencies — where a plain `Select` would be a chore. One value at a
 * time; the empty string is "nothing chosen" and shows the placeholder.
 */
export function Combobox({
  id,
  value,
  onChange,
  options,
  placeholder = "Not set",
  searchPlaceholder = "Search…",
  emptyText = "Nothing matches.",
  disabled,
  className,
  contentClassName,
}: {
  id?: string;
  value: string;
  onChange: (value: string) => void;
  options: ComboboxOption[];
  placeholder?: string;
  searchPlaceholder?: string;
  emptyText?: ReactNode;
  disabled?: boolean;
  className?: string;
  /** The open list's own classes — e.g. wider than the button. */
  contentClassName?: string;
}) {
  const [open, setOpen] = useState(false);
  const chosen = options.find((option) => option.value === value);

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger asChild>
        <Button
          id={id}
          type="button"
          variant="outline"
          role="combobox"
          aria-expanded={open}
          disabled={disabled}
          className={cn("w-full justify-between font-normal shadow-sm", className)}
        >
          {chosen === undefined ? (
            <span className="truncate text-muted-foreground">{placeholder}</span>
          ) : (
            <OptionLabel option={chosen} />
          )}
          <ChevronDown className="h-4 w-4 shrink-0 opacity-50" />
        </Button>
      </PopoverTrigger>
      <PopoverContent
        className={cn("w-(--radix-popover-trigger-width) p-0", contentClassName)}
        align="start"
      >
        <Command>
          <CommandInput placeholder={searchPlaceholder} />
          <CommandList>
            <CommandEmpty>{emptyText}</CommandEmpty>
            <CommandGroup>
              {options.map((option) => (
                <CommandItem
                  key={option.value}
                  value={option.value}
                  keywords={option.keywords}
                  onSelect={(selected) => {
                    onChange(selected);
                    setOpen(false);
                  }}
                >
                  <Check
                    className={cn(
                      "mr-2 h-4 w-4 shrink-0",
                      option.value === value ? "opacity-100" : "opacity-0",
                    )}
                  />
                  {option.detail === undefined ? (
                    <OptionLabel option={option} />
                  ) : (
                    <span className="flex min-w-0 flex-1 flex-col gap-0.5">
                      <OptionLabel option={option} />
                      <span className="truncate text-xs text-muted-foreground">
                        {option.detail}
                      </span>
                    </span>
                  )}
                </CommandItem>
              ))}
            </CommandGroup>
          </CommandList>
        </Command>
      </PopoverContent>
    </Popover>
  );
}

function OptionLabel({ option }: { option: ComboboxOption }) {
  return (
    <span className="flex min-w-0 flex-1 items-center justify-between gap-3">
      <span className="truncate">{option.label ?? option.value}</span>
      {option.description !== undefined && (
        <span className="shrink-0 font-mono text-xs text-muted-foreground">
          {option.description}
        </span>
      )}
      {option.badge !== undefined && <span className="shrink-0">{option.badge}</span>}
    </span>
  );
}
