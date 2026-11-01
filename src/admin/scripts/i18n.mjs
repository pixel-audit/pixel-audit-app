// The message catalogues, generated from the code — see src/lib/i18n/README.md.
//
//   node scripts/i18n.mjs extract   writes messages/en.json and compiled/<locale>.json
//   node scripts/i18n.mjs check     fails when they are out of date, or when a
//                                   message has no translation in a translated locale
//
// English is the source language: every message's `defaultMessage` in the code
// is its English copy, and `messages/en.json` is that copy collected for
// translators. A translated locale is kept by area in `messages/<locale>/*.json`
// (one file per screen area, so that the people working on an area keep its
// translations next to it); the files are merged into `compiled/<locale>.json`.
// The compiled files are what IntlProvider loads; all are committed, so a
// build needs no extraction and a test reads the catalogue the screen does.
//
// There is no translated locale yet: TRANSLATED is empty, and the panel
// speaks English. Adding one is an entry here, in src/lib/i18n/locale.ts and
// in src/lib/i18n/intl.ts, plus its messages/<locale>/ directory.

import { execFileSync } from "node:child_process";
import { mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const TRANSLATED = [];

const ROOT = new URL("..", import.meta.url).pathname;
const I18N = join(ROOT, "src/lib/i18n");
const SOURCE = join(I18N, "messages/en.json");
const COMPILED_EN = join(I18N, "compiled/en.json");
const compiledPath = (locale) => join(I18N, `compiled/${locale}.json`);

const formatjs = (...args) =>
  execFileSync("npx", ["formatjs", ...args], { cwd: ROOT, stdio: ["ignore", "pipe", "inherit"] });

const pretty = (value) => `${JSON.stringify(value, null, 2)}\n`;
const readJson = (path) => JSON.parse(readFileSync(path, "utf8"));

/** A locale's translations, every area's file merged; a duplicate id is an error. */
const readTranslations = (locale) => {
  const dir = join(I18N, "messages", locale);
  const merged = {};
  const owner = {};
  for (const name of readdirSync(dir)
    .filter((n) => n.endsWith(".json"))
    .sort()) {
    const file = readJson(join(dir, name));
    for (const [id, message] of Object.entries(file)) {
      if (id in merged) {
        throw new Error(`${locale}: "${id}" is translated in both ${owner[id]} and ${name}`);
      }
      merged[id] = message;
      owner[id] = name;
    }
  }
  return merged;
};

/** Extracts and compiles into `dir`; returns the files' contents and the problems. */
const generate = (dir) => {
  const source = join(dir, "en.json");
  const compiledEn = join(dir, "en.compiled.json");
  formatjs(
    "extract",
    "src/**/*.{ts,tsx}",
    "--ignore",
    "src/**/*.test.ts",
    "--ignore",
    "src/**/*.d.ts",
    "--ignore",
    "src/api/generated/**",
    "--throws",
    "--out-file",
    source,
  );
  formatjs("compile", source, "--out-file", compiledEn);

  const english = readJson(source);
  const compiled = {};
  const problems = [];
  for (const locale of TRANSLATED) {
    const translations = readTranslations(locale);
    const missing = Object.keys(english).filter((id) => !(id in translations));
    const stale = Object.keys(translations).filter((id) => !(id in english));
    if (missing.length > 0) {
      problems.push(
        `${missing.length} message(s) have no ${locale} translation in src/lib/i18n/messages/${locale}/*.json:\n  ${missing.join("\n  ")}`,
      );
    }
    if (stale.length > 0) {
      problems.push(
        `${stale.length} ${locale} translation(s) have no message in the code:\n  ${stale.join("\n  ")}`,
      );
    }
    // A translation file in the extracted shape, so `compile` validates its ICU.
    const translated = join(dir, `${locale}.json`);
    const compiledTranslated = join(dir, `${locale}.compiled.json`);
    writeFileSync(
      translated,
      pretty(
        Object.fromEntries(
          Object.entries(translations).map(([id, m]) => [id, { defaultMessage: m }]),
        ),
      ),
    );
    formatjs("compile", translated, "--out-file", compiledTranslated);
    compiled[locale] = pretty(readJson(compiledTranslated));
  }

  return {
    source: pretty(readJson(source)),
    compiledEn: pretty(readJson(compiledEn)),
    compiled,
    problems,
  };
};

const dir = mkdtempSync(join(tmpdir(), "pixelaudit-admin-i18n-"));
try {
  const made = generate(dir);
  const problems = [...made.problems];
  if (process.argv[2] === "check") {
    const read = (path) => {
      try {
        return readFileSync(path, "utf8");
      } catch {
        return "";
      }
    };
    const outdated = [
      read(SOURCE) !== made.source && "src/lib/i18n/messages/en.json",
      read(COMPILED_EN) !== made.compiledEn && "src/lib/i18n/compiled/en.json",
      ...TRANSLATED.map(
        (locale) =>
          read(compiledPath(locale)) !== made.compiled[locale] &&
          `src/lib/i18n/compiled/${locale}.json`,
      ),
    ].filter(Boolean);
    if (outdated.length > 0) {
      problems.push(`Catalogue out of date: ${outdated.join(", ")}. Run: npm run i18n:extract`);
    }
    if (problems.length > 0) {
      console.error(problems.join("\n\n"));
      process.exit(1);
    }
    console.log("Message catalogues up to date.");
  } else {
    writeFileSync(SOURCE, made.source);
    writeFileSync(COMPILED_EN, made.compiledEn);
    for (const locale of TRANSLATED) writeFileSync(compiledPath(locale), made.compiled[locale]);
    console.log(`Wrote ${SOURCE} and the compiled catalogues`);
    if (problems.length > 0) console.warn(`\n${problems.join("\n\n")}`);
  }
} finally {
  rmSync(dir, { recursive: true, force: true });
}
