defmodule Indrajaal.Substrate.L2.AntiOscillationFilter do
  @moduledoc """
  L2 Anti-Oscillation Filter — deadband + rate-limiting for control signals.

  Prevents rapid toggling of control outputs by applying:
  1. Deadband: ignore changes smaller than a threshold
  2. Rate limit: max N changes per time window
  3. Hysteresis: different thresholds for rising vs falling

  ## STAMP Constraints
  - SC-S2-003: Anti-oscillation filtering
  - SC-S2-004: Rate limiting for control signals
  """

  @type filter_config :: %{
          deadband: float(),
          rate_limit: pos_integer(),
          rate_window_ms: pos_integer(),
          hysteresis: float()
        }

  @type filter_state :: %{
          last_output: float(),
          change_times: [integer()],
          direction: :rising | :falling | :stable
        }

  @default_config %{
    deadband: 0.05,
    rate_limit: 5,
    rate_window_ms: 10_000,
    hysteresis: 0.02
  }

  @spec new_state() :: filter_state()
  def new_state do
    %{last_output: 0.0, change_times: [], direction: :stable}
  end

  @spec default_config() :: filter_config()
  def default_config, do: @default_config

  @spec filter(float(), filter_state(), filter_config()) :: {float(), filter_state()}
  def filter(input, state, config \\ @default_config) do
    now = System.monotonic_time(:millisecond)
    recent_changes = Enum.filter(state.change_times, &(&1 > now - config.rate_window_ms))

    cond do
      length(recent_changes) >= config.rate_limit ->
        {state.last_output, %{state | change_times: recent_changes}}

      within_deadband?(input, state.last_output, config, state.direction) ->
        {state.last_output, %{state | change_times: recent_changes}}

      true ->
        direction = if input > state.last_output, do: :rising, else: :falling

        {input,
         %{
           last_output: input,
           change_times: [now | recent_changes],
           direction: direction
         }}
    end
  end

  @spec within_deadband?(float(), float(), filter_config(), atom()) :: boolean()
  defp within_deadband?(input, last, config, direction) do
    delta = abs(input - last)
    threshold = config.deadband + hysteresis_offset(input, last, config.hysteresis, direction)
    delta < threshold
  end

  defp hysteresis_offset(input, last, hysteresis, direction) do
    case direction do
      :rising when input < last -> hysteresis
      :falling when input > last -> hysteresis
      _ -> 0.0
    end
  end
end
