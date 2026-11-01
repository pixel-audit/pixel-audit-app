import { describe, expect, it } from "vitest";

import { formatCopy } from "@/lib/i18n/copy";
import { intlFor } from "@/lib/i18n/intl";

import { errorsFor, fieldErrors, refusal } from "./api-response";

const unprocessable = (errors: unknown) => ({ status: 422, data: { errors } });

describe("fieldErrors", () => {
  it("returns a flat changeset as is", () => {
    expect(fieldErrors(unprocessable({ name: ["can't be blank"] }))).toEqual({
      name: ["can't be blank"],
    });
  });

  it("flattens nested changesets to dotted paths", () => {
    expect(
      fieldErrors(
        unprocessable({
          name: ["can't be blank"],
          covers: { from: ["is invalid"] },
          rules: [{}, { rrule: ["is invalid"] }],
        }),
      ),
    ).toEqual({
      name: ["can't be blank"],
      "covers.from": ["is invalid"],
      "rules.1.rrule": ["is invalid"],
    });
  });

  it("is null for anything that isn't a changeset", () => {
    expect(fieldErrors(unprocessable({ detail: "invalid_transition" }))).toBeNull();
    expect(fieldErrors(unprocessable({}))).toBeNull();
    expect(fieldErrors({ status: 409, data: { errors: { name: ["taken"] } } })).toBeNull();
    expect(fieldErrors(null)).toBeNull();
  });
});

describe("errorsFor", () => {
  it("gathers a field's messages from every key it may be filed under", () => {
    const errors = { covers: ["overlaps"], "covers.from": ["is invalid"], "covers.to": ["x"] };
    expect(errorsFor(errors, "from", "covers", "covers.from")).toEqual(["overlaps", "is invalid"]);
    expect(errorsFor(errors, "until")).toBeUndefined();
  });
});

describe("refusal", () => {
  const intl = intlFor("en");
  const nope = { id: "test.nope", defaultMessage: "Nope." };
  const connection = { id: "test.connection", defaultMessage: "connection" };
  const text = (...args: Parameters<typeof refusal>) => formatCopy(intl, refusal(...args));

  it("words the API's detail for the subject, else falls back", () => {
    const gone = { data: { errors: { detail: "not_found" } } };
    expect(text(gone, nope, connection)).toBe("This connection no longer exists.");
    expect(text(gone, nope)).toBe("This item no longer exists.");
    expect(text({ data: { errors: { detail: "managed_by_env" } } }, nope)).toMatch(/environment/);
    expect(text({ data: { errors: { detail: "weird" } } }, nope)).toBe(
      "The API refused the request (weird).",
    );
    expect(text({ data: { errors: { name: ["x"] } } }, nope)).toBe("Nope.");
    expect(text(null, nope)).toBe("Nope.");
  });
});
