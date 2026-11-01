import { Pencil, Shuffle, Trash2 } from "lucide-react";
import { useEffect, useState } from "react";
import { defineMessage, defineMessages, useIntl } from "react-intl";

import type {
  DataSource,
  DataSourceParams,
  DataSourceParamsType,
  Funnel,
} from "@/api/generated/model";
import { connectionTypeLabel, useConnectionTypes } from "@/components/connections/connection-types";
import { okData, refusal } from "@/components/crud/api-response";
import { ConfirmDeleteDialog } from "@/components/crud/confirm-delete-dialog";
import { CrudCard } from "@/components/crud/crud-card";
import { FormDialog } from "@/components/crud/form-dialog";
import { ListRow, RowActionButton, RowDetail } from "@/components/crud/list-row";
import { useApiDelete, useApiSave } from "@/components/crud/use-api-mutations";
import { EntityCombobox } from "@/components/form/entity-combobox";
import { FormField } from "@/components/form/field";
import { FieldSpecFields, type FieldSpecValues } from "@/components/form/field-spec-fields";
import { filledValues } from "@/components/form/field-spec-values";
import { useFormState } from "@/components/form/use-form-state";
import { dataSourceTypeLabel, useDataSourceTypes } from "@/components/funnels/data-source-types";
import { useFunnelInvalidation } from "@/components/funnels/use-funnel-invalidation";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { NonIdealState } from "@/components/ui/non-ideal-state";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { useApi } from "@/lib/api";
import { copy, formatCopy } from "@/lib/i18n/copy";
import { commonMessages } from "@/lib/i18n/common-messages";

/** The funnel's data sources: where each step's counts are read from. */
export function DataSourcesCard({ funnel }: { funnel: Funnel }) {
  const intl = useIntl();
  const api = useApi();
  const types = useDataSourceTypes();
  const connectionTypes = useConnectionTypes();
  const [editing, setEditing] = useState<DataSource | null>(null);
  const [adding, setAdding] = useState(false);
  const [deleting, setDeleting] = useState<DataSource | null>(null);

  const remove = api.useAdminDeleteFunnelDataSource();
  const { destroy, pending: deletePending } = useApiDelete<DataSource>({
    remove: {
      mutateAsync: ({ id }) => remove.mutateAsync({ funnelId: funnel.id, id }),
      isPending: remove.isPending,
    },
    listQueryKey: api.getAdminGetFunnelQueryKey(funnel.id),
    deleted: (item) => intl.formatMessage(messages.deleted, { name: item.name }),
    failed: intl.formatMessage(messages.deleteFailed),
  });

  return (
    <>
      <CrudCard
        title={intl.formatMessage(messages.title)}
        description={intl.formatMessage(messages.description)}
        action={{ label: intl.formatMessage(messages.add), onClick: () => setAdding(true) }}
      >
        {funnel.data_sources.length === 0 ? (
          <NonIdealState>{intl.formatMessage(messages.empty)}</NonIdealState>
        ) : (
          <ul className="space-y-2">
            {funnel.data_sources.map((source) => (
              <ListRow
                key={source.id}
                leading={
                  <span
                    aria-hidden
                    className="size-10 shrink-0 rounded-md"
                    style={{ backgroundColor: source.color }}
                  />
                }
                title={source.name}
                badges={
                  <>
                    <Badge variant="secondary">{dataSourceTypeLabel(types, source.type)}</Badge>
                  </>
                }
                actions={
                  <>
                    <RowActionButton
                      icon={Pencil}
                      label={intl.formatMessage(commonMessages.edit)}
                      onClick={() => setEditing(source)}
                    />
                    <RowActionButton
                      icon={Trash2}
                      label={intl.formatMessage(commonMessages.delete)}
                      onClick={() => setDeleting(source)}
                    />
                  </>
                }
              >
                <RowDetail>
                  {intl.formatMessage(messages.via, {
                    connection: source.connection.name,
                    type: connectionTypeLabel(connectionTypes, source.connection.type),
                  })}
                </RowDetail>
                {Object.keys(source.settings).length > 0 && (
                  <RowDetail muted>
                    {Object.entries(source.settings)
                      .map(([key, value]) => intl.formatMessage(messages.setting, { key, value }))
                      .join(" · ")}
                  </RowDetail>
                )}
              </ListRow>
            ))}
          </ul>
        )}
      </CrudCard>

      <DataSourceDialog
        funnel={funnel}
        open={adding || editing !== null}
        onOpenChange={(open) => {
          if (!open) {
            setAdding(false);
            setEditing(null);
          }
        }}
        dataSource={editing ?? undefined}
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

type Form = {
  name: string;
  description: string;
  type: DataSourceParamsType;
  connection_id: string;
  settings: FieldSpecValues;
  color: string;
};

/**
 * The colours a new source starts from — the API's palette, so a source
 * added here and one dealt by the API look alike. One not yet used in the
 * funnel, at random.
 */
const PALETTE = [
  "#2563eb",
  "#db2777",
  "#16a34a",
  "#ea580c",
  "#7c3aed",
  "#0891b2",
  "#ca8a04",
  "#dc2626",
  "#0d9488",
  "#9333ea",
  "#65a30d",
  "#4f46e5",
];

const randomColor = (used: string[]): string => {
  const free = PALETTE.filter((c) => !used.includes(c));
  const pool = free.length > 0 ? free : PALETTE;
  return pool[Math.floor(Math.random() * pool.length)] ?? PALETTE[0]!;
};

const blank = (used: string[]): Form => ({
  name: "",
  description: "",
  type: "meta_pixel_api",
  connection_id: "",
  settings: {},
  color: randomColor(used),
});

function DataSourceDialog({
  funnel,
  open,
  onOpenChange,
  dataSource,
}: {
  funnel: Funnel;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  dataSource?: DataSource;
}) {
  const intl = useIntl();
  const api = useApi();
  const types = useDataSourceTypes();
  const connectionTypes = useConnectionTypes();
  const connections = okData(api.useAdminListConnections().data)?.data ?? [];
  const invalidate = useFunnelInvalidation(funnel);
  const used = funnel.data_sources.map((s) => s.color);
  const { form, set, reset } = useFormState<Form>(blank(used));
  const editing = dataSource !== undefined;

  useEffect(() => {
    if (open) {
      reset(
        dataSource
          ? {
              name: dataSource.name,
              description: dataSource.description ?? "",
              type: dataSource.type,
              connection_id: dataSource.connection_id,
              settings: { ...dataSource.settings },
              color: dataSource.color,
            }
          : blank(funnel.data_sources.map((s) => s.color)),
      );
    }
  }, [open, dataSource, reset, funnel.data_sources]);

  const type = types.find((t) => t.type === form.type);
  const eligible = connections.filter((c) => c.type === type?.connection_type);

  const create = api.useAdminCreateFunnelDataSource();
  const update = api.useAdminUpdateFunnelDataSource();
  const { errors, setErrors, saving, save } = useApiSave<
    DataSourceParams,
    DataSourceParams,
    DataSource
  >({
    id: dataSource?.id,
    create: {
      mutateAsync: ({ data }) => create.mutateAsync({ funnelId: funnel.id, data }),
      isPending: create.isPending,
    },
    update: {
      mutateAsync: ({ id, data }) => update.mutateAsync({ funnelId: funnel.id, id, data }),
      isPending: update.isPending,
    },
    invalidate: [...invalidate, api.getAdminListRefreshRunsQueryKey()],
    saved: (params) => intl.formatMessage(messages.saved, { name: params.name ?? "" }),
    failed: intl.formatMessage(messages.saveFailed),
  });

  useEffect(() => {
    if (open) setErrors({});
  }, [open, setErrors]);

  // A 422 with a detail (connection_type_mismatch) is not a field error;
  // useApiSave would show the generic toast, so it is caught here first.
  const submit = async () => {
    const params: DataSourceParams = {
      name: form.name,
      description: form.description || null,
      type: form.type,
      connection_id: form.connection_id,
      settings: filledValues(form.settings),
      color: form.color,
    };
    const saved = await save(params);
    if (saved) onOpenChange(false);
  };

  return (
    <FormDialog
      open={open}
      onOpenChange={onOpenChange}
      title={intl.formatMessage(editing ? messages.editTitle : messages.addTitle)}
      submitLabel={intl.formatMessage(editing ? commonMessages.save : commonMessages.add)}
      saving={saving}
      onSubmit={submit}
      className="max-w-xl"
    >
      <FormField
        label={intl.formatMessage(messages.name)}
        htmlFor="source-name"
        errors={errors.name}
      >
        <Input id="source-name" value={form.name} onChange={(e) => set("name", e.target.value)} />
      </FormField>
      <FormField
        label={intl.formatMessage(messages.descriptionField)}
        htmlFor="source-description"
        errors={errors.description}
      >
        <Textarea
          id="source-description"
          value={form.description}
          onChange={(e) => set("description", e.target.value)}
          rows={2}
        />
      </FormField>

      <FormField
        label={intl.formatMessage(messages.color)}
        htmlFor="source-color"
        hint={intl.formatMessage(messages.colorHint)}
        errors={errors.color}
      >
        <div className="flex items-center gap-2">
          <input
            id="source-color"
            type="color"
            value={form.color}
            onChange={(e) => set("color", e.target.value)}
            className="h-9 w-12 cursor-pointer rounded-md border border-input bg-background p-1"
          />
          <code className="text-xs text-muted-foreground">{form.color}</code>
          <Button
            type="button"
            variant="outline"
            size="sm"
            onClick={() => set("color", randomColor(used.filter((c) => c !== dataSource?.color)))}
          >
            <Shuffle className="size-4" /> {intl.formatMessage(messages.randomColor)}
          </Button>
        </div>
      </FormField>

      <FormField
        label={intl.formatMessage(messages.type)}
        htmlFor="source-type"
        hint={type?.description}
        errors={errors.type}
      >
        <Select
          value={form.type}
          onValueChange={(next) => {
            set("type", next as DataSourceParamsType);
            set("connection_id", "");
            set("settings", {});
          }}
        >
          <SelectTrigger id="source-type">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {types.map((t) => (
              <SelectItem key={t.type} value={t.type}>
                {t.label}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </FormField>

      <FormField
        label={intl.formatMessage(messages.connection)}
        htmlFor="source-connection"
        hint={
          type &&
          intl.formatMessage(messages.connectionHint, {
            type: connectionTypeLabel(connectionTypes, type.connection_type),
          })
        }
        errors={errors.connection_id}
      >
        <EntityCombobox
          id="source-connection"
          value={form.connection_id}
          onChange={(value) => set("connection_id", value)}
          options={eligible.map((c) => ({ value: c.id, label: c.name }))}
          placeholder={
            eligible.length === 0
              ? intl.formatMessage(messages.noConnections)
              : intl.formatMessage(commonMessages.notSet)
          }
          disabled={eligible.length === 0}
        />
      </FormField>

      {type && type.settings.length > 0 && (
        <FieldSpecFields
          specs={type.settings}
          values={form.settings}
          onChange={(key, value) => set("settings", { ...form.settings, [key]: value })}
          errors={errors}
          errorPrefix="settings"
          idPrefix="source-setting"
        />
      )}

      {errors.detail && (
        <p className="text-xs text-destructive">
          {formatCopy(
            intl,
            refusal(
              { data: { errors: { detail: errors.detail[0] } } },
              copy(messages.saveFailed),
              messages.subject,
            ),
          )}
        </p>
      )}
    </FormDialog>
  );
}

const messages = {
  ...defineMessages({
    title: { id: "dataSources.card.title", defaultMessage: "Data sources" },
    description: {
      id: "dataSources.card.description",
      defaultMessage:
        "Where the counts come from. Several sources on one funnel show how far the networks disagree.",
    },
    add: { id: "dataSources.card.add", defaultMessage: "Add data source" },
    empty: { id: "dataSources.card.empty", defaultMessage: "No data sources yet." },
    deleteDescription: {
      id: "dataSources.card.deleteDescription",
      defaultMessage: "Its step parameters and cached counts go with it.",
    },
    deleteFailed: {
      id: "dataSources.card.deleteFailed",
      defaultMessage: "The data source could not be deleted.",
    },
    addTitle: { id: "dataSources.dialog.addTitle", defaultMessage: "Add a data source" },
    editTitle: { id: "dataSources.dialog.editTitle", defaultMessage: "Edit the data source" },
    name: { id: "dataSources.dialog.name", defaultMessage: "Name" },
    descriptionField: { id: "dataSources.dialog.description", defaultMessage: "Description" },
    type: { id: "dataSources.dialog.type", defaultMessage: "Type" },
    color: { id: "dataSources.dialog.color", defaultMessage: "Colour" },
    colorHint: {
      id: "dataSources.dialog.colorHint",
      defaultMessage: "How the source is drawn on the funnel chart.",
    },
    randomColor: { id: "dataSources.dialog.randomColor", defaultMessage: "Random" },
    connection: { id: "dataSources.dialog.connection", defaultMessage: "Connection" },
    noConnections: {
      id: "dataSources.dialog.noConnections",
      defaultMessage: "No connection of this type yet — add one under Connections.",
    },
    saveFailed: {
      id: "dataSources.dialog.failed",
      defaultMessage: "The data source could not be saved.",
    },
    subject: { id: "dataSources.dialog.subject", defaultMessage: "data source" },
  }),
  via: defineMessage<{ connection: string; type: string }>({
    id: "dataSources.card.via",
    defaultMessage: "Through {connection} ({type})",
  }),
  setting: defineMessage<{ key: string; value: string }>({
    id: "dataSources.card.setting",
    defaultMessage: "{key}: {value}",
  }),
  connectionHint: defineMessage<{ type: string }>({
    id: "dataSources.dialog.connectionHint",
    defaultMessage: "A connection of type {type}.",
  }),
  deleteTitle: defineMessage<{ name: string }>({
    id: "dataSources.card.deleteTitle",
    defaultMessage: 'Delete the data source "{name}"?',
  }),
  deleted: defineMessage<{ name: string }>({
    id: "dataSources.card.deleted",
    defaultMessage: 'Data source "{name}" deleted.',
  }),
  saved: defineMessage<{ name: string }>({
    id: "dataSources.dialog.saved",
    defaultMessage: 'Data source "{name}" saved.',
  }),
};
