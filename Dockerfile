# PixelAudit — the API and the admin panel in one image.
#
# Build (from the repository root):   docker build -t pixelaudit .
#
# Three stages: the panel is built with Node (src/admin, `vite build`), the
# API is compiled into a Phoenix release with Elixir (src/api) with the
# panel's build copied into its priv/static — Phoenix serves it from the
# same origin as the API — and the release lands in a slim Debian.
#
# The container's command picks its role (src/api/docker/entrypoint.sh):
#
#   docker run --rm --env-file .env -p 4000:4000 pixelaudit            # web (default)
#   docker run --rm --env-file .env pixelaudit boot                    # create + migrate + CONNECTION_* sync
#   docker run --rm --env-file .env pixelaudit migrate                 # Ecto migrations only
#
# Any other command runs as given, e.g. `bin/pixelaudit_api remote`.
#
# The release listens on $PORT (4000 by default) and needs, in production,
# DATABASE_URL, WEB_SECRET_KEY_BASE (the web layer's signing secret),
# CREDENTIALS_ENCRYPTION_KEY (64 hex characters — the key the connection
# credentials are encrypted with at rest) and HOSTNAME; SOURCE_URL is where
# the panel's foot says the source is offered — see src/api/config/runtime.exs.
# The `boot` role reads the CONNECTION_* variables on top.
#
# Node, Elixir and Erlang follow .tool-versions in the repo root. hexpm
# publishes no 1.20.0 image for Erlang 29.0.5, so the closest published
# patch is used — bump OTP_VERSION when one appears (https://bob.hex.pm/docker).
# The runner deliberately uses the same Debian snapshot as the builder so the
# shared libraries the release links against (OpenSSL, ncurses) match.
#
# src/api/rel/vm.args.eex caps the VM's port table (+Q): container runtimes
# hand the process an open-files limit of about a billion, and left to
# itself the VM sizes the table from it and is OOM-killed at boot.

ARG NODE_VERSION=24.19.0
ARG ELIXIR_VERSION=1.20.0
ARG OTP_VERSION=29.0.2
ARG DEBIAN_VERSION=trixie-20260610-slim

ARG NODE_IMAGE="docker.io/node:${NODE_VERSION}-trixie-slim"
ARG BUILDER_IMAGE="docker.io/hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="docker.io/debian:${DEBIAN_VERSION}"

# ---- The panel -----------------------------------------------------------
FROM ${NODE_IMAGE} AS admin

WORKDIR /admin

# Dependencies first, so a source change does not reinstall them.
COPY src/admin/package.json src/admin/package-lock.json ./
RUN npm ci

COPY src/admin/ ./
# The release this build is — CI's build args; unset in a local build. The
# bundle reads them as VITE_RELEASE_*, and the sidebar's foot shows the commit.
ARG RELEASE_SHA
ARG RELEASE_TIMESTAMP
ENV VITE_RELEASE_SHA=$RELEASE_SHA VITE_RELEASE_TIMESTAMP=$RELEASE_TIMESTAMP
RUN npm run build

# ---- The API, with the panel inside ---------------------------------------
FROM ${BUILDER_IMAGE} AS builder

RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential git \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN mix local.hex --force \
  && mix local.rebar --force

ENV MIX_ENV="prod"

# Dependencies first, so a change in lib/ does not refetch or recompile them.
COPY src/api/mix.exs src/api/mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# Compile-time config goes in before deps.compile: a change there must
# recompile the dependencies that read it.
COPY src/api/config/config.exs src/api/config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY src/api/priv priv
COPY src/api/lib lib
RUN mix compile

# The panel's build becomes the API's static files: the hashed assets,
# index.html (served by PanelController for every panel address),
# favicon.ico and robots.txt. Digested, so Plug.Static can serve the
# precompressed and cache-busted variants.
COPY --from=admin /admin/dist priv/static
RUN mix phx.digest

# runtime.exs is read when the release boots, so it comes after compile —
# editing it does not rebuild the app.
COPY src/api/config/runtime.exs config/

COPY src/api/rel rel
RUN mix release

# ---- The image ------------------------------------------------------------
FROM ${RUNNER_IMAGE} AS final

# The release this image is, for whoever asks the running container.
ARG RELEASE_SHA
ARG RELEASE_TIMESTAMP
ENV RELEASE_SHA=$RELEASE_SHA RELEASE_TIMESTAMP=$RELEASE_TIMESTAMP

RUN apt-get update \
  && apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 locales ca-certificates \
  && rm -rf /var/lib/apt/lists/*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
  && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

ENV MIX_ENV="prod"

# Default only — override PORT at run time; runtime.exs binds the endpoint
# to it. EXPOSE is documentation and stays at the default.
ENV PORT=4000
EXPOSE 4000

COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/pixelaudit_api ./
COPY --chown=nobody:root src/api/docker/entrypoint.sh /app/docker-entrypoint

USER nobody

# The roles map onto the release's bin/ scripts from src/api/rel/overlays:
# server (= `PHX_SERVER=true bin/pixelaudit_api start`), boot and migrate —
# the latter two run the matching PixelAudit.Api.Release function.
ENTRYPOINT ["/app/docker-entrypoint"]
CMD ["web"]
