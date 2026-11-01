import { createFileRoute, linkOptions } from "@tanstack/react-router";
import { defineMessages, useIntl } from "react-intl";

import { ApiItem } from "@/components/crud/api-item";
import { okData } from "@/components/crud/api-response";
import type { Crumb } from "@/components/crumbs";
import { Page } from "@/components/page";
import { describeRun, RefreshRunDetail } from "@/components/reporting/refresh-run-detail";
import { useApi } from "@/lib/api";

/** A refresh run's page: its outcome, the whole error, the days it computed. */
export const Route = createFileRoute("/refreshes_/$id")({
  staticData: { crumbs: useRunCrumbs },
  component: RefreshRunPage,
});

const BACK_LINK = linkOptions({ to: "/refreshes" });

function useRunCrumbs(): Crumb[] {
  const { id } = Route.useParams();
  const run = okData(useApi().useAdminGetRefreshRun(id).data)?.data;
  return run ? [{ label: describeRun(run) }] : [];
}

function RefreshRunPage() {
  const intl = useIntl();
  const { id } = Route.useParams();
  const query = useApi().useAdminGetRefreshRun(id, {
    query: {
      refetchInterval: (q) => {
        const status = q.state.data?.status === 200 ? q.state.data.data.data.status : undefined;
        return status === "queued" || status === "running" ? 10_000 : false;
      },
    },
  });

  return (
    <Page wide>
      <ApiItem
        query={query}
        item={(data) => data.data}
        resource="refresh run"
        back={{ label: intl.formatMessage(messages.back), link: BACK_LINK }}
      >
        {(run) => <RefreshRunDetail run={run} />}
      </ApiItem>
    </Page>
  );
}

const messages = defineMessages({
  back: { id: "routes.back.refreshes", defaultMessage: "Back to refreshes" },
});
