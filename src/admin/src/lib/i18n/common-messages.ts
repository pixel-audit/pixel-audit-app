import { defineMessages } from "react-intl";

/**
 * The few words every screen says the same way — the buttons of a dialog,
 * the states of a list. Everything else is defined next to its use; a word
 * joins this list only when three screens say it identically.
 */
export const commonMessages = defineMessages({
  cancel: { id: "common.cancel", defaultMessage: "Cancel" },
  save: { id: "common.save", defaultMessage: "Save" },
  delete: { id: "common.delete", defaultMessage: "Delete" },
  edit: { id: "common.edit", defaultMessage: "Edit" },
  add: { id: "common.add", defaultMessage: "Add" },
  close: { id: "common.close", defaultMessage: "Close" },
  back: { id: "common.back", defaultMessage: "Back" },
  retry: { id: "common.retry", defaultMessage: "Retry" },
  loading: { id: "common.loading", defaultMessage: "Loading…" },
  yes: { id: "common.yes", defaultMessage: "Yes" },
  no: { id: "common.no", defaultMessage: "No" },
  none: { id: "common.none", defaultMessage: "—" },
  notSet: { id: "common.notSet", defaultMessage: "Not set" },
  search: { id: "common.search", defaultMessage: "Search…" },
  nothingMatches: { id: "common.nothingMatches", defaultMessage: "Nothing matches." },
});
