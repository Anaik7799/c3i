defmodule Indrajaal.Ecto.JSONText do
  @moduledoc """
  ## Custom Ecto Type: JSON over Text
  Maps Elixir Maps/Lists to JSON-encoded Strings for SQLite storage.

  **Compliance**: SC-DATA-001 (Data Integrity).
  """
  use Ecto.Type

  def type, do: :string

  def cast(data) when is_map(data) or is_list(data), do: {:ok, data}

  def cast(data) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, decoded} -> {:ok, decoded}
      _ -> :error
    end
  end

  def cast(_), do: :error

  def load(data) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, decoded} -> {:ok, decoded}
      _ -> :error
    end
  end

  def load(_), do: :error

  def dump(data) when is_map(data) or is_list(data) do
    {:ok, Jason.encode!(data)}
  end

  def dump(_), do: :error
end
