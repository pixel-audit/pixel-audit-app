# PixelAudit admin panel — static Vite build served by nginx.
#
# Build (from src/admin):  docker build -t pixelaudit-admin .
# Run:                     docker run --rm -p 8080:8080 \
#                            -e API_URL=https://api.example.com \
#                            pixelaudit-admin
#
# One build serves any environment: the API address is not
# baked into the bundle but read at page load from /config.js, which the
# entrypoint script docker/40-runtime-config.sh writes from API_URL
# and SOURCE_URL on every start (an unset variable keeps
# the development default from public/config.js).
#
# PORT is honoured at run time too: nginx itself has no notion of it, so the
# server block is a template (docker/nginx.conf.template) that the image's
# entrypoint renders with envsubst on every start.
#
# Node follows .tool-versions in the repo root.

ARG NODE_VERSION=24.19.0
ARG NGINX_VERSION=1.30.4

FROM docker.io/node:${NODE_VERSION}-trixie-slim AS builder

WORKDIR /app

# Dependencies first, so a source change does not reinstall them.
COPY package.json package-lock.json ./
RUN npm ci

COPY . .
# The release this build is — CI's build args (.github/workflows); unset in
# a local build. The bundle reads them as VITE_RELEASE_*.
ARG RELEASE_SHA
ARG RELEASE_TIMESTAMP
ENV VITE_RELEASE_SHA=$RELEASE_SHA VITE_RELEASE_TIMESTAMP=$RELEASE_TIMESTAMP
RUN npm run build

# Unprivileged variant: nginx runs as uid 101 and can still bind any
# unprivileged port, which is all a $PORT above 1024 needs.
FROM docker.io/nginxinc/nginx-unprivileged:${NGINX_VERSION}-alpine AS final

# The release this image is, for whoever asks the running container.
ARG RELEASE_SHA
ARG RELEASE_TIMESTAMP
ENV RELEASE_SHA=$RELEASE_SHA RELEASE_TIMESTAMP=$RELEASE_TIMESTAMP

# The stock server block would also listen — on 8080 — and shadow ours.
RUN rm /etc/nginx/conf.d/default.conf

# Only PORT is substituted: nginx's own $uri and friends in the template are
# left alone.
ENV NGINX_ENVSUBST_FILTER=^PORT$
COPY docker/nginx.conf.template /etc/nginx/templates/default.conf.template

COPY --from=builder /app/dist /usr/share/nginx/html

# Runtime configuration: the pristine defaults are kept outside the web root
# and /config.js is regenerated from them by the entrypoint script, so that
# file — and only that file — must be writable by the nginx user.
COPY --from=builder /app/dist/config.js /etc/pixelaudit-admin/config.defaults.js
COPY --from=builder --chown=nginx:nginx /app/dist/config.js /usr/share/nginx/html/config.js
COPY docker/40-runtime-config.sh /docker-entrypoint.d/40-runtime-config.sh

# Default only — override PORT at run time. EXPOSE is documentation and
# stays at the default.
ENV PORT=8080
EXPOSE 8080
