#!/bin/sh
# Entrypoint of the API image. The first argument names the role the
# container plays; anything else is run as-is, so `bin/pixelaudit_api remote`
# and friends still work.
#
#   web      the Phoenix server (the default)                      -> bin/server
#   boot     create + migrate + map CONNECTION_* onto connections   -> bin/boot
#   migrate  run the pending Ecto migrations only                   -> bin/migrate
set -eu

role="${1:-web}"

case "$role" in
  web)
    exec /app/bin/server
    ;;
  boot | migrate)
    exec "/app/bin/$role"
    ;;
  *)
    exec "$@"
    ;;
esac
