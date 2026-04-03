defmodule Indrajaal.Observability.Fractal.HLC do
  @moduledoc """
  Hybrid Logical Clock (HLC) for Fractal Logging System.

  Provides causal ordering of events without tight NTP synchronization.
  L3+ logs MUST use HLC timestamps per SC-LOG-006.

  ## Format

  HLC = {Physical, Counter, NodeID}

  - Physical: Unix microseconds (48 bits usable)
  - Counter: Logical counter (16 bits, 0-65_535)
  - NodeID: Unique node identifier

  ## Usage

      hlc = Indrajaal.Observability.Fractal.HLC.now()
      # => %{physical: 1_735_123_456_789_000, counter: 0, node_id: "node-abc123"}

  ## STAMP Compliance

  - SC-LOG-006: L3+ logs MUST use HLC timestamps
  """

  @type timestamp :: %{
          physical: non_neg_integer(),
          counter: non_neg_integer(),
          node_id: String.t()
        }

  @max_counter 65_535
  @max_drift_ms 50

  # ============================================================
  # STATE (Agent-based for thread-safe counter)
  # ============================================================

  use Agent
  require Logger

  @doc false
  def start_link(_opts \\ []) do
    Agent.start_link(
      fn -> %{last_physical: 0, counter: 0, node_id: generate_node_id()} end,
      name: __MODULE__
    )
  end

  # ============================================================
  # PUBLIC API
  # ============================================================

  @doc """
  Generate a new HLC timestamp.

  Guarantees:
  - Monotonically increasing
  - Causal ordering preserved
  - Max drift of #{@max_drift_ms}ms from wall clock
  """
  @spec now() :: timestamp()
  def now do
    ensure_started()

    Agent.get_and_update(__MODULE__, fn state ->
      physical = System.system_time(:microsecond)
      {new_state, hlc} = advance(state, physical)
      {hlc, new_state}
    end)
  end

  @doc """
  Update the local HLC based on a received remote timestamp.

  Used for distributed systems to maintain causality.
  """
  @spec update(timestamp()) :: timestamp()
  def update(remote) do
    ensure_started()

    Agent.get_and_update(__MODULE__, fn state ->
      physical = System.system_time(:microsecond)
      {new_state, hlc} = merge(state, remote, physical)
      {hlc, new_state}
    end)
  end

  @doc """
  Compare two HLC timestamps.

  Returns:
  - `:lt` if a < b
  - `:eq` if a == b
  - `:gt` if a > b
  """
  @spec compare(timestamp(), timestamp()) :: :lt | :eq | :gt
  def compare(a, b) do
    cond do
      a.physical < b.physical -> :lt
      a.physical > b.physical -> :gt
      a.counter < b.counter -> :lt
      a.counter > b.counter -> :gt
      true -> :eq
    end
  end

  @doc """
  Encode HLC to a compact binary format (12 bytes).
  """
  @spec encode(timestamp()) :: binary()
  def encode(hlc) do
    <<hlc.physical::unsigned-integer-size(64), hlc.counter::unsigned-integer-size(16)>>
  end

  @doc """
  Decode HLC from binary format.
  """
  @spec decode(binary()) :: {:ok, timestamp()} | {:error, :invalid_format}
  def decode(<<physical::unsigned-integer-size(64), counter::unsigned-integer-size(16)>>) do
    {:ok, %{physical: physical, counter: counter, node_id: ""}}
  end

  def decode(_), do: {:error, :invalid_format}

  @doc """
  Get the current node ID.
  """
  @spec node_id() :: String.t()
  def node_id do
    ensure_started()
    Agent.get(__MODULE__, fn state -> state.node_id end)
  end

  # ============================================================
  # PRIVATE: CLOCK ADVANCEMENT
  # ============================================================

  defp advance(state, physical) do
    # Physical time moved forward
    if physical > state.last_physical do
      hlc = %{physical: physical, counter: 0, node_id: state.node_id}
      new_state = %{state | last_physical: physical, counter: 0}
      {new_state, hlc}
    else
      # Same or backwards - increment counter
      new_counter = min(state.counter + 1, @max_counter)

      if new_counter >= @max_counter do
        # Counter overflow - wait for physical time to advance
        :timer.sleep(1)
        advance(state, System.system_time(:microsecond))
      else
        hlc = %{physical: state.last_physical, counter: new_counter, node_id: state.node_id}
        new_state = %{state | counter: new_counter}
        {new_state, hlc}
      end
    end
  end

  defp merge(state, remote, physical) do
    max_physical = Enum.max([physical, state.last_physical, remote.physical])

    # Check for excessive drift
    drift_ms = div(max_physical - physical, 1000)

    if drift_ms > @max_drift_ms do
      # Clock skew detected - use local time with warning
      Logger.warning("[Fractal.HLC] Clock skew detected: #{drift_ms}ms")
      advance(state, physical)
    else
      new_counter =
        cond do
          max_physical == state.last_physical and max_physical == remote.physical ->
            Enum.max([state.counter, remote.counter]) + 1

          max_physical == state.last_physical ->
            state.counter + 1

          max_physical == remote.physical ->
            remote.counter + 1

          true ->
            0
        end

      hlc = %{
        physical: max_physical,
        counter: min(new_counter, @max_counter),
        node_id: state.node_id
      }

      new_state = %{state | last_physical: max_physical, counter: new_counter}
      {new_state, hlc}
    end
  end

  # ============================================================
  # PRIVATE: INITIALIZATION
  # ============================================================

  defp ensure_started do
    case Process.whereis(__MODULE__) do
      nil -> start_link()
      _pid -> :ok
    end
  end

  defp generate_node_id do
    node_str = node() |> to_string()
    suffix_bytes = :crypto.strong_rand_bytes(3)
    random_suffix = suffix_bytes |> Base.encode16(case: :lower)
    "#{node_str}-#{random_suffix}"
  end
end
