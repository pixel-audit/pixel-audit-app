/// <reference types="vite/client" />

interface ImportMetaEnv {
  /** CI's short commit SHA of the build — see lib/release.ts. */
  readonly VITE_RELEASE_SHA?: string;
  /** The vX.Y.Z tag the build was made from, when it was; empty on a branch build. */
  readonly VITE_RELEASE_TAG?: string;
  /** When CI started the build, ISO 8601 — see lib/release.ts. */
  readonly VITE_RELEASE_TIMESTAMP?: string;
}
