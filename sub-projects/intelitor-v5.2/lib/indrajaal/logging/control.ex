defmodule Indrajaal.Logging.Control do
  @moduledoc """
  Centralized control for logging verbosity and sampling.
  Prevents high-frequency subsystems (like Cortex/OODA) from flooding telemetry.
  """

  @type level :: :debug | :info | :warning | :error | :critical
  @type subsystem :: atom()

  @default_sampling_rate 1
  @default_level :info

  @doc """
  Determines if a log message should be emitted based on subsystem configuration.
  Always returns true for :error and :critical levels.
  Applies probabilistic sampling for lower levels.
  """
  @spec should_log?(subsystem, level) :: boolean()
  def should_log?(_subsystem, level) when level in [:error, :critical], do: true

  def should_log?(subsystem, level) do
    config = get_config()
    sub_config = get_in(config, [:subsystems, subsystem]) || %{}

    configured_level = Map.get(sub_config, :level, config[:global_level] || @default_level)
    sampling_rate = Map.get(sub_config, :sampling_rate, @default_sampling_rate)

    if level_allowed?(level, configured_level) do
      apply_sampling(sampling_rate)
    else
      false
    end
  end

  @doc """
  Updates logging configuration for a subsystem at runtime.
  Example: Indrajaal.Logging.Control.update(:cortex_ooda, %{level: :debug, sampling_rate: 1})
  """
  @spec update(subsystem, map()) :: :ok
  def update(subsystem, config) do
    current_config = get_config()
    current_subsystems = current_config[:subsystems] || %{}
    new_subsystems = Map.put(current_subsystems, subsystem, config)
    new_config = Keyword.put(current_config, :subsystems, new_subsystems)
    Application.put_env(:indrajaal, :logging_control, new_config)
  end

  defp get_config do
    Application.get_env(:indrajaal, :logging_control, [])
  end

  defp level_allowed?(level, threshold) do
    Logger.compare_levels(level, threshold) != :lt
  end

  defp apply_sampling(1), do: true

  defp apply_sampling(rate) when is_integer(rate) and rate > 1 do
    :rand.uniform(rate) == 1
  end

  defp apply_sampling(_), do: true
end
