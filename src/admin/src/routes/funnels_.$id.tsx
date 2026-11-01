import { createFileRoute, linkOptions, Outlet } from "@tanstack/react-router";
import { defineMessages, useIntl } from "react-intl";

import { ApiItem } from "@/components/crud/api-item";
import { okData } from "@/components/crud/api-response";
import type { Crumb } from "@/components/crumbs";
import { FunnelDetail } from "@/components/funnels/funnel-detail";
import { Page } from "@/components/page";
import { useApi } from "@/lib/api";

/** The funnel's page: the frame with its tabs; the tab routes render inside. */
export const Route = createFileRoute("/funnels_/$id")({
  staticData: { crumbs: useFunnelCrumbs },
  component: FunnelPage,
});

const BACK_LINK = linkOptions({ to: "/funnels" });

function useFunnelCrumbs(): Crumb[] {
  const { id } = Route.useParams();
  const funnel = okData(useApi().useAdminGetFunnel(id).data)?.data;
  return funnel ? [{ label: funnel.name }] : [];
}

function FunnelPage() {
  const intl = useIntl();
  const { id } = Route.useParams();
  const query = useApi().useAdminGetFunnel(id);

  return (
    <Page wide>
      <ApiItem
        query={query}
        item={(data) => data.data}
        resource="funnel"
        back={{ label: intl.formatMessage(messages.back), link: BACK_LINK }}
      >
        {(funnel) => (
          <FunnelDetail funnel={funnel}>
            <Outlet />
          </FunnelDetail>
        )}
      </ApiItem>
    </Page>
  );
}

const messages = defineMessages({
  back: { id: "routes.back.funnels", defaultMessage: "Back to funnels" },
});
