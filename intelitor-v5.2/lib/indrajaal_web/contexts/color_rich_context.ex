defmodule IndrajaalWeb.Contexts.ColorRichContext do
  @moduledoc """
  Context for the Color Rich Mechanism (SC-HMI-010).

  WHAT: Calculates vibrancy factors and chromatic shifts based on metabolic telemetry.
  WHY: Provides dynamic UI engagement that reflects system "life".
  """

  @vibrancy_base 0.8
  @max_vibrancy 1.2

  @doc """
  Calculate vibrancy factor from metabolic rate (0.0 - 1.0).
  """
  def calculate_vibrancy(metabolic_rate) do
    factor = metabolic_rate * 0.5 + @vibrancy_base
    Float.round(min(factor, @max_vibrancy), 2)
  end

  @doc """
  Get CSS variables for current metabolic state.
  """
  def get_chromatic_vars(metabolic_rate) do
    vibrancy = calculate_vibrancy(metabolic_rate)

    %{
      "--vibrancy-factor": vibrancy,
      "--metabolic-pulse": "#{max(0.5, 2.0 - metabolic_rate)}s",
      "--health-hue": calculate_hue(metabolic_rate)
    }
  end

  defp calculate_hue(rate) do
    # Transition from healthy Forest Green (140) to metabolic Electric Blue (200)
    round(140 + rate * 60)
  end
end
