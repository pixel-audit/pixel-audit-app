import Config

# The API sits behind the deployment's ingress, which terminates TLS; the
# redirect is left to it (no force_ssl), so the health check and in-cluster
# calls work over plain HTTP.

# Do not print debug messages in production
config :logger, level: :info

# Runtime production configuration, including reading
# of environment variables, is done on config/runtime.exs.
