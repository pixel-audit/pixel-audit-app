# The `boot` role in development (`mix boot`, after ecto.create and
# ecto.migrate): maps the CONNECTION_* environment onto connection rows.
# The release does the same through PixelAudit.Api.Release.boot/0.
case PixelAudit.Api.Connections.EnvSync.run() do
  {:ok, results} ->
    IO.puts("Connections from the environment: #{length(results)}")

  {:error, problems} ->
    IO.puts(:stderr, "The CONNECTION_* environment is invalid:\n" <> Enum.join(problems, "\n"))
    System.halt(1)
end
