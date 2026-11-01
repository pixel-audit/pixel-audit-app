import type { ReactNode } from "react";

import * as endpoints from "@/api/generated/endpoints";
import { ApiContext } from "@/lib/api";

/**
 * Exposes the orval-generated API client to subcomponents via `useApi()`
 * (lib/api.ts). Sits above the router, so every route sees the client.
 */
export function ApiProvider({ children }: { children: ReactNode }) {
  return <ApiContext.Provider value={endpoints}>{children}</ApiContext.Provider>;
}
