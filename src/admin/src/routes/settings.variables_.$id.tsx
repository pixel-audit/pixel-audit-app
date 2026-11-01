import { createFileRoute, linkOptions } from "@tanstack/react-router";
import { defineMessages, useIntl } from "react-intl";

import { ApiItem } from "@/components/crud/api-item";
import { okData } from "@/components/crud/api-response";
import type { Crumb } from "@/components/crumbs";
import { Page } from "@/components/page";
import { VariableDetail } from "@/components/variables/variable-detail";
import { useApi } from "@/lib/api";

export const Route = createFileRoute("/settings/variables_/$id")({
  staticData: { crumbs: useVariableCrumbs },
  component: VariablePage,
});

const BACK_LINK = linkOptions({ to: "/settings/variables" });

function useVariableCrumbs(): Crumb[] {
  const { id } = Route.useParams();
  const variable = okData(useApi().useAdminGetVariable(id).data)?.data;
  return variable ? [{ label: variable.key }] : [];
}

function VariablePage() {
  const intl = useIntl();
  const { id } = Route.useParams();
  const query = useApi().useAdminGetVariable(id);

  return (
    <Page>
      <ApiItem
        query={query}
        item={(data) => data.data}
        resource="variable"
        back={{ label: intl.formatMessage(messages.back), link: BACK_LINK }}
      >
        {(variable) => <VariableDetail variable={variable} />}
      </ApiItem>
    </Page>
  );
}

const messages = defineMessages({
  back: { id: "routes.back.variables", defaultMessage: "Back to variables" },
});
