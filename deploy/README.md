# PixelAudit Helm chart

Installs PixelAudit — the API with the admin panel built in, one image under one hostname — on your own Kubernetes. One release is one instance: a Deployment, a boot Job that migrates the database and applies the `CONNECTION_*` environment before every rollout, and optionally the chart's own PostgreSQL and a way of exposing the hostname. The only state is the PostgreSQL database.

PixelAudit is released under the GNU AGPL v3. The image and this chart are published to the GitHub Container Registry as public packages by the repository's CI.

## Prerequisites

- Kubernetes 1.28 or later, and Helm 3.8 or later (OCI support).
- A database: a managed PostgreSQL 15 or later reachable from the cluster, or a StorageClass for the chart's own PostgreSQL 18.
- To expose it: an ingress controller, or the Gateway API CRDs with a controller for your GatewayClass. Both are optional and off by default.
- The panel is served at the hostname's root and the API under `/api`, so one hostname and no CORS.
- Optional: cert-manager, for the TLS certificate.

The API has **no authentication**. Keep the hostname behind your network boundary: a VPN, an IP allow-list on the ingress or gateway, or an authenticating proxy in front of it. Search engines are told to stay away (`robots.txt`, a `noindex` header), which is no substitute for the boundary.

## Secrets

The chart never takes a secret as a value. Everything secret is a Secret you create and name:

| Secret | Keys | Value |
|---|---|---|
| `secrets.secretName` (**required**) | `WEB_SECRET_KEY_BASE`, `CREDENTIALS_ENCRYPTION_KEY` | Phoenix's signing secret (64+ characters; what the framework signs its tokens and cookies with), and the 256-bit key the connection credentials are encrypted with at rest, as 64 hex characters. |
| `database.external.secretName` | `DATABASE_URL` | Your managed Postgres: `postgres://user:password@host:5432/db?sslmode=require`. |
| `database.internal.passwordSecret.name` | `POSTGRES_PASSWORD` | The chart's own Postgres, when you want to choose its password; left empty, the chart generates one once and keeps it. |
| `app.extraEnvFrom` (a `secretRef`) | `CONNECTION_*`, `VARIABLE_*` | Connections and variables defined by the environment — see below. |
| `ingress.tlsSecretName` / `gateway.tlsSecretName` | `tls.crt`, `tls.key` | The certificate for the hostname, unless cert-manager issues it. |

The key names inside the first two can be changed with `secrets.keys.*` and `database.external.secretKey`.

```sh
kubectl create namespace pixelaudit
kubectl -n pixelaudit create secret generic pixelaudit-keys \
  --from-literal=WEB_SECRET_KEY_BASE="$(openssl rand -base64 64 | tr -d '\n')" \
  --from-literal=CREDENTIALS_ENCRYPTION_KEY="$(openssl rand -hex 32)"
```

**Back `CREDENTIALS_ENCRYPTION_KEY` up with the database**: a database restored without it cannot read any stored credential. `WEB_SECRET_KEY_BASE` can be rotated freely; nothing stored depends on it.

## Install

1. Create the Secrets above — at least the keys, and the database URL if you bring your own Postgres.
2. Write your values, starting from one of the examples:
   - [`examples/values-minimal.yaml`](examples/values-minimal.yaml) — your managed Postgres, an Ingress with TLS from cert-manager.
   - [`examples/values-gateway.yaml`](examples/values-gateway.yaml) — the same, exposed through the Gateway API.
   - [`examples/values-all-in-one.yaml`](examples/values-all-in-one.yaml) — the chart's own Postgres on a volume, a plain-http Ingress, for a try-out.
   - [`examples/values-track-latest.yaml`](examples/values-track-latest.yaml) — the minimal shape running the main branch's images.
3. Install:

   ```sh
   helm install pixelaudit oci://ghcr.io/pixel-audit/charts/pixelaudit --version 0.0.3 \
     --namespace pixelaudit --atomic --values my-values.yaml
   ```

   `--atomic` rolls the release back if the boot Job fails — a migration that did not apply, a malformed `CONNECTION_*` set — so a bad upgrade never leaves half a release running.

The chart's notes print the URLs. The panel is at `https://<hostname>/`, the API under `https://<hostname>/api/admin/v1`, the OpenAPI document at `https://<hostname>/openapi/admin.json`.

## The database

Exactly one of the two:

- **A managed PostgreSQL** (15 or later): `database.external.secretName` names a Secret holding `DATABASE_URL`. Use `?sslmode=require` or `verify-full` for TLS.
- **The chart's own PostgreSQL 18**: `database.internal.enabled: true` runs a StatefulSet of one pod on a persistent volume claim, sized by `database.internal.storage.size` and placed by `database.internal.storage.storageClassName` (empty: the cluster's default class). The image tag must be 18 or later; the schema checks it. The claim and the generated password Secret stay on uninstall, so a reinstall finds its data. Back it up yourself.

With the chart's own Postgres the first install runs the boot Job *after* the resources are created (there is no database before), waiting for Postgres; the API pods restart until it is through. Upgrades run it before the rollout, as always.

## Exposing the hostname

`hostname` is always required — the application is told its own hostname — and `tls` says whether it is served over https. How it reaches the network is up to you, and nothing is created unless you ask:

- **Ingress** — `ingress.enabled: true`, with `ingress.className` and annotations such as `cert-manager.io/cluster-issuer`; with `tls` the TLS Secret is `ingress.tlsSecretName` (default `<release>-tls`).
- **Gateway API** — `gateway.enabled: true`. The chart creates a Gateway of `gateway.className` with a listener for the hostname on port 80 and, with `tls`, on 443 serving `gateway.tlsSecretName` (default `<release>-tls`; cert-manager fills it in from `gateway.annotations`), and an HTTPRoute attached to it. To attach the route to a Gateway you already run, leave `className` empty and set `gateway.existing.name` (and `namespace`); its listeners must admit routes from the release's namespace for this hostname.
- **Neither** — the Service `<release>` stays cluster-internal, for whatever you put in front yourself.

## Choosing the image version

The image is `ghcr.io/pixel-audit/pixel-audit-app` (`pixel-audit/pixel-audit-app` is the GitHub organisation and repository the code lives under; a fork publishes under its own, set `image.repository`). CI tags it `X.Y.Z` on a `vX.Y.Z` release and moves `latest` on every push to `main`. Two ways to pick one:

| Mode | Values | Behaviour |
|---|---|---|
| **A release** (default) | `image.tag` empty — or any released `X.Y.Z` | Runs the chart's `appVersion`, the release the chart came from; pulled once (`IfNotPresent`). Upgrade by installing a newer chart version. |
| **Track `main`** | `image.trackLatest: true` | Runs the `latest` tag with `pullPolicy: Always`, so every pod start fetches the current one. |

Picking up a newer `latest`:

```sh
helm upgrade pixelaudit oci://ghcr.io/pixel-audit/charts/pixelaudit \
  --namespace pixelaudit --reuse-values --atomic                  # re-runs the boot Job: migrations first
kubectl -n pixelaudit rollout restart deployment/pixelaudit
```

`image.trackLatest` overrides `image.tag` and `image.pullPolicy` in one switch; the boot Job and the Deployment always run the same tag.

## Connections and variables from the environment

Connections (a Meta pixel, a BigQuery project, a Postgres or ClickHouse database) can be added in the panel, or defined by `CONNECTION_*` variables that the boot Job maps onto connection rows on every install and upgrade:

```
CONNECTION_<id>_TYPE = meta | bigquery | postgres | clickhouse
CONNECTION_<id>_<PARAM> = ...
```

`<id>` is the connection's code — lowercase letters and digits — and `<PARAM>` one of the type's credentials: `ACCESS_TOKEN`, `PIXEL_ID`, `API_VERSION` for `meta`; `CREDENTIALS_JSON` (the service account's key file, as JSON or base64 of it), `PROJECT_ID`, `LOCATION` for `bigquery`; `URL` for `postgres` (`postgres://user:password@host:5432/database`) and for `clickhouse` (`http://user:password@host:8123/database`, the HTTP interface). Put them in a Secret and hand it to the application through `app.extraEnvFrom`:

```sh
kubectl -n pixelaudit create secret generic pixelaudit-connections \
  --from-literal=CONNECTION_fb_TYPE=meta \
  --from-literal=CONNECTION_fb_PIXEL_ID=123456789012345 \
  --from-literal=CONNECTION_fb_ACCESS_TOKEN=EAA... \
  --from-literal=CONNECTION_bq_TYPE=bigquery \
  --from-literal=CONNECTION_bq_PROJECT_ID=my-project \
  --from-file=CONNECTION_bq_CREDENTIALS_JSON=service-account.json
```

```yaml
app:
  extraEnvFrom:
    - secretRef:
        name: pixelaudit-connections
```

A connection defined this way is marked *managed by the environment* in the panel: its type and credentials are read-only there, its name and description editable. An existing connection with the same code is updated, a new one created with its name set to its code.

Variables — the key/value store under **Settings → Variables** — are seeded the same way, from the same Secret or another one handed over through `app.extraEnvFrom`:

```
VARIABLE_<key>_VALUE = ...
VARIABLE_<key>_DESCRIPTION = ...   (optional)
```

`<key>` is letters and digits, case-sensitive. A variable defined this way has its value read-only in the panel.

After changing the Secret, `helm upgrade` re-runs the boot Job so the rows follow, and restart the pods (`kubectl rollout restart deployment/<release>`) since the Secret's values are their environment.

## Resources

No CPU or memory requests or limits are set by default. `app.resources`, `app.boot.resources` and `database.internal.resources` take the usual block:

```yaml
app:
  resources:
    requests: { cpu: 50m, memory: 128Mi }
    limits: { cpu: "1", memory: 512Mi }
```

As a guide: the application idles around 100Mi and takes a few hundred more while refreshing a wide range.

## Upgrading

```sh
helm upgrade pixelaudit oci://ghcr.io/pixel-audit/charts/pixelaudit --version <new> \
  --namespace pixelaudit --atomic --reuse-values
```

The boot Job runs as a pre-upgrade hook: the new release's migrations are applied before the new pods roll out, and a failure rolls the release back without touching the running pods.

## Backups

The database is the only state. Back it up together with `CREDENTIALS_ENCRYPTION_KEY`: the connection credentials in it are encrypted with that key, and a restore without it loses every credential (the connections themselves stay, with their credentials to be entered again).

## Uninstall

```sh
helm uninstall pixelaudit --namespace pixelaudit
```

Secrets you created stay. So do the chart's own Postgres volume claim and its generated password Secret; delete them yourself when the data is no longer wanted. With `serviceAccount.create`, the ServiceAccount (a hook) stays too.

## Try it on kind or minikube

[`examples/values-all-in-one.yaml`](examples/values-all-in-one.yaml) runs everything in the cluster: the chart's own PostgreSQL on a 2Gi claim, a plain-http Ingress. With an nginx ingress controller listening on the host's port 80:

```sh
git clone https://github.com/pixel-audit/pixel-audit-app && cd pixel-audit-app
kubectl create namespace pixelaudit
kubectl -n pixelaudit create secret generic pixelaudit-keys \
  --from-literal=WEB_SECRET_KEY_BASE="$(openssl rand -base64 64 | tr -d '\n')" \
  --from-literal=CREDENTIALS_ENCRYPTION_KEY="$(openssl rand -hex 32)"
helm install pixelaudit deploy --namespace pixelaudit --atomic \
  --values deploy/examples/values-all-in-one.yaml
```

Then open <http://pixelaudit.127.0.0.1.nip.io>.

## Values

| Key | Default | Description |
|---|---|---|
| `image.registry` | `ghcr.io` | The registry. |
| `image.repository` | `pixel-audit/pixel-audit-app` | Images are `<registry>/<repository>-api` and `-admin`. |
| `image.tag` | `""` | The image tag; empty: the chart's `appVersion`. |
| `image.pullPolicy` | `IfNotPresent` | |
| `image.trackLatest` | `false` | Run the `latest` tag with `pullPolicy: Always` (overrides the two above). |
| `image.pullSecrets` | `[]` | Image pull Secret names, for a private registry. |
| `hostname` | — | **Required.** The public hostname (`HOSTNAME`): the panel at its root, the API under `/api`. |
| `tls` | `true` | Whether the hostname is served over https. |
| `sourceUrl` | the repository | Where the panel's foot says the source is offered (`SOURCE_URL`). |
| `secrets.secretName` | — | **Required.** The Secret holding the two secrets. |
| `secrets.keys.webSecretKeyBase` | `WEB_SECRET_KEY_BASE` | Its key for Phoenix's signing secret. |
| `secrets.keys.credentialsEncryptionKey` | `CREDENTIALS_ENCRYPTION_KEY` | Its key for the credentials' encryption key. |
| `database.external.secretName` | `""` | A Secret holding your Postgres URL. |
| `database.external.secretKey` | `DATABASE_URL` | Its key. |
| `database.internal.enabled` | `false` | Run the chart's own PostgreSQL instead. |
| `database.internal.image.repository` | `docker.io/library/postgres` | |
| `database.internal.image.tag` | `"18"` | 18 or later. |
| `database.internal.storage.size` | `10Gi` | The volume claim's size. |
| `database.internal.storage.storageClassName` | `""` | The StorageClass; empty: the default class. |
| `database.internal.database` | `pixelaudit` | |
| `database.internal.username` | `pixelaudit` | |
| `database.internal.passwordSecret.name` | `""` | A Secret with the password; empty: generated once and kept. |
| `database.internal.passwordSecret.key` | `POSTGRES_PASSWORD` | |
| `database.internal.resources` | `{}` | |
| `database.internal.waitImage` | `busybox:1.37` | What the boot Job waits for Postgres with on a first install. |
| `ingress.enabled` | `false` | Expose the hostname with an Ingress. |
| `ingress.className` | `""` | The IngressClass; empty: the cluster's default. |
| `ingress.annotations` | `{}` | e.g. `cert-manager.io/cluster-issuer`. |
| `ingress.tlsSecretName` | `""` | The TLS Secret; empty: `<release>-tls`. |
| `gateway.enabled` | `false` | Expose the hostname with the Gateway API. |
| `gateway.className` | `""` | The GatewayClass of the Gateway the chart creates. |
| `gateway.annotations` | `{}` | Annotations on that Gateway. |
| `gateway.tlsSecretName` | `""` | The TLS Secret its https listeners serve; empty: `<release>-tls`. |
| `gateway.existing.name` | `""` | Attach to this Gateway instead of creating one. |
| `gateway.existing.namespace` | `""` | Its namespace; empty: the release's. |
| `app.replicaCount` | `1` | |
| `app.port` | `4000` | The container port (`PORT`). |
| `app.poolSize` | `10` | `DATABASE_POOL_SIZE`. |
| `app.extraEnv` | `[]` | Extra environment variables for the pods and the boot Job. |
| `app.extraEnvFrom` | `[]` | `envFrom` entries (a Secret of `CONNECTION_*` variables). |
| `app.resources` | `{}` | |
| `app.boot.activeDeadlineSeconds` | `600` | How long the boot Job may take. |
| `app.boot.resources` | `{}` | |
| `serviceAccount.create` | `false` | Create a ServiceAccount for the pods (a pre-install/upgrade hook, ahead of the boot Job; kept on uninstall). Off: the pods run as an existing one. |
| `serviceAccount.name` | `""` | With `create`: empty is the release's full name. Without: an existing ServiceAccount, empty is the namespace's `default`. |
| `serviceAccount.annotations` | `{}` | Annotations on the created ServiceAccount. |
| `podSecurityContext` | non-root, RuntimeDefault seccomp | |
| `securityContext` | no escalation, all capabilities dropped, read-only root | |
| `nodeSelector`, `tolerations`, `affinity` | `{}`, `[]`, `{}` | |

`values.schema.json` checks the values at install time: `hostname` and `secrets.secretName` are required, the internal Postgres tag must be 18 or later, and the templates refuse a release with no database or with both.
