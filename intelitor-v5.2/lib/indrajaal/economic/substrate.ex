defmodule Indrajaal.Economic.Substrate do
  @moduledoc """
  Indrajaal Economic Substrate - Energy and Resource Metering.

  WHAT: Tracks resource consumption (credits) across the biomorphic swarm.
  WHY: SC-ECON-001 enables goal-directed power accumulation and efficiency.
  """

  use GenServer
  require Logger

  # ============================================================
  # TYPE DEFINITIONS
  # ============================================================

  @type credit_ledger :: %{
          holon_id: String.t(),
          balance: float(),
          total_consumed: float(),
          last_metered_at: DateTime.t()
        }

  # ============================================================
  # CLIENT API
  # ============================================================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Meters resource usage for a specific holon.
  """
  def meter_usage(holon_id, amount, type \\ :cpu) do
    GenServer.cast(__MODULE__, {:meter, holon_id, amount, type})
  end

  @doc """
  Gets the credit balance for a holon.
  """
  def get_balance(holon_id) do
    GenServer.call(__MODULE__, {:get_balance, holon_id})
  end

  # ============================================================
  # SERVER CALLBACKS
  # ============================================================

  @hibernation_threshold 50.0

  @impl true
  def init(_opts) do
    Logger.info("[Economic.Substrate] Initializing Energy Ledger")
    {:ok, %{ledger: %{}, total_swarm_energy: 0.0, mode: :active}}
  end

  @impl true
  def handle_cast({:meter, holon_id, amount, _type}, state) do
    new_ledger =
      Map.update(
        state.ledger,
        holon_id,
        %{balance: 1000.0 - amount, total_consumed: amount, last_metered_at: DateTime.utc_now()},
        fn entry ->
          %{
            entry
            | balance: entry.balance - amount,
              total_consumed: entry.total_consumed + amount,
              last_metered_at: DateTime.utc_now()
          }
        end
      )

    entry = Map.get(new_ledger, holon_id)

    # SC-ECON-005: Hibernation Reflex
    new_mode =
      if entry.balance < @hibernation_threshold and state.mode == :active do
        trigger_hibernation(holon_id, entry.balance)
        :hibernating
      else
        state.mode
      end

    {:noreply,
     %{
       state
       | ledger: new_ledger,
         total_swarm_energy: state.total_swarm_energy + amount,
         mode: new_mode
     }}
  end

  defp trigger_hibernation(id, balance) do
    Logger.warning(
      "❄️ [Economic.Substrate] HIBERNATION TRIGGERED: Holon #{id} exhausted (Balance: #{balance})"
    )

    # Broadcast to Zenoh for Swarm coordination
    if Code.ensure_loaded?(Indrajaal.Observability.ZenohNeuralStream) do
      Indrajaal.Observability.ZenohNeuralStream.stream_state(:economic, :hibernation_active, %{
        trigger_holon: id,
        balance: balance,
        timestamp: DateTime.utc_now()
      })
    end
  end

  @impl true
  def handle_call({:get_balance, holon_id}, _from, state) do
    balance = get_in(state.ledger, [holon_id, :balance]) || 0.0
    {:reply, {:ok, balance}, state}
  end
end
