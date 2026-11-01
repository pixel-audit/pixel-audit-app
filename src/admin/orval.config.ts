import { defineConfig } from "orval";

// Generates a typed API client from the admin API's OpenAPI document.
// The document is served by the running Phoenix API (`make up`, or
// `mix phx.server` in src/api), so start it before `npm run api:generate`
// — or point OPENAPI_INPUT at a document exported with
// `mix openapi.spec.json --vendor-extensions=false` to generate without a
// server. The flag matters: the default export adds `x-struct`/`x-validate`
// to every schema, and with those present orval inlines nested objects
// instead of giving them their own named types, so the output no longer
// matches what the served document generates.
export default defineConfig({
  admin: {
    input: {
      target: process.env.OPENAPI_INPUT ?? "http://localhost:16000/openapi/admin.json",
    },
    output: {
      target: "src/api/generated/endpoints.ts",
      schemas: "src/api/generated/model",
      client: "react-query",
      httpClient: "fetch",
      clean: true,
      formatter: "prettier",
      override: {
        mutator: {
          path: "src/api/http.ts",
          name: "customFetch",
        },
      },
    },
  },
});
