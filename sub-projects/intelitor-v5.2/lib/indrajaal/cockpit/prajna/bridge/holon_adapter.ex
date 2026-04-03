defmodule Indrajaal.Cockpit.Prajna.Bridge.HolonAdapter do
  @moduledoc """
  ## Holon Bridge Adapter

  Transforms raw Elixir state (SmartMetrics, Alarms) into the standardized
  F# Holon Tree structure for rendering.

  **Intelligence Injection:**
  - Injects AI Predictions into the `Prediction` field.
  - Calculates `Salience` based on alarm severity and user focus.
  """

  alias Indrajaal.Cockpit.Prajna.SmartMetrics

  @doc """
  Builds the full Holon Tree from current system state.
  """
  def build_snapshot do
    # 1. Root Holon (System)
    %{
      id: Ecto.UUID.generate(),
      name: "Indrajaal System",
      type: :system,
      health: SmartMetrics.health_summary().health_score / 100.0,
      stress: calculate_system_stress(),
      # AI Injection
      prediction: predict_health_trend(),
      salience: 1.0,
      children: build_clusters()
    }
  end

  defp build_clusters do
    # Mock: In reality, iterate over Domain.zones
    [
      %{
        id: Ecto.UUID.generate(),
        name: "Cluster Alpha",
        type: :cluster,
        health: 0.95,
        stress: 0.1,
        prediction: nil,
        salience: 0.8,
        # Recurse here
        children: []
      }
    ]
  end

  defp calculate_system_stress do
    # Mock: Aggregate CPU/RAM pressure
    0.2
  end

  defp predict_health_trend do
    # Mock: Call AiCopilot for trend prediction
    # Returns float (e.g., 0.9 = expected to degrade slightly)
    0.98
  end
end
