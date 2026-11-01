import { createContext, useContext } from "react";

import * as endpoints from "@/api/generated/endpoints";

export type ApiClient = typeof endpoints;

/** The orval-generated client, handed down by `ApiProvider` (lib/api-provider.tsx). */
export const ApiContext = createContext<ApiClient | null>(null);

/** The orval-generated API client (query/mutation hooks, query keys, raw calls). */
export function useApi(): ApiClient {
  const client = useContext(ApiContext);
  if (!client) throw new Error("useApi must be used within ApiProvider");
  return client;
}
