import { ArrowDown, ArrowUp, Footprints, Pencil, Trash2 } from "lucide-react";
import { useEffect, useState } from "react";
import { defineMessage, defineMessages, useIntl } from "react-intl";

import type { Funnel, Step, StepParams } from "@/api/generated/model";
import { refusal } from "@/components/crud/api-response";
import { ConfirmDeleteDialog } from "@/components/crud/confirm-delete-dialog";
import { CrudCard } from "@/components/crud/crud-card";
import { FormDialog } from "@/components/crud/form-dialog";
import { ListRow, RowActionButton, RowDetail } from "@/components/crud/list-row";
import { useApiCommand, useApiDelete, useApiSave } from "@/components/crud/use-api-mutations";
import { FormField } from "@/components/form/field";
import { useFormState } from "@/components/form/use-form-state";
import { Input } from "@/components/ui/input";
import { NonIdealState } from "@/components/ui/non-ideal-state";
import { Textarea } from "@/components/ui/textarea";
import { useApi } from "@/lib/api";
import { copy, formatCopy } from "@/lib/i18n/copy";
import { commonMessages } from "@/lib/i18n/common-messages";

/**
 * What every write to the funnel's setup refreshes: the funnel's page and
 * the list. The page's query is keyed by the funnel's code — its address.
 */
export function useFunnelInvalidation(funnel: Funnel) {
  const api = useApi();
  return [api.getAdminGetFunnelQueryKey(funnel.code), api.getAdminListFunnelsQueryKey()];
}

/**
 * The funnel's steps in their order: add, edit, delete, and move one up or
 * down (the whole order is sent, so two quick moves never cross).
 */
export function StepsCard({ funnel }: { funnel: Funnel }) {
  const intl = useIntl();
  const api = useApi();
  const invalidate = useFunnelInvalidation(funnel);
  const [editing, setEditing] = useState<Step | null>(null);
  const [adding, setAdding] = useState(false);
  const [deleting, setDeleting] = useState<Step | null>(null);

  const reorder = api.useAdminReorderFunnelSteps();
  const remove = api.useAdminDeleteFunnelStep();
  const { run, pending } = useApiCommand();

  const move = (step: Step, by: -1 | 1) => {
    const ids = funnel.steps.map((s) => s.id);
    const index = ids.indexOf(step.id);
    const other = index + by;
    if (other < 0 || other >= ids.length) return;
    [ids[index], ids[other]] = [ids[other]!, ids[index]!];
    void run(() => reorder.mutateAsync({ funnelId: funnel.id, data: { step_ids: ids } }), {
      failed: (result) =>
        formatCopy(intl, refusal(result, copy(messages.reorderFailed), messages.subject)),
      invalidate,
    });
  };

  const { destroy, pending: deletePending } = useApiDelete<Step>({
    remove: {
      mutateAsync: ({ id }) => remove.mutateAsync({ funnelId: funnel.id, id }),
      isPending: remove.isPending,
    },
    listQueryKey: api.getAdminGetFunnelQueryKey(funnel.code),
    deleted: (step) => intl.formatMessage(messages.deleted, { name: step.name }),
    failed: intl.formatMessage(messages.deleteFailed),
  });

  return (
    <>
      <CrudCard
        title={intl.formatMessage(messages.title)}
        description={intl.formatMessage(messages.description)}
        action={{ label: intl.formatMessage(messages.add), onClick: () => setAdding(true) }}
      >
        {funnel.steps.length === 0 ? (
          <NonIdealState>{intl.formatMessage(messages.empty)}</NonIdealState>
        ) : (
          <ol className="space-y-2">
            {funnel.steps.map((step, index) => (
              <ListRow
                key={step.id}
                icon={Footprints}
                title={step.name}
                actions={
                  <>
                    <RowActionButton
                      icon={ArrowUp}
                      label={intl.formatMessage(messages.moveUp)}
                      disabled={index === 0 || pending}
                      onClick={() => move(step, -1)}
                    />
                    <RowActionButton
                      icon={ArrowDown}
                      label={intl.formatMessage(messages.moveDown)}
                      disabled={index === funnel.steps.length - 1 || pending}
                      onClick={() => move(step, 1)}
                    />
                    <RowActionButton
                      icon={Pencil}
                      label={intl.formatMessage(commonMessages.edit)}
                      onClick={() => setEditing(step)}
                    />
                    <RowActionButton
                      icon={Trash2}
                      label={intl.formatMessage(commonMessages.delete)}
                      onClick={() => setDeleting(step)}
                    />
                  </>
                }
              >
                {step.description && <RowDetail>{step.description}</RowDetail>}
              </ListRow>
            ))}
          </ol>
        )}
      </CrudCard>

      <StepDialog
        funnel={funnel}
        open={adding || editing !== null}
        onOpenChange={(open) => {
          if (!open) {
            setAdding(false);
            setEditing(null);
          }
        }}
        step={editing ?? undefined}
      />

      <ConfirmDeleteDialog
        open={deleting !== null}
        onOpenChange={(open) => !open && setDeleting(null)}
        title={intl.formatMessage(messages.deleteTitle, { name: deleting?.name ?? "" })}
        description={intl.formatMessage(messages.deleteDescription)}
        confirmLabel={intl.formatMessage(commonMessages.delete)}
        pending={deletePending}
        onConfirm={async () => {
          if (deleting && (await destroy(deleting))) setDeleting(null);
        }}
      />
    </>
  );
}

type Form = { code: string; name: string; description: string };

function StepDialog({
  funnel,
  open,
  onOpenChange,
  step,
}: {
  funnel: Funnel;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  step?: Step;
}) {
  const intl = useIntl();
  const api = useApi();
  const invalidate = useFunnelInvalidation(funnel);
  const { form, set, reset } = useFormState<Form>({ code: "", name: "", description: "" });
  const editing = step !== undefined;

  useEffect(() => {
    if (open) {
      reset(
        step
          ? { code: step.code, name: step.name, description: step.description ?? "" }
          : { code: "", name: "", description: "" },
      );
    }
  }, [open, step, reset]);

  const create = api.useAdminCreateFunnelStep();
  const update = api.useAdminUpdateFunnelStep();
  const { errors, setErrors, saving, save } = useApiSave<StepParams, StepParams, Step>({
    id: step?.id,
    create: {
      mutateAsync: ({ data }) => create.mutateAsync({ funnelId: funnel.id, data }),
      isPending: create.isPending,
    },
    update: {
      mutateAsync: ({ id, data }) => update.mutateAsync({ funnelId: funnel.id, id, data }),
      isPending: update.isPending,
    },
    invalidate,
    saved: (params) => intl.formatMessage(messages.saved, { name: params.name ?? "" }),
    failed: intl.formatMessage(messages.saveFailed),
  });

  useEffect(() => {
    if (open) setErrors({});
  }, [open, setErrors]);

  return (
    <FormDialog
      open={open}
      onOpenChange={onOpenChange}
      title={intl.formatMessage(editing ? messages.editTitle : messages.addTitle)}
      submitLabel={intl.formatMessage(editing ? commonMessages.save : commonMessages.add)}
      saving={saving}
      onSubmit={async () => {
        const saved = await save({
          code: form.code,
          name: form.name,
          description: form.description || null,
        });
        if (saved) onOpenChange(false);
      }}
    >
      <FormField
        label={intl.formatMessage(messages.code)}
        htmlFor="step-code"
        hint={intl.formatMessage(messages.codeHint)}
        errors={errors.code}
      >
        <Input
          id="step-code"
          value={form.code}
          onChange={(e) => set("code", e.target.value)}
          disabled={editing}
          autoComplete="off"
          pattern="[a-z0-9]+"
        />
      </FormField>
      <FormField label={intl.formatMessage(messages.name)} htmlFor="step-name" errors={errors.name}>
        <Input id="step-name" value={form.name} onChange={(e) => set("name", e.target.value)} />
      </FormField>
      <FormField
        label={intl.formatMessage(messages.descriptionField)}
        htmlFor="step-description"
        errors={errors.description}
      >
        <Textarea
          id="step-description"
          value={form.description}
          onChange={(e) => set("description", e.target.value)}
          rows={2}
        />
      </FormField>
    </FormDialog>
  );
}

const messages = {
  ...defineMessages({
    title: { id: "steps.card.title", defaultMessage: "Steps" },
    description: {
      id: "steps.card.description",
      defaultMessage:
        "The user journey, first step at the top. Each data source counts each step its own way.",
    },
    add: { id: "steps.card.add", defaultMessage: "Add step" },
    empty: { id: "steps.card.empty", defaultMessage: "No steps yet." },
    moveUp: { id: "steps.card.moveUp", defaultMessage: "Move up" },
    moveDown: { id: "steps.card.moveDown", defaultMessage: "Move down" },
    reorderFailed: {
      id: "steps.card.reorderFailed",
      defaultMessage: "The steps could not be reordered.",
    },
    subject: { id: "steps.card.subject", defaultMessage: "step" },
    deleteDescription: {
      id: "steps.card.deleteDescription",
      defaultMessage: "Every data source's parameters and cached counts for this step go with it.",
    },
    deleteFailed: {
      id: "steps.card.deleteFailed",
      defaultMessage: "The step could not be deleted.",
    },
    addTitle: { id: "steps.dialog.addTitle", defaultMessage: "Add a step" },
    editTitle: { id: "steps.dialog.editTitle", defaultMessage: "Edit the step" },
    code: { id: "steps.dialog.code", defaultMessage: "Code" },
    codeHint: {
      id: "steps.dialog.codeHint",
      defaultMessage:
        "Lowercase letters and digits, unique within the funnel. Cannot be changed later.",
    },
    name: { id: "steps.dialog.name", defaultMessage: "Name" },
    descriptionField: { id: "steps.dialog.description", defaultMessage: "Description" },
    saveFailed: { id: "steps.dialog.failed", defaultMessage: "The step could not be saved." },
  }),
  deleteTitle: defineMessage<{ name: string }>({
    id: "steps.card.deleteTitle",
    defaultMessage: 'Delete the step "{name}"?',
  }),
  deleted: defineMessage<{ name: string }>({
    id: "steps.card.deleted",
    defaultMessage: 'Step "{name}" deleted.',
  }),
  saved: defineMessage<{ name: string }>({
    id: "steps.dialog.saved",
    defaultMessage: 'Step "{name}" saved.',
  }),
};
