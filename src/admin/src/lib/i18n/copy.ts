import type {
  IntlShape,
  MessageDescriptor,
  MessageTag,
  MessageValue,
  TypedMessageDescriptor,
} from "react-intl";

/** What `defineMessage<V>` declares — react-intl keeps this one to itself. */
type MessageValues = Record<string, MessageValue | MessageTag>;

/** What fills a placeholder: a primitive, or another sentence, formatted first. */
export type CopyValue = string | number | bigint | boolean | Date | null | undefined | Copy;

export type CopyValues = Record<string, CopyValue>;

/**
 * A sentence for the screen, not yet in any language: the message and what
 * fills its placeholders. Pure logic (`lib/*`, the API client's refusals) answers
 * with a `Copy` where it used to answer with a Polish string, and the screen
 * that shows it formats it in the station's language with `formatCopy`. A
 * placeholder may itself be a `Copy` — "participants: {error}" — so
 * a sentence can be built from sentences without an `intl` in hand.
 */
export type Copy = MessageDescriptor & { values?: CopyValues };

/** The values a typed message takes, with a `Copy` allowed wherever text is. */
type ValuesFor<V extends MessageValues> = {
  [K in keyof V]: V[K] extends MessageTag ? never : V[K] | Copy;
};

/** A message with its values — the values the message declares, no others. */
export const copy = <V extends MessageValues>(
  message: TypedMessageDescriptor<V>,
  // `{}` is the contract of a message with no placeholders — react-intl's own type for it.
  // eslint-disable-next-line @typescript-eslint/no-empty-object-type
  ...values: {} extends V ? [] : [ValuesFor<V>]
): Copy => {
  const [filled] = values;
  return filled === undefined ? message : { ...message, values: filled as CopyValues };
};

const isCopy = (value: CopyValue): value is Copy =>
  typeof value === "object" && value !== null && !(value instanceof Date);

/** The sentence, in `intl`'s language. */
export const formatCopy = (intl: IntlShape, text: Copy): string => {
  const values =
    text.values === undefined
      ? undefined
      : Object.fromEntries(
          Object.entries(text.values).map(([key, value]) => [
            key,
            isCopy(value) ? formatCopy(intl, value) : value,
          ]),
        );
  return intl.formatMessage(text, values);
};
