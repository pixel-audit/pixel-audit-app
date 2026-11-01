import { RouterProvider } from "@tanstack/react-router";
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";

import { ApiProvider } from "./lib/api-provider";
import { I18nProvider } from "./lib/i18n/provider";
import { getRouter } from "./router";
import "./styles.css";

const rootElement = document.getElementById("root");
if (!rootElement) throw new Error("No #root in index.html — nowhere to mount the application.");

const router = getRouter();

createRoot(rootElement).render(
  <StrictMode>
    {/* Outermost: the language is known before anything is said. */}
    <I18nProvider>
      {/* Above the router, so every route sees the API client. */}
      <ApiProvider>
        <RouterProvider router={router} />
      </ApiProvider>
    </I18nProvider>
  </StrictMode>,
);
