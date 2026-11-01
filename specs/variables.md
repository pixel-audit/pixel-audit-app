# Variables

A variable is one string value under a key, with an optional description:
a key/value store for whatever a deployment wants to keep beside its
funnels. Part of the Settings context (`PixelAudit.Api.Settings`, schema
`PixelAudit.Api.Settings.Variable`, table `settings_variables`, API
`/api/admin/v1/settings/variables`), beside the connections
(`specs/connections.md`).

- `key` is `[a-zA-Z0-9]+`, case-sensitive and unique; it cannot be changed
  once set (the panel disables it on edit).
- `value` is any string, the empty one included; it is stored as sent,
  untrimmed. Not a secret: the API returns it.
- `description` is optional.

## The environment (`boot`)

`PixelAudit.Api.Settings.EnvSync.Variables` maps `VARIABLE_*` variables
onto rows, in the same run and transaction as the connections:

- `VARIABLE_<key>_VALUE` defines the variable; `VARIABLE_<key>_DESCRIPTION`
  its description, optional. Any other suffix is a problem, as is a
  description without a value; a name whose key is not alphanumeric is
  ignored (it cannot be one).
- An existing key gets the value, and the description when the
  environment gives one — a description typed in the panel survives a
  boot that says none. A new key is created. Both are `managed_by_env`:
  the API refuses a change of their key or value (`409 managed_by_env`);
  the description stays editable.
- A variable that was managed and is no longer in the environment is left
  in place, no longer marked.

## Deleting

A variable can always be deleted. One the environment defines comes back
at the next boot.
