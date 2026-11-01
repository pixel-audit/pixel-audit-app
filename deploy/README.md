# PixelAudit Helm chart

Installs PixelAudit — the API and the admin panel — on your own Kubernetes. One release is one instance: an API Deployment, an admin Deployment, a boot Job that migrates the database and applies the `CONNECTION_*` environment before every rollout, one Ingress with a hostname for each. The only state is a PostgreSQL database: yours, or the Bitnami subchart's for a try-out.

PixelAudit is released under the GNU AGPL v3. The images and this chart are published to the GitHub Container Registry as public packages by the repository's CI.

## Prerequisites

- Kubernetes 1.28 or later, and Helm 3.8 or later (OCI support).
- An ingress controller (the examples name the `nginx` class).
- A PostgreSQL 15 or later reachable from the cluster — or `postgresql.enabled: true` for the in-chart one.
- Optional: cert-manager, for the TLS certificate (`ingress.annotations`).

The API has **no authentication**. Keep both hostnames behind your network boundary: a VPN, an IP allow-list on the ingress, or an authenticating proxy in front of it.

## Install

1. Generate the two keys:

   ```sh
   SECRET_KEY_BASE="$(openssl rand -base64 64 | tr -d '\n')"   # or: mix phx.gen.secret
   SECRET_KEY="$(openssl rand -hex 32)"                          # 64 hex characters
   ```

   `SECRET_KEY` encrypts the connection credentials stored in the database. **Back it up with the database**: a database restored without it cannot read any credential.

2. Put them in a Secret (or inline under `secrets.secretKeyBase` / `secrets.secretKey`):

   ```sh
   kubectl create namespace pixelaudit
   kubectl -n pixelaudit create secret generic pixelaudit-keys \
     --from-literal=SECRET_KEY_BASE="$SECRET_KEY_BASE" \
     --from-literal=SECRET_KEY="$SECRET_KEY"
   ```

3. Write your values (start from [`examples/values-minimal.yaml`](examples/values-minimal.yaml)): the two hostnames, the database URL, the ingress class and issuer.

4. Install:

   ```sh
   helm install pixelaudit oci://ghcr.io/pixel-audit/charts/pixelaudit --version 0.1.0 \
     --namespace pixelaudit --atomic --values my-values.yaml
   ```

   `--atomic` rolls the release back if the boot Job fails — a migration that did not apply, a malformed `CONNECTION_*` set — so a bad upgrade never leaves half a release running.

The chart's notes print the URLs. The OpenAPI document is at `https://<api.hostname>/openapi/admin.json`.

## Choosing the image version

The images are `ghcr.io/pixel-audit/pixel-audit-app-api` and `ghcr.io/pixel-audit/pixel-audit-app-admin` (`pixel-audit/pixel-audit-app` is the GitHub organisation and repository the code lives under; a fork publishes under its own, set `image.repository`). CI tags them `X.Y.Z` on a `vX.Y.Z` release and moves `latest` on every push to `main`. Two ways to pick one:

| Mode | Values | Behaviour |
|---|---|---|
| **A release** (default) | `image.tag` empty — or any released `X.Y.Z` | Runs the chart's `appVersion`, the release the chart came from; pulled once (`IfNotPresent`). Upgrade by installing a newer chart version. |
| **Track `main`** | `image.trackLatest: true` | Runs the `latest` tag with `pullPolicy: Always`, so every pod start fetches the current one. |

Picking up a newer `latest`:

```sh
helm upgrade pixelaudit oci://ghcr.io/pixel-audit/charts/pixelaudit \
  --namespace pixelaudit --reuse-values --atomic                  # re-runs the boot Job: migrations first
kubectl -n pixelaudit rollout restart deployment -l app.kubernetes.io/instance=pixelaudit
```

`image.trackLatest` overrides `image.tag` and `image.pullPolicy` in one switch; the boot Job and both Deployments always run the same tag. [`examples/values-track-latest.yaml`](examples/values-track-latest.yaml) is the minimal example in this mode.

## Connections from the environment

Connections (a Meta pixel, a BigQuery project, a Postgres or ClickHouse database) can be added in the panel, or defined by `CONNECTION_*` variables that the boot Job maps onto connection rows on every install and upgrade:

```
CONNECTION_<id>_TYPE = meta-api | bigquery | postgres | clickhouse
CONNECTION_<id>_<PARAM> = ...
```

`<id>` is the connection's code — lowercase letters and digits — and `<PARAM>` one of the type's credentials: `ACCESS_TOKEN`, `PIXEL_ID`, `API_VERSION` for `meta-api`; `CREDENTIALS_JSON` (the service account's key file, as JSON or base64 of it), `PROJECT_ID`, `LOCATION` for `bigquery`; `DATABASE_URL` for `postgres`; `URL`, `DATABASE`, `USERNAME`, `PASSWORD` for `clickhouse`. Put them in a Secret and hand it to the API through `api.extraEnvFrom`:

```sh
kubectl -n pixelaudit create secret generic pixelaudit-connections \
  --from-literal=CONNECTION_fb_TYPE=meta-api \
  --from-literal=CONNECTION_fb_PIXEL_ID=123456789012345 \
  --from-literal=CONNECTION_fb_ACCESS_TOKEN=EAA... \
  --from-literal=CONNECTION_bq_TYPE=bigquery \
  --from-literal=CONNECTION_bq_PROJECT_ID=my-project \
  --from-file=CONNECTION_bq_CREDENTIALS_JSON=service-account.json
```

```yaml
api:
  extraEnvFrom:
    - secretRef:
        name: pixelaudit-connections
```

A connection defined this way is marked *managed by the environment* in the panel: its type and credentials are read-only there, its name and description editable. An existing connection with the same code is updated, a new one created with its name set to its code. After changing the Secret, `helm upgrade` re-runs the boot Job so the rows follow; the API pods also restart, since the Secret's values are their environment.

## Upgrading

```sh
helm upgrade pixelaudit oci://ghcr.io/pixel-audit/charts/pixelaudit --version <new> \
  --namespace pixelaudit --atomic --reuse-values
```

The boot Job runs as a pre-upgrade hook: the new release's migrations are applied before the new pods roll out, and a failure rolls the release back without touching the running pods.

## Backups

The database is the only state. Back it up together with `SECRET_KEY`: the connection credentials in it are encrypted with that key, and a restore without it loses every credential (the connections themselves stay, with their credentials to be entered again).

## Uninstall

```sh
helm uninstall pixelaudit --namespace pixelaudit
```

Secrets you created (`pixelaudit-keys`, `pixelaudit-connections`) and the in-chart PostgreSQL's volume claim stay; delete them yourself.

## Try it on kind or minikube

[`examples/values-all-in-one.yaml`](examples/values-all-in-one.yaml) runs everything in the cluster: the Bitnami PostgreSQL subchart, plain http, inline placeholder keys. With an nginx ingress controller listening on the host's port 80:

```sh
git clone https://github.com/pixel-audit/pixel-audit-app && cd pixel-audit-app
helm dependency build deploy
helm install pixelaudit deploy --namespace pixelaudit --create-namespace --atomic \
  --values deploy/examples/values-all-in-one.yaml
```

Then open <http://pixelaudit.127.0.0.1.nip.io>. On a first install with the subchart the boot Job runs *after* the resources are created (there is no database before), waiting for Postgres; the API pods restart until it is through.

## Values

| Key | Default | Description |
|---|---|---|
| `image.registry` | `ghcr.io` | The registry. |
| `image.repository` | `pixel-audit/pixel-audit-app` | Images are `<registry>/<repository>-api` and `-admin`. |
| `image.tag` | `""` | The image tag; empty: the chart's `appVersion`. |
| `image.pullPolicy` | `IfNotPresent` | |
| `image.trackLatest` | `false` | Run the `latest` tag with `pullPolicy: Always` (overrides the two above). |
| `image.pullSecrets` | `[]` | Image pull Secret names, for a private registry. |
| `api.replicaCount` | `1` | |
| `api.hostname` | — | **Required.** The API's public hostname (`HOSTNAME`, the Ingress host). |
| `api.port` | `4000` | The container port (`PORT`). |
| `api.poolSize` | `10` | `DATABASE_POOL_SIZE`. |
| `api.corsOrigins` | `[]` | Extra browser origins allowed to call the API; the panel's is always allowed. |
| `api.extraEnv` | `[]` | Extra environment variables for the API pods and the boot Job. |
| `api.extraEnvFrom` | `[]` | `envFrom` entries (a Secret of `CONNECTION_*` variables). |
| `api.resources` | requests 128Mi/50m, limits 512Mi/1 | |
| `api.boot.activeDeadlineSeconds` | `600` | How long the boot Job may take. |
| `api.boot.resources` | as `api.resources` | |
| `admin.replicaCount` | `1` | |
| `admin.hostname` | — | **Required.** The panel's public hostname. |
| `admin.port` | `8080` | The nginx port (`PORT`). |
| `admin.resources` | requests 16Mi/5m, limits 64Mi/100m | |
| `database.url` | `""` | `DATABASE_URL`, rendered into a chart-managed Secret. `?sslmode=require` or `verify-full` for TLS. |
| `database.existingSecret` | `""` | A Secret holding the URL instead. |
| `database.existingSecretKey` | `DATABASE_URL` | Its key. |
| `secrets.secretKeyBase` | `""` | `SECRET_KEY_BASE`, inline. |
| `secrets.secretKey` | `""` | `SECRET_KEY`, inline: 64 hex characters. |
| `secrets.existingSecret` | `""` | A Secret with the keys `SECRET_KEY_BASE` and `SECRET_KEY` instead. |
| `ingress.enabled` | `true` | |
| `ingress.className` | `""` | The IngressClass; empty: the cluster's default. |
| `ingress.annotations` | `{}` | e.g. `cert-manager.io/cluster-issuer`. |
| `ingress.tls` | `true` | Serve both hostnames over TLS; the panel then calls the API over https. |
| `ingress.tlsSecretName` | `""` | The TLS Secret; empty: `<release>-tls`. |
| `postgresql.enabled` | `false` | The Bitnami PostgreSQL subchart. |
| `postgresql.auth.username` | `pixelaudit` | |
| `postgresql.auth.password` | `""` | URL-safe characters only. |
| `postgresql.auth.database` | `pixelaudit` | |
| `postgresql.waitImage` | `busybox:1.37` | What the boot Job waits for the subchart's Postgres with. |
| `serviceAccount.create` | `true` | |
| `serviceAccount.name` | `""` | Empty: the release's full name. |
| `serviceAccount.annotations` | `{}` | |
| `podSecurityContext` | non-root, RuntimeDefault seccomp | |
| `securityContext` | no escalation, all capabilities dropped, read-only root | |
| `nodeSelector`, `tolerations`, `affinity` | `{}`, `[]`, `{}` | |

`values.schema.json` checks the values at install time: the hostnames are required, `secrets.secretKey` must be 64 hex characters, `database.url` a `postgres://` URL.
