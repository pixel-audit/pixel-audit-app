import { useQueryClient, type QueryKey } from "@tanstack/react-query";
import { useState } from "react";
import { toast } from "sonner";

import type { ValidationErrors, ValidationErrorsErrors } from "@/api/generated/model";

/** What the orval-generated `mutateAsync` resolves to: a status-tagged body. */
export type ApiResponse = { status: number; data: unknown };

export type Mutation<V> = {
  mutateAsync: (variables: V) => Promise<ApiResponse>;
  isPending: boolean;
};

/**
 * Create-or-update for one API resource. Owns the field errors returned by a
 * 422, the "saving" flag and the success/failure toasts; on success it
 * invalidates the list query so the card refreshes — or, given `invalidate`,
 * every query under those keys (`invalidateUnder`), for a resource whose
 * write other screens derive from (a day type's colour on every plan).
 *
 * `id` set means update, absent means create — the same rule the dialogs
 * use for their title. A resource that is only ever added (never edited in
 * place) passes no `update`.
 *
 * Create and update commonly take slightly different params (create requires
 * a stable `code`/id the update omits) — pass both type arguments when they
 * differ; a single `P` still works when create and update share one type.
 */
export function useApiSave<PCreate, PUpdate = PCreate, TSaved = unknown>({
  id,
  create,
  update,
  listQueryKey,
  invalidate,
  saved,
  failed,
}: {
  id?: string;
  create: Mutation<{ data: PCreate }>;
  update?: Mutation<{ id: string; data: PUpdate }>;
  /** The list to refresh: `listQueryKey` exactly, or everything under `invalidate`. */
  listQueryKey?: QueryKey;
  invalidate?: QueryKey[];
  /** Success toast, e.g. `Venue "X" added.`; gets the saved params. */
  saved: (params: PCreate | PUpdate) => string;
  /** Failure toast for anything that isn't a validation error. */
  failed: string;
}) {
  const queryClient = useQueryClient();
  const [errors, setErrors] = useState<ValidationErrorsErrors>({});

  /** Sends the params; resolves to the saved item, or null when it was not saved. */
  const save = async (params: PCreate | PUpdate): Promise<TSaved | null> => {
    try {
      const result =
        id !== undefined && update !== undefined
          ? await update.mutateAsync({ id, data: params as PUpdate })
          : await create.mutateAsync({ data: params as PCreate });

      if (result.status === 200 || result.status === 201) {
        toast.success(saved(params));
        await Promise.all([
          listQueryKey && queryClient.invalidateQueries({ queryKey: listQueryKey }),
          invalidate && invalidateUnder(queryClient, invalidate),
        ]);
        return (result.data as { data: TSaved }).data;
      }
      if (result.status === 422) {
        setErrors((result.data as ValidationErrors).errors);
        return null;
      }
      toast.error(failed);
    } catch {
      toast.error(failed);
    }
    return null;
  };

  return {
    errors,
    setErrors,
    saving: create.isPending || (update?.isPending ?? false),
    save,
  };
}

/**
 * Delete for one API resource: the toasts and the list invalidation. Resolves
 * to true when the item is gone, so the caller can close its confirmation.
 */
export function useApiDelete<T extends { id: string }>({
  remove,
  listQueryKey,
  deleted,
  failed,
}: {
  remove: Mutation<{ id: string }>;
  listQueryKey: QueryKey;
  deleted: (item: T) => string;
  failed: string;
}) {
  const queryClient = useQueryClient();

  const destroy = async (item: T): Promise<boolean> => {
    try {
      const result = await remove.mutateAsync({ id: item.id });
      if (result.status === 204) {
        toast.success(deleted(item));
        await queryClient.invalidateQueries({ queryKey: listQueryKey });
        return true;
      }
      toast.error(failed);
    } catch {
      toast.error(failed);
    }
    return false;
  };

  return { destroy, pending: remove.isPending };
}

/**
 * A by-id action on one API resource that is neither a save nor a delete —
 * it carries no body and leaves the item in place (resending a guide's
 * invitation, say). Same shape as its two siblings above: the toasts and the
 * list invalidation, resolving to true when the action went through.
 */
export function useApiAction<T extends { id: string }>({
  act,
  listQueryKey,
  done,
  failed,
}: {
  act: Mutation<{ id: string }>;
  listQueryKey: QueryKey;
  done: (item: T) => string;
  failed: string;
}) {
  const queryClient = useQueryClient();

  const run = async (item: T): Promise<boolean> => {
    try {
      const result = await act.mutateAsync({ id: item.id });
      if (result.status === 200) {
        toast.success(done(item));
        await queryClient.invalidateQueries({ queryKey: listQueryKey });
        return true;
      }
      toast.error(failed);
    } catch {
      toast.error(failed);
    }
    return false;
  };

  return { run, pending: act.isPending };
}

/**
 * Adapts a mutation addressed by `code` (day types, rate options) to the
 * `id`-addressed shape `useApiSave` and `useApiDelete` take: the item's code
 * travels as `id`.
 */
export function byCode<V extends { code: string }>(mutation: {
  mutateAsync: (variables: V) => Promise<ApiResponse>;
  isPending: boolean;
}): Mutation<Omit<V, "code"> & { id: string }> {
  return {
    mutateAsync: ({ id, ...rest }) => mutation.mutateAsync({ ...rest, code: id } as unknown as V),
    isPending: mutation.isPending,
  };
}

/**
 * Invalidates every query whose URL starts with one of the given keys' URL —
 * `getAdminGetOperationsPlanQueryKey(id)` also refreshes the plan's preview,
 * validation and impact, which live under it.
 */
export async function invalidateUnder(
  queryClient: ReturnType<typeof useQueryClient>,
  keys: QueryKey[],
): Promise<void> {
  const prefixes = keys.map((key) => String(key[0]));
  await queryClient.invalidateQueries({
    predicate: (query) => prefixes.some((prefix) => String(query.queryKey[0]).startsWith(prefix)),
  });
}

/** Success statuses a command may answer with. */
const isSuccess = (status: number) => status >= 200 && status < 300;

/**
 * A one-off API command — approve, activate, replace a list, cancel an
 * exception: runs the generated raw call, toasts the outcome, invalidates
 * the queries under `invalidate` on success. Resolves to the response on
 * success and null otherwise; `failed` gets the non-2xx response (or null
 * when the request itself failed) so the screen can word the refusal.
 */
export function useApiCommand() {
  const queryClient = useQueryClient();
  const [pending, setPending] = useState(false);

  const run = async <R extends ApiResponse>(
    call: () => Promise<R>,
    {
      done,
      failed,
      invalidate = [],
    }: {
      /** Success toast; omit (or return null) for none. */
      done?: string | ((result: R) => string | null);
      failed: (result: R | null) => string | null;
      invalidate?: QueryKey[];
    },
  ): Promise<R | null> => {
    setPending(true);
    try {
      const result = await call();
      if (isSuccess(result.status)) {
        const message = typeof done === "function" ? done(result) : done;
        if (message) toast.success(message);
        await invalidateUnder(queryClient, invalidate);
        return result;
      }
      const message = failed(result);
      if (message) toast.error(message);
    } catch {
      const message = failed(null);
      if (message) toast.error(message);
    } finally {
      setPending(false);
    }
    return null;
  };

  return { run, pending };
}
