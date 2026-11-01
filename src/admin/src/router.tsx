import { QueryClient } from "@tanstack/react-query";
import { createRouter } from "@tanstack/react-router";
import { routeTree } from "./routeTree.gen";

export const getRouter = () => {
  const queryClient = new QueryClient();

  const router = createRouter({
    routeTree,
    // If the app were deployed in a subdirectory, the router must know that
    // prefix — otherwise <Link to="/accounting/reports/orders"> targets the domain root. BASE_URL
    // comes from `base` in vite.config.ts, without the trailing slash the
    // router does not expect.
    basepath: import.meta.env.BASE_URL.replace(/\/$/, ""),
    context: { queryClient },
    scrollRestoration: true,
    defaultPreloadStaleTime: 0,
  });

  return router;
};

// routeTree.gen.ts does not declare Register — it has to be done here. Without
// it <Link to="..."> loses path typing and accepts any string.
declare module "@tanstack/react-router" {
  interface Register {
    router: ReturnType<typeof getRouter>;
  }
}
