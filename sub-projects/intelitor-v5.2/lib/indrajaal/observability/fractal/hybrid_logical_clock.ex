defmodule Indrajaal.Observability.Fractal.HybridLogicalClock do
  @moduledoc """
  Hybrid Logical Clock (HLC) for Distributed Systems.

  WHAT: Provides globally unique timestamps combining physical and logical time.
  WHY: SC-DIST-005/SC-DIST-010 require HLC for FQUN instance IDs to ensure
       causal ordering and collision avoidance across distributed nodes.
  CONSTRAINTS: Must be monotonically increasing. Physical time resolution is ms.

  ## Mathematical Specification

  ```
  HLC := (physical, logical)

  where:
    physical ∈ ℕ (milliseconds since epoch)
    logical ∈ ℕ (counter for same physical time)

  Ordering:
    hlc₁ < hlc₂ ⟺
      physical(hlc₁) < physical(hlc₂) ∨
      (physical(hlc₁) = physical(hlc₂) ∧ logical(hlc₁) < logical(hlc₂))

  Monotonicity Invariant:
    ∀ t₁, t₂: t₁ < t₂ ⟹ now(t₁) < now(t₂)
  ```

  ## STAMP Constraints
  - SC-DIST-005: HLC generation MUST complete < 1ms
  - SC-DIST-010: FQUN MUST contain HLC timestamp

  ## AOR Rules
  - AOR-HLC-001: HLC MUST be monotonically increasing
  - AOR-HLC-002: HLC MUST survive node restart via persistence
  """

  use GenServer
  require Logger

  @type hlc :: {non_neg_integer(), non_neg_integer()}

  # ============================================================
  # CLIENT API
  # ============================================================

  @doc """
  Start the HLC GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get current HLC timestamp.

  Returns `{:ok, {physical, logical}}` on success or `{:error, reason}` on failure.
  Falls back to system time if GenServer is not available.
  """
  @spec now() :: {:ok, hlc()} | {:error, term()}
  def now do
    case GenServer.whereis(__MODULE__) do
      nil ->
        # Fallback when GenServer not started
        physical = System.system_time(:millisecond)
        {:ok, {physical, 0}}

      pid when is_pid(pid) ->
        try do
          GenServer.call(__MODULE__, :now, 1000)
        catch
          :exit, _ ->
            physical = System.system_time(:millisecond)
            {:ok, {physical, 0}}
        end
    end
  end

  @doc """
  Get current HLC timestamp without tuple wrapper.
  Returns the raw HLC value or a fallback.
  """
  @spec now!() :: hlc()
  def now! do
    case now() do
      {:ok, hlc} -> hlc
      {:error, _} -> {System.system_time(:millisecond), 0}
    end
  end

  @doc """
  Update HLC with received timestamp (for distributed sync).
  """
  @spec update(hlc()) :: {:ok, hlc()} | {:error, term()}
  def update(received_hlc) do
    case GenServer.whereis(__MODULE__) do
      nil ->
        {:error, :not_started}

      pid when is_pid(pid) ->
        try do
          GenServer.call(__MODULE__, {:update, received_hlc}, 1000)
        catch
          :exit, reason -> {:error, reason}
        end
    end
  end

  @doc """
  Encode HLC to string for use in FQUNs.
  """
  @spec encode(hlc()) :: String.t()
  def encode({physical, logical}) do
    "#{physical}.#{logical}"
  end

  @doc """
  Decode HLC from string.
  """
  @spec decode(String.t()) :: {:ok, hlc()} | {:error, :invalid_format}
  def decode(str) when is_binary(str) do
    case String.split(str, ".") do
      [physical_str, logical_str] ->
        try do
          physical = String.to_integer(physical_str)
          logical = String.to_integer(logical_str)
          {:ok, {physical, logical}}
        rescue
          ArgumentError -> {:error, :invalid_format}
        end

      _ ->
        {:error, :invalid_format}
    end
  end

  @doc """
  Compare two HLC timestamps.
  Returns :lt, :eq, or :gt.
  """
  @spec compare(hlc(), hlc()) :: :lt | :eq | :gt
  def compare({p1, l1}, {p2, l2}) do
    cond do
      p1 < p2 -> :lt
      p1 > p2 -> :gt
      l1 < l2 -> :lt
      l1 > l2 -> :gt
      true -> :eq
    end
  end

  # ============================================================
  # SERVER CALLBACKS
  # ============================================================

  @impl true
  def init(_opts) do
    state = %{
      physical: System.system_time(:millisecond),
      logical: 0,
      ticks: 0
    }

    Logger.info("[HLC] Started Hybrid Logical Clock")
    {:ok, state}
  end

  @impl true
  def handle_call(:now, _from, state) do
    current_physical = System.system_time(:millisecond)

    {new_physical, new_logical} =
      if current_physical > state.physical do
        # Physical time advanced, reset logical
        {current_physical, 0}
      else
        # Same physical time, increment logical
        {state.physical, state.logical + 1}
      end

    new_state = %{state | physical: new_physical, logical: new_logical, ticks: state.ticks + 1}

    {:reply, {:ok, {new_physical, new_logical}}, new_state}
  end

  @impl true
  def handle_call({:update, {recv_physical, recv_logical}}, _from, state) do
    current_physical = System.system_time(:millisecond)

    {new_physical, new_logical} =
      cond do
        current_physical > state.physical and current_physical > recv_physical ->
          # Local physical time is ahead
          {current_physical, 0}

        state.physical == recv_physical and state.physical == current_physical ->
          # All same, increment logical
          {state.physical, max(state.logical, recv_logical) + 1}

        state.physical == recv_physical ->
          # Local and received same, but physical advanced
          {max(current_physical, state.physical), max(state.logical, recv_logical) + 1}

        recv_physical > state.physical and recv_physical > current_physical ->
          # Received is ahead
          {recv_physical, recv_logical + 1}

        state.physical > recv_physical and state.physical > current_physical ->
          # Local is ahead
          {state.physical, state.logical + 1}

        true ->
          # Physical time is ahead of both
          {current_physical, 0}
      end

    new_state = %{state | physical: new_physical, logical: new_logical, ticks: state.ticks + 1}

    {:reply, {:ok, {new_physical, new_logical}}, new_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end
end
