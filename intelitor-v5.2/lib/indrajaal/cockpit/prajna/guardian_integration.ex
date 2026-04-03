defmodule Indrajaal.Cockpit.Prajna.GuardianIntegration do
  @moduledoc """
  Guardian Integration for Prajna Cockpit.

  Provides a supervised GenServer that acts as a facade for Guardian safety kernel
  integration within the Prajna C3I mesh.

  ## STAMP Constraints
  - SC-PRAJNA-001: All commands through Guardian pre-approval
  - SC-PRAJNA-006: Constitutional invariants checked
  - SC-CONST-007: Guardian has absolute veto
  """
  use GenServer
  require Logger
  alias Indrajaal.Safety.Guardian

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    Logger.info("[GuardianIntegration] Initialized - Guardian safety gate active")
    {:ok, %{circuit_state: :closed, proposals_count: 0}}
  end

  # Public API

  def submit_proposal(proposal) do
    Guardian.validate_proposal(proposal)
  end

  def approve_action(type, args) do
    Guardian.validate_proposal(%{type: type, args: args})
  end

  def circuit_state do
    GenServer.call(__MODULE__, :get_circuit_state)
  end

  # GenServer callbacks

  @impl GenServer
  def handle_call(:get_circuit_state, _from, state) do
    {:reply, state.circuit_state, state}
  end

  @impl GenServer
  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
