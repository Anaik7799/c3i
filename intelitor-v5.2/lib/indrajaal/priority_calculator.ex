defmodule Indrajaal.PriorityCalculator do
  @moduledoc """
  Shared priority calculation logic for alarms.
  Eliminates duplication between AlarmEvent and RealTimeProcessor.
  """

  @spec calculate_priority(atom() | binary()) :: atom()
  def calculate_priority(type) when is_atom(type) do
    calculate_priority(Atom.to_string(type))
  end

  @spec calculate_priority(term()) :: term()
  def calculate_priority(type) when is_binary(type) do
    cond do
      type in ["panic", "duress", "emergency"] -> :critical
      type in ["intrusion", "fire", "medical"] -> :high
      type in ["motion", "door", "window"] -> :medium
      type in ["tamper", "fault", "trouble"] -> :low
      true -> :normal
    end
  end

  @spec calculate_priority(term()) :: term()
  # def calculate_priority(_), do: :normal
  # Claude Agent: EP-076 - Unreachable function clause commented out
end

# AGENT GA FIX: Added missing module end
