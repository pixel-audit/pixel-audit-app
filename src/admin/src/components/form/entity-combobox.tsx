import { useIntl } from "react-intl";

import { Combobox, type ComboboxOption } from "@/components/ui/combobox";
import { commonMessages } from "@/lib/i18n/common-messages";

export type EntityOption = ComboboxOption;

/**
 * The picker for an entity the database holds — a seller, a venue, a user, a
 * till, a rate option: a `Combobox` with a search box, since such a list has
 * no fixed size and grows with the organization. A plain `Select` stays for
 * enums and fixed vocabularies (a role, a kind, a weekday, an ISO code).
 *
 * The search matches the option's label when it is text; an option whose
 * label is a node (a colour dot and a name) says what to match with
 * `keywords`. The words around the box are the panel's common ones.
 */
export function EntityCombobox({
  id,
  value,
  onChange,
  options,
  placeholder,
  disabled,
  className,
}: {
  id?: string;
  value: string;
  onChange: (value: string) => void;
  options: EntityOption[];
  placeholder?: string;
  disabled?: boolean;
  className?: string;
}) {
  const intl = useIntl();
  return (
    <Combobox
      id={id}
      value={value}
      onChange={onChange}
      options={options.map((option) => ({
        ...option,
        keywords:
          option.keywords ?? (typeof option.label === "string" ? [option.label] : undefined),
      }))}
      placeholder={placeholder ?? intl.formatMessage(commonMessages.notSet)}
      searchPlaceholder={intl.formatMessage(commonMessages.search)}
      emptyText={intl.formatMessage(commonMessages.nothingMatches)}
      disabled={disabled}
      className={className}
    />
  );
}
