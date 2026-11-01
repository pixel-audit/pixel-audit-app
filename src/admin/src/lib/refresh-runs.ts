import type { RefreshRun } from "@/api/generated/model";

/** A run's name: its funnel and data source, or its connection. */
export function describeRun(run: RefreshRun): string {
  return (
    run.kind === "data_source" ? [run.funnel?.name, run.data_source?.name] : [run.connection?.name]
  )
    .filter((part): part is string => typeof part === "string")
    .join(" › ");
}
