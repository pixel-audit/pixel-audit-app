import type { AdminListConnectionCallsPurpose as CallPurpose } from "@/api/generated/model";

/** Why a call is made, in the order the filter lists them. */
export const CALL_PURPOSES: readonly CallPurpose[] = ["count", "meta_stats_pull", "check"];
