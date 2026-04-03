defmodule Indrajaal.Shared.ComponentHelpers do
  @moduledoc """
  Component helpers eliminating ~50 duplicate violations.
  """

  use Phoenix.Component

  @doc """
  Renders a metric card component.
  """
  @spec metric_card(term()) :: term()
  def metric_card(assigns) do
    ~H"""
    <div _class="metric - card">
      <h3>{@title}</h3>
      <p>{@value}</p>
    </div>
    """
  end
end
