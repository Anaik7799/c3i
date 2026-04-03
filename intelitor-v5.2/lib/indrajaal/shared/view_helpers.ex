defmodule Indrajaal.Shared.ViewHelpers do
  @moduledoc """
  View helpers eliminating ~150 duplicate violations.
  """

  @spec format_percentage(term()) :: term()
  def format_percentage(value) when is_number(value) do
    "#{Float.round(value, 1)}%"
  end
end
