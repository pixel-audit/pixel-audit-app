defmodule PixelAudit.ApiWeb.ChangesetJSON do
  @doc """
  Renders changeset errors as `{"errors": {"field": ["message"]}}`. A key
  may be dotted (`credentials.access_token`, `settings.dataset`,
  `parameters.sql`) when the field sits inside a declared map.
  """
  def error(%{changeset: changeset}) do
    %{errors: Ecto.Changeset.traverse_errors(changeset, &translate_error/1)}
  end

  # "should be at most %{count} character(s)" and friends.
  defp translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end
end
