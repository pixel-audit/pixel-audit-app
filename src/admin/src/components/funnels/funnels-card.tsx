import { linkOptions } from "@tanstack/react-router";
import { Filter } from "lucide-react";
import { useState } from "react";
import { defineMessage, defineMessages, useIntl } from "react-intl";

import type { Funnel } from "@/api/generated/model";
import { ApiList } from "@/components/crud/api-list";
import { CrudCard } from "@/components/crud/crud-card";
import { ListRow, RowDetail } from "@/components/crud/list-row";
import { FunnelDialog } from "@/components/funnels/funnel-dialog";
import { useApi } from "@/lib/api";

/** The funnels list, each leading to its page. */
export function FunnelsCard() {
  const intl = useIntl();
  const api = useApi();
  const list = api.useAdminListFunnels();
  const [adding, setAdding] = useState(false);

  return (
    <>
      <CrudCard
        page
        title={intl.formatMessage(messages.title)}
        action={{ label: intl.formatMessage(messages.add), onClick: () => setAdding(true) }}
      >
        <ApiList
          query={list}
          items={(data) => data.data}
          resource="funnels"
          empty={intl.formatMessage(messages.empty)}
        >
          {(funnels: Funnel[]) =>
            funnels.map((funnel) => (
              <ListRow
                key={funnel.id}
                icon={Filter}
                title={funnel.name}
                link={linkOptions({ to: "/funnels/$id", params: { id: funnel.id } })}
              >
                <RowDetail>
                  {intl.formatMessage(messages.summary, {
                    steps: funnel.steps.length,
                    sources: funnel.data_sources.length,
                  })}
                </RowDetail>
                {funnel.description && <RowDetail muted>{funnel.description}</RowDetail>}
              </ListRow>
            ))
          }
        </ApiList>
      </CrudCard>
      <FunnelDialog open={adding} onOpenChange={setAdding} />
    </>
  );
}

const messages = {
  ...defineMessages({
    title: { id: "funnels.list.title", defaultMessage: "Funnels" },
    add: { id: "funnels.list.add", defaultMessage: "Add funnel" },
    empty: {
      id: "funnels.list.empty",
      defaultMessage: "No funnels yet. Add one, then give it steps and data sources.",
    },
  }),
  summary: defineMessage<{ steps: number; sources: number }>({
    id: "funnels.list.summary",
    defaultMessage:
      "{steps, plural, one {# step} other {# steps}} · {sources, plural, one {# data source} other {# data sources}}",
  }),
};
