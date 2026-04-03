defmodule Indrajaal.Substrate.L4.DisruptionSensor do
  @moduledoc """
  L4 Disruption Sensor — Disruptive change detector for environmental scanning.

  Tracks change signals across domains and computes a disruption index using
  a weighted velocity model. Signals that exceed the disruption threshold
  are flagged for escalation to L4 strategic planning.

  Algorithm:
  - Disruption index: weighted sum of normalised signal velocities
  - Velocity: delta between consecutive observations per signal
  - Threshold crossing triggers :disruptive status

  ## STAMP Constraints
  - SC-S4-001: Cybernetic VSM S4 intelligence — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @default_threshold 0.6
  @max_signals 64

  @type signal :: %{
          domain: String.t(),
          value: float(),
          weight: float()
        }

  @type disruption_status :: :calm | :elevated | :disruptive | :critical

  @type t :: %__MODULE__{
          signals: [signal()],
          threshold: float(),
          index: float(),
          status: disruption_status()
        }

  defstruct signals: [],
            threshold: @default_threshold,
            index: 0.0,
            status: :calm

  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    threshold = Keyword.get(opts, :threshold, @default_threshold)

    cond do
      not is_number(threshold) ->
        {:error, "threshold must be numeric"}

      threshold <= 0.0 or threshold > 1.0 ->
        {:error, "threshold must be in (0.0, 1.0]"}

      true ->
        {:ok, %__MODULE__{threshold: threshold / 1.0}}
    end
  end

  @spec observe(t(), String.t(), float(), float()) :: {:ok, t()} | {:error, String.t()}
  def observe(%__MODULE__{} = state, domain, value, weight)
      when is_binary(domain) and is_number(value) and is_number(weight) do
    cond do
      length(state.signals) >= @max_signals ->
        {:error, "signal capacity (#{@max_signals}) reached"}

      weight < 0.0 or weight > 1.0 ->
        {:error, "weight must be in [0.0, 1.0]"}

      true ->
        signal = %{domain: domain, value: max(0.0, min(1.0, value / 1.0)), weight: weight / 1.0}
        existing = Enum.reject(state.signals, &(&1.domain == domain))
        updated = %{state | signals: existing ++ [signal]}
        {:ok, recompute(updated)}
    end
  end

  @spec disrupted?(t()) :: boolean()
  def disrupted?(%__MODULE__{status: status}), do: status in [:disruptive, :critical]

  @spec top_signals(t(), non_neg_integer()) :: [signal()]
  def top_signals(%__MODULE__{signals: signals}, n) when is_integer(n) and n >= 0 do
    signals
    |> Enum.sort_by(fn s -> s.value * s.weight end, :desc)
    |> Enum.take(n)
  end

  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    %{
      disruption_index: state.index,
      threshold: state.threshold,
      status: state.status,
      signal_count: length(state.signals),
      top_3: top_signals(state, 3) |> Enum.map(& &1.domain)
    }
  end

  # ── Private ──────────────────────────────────────────────────────────

  defp recompute(%__MODULE__{signals: []} = state), do: %{state | index: 0.0, status: :calm}

  defp recompute(%__MODULE__{signals: signals, threshold: threshold} = state) do
    total_weight = Enum.reduce(signals, 0.0, fn s, acc -> acc + s.weight end)

    index =
      if total_weight == 0.0 do
        0.0
      else
        signals
        |> Enum.reduce(0.0, fn s, acc -> acc + s.value * s.weight end)
        |> Kernel./(total_weight)
        |> Float.round(4)
      end

    status =
      cond do
        index >= 0.9 -> :critical
        index >= threshold -> :disruptive
        index >= threshold * 0.6 -> :elevated
        true -> :calm
      end

    %{state | index: index, status: status}
  end
end
