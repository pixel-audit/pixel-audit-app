import { Check, Minus } from "lucide-react";
import { useState } from "react";
import { defineMessage, defineMessages, useIntl } from "react-intl";

import type { DataSource, Funnel, Step } from "@/api/generated/model";
import { fieldErrors } from "@/components/crud/api-response";
import { CrudCard } from "@/components/crud/crud-card";
import { FormDialog } from "@/components/crud/form-dialog";
import { useApiCommand } from "@/components/crud/use-api-mutations";
import { FieldErrors, FormField, SwitchRow } from "@/components/form/field";
import { FieldSpecFields, type FieldSpecValues } from "@/components/form/field-spec-fields";
import { filledValues } from "@/components/form/field-spec-values";
import { useDataSourceTypes } from "@/components/funnels/data-source-types";
import { useFunnelInvalidation } from "@/components/funnels/use-funnel-invalidation";
import { Button } from "@/components/ui/button";
import { NonIdealState } from "@/components/ui/non-ideal-state";
import { Textarea } from "@/components/ui/textarea";
import { useApi } from "@/lib/api";
import { commonMessages } from "@/lib/i18n/common-messages";
import { cn } from "@/lib/utils";

type Cell = { source: DataSource; step: Step };

/**
 * The grid of steps × data sources: each cell says whether the source
 * measures the step, and opens the parameters the source's type takes for
 * it (an event name, a SQL query) with an optional note on how it counts
 * the step, shown on the count in the report, and whether the source is
 * the step's primary one — the most reliable, its count in bold; at most
 * one per step. A step a source does not measure stays blank in the report.
 */
export function ParametersCard({ funnel }: { funnel: Funnel }) {
  const intl = useIntl();
  const [cell, setCell] = useState<Cell | null>(null);

  const measured = (source: DataSource, step: Step) =>
    source.step_parameters.find((p) => p.step_id === step.id);

  return (
    <>
      <CrudCard
        title={intl.formatMessage(messages.title)}
        description={intl.formatMessage(messages.description)}
      >
        {funnel.steps.length === 0 || funnel.data_sources.length === 0 ? (
          <NonIdealState>{intl.formatMessage(messages.empty)}</NonIdealState>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-left text-xs text-muted-foreground uppercase">
                  <th className="py-2 pr-4 font-semibold">{intl.formatMessage(messages.source)}</th>
                  {funnel.steps.map((step) => (
                    <th key={step.id} className="px-2 py-2 text-center font-semibold">
                      {step.name}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {funnel.data_sources.map((source) => (
                  <tr key={source.id} className="border-t border-border">
                    <th scope="row" className="py-2 pr-4 text-left font-medium text-foreground">
                      {source.name}
                    </th>
                    {funnel.steps.map((step) => {
                      const set = measured(source, step) !== undefined;
                      return (
                        <td key={step.id} className="px-2 py-2 text-center">
                          <Button
                            type="button"
                            size="sm"
                            variant={set ? "secondary" : "outline"}
                            className={cn("gap-1", !set && "text-muted-foreground")}
                            aria-label={intl.formatMessage(messages.cellLabel, {
                              source: source.name,
                              step: step.name,
                            })}
                            onClick={() => setCell({ source, step })}
                          >
                            {set ? (
                              <Check aria-hidden className="size-4" />
                            ) : (
                              <Minus aria-hidden className="size-4" />
                            )}
                            {intl.formatMessage(set ? messages.set : messages.notSet)}
                          </Button>
                        </td>
                      );
                    })}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </CrudCard>

      {cell && (
        <ParametersDialog
          funnel={funnel}
          cell={cell}
          open
          onOpenChange={(open) => !open && setCell(null)}
        />
      )}
    </>
  );
}

function ParametersDialog({
  funnel,
  cell,
  open,
  onOpenChange,
}: {
  funnel: Funnel;
  cell: Cell;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  const intl = useIntl();
  const api = useApi();
  const types = useDataSourceTypes();
  const invalidate = [...useFunnelInvalidation(funnel), api.getAdminListRefreshRunsQueryKey()];
  const type = types.find((t) => t.type === cell.source.type);
  const existing = cell.source.step_parameters.find((p) => p.step_id === cell.step.id);
  // The dialog is mounted for one cell and unmounted when it closes
  // (`ParametersCard`), so the state starts from that cell's parameters.
  const [values, setValues] = useState<FieldSpecValues>({ ...(existing?.parameters ?? {}) });
  const [description, setDescription] = useState(existing?.description ?? "");
  const [primary, setPrimary] = useState(existing?.primary ?? false);
  const [errors, setErrors] = useState<Record<string, string[]>>({});
  const put = api.useAdminPutFunnelStepParameters();
  const clear = api.useAdminDeleteFunnelStepParameters();
  const { run, pending } = useApiCommand();

  const ids = { funnelId: funnel.id, dataSourceId: cell.source.id, stepId: cell.step.id };

  const save = async () => {
    setErrors({});
    const result = await run(
      () =>
        put.mutateAsync({
          ...ids,
          data: { parameters: filledValues(values), description: description || null, primary },
        }),
      {
        done: intl.formatMessage(messages.saved),
        failed: (result) => {
          const fields = fieldErrors(result);
          if (fields) {
            setErrors(fields);
            return null;
          }
          return intl.formatMessage(messages.saveFailed);
        },
        invalidate,
      },
    );
    if (result) onOpenChange(false);
  };

  const remove = async () => {
    const result = await run(() => clear.mutateAsync(ids), {
      done: intl.formatMessage(messages.cleared),
      failed: () => intl.formatMessage(messages.clearFailed),
      invalidate,
    });
    if (result) onOpenChange(false);
  };

  return (
    <FormDialog
      open={open}
      onOpenChange={onOpenChange}
      title={intl.formatMessage(messages.dialogTitle, {
        source: cell.source.name,
        step: cell.step.name,
      })}
      description={type?.label}
      submitLabel={intl.formatMessage(commonMessages.save)}
      cancelLabel={
        existing ? (
          <span className="text-destructive">{intl.formatMessage(messages.clear)}</span>
        ) : undefined
      }
      saving={pending}
      onSubmit={save}
      className="max-w-xl"
    >
      {type && (
        <FieldSpecFields
          specs={type.parameters}
          values={values}
          onChange={(key, value) => setValues({ ...values, [key]: value })}
          errors={errors}
          errorPrefix="parameters"
          idPrefix="parameter"
        />
      )}
      <FormField
        label={intl.formatMessage(messages.descriptionField)}
        htmlFor="parameter-description"
        errors={errors.description}
      >
        <Textarea
          id="parameter-description"
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          rows={2}
        />
      </FormField>
      <div className="space-y-1">
        <SwitchRow
          id="parameter-primary"
          label={intl.formatMessage(messages.primary)}
          description={intl.formatMessage(messages.primaryHint)}
          checked={primary}
          onCheckedChange={setPrimary}
        />
        <FieldErrors errors={errors.primary} />
      </div>
      {existing && (
        <p className="text-xs text-muted-foreground">
          {intl.formatMessage(messages.clearHint)}
          <Button
            type="button"
            variant="link"
            size="sm"
            className="h-auto px-1 text-destructive"
            disabled={pending}
            onClick={() => void remove()}
          >
            {intl.formatMessage(messages.clear)}
          </Button>
        </p>
      )}
    </FormDialog>
  );
}

const messages = {
  ...defineMessages({
    title: { id: "parameters.card.title", defaultMessage: "Step parameters" },
    description: {
      id: "parameters.card.description",
      defaultMessage:
        "What each data source needs to count each step. A change recomputes the source's recent days.",
    },
    empty: {
      id: "parameters.card.empty",
      defaultMessage: "Add at least one step and one data source first.",
    },
    source: { id: "parameters.card.source", defaultMessage: "Data source" },
    set: { id: "parameters.card.set", defaultMessage: "Measured" },
    notSet: { id: "parameters.card.notSet", defaultMessage: "Not measured" },
    saved: {
      id: "parameters.dialog.saved",
      defaultMessage: "Parameters saved; the recent days are being recomputed.",
    },
    saveFailed: {
      id: "parameters.dialog.failed",
      defaultMessage: "The parameters could not be saved.",
    },
    descriptionField: { id: "parameters.dialog.description", defaultMessage: "Description" },
    primary: { id: "parameters.dialog.primary", defaultMessage: "Primary" },
    primaryHint: {
      id: "parameters.dialog.primaryHint",
      defaultMessage:
        "A data source marked as primary gives a visual indication that it is the most reliable for this funnel step.",
    },
    clear: { id: "parameters.dialog.clear", defaultMessage: "Stop measuring" },
    clearHint: {
      id: "parameters.dialog.clearHint",
      defaultMessage: "The source's cached counts for this step go with the parameters.",
    },
    cleared: {
      id: "parameters.dialog.cleared",
      defaultMessage: "The step is no longer measured by this source.",
    },
    clearFailed: {
      id: "parameters.dialog.clearFailed",
      defaultMessage: "The parameters could not be cleared.",
    },
  }),
  cellLabel: defineMessage<{ source: string; step: string }>({
    id: "parameters.card.cellLabel",
    defaultMessage: "{source}: {step}",
  }),
  dialogTitle: defineMessage<{ source: string; step: string }>({
    id: "parameters.dialog.title",
    defaultMessage: "{source} → {step}",
  }),
};
