defmodule Indrajaal.Compliance.Helpers do
  @moduledoc """
  Shared helper functions for compliance domain modules.

  Provides common utilities for generating identifiers, formatting data,
  and handling compliance-specific transformations across multiple resources.
  """

  @doc """
  Generate a numbered identifier with date and random suffix.

  Generates an identifier in the format: PREFIX-YYYYMMDD-###
  For example: ASS-20_251_229-001, DOC-20_251_229-042, RPT-20_251_229-137

  ## Parameters
    - prefix: String prefix for the identifier (e.g., "ASS", "DOC", "RPT")
    - changeset: Ash.Changeset - the changeset to update
    - attribute: Atom - the attribute name to update on the changeset

  ## Returns
    - Updated changeset with the generated identifier
  """
  @spec generate_numbered_identifier(String.t(), term(), atom()) :: term()
  def generate_numbered_identifier(prefix, changeset, attribute) do
    today = Date.utc_today()
    date_str = today |> Date.to_string() |> String.replace("-", "")

    random_number = :rand.uniform(999)

    random_suffix =
      random_number
      |> Integer.to_string()
      |> String.pad_leading(3, "0")

    identifier = "#{prefix}-#{date_str}-#{random_suffix}"

    Ash.Changeset.force_change_attribute(changeset, attribute, identifier)
  end

  @doc """
  Conditionally apply an attribute value to a changeset.

  Only updates the attribute if the value is not nil.

  ## Parameters
    - changeset: Ash.Changeset - the changeset to potentially update
    - attribute: Atom - the attribute name
    - value: Any - the value to set (only applied if not nil)

  ## Returns
    - Potentially updated changeset
  """
  @spec apply_conditional_attribute(term(), atom(), any()) :: term()
  def apply_conditional_attribute(changeset, attribute, value) do
    if value do
      Ash.Changeset.force_change_attribute(changeset, attribute, value)
    else
      changeset
    end
  end
end
