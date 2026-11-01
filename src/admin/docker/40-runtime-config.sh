#!/bin/sh
# Runs from the nginx image's entrypoint (/docker-entrypoint.d) before nginx
# starts. Writes the panel's runtime configuration, /config.js, from the
# container's environment:
#
#   API_URL     -> apiUrl      base URL of the PixelAudit API
#   SOURCE_URL  -> sourceUrl   where this program's source is offered (AGPL §13)
#
# The file is rebuilt on every start from the pristine copy of the build's
# public/config.js (its development defaults) plus one override line per
# variable that is set, so an unset variable keeps the default and a restart
# never accumulates stale overrides.
set -eu

defaults=/etc/pixelaudit-admin/config.defaults.js
target=/usr/share/nginx/html/config.js

# Value as a JS double-quoted string literal.
js_string() {
  printf '"%s"' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')"
}

override() {
  key=$1
  value=$2

  if [ -n "$value" ]; then
    printf 'window.PIXELAUDIT_CONFIG.%s = %s;\n' "$key" "$(js_string "$value")" >> "$target"
  fi
}

# A redirect rather than cp: busybox cp wants to recreate the file, which the
# root-owned web root forbids; the file itself is ours and overwritable.
cat "$defaults" > "$target"

printf '\n// Overrides from the container environment (docker/40-runtime-config.sh).\n' >> "$target"
override apiUrl "${API_URL:-}"
override sourceUrl "${SOURCE_URL:-}"
