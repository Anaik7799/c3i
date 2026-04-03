defmodule Indrajaal.Substrate.L3.ThresholdSentinel do
  @moduledoc """
  ## Design Intent
  L3 substrate threshold sentinel — pure functional module that detects
  threshold crossings in scalar metric streams.

  Biological metaphor: sensory neuron threshold gating — a neuron fires only
  when its membrane potential crosses a fixed threshold. Hysteresis (upper +
  lower band) prevents rapid re-firing ("chatter") around the crossing point.

  Algorithm:
    - Each threshold has: high (fire level), low (reset level), and direction.
    - `direction: :above` — fires when value ≥ high; resets when value ≤ low.
    - `direction: :below` — fires when value ≤ low; resets when value ≥ high.
    - State per threshold: :nominal | :triggered.
    - `check/2` evaluates a value map against all registered thresholds,
      returning `{new_state, [crossing_event]}` where events include the
      crossing direction, metric name, and triggering value.

  ## STAMP Constraints
  - SC-S3-001: Cybernetic VSM S3 control — ENFORCED
  - SC-ALARM-001: Alarm processing — threshold detection feeds alarm engine — REFERENCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type direction :: :above | :below

  @type threshold :: %{
          high: float(),
          low: float(),
          direction: direction(),
          state: :nominal | :triggered
        }

  @type crossing_event :: %{
          metric: String.t(),
          direction: direction(),
          value: float(),
          crossed: :triggered | :reset
        }

  @type t :: %__MODULE__{
          thresholds: %{String.t() => threshold()},
          event_count: non_neg_integer()
        }

  defstruct thresholds: %{},
            event_count: 0

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Create a new ThresholdSentinel.

  Options:
    - `:thresholds` — `%{name => %{high: float, low: float, direction: :above|:below}}`
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    raw = Keyword.get(opts, :thresholds, %{})

    cond do
      not is_map(raw) ->
        {:error, "thresholds must be a map"}

      not all_thresholds_valid?(raw) ->
        {:error, "each threshold needs high >= low and direction :above | :below"}

      true ->
        thresholds =
          Map.new(raw, fn {k, v} ->
            {k, Map.put_new(v, :state, :nominal)}
          end)

        {:ok, %__MODULE__{thresholds: thresholds}}
    end
  end

  @doc """
  Register a named threshold.

  `direction` controls which crossing fires the event:
  - `:above` — fires when `value >= high`, resets when `value <= low`.
  - `:below` — fires when `value <= low`, resets when `value >= high`.
  """
  @spec register(t(), String.t(), float(), float(), direction()) ::
          {:ok, t()} | {:error, String.t()}
  def register(%__MODULE__{} = state, name, high, low, direction)
      when is_binary(name) and is_atom(direction) do
    cond do
      high < low ->
        {:error, "high must be >= low"}

      direction not in [:above, :below] ->
        {:error, "direction must be :above or :below"}

      true ->
        thr = %{high: high, low: low, direction: direction, state: :nominal}
        {:ok, %{state | thresholds: Map.put(state.thresholds, name, thr)}}
    end
  end

  def register(%__MODULE__{}, _name, _high, _low, _direction),
    do: {:error, "name must be a string"}

  @doc """
  Check a map of metric values against all registered thresholds.

  Returns `{updated_state, [crossing_event]}`.
  """
  @spec check(t(), %{String.t() => float()}) :: {t(), [crossing_event()]}
  def check(%__MODULE__{} = state, values) when is_map(values) do
    {new_thresholds, events} =
      Enum.reduce(state.thresholds, {%{}, []}, fn {name, thr}, {thr_acc, ev_acc} ->
        value = Map.get(values, name)

        if value == nil do
          {Map.put(thr_acc, name, thr), ev_acc}
        else
          {new_thr, maybe_event} = evaluate_threshold(name, thr, value * 1.0)
          new_evs = if maybe_event, do: [maybe_event | ev_acc], else: ev_acc
          {Map.put(thr_acc, name, new_thr), new_evs}
        end
      end)

    new_state = %{
      state
      | thresholds: new_thresholds,
        event_count: state.event_count + length(events)
    }

    {new_state, events}
  end

  @doc "Returns a summary status map."
  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    triggered =
      state.thresholds
      |> Enum.filter(fn {_k, v} -> v.state == :triggered end)
      |> Enum.map(fn {k, _v} -> k end)

    %{
      threshold_count: map_size(state.thresholds),
      triggered_count: length(triggered),
      triggered: triggered,
      event_count: state.event_count
    }
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec evaluate_threshold(String.t(), threshold(), float()) ::
          {threshold(), crossing_event() | nil}
  defp evaluate_threshold(name, %{direction: :above} = thr, value) do
    cond do
      thr.state == :nominal and value >= thr.high ->
        event = %{metric: name, direction: :above, value: value, crossed: :triggered}
        {%{thr | state: :triggered}, event}

      thr.state == :triggered and value <= thr.low ->
        event = %{metric: name, direction: :above, value: value, crossed: :reset}
        {%{thr | state: :nominal}, event}

      true ->
        {thr, nil}
    end
  end

  defp evaluate_threshold(name, %{direction: :below} = thr, value) do
    cond do
      thr.state == :nominal and value <= thr.low ->
        event = %{metric: name, direction: :below, value: value, crossed: :triggered}
        {%{thr | state: :triggered}, event}

      thr.state == :triggered and value >= thr.high ->
        event = %{metric: name, direction: :below, value: value, crossed: :reset}
        {%{thr | state: :nominal}, event}

      true ->
        {thr, nil}
    end
  end

  @spec all_thresholds_valid?(map()) :: boolean()
  defp all_thresholds_valid?(thresholds) do
    Enum.all?(thresholds, fn
      {_k, %{high: h, low: l, direction: d}}
      when is_float(h) and is_float(l) and is_atom(d) ->
        h >= l and d in [:above, :below]

      _ ->
        false
    end)
  end
end
