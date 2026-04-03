defmodule Indrajaal.Shared.UnifiedHelperPatterns do
  @moduledoc """
  Unified shared helper patterns - Phase N consolidation
  Eliminates duplications across shared utilities
  """

  @doc """
  Common changeset error formatting
  """
  @spec format_changeset_errors(Ecto.Changeset.t()) :: term()
  def format_changeset_errors(changeset) do
    # Placeholder implementation for changeset error formatting
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  # def format_datetime(nil), do: ""
  # Claude Agent: EP-076 - Unreachable function clause commented
  @spec format_datetime(term()) :: term()
  def format_datetime(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S %Z")
  end

  @doc """
  Common validation helpers
  """
  @spec validate_required_fields(term(), term()) :: term()
  def validate_required_fields(params, required_fields) do
    missing_fields = required_fields -- Map.keys(params)

    case missing_fields do
      [] -> {:ok, params}
      fields -> {:error, {:missing_fields, fields}}
    end
  end

  @doc """
  Common sanitization helpers
  """
  @spec sanitize_params(term()) :: term()
  def sanitize_params(params) do
    params
    |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
    |> Map.new()
  end
end
