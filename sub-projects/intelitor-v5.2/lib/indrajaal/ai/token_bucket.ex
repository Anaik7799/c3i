defmodule Indrajaal.AI.TokenBucket do
  @moduledoc """
  Metabolic Throttle (Token Bucket Algorithm).

  Manages API usage rate limiting to prevent "Metabolic Burnout" (Rate limit exceeded).
  Part of the Cybernetic Energy Governor.

  ## Architecture
  - Uses a GenServer to hold state.
  - Refills tokens at a constant rate.
  - Consumes tokens per request.

  ## STAMP Constraints
  - SC-RES-001: Resource limits must be enforced.
  """
  use GenServer
  require Logger

  # Configuration
  # Tokens (approx $1.00 at standard rates)
  @default_capacity 100_000
  # Tokens per second
  @default_refill_rate 100

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Consumes tokens. Returns :ok or {:error, :insufficient_energy}.
  """
  def consume(amount) do
    GenServer.call(__MODULE__, {:consume, amount})
  end

  @doc """
  Returns current energy level.
  """
  def check_energy do
    GenServer.call(__MODULE__, :check)
  end

  # Callbacks

  @impl true
  def init(opts) do
    capacity = Keyword.get(opts, :capacity, @default_capacity)
    rate = Keyword.get(opts, :rate, @default_refill_rate)

    state = %{
      capacity: capacity,
      tokens: capacity,
      rate: rate,
      last_refill: System.monotonic_time(:millisecond)
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:consume, amount}, _from, state) do
    {new_tokens, new_time} = refill(state)

    if new_tokens >= amount do
      {:reply, :ok, %{state | tokens: new_tokens - amount, last_refill: new_time}}
    else
      Logger.warning("Metabolic Throttle: Insufficient energy (#{new_tokens} < #{amount})")

      {:reply, {:error, :insufficient_energy},
       %{state | tokens: new_tokens, last_refill: new_time}}
    end
  end

  @impl true
  def handle_call(:check, _from, state) do
    {tokens, _} = refill(state)
    {:reply, tokens, state}
  end

  defp refill(%{tokens: tokens, capacity: capacity, rate: rate, last_refill: last_refill}) do
    now = System.monotonic_time(:millisecond)
    delta_seconds = (now - last_refill) / 1000.0
    added = floor(delta_seconds * rate)

    new_tokens = min(capacity, tokens + added)
    {new_tokens, now}
  end
end
