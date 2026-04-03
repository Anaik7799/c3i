defmodule Indrajaal.Substrate.L3.VarietyAmplifier do
  @moduledoc """
  L3 Variety Amplifier — Ashby's Law of Requisite Variety implementation.

  Ensures the system's response repertoire matches or exceeds the variety
  of disturbances it faces. When environmental variety increases, the
  amplifier expands the system's behavioral repertoire by activating
  dormant capabilities or generating novel response strategies.

  ## Ashby's Law
  Only variety can absorb variety. If D = disturbance variety and
  R = response variety, then effective regulation requires R >= D.

  ## STAMP Constraints
  - SC-S3-001: S3 internal control
  - SC-S3-002: Requisite variety maintenance
  """

  @type variety_state :: %{
          disturbance_variety: non_neg_integer(),
          response_variety: non_neg_integer(),
          gap: integer(),
          amplification_active: boolean(),
          dormant_capabilities: [atom()]
        }

  @dormant_capabilities [
    :adaptive_routing,
    :load_shedding,
    :graceful_degradation,
    :emergency_mode,
    :federation_assist,
    :cache_warmup,
    :predictive_scaling,
    :chaos_resistance
  ]

  @spec assess(non_neg_integer(), non_neg_integer()) :: variety_state()
  def assess(disturbance_count, active_response_count) do
    gap = disturbance_count - active_response_count
    needs_amplification = gap > 0

    dormant =
      if needs_amplification do
        Enum.take(@dormant_capabilities, min(gap, length(@dormant_capabilities)))
      else
        []
      end

    %{
      disturbance_variety: disturbance_count,
      response_variety: active_response_count + length(dormant),
      gap: gap,
      amplification_active: needs_amplification,
      dormant_capabilities: dormant
    }
  end

  @spec requisite_variety_ratio(variety_state()) :: float()
  def requisite_variety_ratio(state) do
    if state.disturbance_variety > 0 do
      Float.round(state.response_variety / state.disturbance_variety, 3)
    else
      1.0
    end
  end

  @spec sufficient?(variety_state()) :: boolean()
  def sufficient?(state) do
    requisite_variety_ratio(state) >= 1.0
  end

  @spec available_capabilities() :: [atom()]
  def available_capabilities, do: @dormant_capabilities

  @spec recommend_activation(variety_state()) :: [atom()]
  def recommend_activation(state) do
    if state.gap > 0 do
      state.dormant_capabilities
    else
      []
    end
  end
end
