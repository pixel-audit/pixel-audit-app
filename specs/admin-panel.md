# Admin panel

What the admin panel (`src/admin`) is and the rules new screens follow.
Component and code conventions are in `src/admin/CLAUDE.md`; this file does
not repeat them. The API is in `specs/api.md`.

## Navigation

Three groups in the top bar — Funnels and Refreshes with one screen each,
Settings with two (Connections, Variables); the sidebar shows the open
group's screens. Screens are file routes in `src/routes`; an item's own page
is a route escaped from its list (`funnels_.$id.tsx`). Every item's address is its id.

| Route | Screen |
|---|---|
| `/` | Dashboard: a card per funnel (its steps and sources), the last ten refresh runs. |
| `/funnels` | The funnels; add. |
| `/funnels/$id` | The funnel's page, **View** tab: a date range (presets and two dates, kept in the address as `date_from`/`date_to`), the data source the sankey draws (`source`), the sankey, the counts table, a Refresh button for the shown range. |
| `/funnels/$id/setup` | **Setup** tab: the steps (add, edit, delete, move up/down), the data sources (type → connection of that type → the type's settings), the parameters grid (steps × sources; a cell opens the type's parameter form, or stops measuring the step). |
| `/settings` | Leads to `/settings/connections`. |
| `/settings/connections` | The connections; add. |
| `/settings/connections/$id` | The connection's page, **Credentials** tab: the credentials (secrets shown as set, not their values; a URL with its password hidden). The header carries the actions: check, pull pixel stats (Meta), edit, delete (blocked while in use). |
| `/settings/connections/$id/checks` | **Checks** tab: the last check's time, outcome and error. |
| `/settings/connections/$id/calls` | **Queries** (a database) or **Calls** (Meta) tab: what went through the connection, newest first, fifty a page (`offset`), optionally between two days (`date_from`, `date_to`); a row opens to the SQL, parameters and rows, or the request and response. |
| `/settings/variables` | The variables (key, value, description); add. |
| `/settings/variables/$id` | The variable's page: the value, and the actions: edit (a managed one's description only), delete. |
| `/refreshes` | Every refresh run, filtered by status and kind (in the address); a row leads to the run's page. |
| `/refreshes/$id` | The run's page: what it refreshed, when, the whole error as selectable text, and — for a daily-counts run — every step and day it computed with its count or error. |

## The sidebar's foot

Beside the fold toggle, in a box of fixed height so the toggle never
moves: "PixelAudit — free software under the GNU AGPL v3.", where the name
links to the source (`sourceUrl`, AGPL §13) and, in a built release, the
build follows the name: the `vX.Y.Z` tag it was made from
(`VITE_RELEASE_TAG`, CI's build argument on a tag build), linked to the
release on GitHub, or else the short commit (`VITE_RELEASE_SHA`), linked
to the commit. A local dev build shows neither.

## Locales

Every string is a message (`react-intl`), English the source language; the
catalogue machinery is in place and `src/lib/i18n/README.md` says how a
translation is added. The panel speaks the browser's language it has a
catalogue for — English, for now.

## The funnel chart

Every data source the person has switched on is drawn over the others,
centred on the chart's midline: a column per step, in it one node per
source as tall as the source's count on one scale shared by all (the
largest count shown is the full height), and from each node a ribbon
whose both edges curve in to the source's next node — the reduction is
the shape. No shares or conversion rates: the chart is a
sanity check of event delivery, and a ratio adds nothing to it. Each
source has a colour of its own (dealt from a palette when it is added,
editable in its dialog) and is drawn in it either as a translucent fill,
so two sources that agree lie on top of each other, or as an outline. A
step a source does not measure is drawn dashed at the median of the other
sources' values for it, so the source's ribbons keep their shape; a
source shown alone skips such a step. Hovering a node or a ribbon names
the source and the counts. Hovering a step's name says how far the
sources disagree on it: the lowest and the highest count, each with the
source that reports it, and the average over the sources that measure
the step. The chart and the table share one card with no heading, and
nothing is explained in prose on the screen: the hover texts carry the
detail.

## The counts table

Rows are the data sources, columns the steps, aligned with the chart's
columns. Each row starts with a three-state box in the source's colour —
ticked: drawn filled; a dash: drawn as an outline; empty: not drawn — and
a click moves to the next state; the states are in the address
(`show=db:outline,warehouse:hidden`, filled being the default), so a link
keeps the picture; changing a state or the range keeps the page where it
is. A cell shows the count over the chosen range — the same figures the
chart draws; a warning
icon with a tooltip when some days failed or are not computed yet (how
many, and the last error). A step the source does not measure shows a
dash; one with no day counted yet an ellipsis.

## Forms from the API

The credentials of a connection, the settings of a data source and the
parameters of a step are declared by the API as field specs; the panel
renders them (`FieldSpecFields`) and hard-codes none of them. A secret
already set is not shown and is kept unless a new value is typed; on an
update only the keys that were filled in are sent.
