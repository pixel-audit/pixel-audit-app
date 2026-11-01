import type { DataSourceType } from "@/api/generated/model";
import { okData } from "@/components/crud/api-response";
import { useApi } from "@/lib/api";

/** The data source types as the API declares them: settings and step parameters included. */
export function useDataSourceTypes(): DataSourceType[] {
  return okData(useApi().useAdminListDataSourceTypes().data)?.data ?? [];
}

/** A type's label: the API's, or the raw type while the types load. */
export function dataSourceTypeLabel(types: DataSourceType[], type: string): string {
  return types.find((t) => t.type === type)?.label ?? type;
}
