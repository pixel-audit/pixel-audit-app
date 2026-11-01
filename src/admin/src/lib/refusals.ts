import { defineMessage, defineMessages, type MessageDescriptor } from "react-intl";

import { copy, type Copy } from "@/lib/i18n/copy";

/**
 * The API's refusals (`errors.detail` of a 409 or a 422 — see the API's
 * `FallbackController`) in plain words. `subject` names what was refused
 * ("connection", "funnel") for the sentences that mention it; an unknown
 * detail reads as the generic sentence with the detail in it, so nothing
 * is lost.
 */
export function describeErrorDetail(detail: string, subject?: MessageDescriptor): Copy {
  const what: Copy = subject ?? copy(messages.item);
  switch (detail) {
    case "not_found":
      return copy(messages.notFound, { subject: what });
    case "connection_in_use":
      return copy(messages.connectionInUse);
    case "managed_by_env":
      return copy(messages.managedByEnv, { subject: what });
    case "connection_type_mismatch":
      return copy(messages.connectionTypeMismatch);
    case "not_a_meta_connection":
      return copy(messages.notAMetaConnection);
    case "invalid_order":
      return copy(messages.invalidOrder);
    case "missing_date":
    case "invalid_date":
      return copy(messages.invalidDate);
    case "invalid_date_range":
      return copy(messages.invalidDateRange);
    case "range_too_large":
      return copy(messages.rangeTooLarge);
    default:
      return copy(messages.unknown, { detail });
  }
}

const messages = {
  ...defineMessages({
    item: { id: "refusal.item", defaultMessage: "item" },
    connectionInUse: {
      id: "refusal.connectionInUse",
      defaultMessage: "A data source still reads through this connection. Move it first.",
    },
    connectionTypeMismatch: {
      id: "refusal.connectionTypeMismatch",
      defaultMessage: "The connection is not of the type this data source reads through.",
    },
    notAMetaConnection: {
      id: "refusal.notAMetaConnection",
      defaultMessage: "Only a Meta connection has pixel stats to pull.",
    },
    invalidOrder: {
      id: "refusal.invalidOrder",
      defaultMessage: "The order must name every step of the funnel exactly once.",
    },
    invalidDate: {
      id: "refusal.invalidDate",
      defaultMessage: "Both dates are needed, as YYYY-MM-DD.",
    },
    invalidDateRange: {
      id: "refusal.invalidDateRange",
      defaultMessage: "The range's end lies before its start.",
    },
    rangeTooLarge: {
      id: "refusal.rangeTooLarge",
      defaultMessage: "The range is too long: at most 366 days at a time.",
    },
  }),
  managedByEnv: defineMessage<{ subject: string }>({
    id: "refusal.managedByEnv",
    defaultMessage:
      "This {subject} is defined by the environment (CONNECTION_* or VARIABLE_* variables); what it defines cannot be changed here.",
  }),
  notFound: defineMessage<{ subject: string }>({
    id: "refusal.notFound",
    defaultMessage: "This {subject} no longer exists.",
  }),
  unknown: defineMessage<{ detail: string }>({
    id: "refusal.unknown",
    defaultMessage: "The API refused the request ({detail}).",
  }),
};
