# The `boot` role in development (`mix boot`, after ecto.create and
# ecto.migrate): maps the CONNECTION_* and VARIABLE_* environment onto
# settings rows. The release does the same through PixelAudit.Api.Release.boot/0.
case PixelAudit.Api.Settings.EnvSync.run() do
  {:ok, results} ->
    IO.puts(
      "From the environment: #{length(results.connections)} connections, " <>
        "#{length(results.variables)} variables"
    )

  {:error, problems} ->
    IO.puts(
      :stderr,
      "The CONNECTION_*/VARIABLE_* environment is invalid:\n" <> Enum.join(problems, "\n")
    )

    System.halt(1)
end
