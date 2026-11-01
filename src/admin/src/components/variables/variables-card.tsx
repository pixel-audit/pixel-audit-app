import { linkOptions } from "@tanstack/react-router";
import { Variable as VariableIcon } from "lucide-react";
import { useState } from "react";
import { defineMessages, useIntl } from "react-intl";

import type { Variable } from "@/api/generated/model";
import { ApiList } from "@/components/crud/api-list";
import { CrudCard } from "@/components/crud/crud-card";
import { ListRow, RowDetail } from "@/components/crud/list-row";
import { Badge } from "@/components/ui/badge";
import { VariableDialog } from "@/components/variables/variable-dialog";
import { useApi } from "@/lib/api";

/** The variables list: every variable, by key, leading to its page. */
export function VariablesCard() {
  const intl = useIntl();
  const api = useApi();
  const list = api.useAdminListVariables();
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
          resource="variables"
          empty={intl.formatMessage(messages.empty)}
        >
          {(variables: Variable[]) =>
            variables.map((variable) => (
              <ListRow
                key={variable.id}
                icon={VariableIcon}
                title={<code className="font-mono text-sm">{variable.key}</code>}
                link={linkOptions({ to: "/settings/variables/$id", params: { id: variable.id } })}
                badges={
                  variable.managed_by_env && (
                    <Badge variant="secondary">{intl.formatMessage(messages.managed)}</Badge>
                  )
                }
              >
                <RowDetail>
                  <span className="font-mono break-all">{variable.value}</span>
                </RowDetail>
                {variable.description && <RowDetail>{variable.description}</RowDetail>}
              </ListRow>
            ))
          }
        </ApiList>
      </CrudCard>
      <VariableDialog open={adding} onOpenChange={setAdding} />
    </>
  );
}

const messages = defineMessages({
  title: { id: "variables.list.title", defaultMessage: "Variables" },
  add: { id: "variables.list.add", defaultMessage: "Add variable" },
  empty: {
    id: "variables.list.empty",
    defaultMessage:
      "No variables yet. Add one here, or define it with VARIABLE_* variables and run the boot role.",
  },
  managed: { id: "variables.list.managed", defaultMessage: "From environment" },
});
