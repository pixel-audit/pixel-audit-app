# Admin panel — conventions

Read this before writing any code in `src/admin`.

## Don't repeat yourself — build from reusable components

Every CRUD screen in the panel is the same shape: a card with a title and an
"Add" button, a list of rows with badges and icon actions, an add/edit dialog
with labelled fields, and a "Delete X?" confirmation. That shape lives in
shared components, and new screens are assembled from them rather than written
out again:

| Need                                                        | Use                                                                                     |
| ----------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| Card with title, description and an Add button              | `CrudCard` (`components/crud/crud-card.tsx`)                                            |
| A list item: icon/colour rail, title, badges, actions       | `ListRow`, `RowDetail`, `RowActionButton` (`crud/list-row.tsx`)                         |
| Add/edit dialog chrome (header, form, footer)               | `FormDialog` (`crud/form-dialog.tsx`)                                                   |
| "Delete X?" confirmation, incl. the blocked case            | `ConfirmDeleteDialog` (`crud/confirm-delete-dialog.tsx`)                                |
| Labelled field with hint and validation errors              | `FormField`, `FieldErrors` (`components/form/field.tsx`)                                |
| Boxed on/off setting with a description                     | `SwitchRow` (`components/form/field.tsx`)                                               |
| Flat form state with a typed `set(key, value)`              | `useFormState` (`form/use-form-state.ts`)                                               |
| Empty / failed box                                          | `NonIdealState` (`components/ui/non-ideal-state.tsx`)                                   |
| A warning inside a card or dialog                           | `InlineWarning` (`components/ui/inline-warning.tsx`)                                    |
| Why a disabled button is disabled (tooltip on hover)        | `WhyDisabled` (`crud/why-disabled.tsx`)                                                 |
| API list through loading/error/empty                        | `ApiList` (`crud/api-list.tsx`)                                                         |
| One API item (by the address's id) through the same states  | `ApiItem` (`crud/api-item.tsx`)                                                         |
| An item's page: title and the Edit / Delete actions         | `PageHeader` (`components/page-header.tsx`) + `ActionButton` (`crud/action-button.tsx`) |
| An item's fields as a labelled grid                         | `DetailsCard`, `DetailField` (`crud/details-card.tsx`)                                  |
| A list row that leads to the item's page                    | `ListRow` with `link` (`linkOptions(...)`)                                              |
| API create-or-update with 422 field errors                  | `useApiSave` (`crud/use-api-mutations.ts`)                                              |
| API delete with toasts and list invalidation                | `useApiDelete` (`crud/use-api-mutations.ts`)                                            |
| A one-off API command (check, refresh, reorder)             | `useApiCommand` (`crud/use-api-mutations.ts`)                                           |
| Narrowing an orval response to its 200 body                 | `okData` (`crud/api-response.ts`)                                                       |
| A refusal / 422 field errors in plain words                 | `refusal`, `fieldErrors`, `errorsFor` (`crud/api-response.ts`), `lib/refusals.ts`       |
| Picking an entity the database holds (a connection…)        | `EntityCombobox` (`components/form/entity-combobox.tsx`)                                |
| A form from the API's field specs (credentials, settings…)  | `FieldSpecFields` (`components/form/field-spec-fields.tsx`)                             |
| A date range with presets, kept in the address              | `DateRangePicker` (`components/reporting/date-range-picker.tsx`), `lib/date-range.ts`   |
| The funnel as a sankey                                      | `FunnelSankey` (`components/funnels/funnel-sankey.tsx`), `lib/sankey.ts`                |
| The counts table (sources × steps)                          | `FunnelCountsTable` (`components/funnels/funnel-counts-table.tsx`)                      |
| A refresh run's status as a badge                           | `RefreshRunStatus` (`components/reporting/refresh-run-status.tsx`)                      |

The rules that follow from this:

- **Before writing markup, look for the component.** If a card, row, dialog or
  field already exists in `components/crud`, `components/form` or
  `components/ui`, use it. Copying its JSX into a screen file is a bug, even
  when the copy is small.
- **When two screens share a shape, extract it — don't duplicate it.**
- **An entity from the database is picked with a search box** —
  `EntityCombobox`. A plain `Select` is for enums and fixed vocabularies
  only: a connection type, a data source type, a run status.
- **The API's field specs drive the forms.** A connection's credentials, a
  data source's settings and a step's parameters are declared by the API
  (`GET /settings/connections/types`, `GET /funnels/data-source-types`) as
  `FieldSpec`s; `FieldSpecFields` renders them. No screen hard-codes which
  credential a type takes.
- **Components take slots, not flags.** `ListRow` receives `badges`, `actions`
  and children; it doesn't know what a funnel is. Derived data (labels,
  counts, colours) is computed by the screen and passed in.
- **Shared components are generic by contract, not by cast.** `ApiList` and
  `useApiSave` are typed against the generated API client; reach for
  `okData` rather than `as` when a response needs narrowing.
- **Copy stays with the screen, and copy is a message.** Titles, empty-state
  messages, toasts and descriptions are props; the shared components carry
  no domain wording, only their own generic words ("Cancel", "Save"), which
  come from `commonMessages`. See „Copy is a message" below.

## Copy is a message, written in English

Everything the user reads — a title, a label, a toast, an `aria-label`, the
sentence `refusal` answers with — is a **message**, never a string in the
JSX: `react-intl`'s `defineMessages` at the bottom of the file that shows
it, with an explicit dotted `id` (`funnels.list.title`, `crud.delete.confirm`)
and the English copy in `defaultMessage`. `src/lib/i18n/README.md` has the
mechanics; the rules that matter here:

- **English is the source language.** `defaultMessage` is English. There is
  no translation yet; the README says how one is added, and the machinery
  (`npm run i18n:extract`, `npm run i18n:check`) is in place. `npm run check`
  fails when the catalogue is stale.
- **The panel speaks the browser's language** (`lib/i18n/locale.ts`): the
  first of `navigator.languages` it has a catalogue for, English otherwise.
- **Pure logic answers with a `Copy`, the screen formats it.** A function in
  `lib/` or a hook that has a sentence for the user returns
  `copy(message, values)` (`lib/i18n/copy.ts`), and the component that shows
  it calls `formatCopy(intl, …)`.
- **Counts are ICU plurals**, dates and numbers are `intl.formatDate` and
  `intl.formatNumber` — never `toLocaleDateString("en-GB")`.
- A message with placeholders is `defineMessage<{ name: string }>`, so a
  call with the wrong values fails to compile; text next to a value is a
  message with a placeholder, never concatenation. ESLint's
  `react/jsx-no-literals` holds the line: no sentence in the JSX.
- `commonMessages` (`lib/i18n/common-messages.ts`) holds the few words every
  screen says identically; a word joins it only when three screens say it.

## Every item has a page, not a modal

A list row leads to the item's own page (`/funnels/$id`, `/settings/connections/$id`),
where the item is shown, edited (the add/edit `FormDialog` opens from there),
checked, refreshed or deleted. Lists only list and add. The page is a route
file escaped from its list's route (`funnels_.$id.tsx`), so it renders on its
own rather than inside the list; it is assembled from `ApiItem` + a
`*-detail.tsx` component. A funnel's page has two tabs, View and Setup, as
tab routes (`funnels_.$id.tsx` and `funnels_.$id.setup.tsx`). Every item is addressed by its id.

## The address follows the navigation

Navigation has two levels: the groups (Funnels, Refreshes, Settings) are
tabs in the top bar, and the open group's screens fill the sidebar. The
address follows that tree: `/group/screen`, then the item and the tab
(`/funnels/$id/setup`). A group with one screen skips the second segment.
Every screen wraps itself in `Page` (`wide` for the report). A selection a
reload should keep — the report's date range, the sankey's source — is in
the address (`validateSearch`), not component state.

The breadcrumb bar under the top bar (`components/app-breadcrumbs.tsx`) is
global. The group and screen come from the navigation tree in
`lib/navigation.ts` (the top bar's and the sidebar's too — add a screen
there, not in either bar); the item's own crumb is a hook the route declares
in `staticData: { crumbs }`, which runs in the bar and may read the route's
params and queries. Pages don't render breadcrumbs themselves. The same
trail, read from the page up, is the document's title (`trailTitle`).

Exempt from all of this: `src/components/ui/**` (shadcn/ui, generated),
`src/api/generated/**` (orval) and `src/routeTree.gen.ts`.

## The API client is generated, never hand-written

Every call to the API goes through the orval-generated client in
`src/api/generated` (`useApi()` — hooks, query keys, raw calls, model types).
When the API gains or changes an endpoint, regenerate the client with
`npm run api:generate` (against the running API, or `OPENAPI_INPUT` pointing
at a document exported with `mix openapi.spec.json` in `src/api`) and build on
what comes out. Never hand-write a hook, a fetch call or a response type for
an endpoint — a hand-written twin of the generated code drifts from the API
the moment the API moves. Always run `npm run typecheck` after regenerating.

## Quality gate

`npm run check` (catalogue + types + lint + tests) must pass before the work
is called done.
