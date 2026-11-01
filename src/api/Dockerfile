# PixelAudit API — Phoenix release in a container.
#
# Build (from src/api):   docker build -t pixelaudit-api .
#
# The container's command picks its role (docker/entrypoint.sh):
#
#   docker run --rm --env-file .env -p 4000:4000 pixelaudit-api            # web (default)
#   docker run --rm --env-file .env pixelaudit-api boot                    # create + migrate + CONNECTION_* sync
#   docker run --rm --env-file .env pixelaudit-api migrate                 # Ecto migrations only
#
# Any other command runs as given, e.g. `bin/pixelaudit_api remote`.
#
# The release listens on $PORT (config/runtime.exs reads it; 4000 below is
# only the default) and needs, in production, DATABASE_URL,
# WEB_SECRET_KEY_BASE (Phoenix's signing secret),
# CREDENTIALS_ENCRYPTION_KEY (64 hex characters — the key the connection
# credentials are encrypted with at rest) and HOSTNAME; CORS_ORIGINS names
# the panel's origin — see config/runtime.exs. The `boot` role reads the
# CONNECTION_* variables on top.
#
# Elixir/Erlang follow .tool-versions in the repo root. hexpm publishes no
# 1.20.0 image for Erlang 29.0.5, so the closest published patch is used —
# bump OTP_VERSION when one appears (https://bob.hex.pm/docker).
# The runner deliberately uses the same Debian snapshot as the builder so the
# shared libraries the release links against (OpenSSL, ncurses) match.
#
# rel/vm.args.eex caps the VM's port table (+Q): container runtimes hand the
# process an open-files limit of about a billion, and left to itself the VM
# sizes the table from it and is OOM-killed at boot.

ARG ELIXIR_VERSION=1.20.0
ARG OTP_VERSION=29.0.2
ARG DEBIAN_VERSION=trixie-20260610-slim

ARG BUILDER_IMAGE="docker.io/hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="docker.io/debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential git \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN mix local.hex --force \
  && mix local.rebar --force

ENV MIX_ENV="prod"

# Dependencies first, so a change in lib/ does not refetch or recompile them.
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# Compile-time config goes in before deps.compile: a change there must
# recompile the dependencies that read it.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv
COPY lib lib
RUN mix compile

# runtime.exs is read when the release boots, so it comes after compile —
# editing it does not rebuild the app.
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

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
COPY --chown=nobody:root docker/entrypoint.sh /app/docker-entrypoint

USER nobody

# The roles map onto the release's bin/ scripts from rel/overlays:
# server (= `PHX_SERVER=true bin/pixelaudit_api start`), boot and migrate —
# the latter two run the matching PixelAudit.Api.Release function.
ENTRYPOINT ["/app/docker-entrypoint"]
CMD ["web"]
