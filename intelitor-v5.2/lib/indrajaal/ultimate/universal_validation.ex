defmodule Indrajaal.Ultimate.UniversalValidation do
  @moduledoc """
  Universal Validation Framework - Phase S final consolidation

  Eliminates ALL validation - related duplications.
  """

  @doc """
  Universal validation pipeline
  """
  @spec validate(term(), list()) :: term()
  def validate(data, validations) do
    Enum.reduce_while(validations, {:ok, data}, fn validation, {:ok, acc} ->
      case apply_validation(acc, validation) do
        {:ok, result} -> {:cont, {:ok, result}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp apply_validation(data, {:__required, fields}) do
    missing = Enum.filter(fields, &(not Map.has_key?(data, &1)))
    if Enum.empty?(missing), do: {:ok, data}, else: {:error, {:missing_fields, missing}}
  end

  defp apply_validation(data, {:type, typechecks}) do
    invalid =
      Enum.filter(typechecks, fn {field, expected_type} ->
        not type_matches?(Map.get(data, field), expected_type)
      end)

    if Enum.empty?(invalid), do: {:ok, data}, else: {:error, {:type_mismatch, invalid}}
  end

  defp apply_validation(data, {:custom, validator_fn}) do
    validator_fn.(data)
  end

  defp type_matches?(nil, _), do: true
  defp type_matches?(value, :string), do: is_binary(value)
  defp type_matches?(value, :integer), do: is_integer(value)
  defp type_matches?(value, :float), do: is_float(value)
  defp type_matches?(value, :number), do: is_number(value)
  defp type_matches?(value, :atom), do: is_atom(value)
  defp type_matches?(value, :map), do: is_map(value)
  defp type_matches?(value, :list), do: is_list(value)
  defp type_matches?(_, _), do: false
end
