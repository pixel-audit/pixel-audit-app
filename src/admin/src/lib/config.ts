/**
 * Runtime configuration — the values of /config.js, which index.html loads
 * before the bundle. The API renders it (PanelController) from its
 * environment: in the image directly, in development through the dev
 * server's proxy, so nothing is baked into the build.
 *
 * Read once at startup. A value that is missing or empty — the script did
 * not load — falls back to the default here, so the app always starts.
 */

export interface RuntimeConfig {
  /** Where this program's source is offered (AGPL §13): the sidebar's foot links there. */
  sourceUrl: string;
}

declare global {
  interface Window {
    PIXELAUDIT_CONFIG?: Partial<Record<keyof RuntimeConfig, unknown>>;
  }
}

const DEFAULTS: RuntimeConfig = {
  sourceUrl: "https://github.com/pixel-audit/pixel-audit-app",
};

function readConfig(): RuntimeConfig {
  const raw = window.PIXELAUDIT_CONFIG ?? {};
  const config = { ...DEFAULTS };

  for (const key of Object.keys(DEFAULTS) as (keyof RuntimeConfig)[]) {
    const value = raw[key];

    if (typeof value === "string" && value !== "") {
      config[key] = value;
    }
  }

  return config;
}

export const config: RuntimeConfig = readConfig();
