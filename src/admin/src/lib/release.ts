/**
 * The build this bundle is: CI's commit SHA, the vX.Y.Z tag when the build
 * was made from one, and the moment the build was started, baked in as
 * VITE_RELEASE_* (the Dockerfile's build args, the workflow's env for the
 * artifact). All null in a local build, and nothing here guesses — a
 * release stamp that is not CI's is worse than none.
 */

const nonEmpty = (value: string | undefined): string | null =>
  value === undefined || value === "" ? null : value;

export const RELEASE = {
  sha: nonEmpty(import.meta.env.VITE_RELEASE_SHA),
  tag: nonEmpty(import.meta.env.VITE_RELEASE_TAG),
  timestamp: nonEmpty(import.meta.env.VITE_RELEASE_TIMESTAMP),
} as const;

/**
 * Sent with every call to the API, so a request can be traced to the build
 * that made it. Allowed by the API's CORS (`PixelAudit.ApiWeb.Cors`,
 * specs/api.md „CORS") — a header the API does not list never leaves the
 * browser.
 */
export const RELEASE_HEADER = "x-pixelaudit-release-sha";
