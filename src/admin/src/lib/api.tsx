import { createContext, useContext, type ReactNode } from "react";

import * as endpoints from "@/api/generated/endpoints";

type ApiClient = typeof endpoints;

const ApiContext = createContext<ApiClient | null>(null);

/**
 * Exposes the orval-generated API client to subcomponents via `useApi()`.
 * Sits above the router, so every route sees the client.
 */
export function ApiProvider({ children }: { children: ReactNode }) {
  return <ApiContext.Provider value={endpoints}>{children}</ApiContext.Provider>;
}

/** The orval-generated API client (query/mutation hooks, query keys, raw calls). */
export function useApi(): ApiClient {
  const client = useContext(ApiContext);
  if (!client) throw new Error("useApi must be used within ApiProvider");
  return client;
}
