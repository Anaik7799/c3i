defmodule Indrajaal.Security.EncryptedBinary do
  @moduledoc """
  Basic encrypted binary type for Ash.
  """
  use Ash.Type

  @impl true
  def storage_type(_), do: :binary

  @impl true
  def cast_input(nil, _), do: {:ok, nil}
  def cast_input(value, _) when is_binary(value), do: {:ok, value}
  def cast_input(_, _), do: :error

  @impl true
  def cast_stored(nil, _), do: {:ok, nil}
  def cast_stored(value, _) when is_binary(value), do: {:ok, value}
  def cast_stored(_, _), do: :error

  @impl true
  def dump_to_native(nil, _), do: {:ok, nil}
  def dump_to_native(value, _) when is_binary(value), do: {:ok, value}
  def dump_to_native(_, _), do: :error
end
