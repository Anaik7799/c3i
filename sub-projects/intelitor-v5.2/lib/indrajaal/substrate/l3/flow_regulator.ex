defmodule Indrajaal.Substrate.L3.FlowRegulator do
  @moduledoc """
  ## Design Intent
  L3 substrate flow regulator — pure functional module implementing throughput
  flow control using a token-bucket algorithm.

  Biological metaphor: vascular smooth muscle — constricts or dilates to
  maintain steady blood flow despite varying upstream pressure. Burst capacity
  (bucket depth) absorbs transient spikes; the refill rate governs steady-state
  throughput.

  Token-bucket algorithm:
    - Bucket starts at `capacity` tokens.
    - `refill/2` adds `rate × elapsed_seconds` tokens (clamped to `capacity`).
    - `consume/2` subtracts `tokens` from bucket; returns `:ok` or `:throttled`.
    - Fractional tokens supported (float bucket level).
    - Utilization = 1.0 − (tokens / capacity).

  ## STAMP Constraints
  - SC-S3-001: Cybernetic VSM S3 control — ENFORCED
  - SC-API-001: API safety — rate limiting — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type t :: %__MODULE__{
          capacity: float(),
          tokens: float(),
          rate: float(),
          consumed_total: float(),
          throttle_count: non_neg_integer(),
          last_refill_ts: integer()
        }

  defstruct capacity: 100.0,
            tokens: 100.0,
            rate: 10.0,
            consumed_total: 0.0,
            throttle_count: 0,
            last_refill_ts: 0

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Create a new FlowRegulator.

  Options:
    - `:capacity` — bucket depth in tokens (default 100.0, must be > 0).
    - `:rate` — refill rate in tokens/second (default 10.0, must be > 0).
    - `:initial_tokens` — starting token level (default = capacity).
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    capacity = Keyword.get(opts, :capacity, 100.0) * 1.0
    rate = Keyword.get(opts, :rate, 10.0) * 1.0
    initial = Keyword.get(opts, :initial_tokens, capacity) * 1.0

    cond do
      capacity <= 0.0 ->
        {:error, "capacity must be > 0"}

      rate <= 0.0 ->
        {:error, "rate must be > 0"}

      initial < 0.0 or initial > capacity ->
        {:error, "initial_tokens must be in [0, capacity]"}

      true ->
        {:ok,
         %__MODULE__{
           capacity: capacity,
           tokens: initial,
           rate: rate,
           last_refill_ts: System.monotonic_time(:millisecond)
         }}
    end
  end

  @doc """
  Refill the bucket based on elapsed time since the last refill.

  Caller may provide explicit `now_ms` (monotonic milliseconds) for
  deterministic/test scenarios; defaults to `System.monotonic_time(:millisecond)`.
  """
  @spec refill(t()) :: t()
  def refill(%__MODULE__{} = state) do
    refill(state, System.monotonic_time(:millisecond))
  end

  @spec refill(t(), integer()) :: t()
  def refill(%__MODULE__{} = state, now_ms) when is_integer(now_ms) do
    elapsed_s = max(0, now_ms - state.last_refill_ts) / 1_000.0
    new_tokens = min(state.capacity, state.tokens + state.rate * elapsed_s)
    %{state | tokens: new_tokens, last_refill_ts: now_ms}
  end

  @doc """
  Attempt to consume `amount` tokens.

  Returns `{:ok, updated_state}` if tokens are available, or
  `{:throttled, updated_state}` if not enough tokens exist.
  """
  @spec consume(t(), float()) :: {:ok, t()} | {:throttled, t()}
  def consume(%__MODULE__{} = state, amount) when is_float(amount) or is_integer(amount) do
    a = amount * 1.0

    if state.tokens >= a do
      new_state = %{state | tokens: state.tokens - a, consumed_total: state.consumed_total + a}
      {:ok, new_state}
    else
      new_state = %{state | throttle_count: state.throttle_count + 1}
      {:throttled, new_state}
    end
  end

  @doc "Compute current utilization in [0.0, 1.0] (0 = empty, 1 = full)."
  @spec utilization(t()) :: float()
  def utilization(%__MODULE__{capacity: cap, tokens: tokens}) do
    Float.round(min(1.0, tokens / cap), 4)
  end

  @doc "Returns a summary status map."
  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    %{
      capacity: state.capacity,
      tokens: Float.round(state.tokens, 4),
      rate: state.rate,
      utilization: utilization(state),
      consumed_total: Float.round(state.consumed_total, 2),
      throttle_count: state.throttle_count
    }
  end
end
