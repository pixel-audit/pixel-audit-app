// Fetch wrapper used by the orval-generated client (src/api/generated).
// Prefixes the API base URL. The API has no authentication (specs/api.md):
// nothing is attached beyond the release stamp.

import { config } from "@/lib/config";
import { RELEASE, RELEASE_HEADER } from "@/lib/release";

// From the runtime configuration (public/config.js) — not a build-time
// variable, so one build can point at any API.
const baseUrl: string = config.apiUrl;

async function getBody<T>(response: Response): Promise<T> {
  const contentType = response.headers.get("content-type");

  if (contentType?.includes("application/json")) {
    return response.json() as Promise<T>;
  }

  return response.text() as Promise<T>;
}

// The return shape ({ status, data, headers } cast to T) is the contract
// orval's fetch client expects from a custom mutator.
export async function customFetch<T>(url: string, options: RequestInit): Promise<T> {
  const headers = new Headers(options.headers);
  if (RELEASE.sha !== null) headers.set(RELEASE_HEADER, RELEASE.sha);

  const response = await fetch(baseUrl + url, { ...options, headers });
  const data = await getBody<T>(response);

  return { status: response.status, data, headers: response.headers } as T;
}
