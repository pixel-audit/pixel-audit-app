import { useState } from "react";

/**
 * A flat form object with a typed per-key setter — the shape every dialog
 * form has. `set("name", value)` replaces one key, `reset(values)` the whole
 * object (used when the dialog opens for a different item).
 */
export function useFormState<T extends object>(initial: T) {
  const [form, setForm] = useState<T>(initial);

  const set = <K extends keyof T>(key: K, value: T[K]) => setForm((f) => ({ ...f, [key]: value }));

  return { form, set, reset: setForm };
}
