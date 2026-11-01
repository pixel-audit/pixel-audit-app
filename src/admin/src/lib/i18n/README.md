# Copy and languages

Every sentence, label and `aria-label` on the screen is a **message**:
`react-intl`'s `defineMessages` next to the component that shows it, with an
explicit dotted `id` (`funnels.list.title`, `crud.delete.confirm`) and the
English copy in `defaultMessage`. English is the source language; the panel
speaks the browser's preferred language it has a catalogue for (`locale.ts`)
— English only, for now.

- A component formats with `useIntl()` and `intl.formatMessage(messages.x)`.
- Pure logic answers with a `Copy` (`copy.ts`): the message and its values,
  formatted by the screen that shows it with `formatCopy(intl, text)`.
- Code outside React is given an `intl` (`intlFor(locale)` in `intl.ts`).
- Counts are ICU plurals in the message (`{count, plural, one {…} other {…}}`),
  dates and numbers are `intl.formatDate` / `intl.formatNumber`.

`npm run i18n:extract` collects the messages into `messages/en.json` and
compiles it into `compiled/en.json`, which `I18nProvider` loads. Everything
is committed; `npm run check` fails when the catalogue is stale.

Adding a translation (say Polish): list `pl` in `scripts/i18n.mjs`
(`TRANSLATED`), `locale.ts` (`LOCALES`) and `intl.ts` (`CATALOGUES`), and
keep its messages in `messages/pl/<area>.json`, one file per screen area,
keyed by id. From then on `npm run check` fails on a message without a
Polish translation and on a translation without a message.
