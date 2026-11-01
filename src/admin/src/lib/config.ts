/**
 * Runtime configuration — the values from public/config.js, which index.html
 * loads before the bundle. See that file for what each value is and how the
 * Docker image sets them.
 *
 * Read once at startup. A value that is missing or empty — the file did not
 * load, or a deployment set nothing — falls back to the local development
 * default, the same one public/config.js carries, so the app always starts
 * and in development needs no configuration at all.
 */

export interface RuntimeConfig {
  apiUrl: string;
  sourceUrl: string;
}

declare global {
  interface Window {
    PIXELAUDIT_CONFIG?: Partial<Record<keyof RuntimeConfig, unknown>>;
  }
}

/** The local development stack (Procfile, docker-compose.yml) — mirrors public/config.js. */
const DEVELOPMENT: RuntimeConfig = {
  apiUrl: "http://localhost:16000",
  sourceUrl: "https://github.com/pixel-audit/pixel-audit-app",
};

function readConfig(): RuntimeConfig {
  const raw = window.PIXELAUDIT_CONFIG ?? {};
  const config = { ...DEVELOPMENT };

  for (const key of Object.keys(DEVELOPMENT) as (keyof RuntimeConfig)[]) {
    const value = raw[key];

    if (typeof value === "string" && value !== "") {
      config[key] = value;
    }
  }

  return config;
}

export const config: RuntimeConfig = readConfig();
