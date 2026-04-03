defmodule Indrajaal.Compute.Credits do
  @moduledoc """
  Compute Credits - Internal Resource Currency for v20.0.0

  Implements an internal economy for resource allocation:
  - Compute credits as fungible tokens
  - Credit minting and burning
  - Credit transfer between agents
  - Credit balance tracking

  ## Economic Model

  Credits represent computational capacity:
  - 1 Credit ≈ 1ms of CPU time
  - 1 Credit ≈ 1KB of memory allocation
  - 1 Credit ≈ 1 network message

  ## Monetary Policy
  - Initial allocation based on agent role
  - Periodic minting for productive agents
  - Burning for resource consumption
  - No inflation beyond productivity gains

  ## STAMP Constraints
  - SC-CRD-001: Total credits MUST be conserved (no creation from nothing)
  - SC-CRD-002: Credit balance MUST never be negative
  - SC-CRD-003: Transfers MUST be atomic
  - SC-CRD-004: Minting MUST be authorized by S5 policy
  """

  use GenServer
  require Logger

  @type credit_amount :: non_neg_integer()
  @type agent_id :: String.t()

  @type credit_state :: %{
          total_supply: credit_amount(),
          circulating: credit_amount(),
          burned: credit_amount(),
          minting_authority: agent_id(),
          last_mint: DateTime.t() | nil
        }

  # Initial credit allocation per role
  @role_allocations %{
    executive: 1_000_000,
    domain: 100_000,
    functional: 10_000,
    worker: 1_000
  }

  # Credit value constants
  @credit_per_cpu_ms 1
  @credit_per_memory_kb 1
  @credit_per_message 1

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets the current credit state.
  """
  @spec state() :: credit_state()
  def state do
    GenServer.call(__MODULE__, :state)
  end

  @doc """
  Mints new credits (requires S5 authorization).
  """
  @spec mint(agent_id(), credit_amount(), map()) ::
          {:ok, credit_amount()} | {:error, term()}
  def mint(recipient, amount, authorization) do
    GenServer.call(__MODULE__, {:mint, recipient, amount, authorization})
  end

  @doc """
  Burns credits (removes from circulation).
  """
  @spec burn(agent_id(), credit_amount()) :: {:ok, credit_amount()} | {:error, term()}
  def burn(agent_id, amount) do
    GenServer.call(__MODULE__, {:burn, agent_id, amount})
  end

  @doc """
  Transfers credits between agents.
  """
  @spec transfer(agent_id(), agent_id(), credit_amount()) ::
          {:ok, :transferred} | {:error, term()}
  def transfer(from, to, amount) do
    GenServer.call(__MODULE__, {:transfer, from, to, amount})
  end

  @doc """
  Gets the balance for an agent.
  """
  @spec balance(agent_id()) :: credit_amount()
  def balance(agent_id) do
    GenServer.call(__MODULE__, {:balance, agent_id})
  end

  @doc """
  Calculates credit cost for resource usage.
  """
  @spec calculate_cost(map()) :: credit_amount()
  def calculate_cost(usage) do
    cpu_cost = Map.get(usage, :cpu_ms, 0) * @credit_per_cpu_ms
    memory_cost = Map.get(usage, :memory_kb, 0) * @credit_per_memory_kb
    message_cost = Map.get(usage, :messages, 0) * @credit_per_message

    cpu_cost + memory_cost + message_cost
  end

  @doc """
  Gets the initial allocation for a role.
  """
  @spec initial_allocation(atom()) :: credit_amount()
  def initial_allocation(role) do
    Map.get(@role_allocations, role, 1_000)
  end

  @doc """
  Returns credit system summary.
  """
  @spec summary() :: map()
  def summary do
    GenServer.call(__MODULE__, :summary)
  end

  # GenServer callbacks

  @impl true
  def init(opts) do
    state = %{
      total_supply: 0,
      circulating: 0,
      burned: 0,
      minting_authority: Keyword.get(opts, :authority, "system"),
      last_mint: nil,
      balances: %{}
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:state, _from, state) do
    public_state = %{
      total_supply: state.total_supply,
      circulating: state.circulating,
      burned: state.burned,
      minting_authority: state.minting_authority,
      last_mint: state.last_mint
    }

    {:reply, public_state, state}
  end

  @impl true
  def handle_call({:mint, recipient, amount, authorization}, _from, state) do
    # Verify authorization (SC-CRD-004)
    if authorized_to_mint?(authorization, state) do
      current_balance = Map.get(state.balances, recipient, 0)
      new_balances = Map.put(state.balances, recipient, current_balance + amount)

      new_state = %{
        state
        | total_supply: state.total_supply + amount,
          circulating: state.circulating + amount,
          balances: new_balances,
          last_mint: DateTime.utc_now()
      }

      Logger.info("Minted #{amount} credits to #{recipient}")
      emit_telemetry(:mint, %{recipient: recipient, amount: amount})

      {:reply, {:ok, amount}, new_state}
    else
      {:reply, {:error, :unauthorized}, state}
    end
  end

  @impl true
  def handle_call({:burn, agent_id, amount}, _from, state) do
    current_balance = Map.get(state.balances, agent_id, 0)

    if current_balance >= amount do
      new_balances = Map.put(state.balances, agent_id, current_balance - amount)

      new_state = %{
        state
        | circulating: state.circulating - amount,
          burned: state.burned + amount,
          balances: new_balances
      }

      Logger.debug("Burned #{amount} credits from #{agent_id}")
      emit_telemetry(:burn, %{agent: agent_id, amount: amount})

      {:reply, {:ok, amount}, new_state}
    else
      {:reply, {:error, :insufficient_balance}, state}
    end
  end

  @impl true
  def handle_call({:transfer, from, to, amount}, _from, state) do
    from_balance = Map.get(state.balances, from, 0)

    # Check sufficient balance (SC-CRD-002)
    if from_balance >= amount do
      to_balance = Map.get(state.balances, to, 0)

      # Atomic transfer (SC-CRD-003)
      new_balances =
        state.balances
        |> Map.put(from, from_balance - amount)
        |> Map.put(to, to_balance + amount)

      new_state = %{state | balances: new_balances}

      Logger.debug("Transferred #{amount} credits: #{from} -> #{to}")
      emit_telemetry(:transfer, %{from: from, to: to, amount: amount})

      {:reply, {:ok, :transferred}, new_state}
    else
      {:reply, {:error, :insufficient_balance}, state}
    end
  end

  @impl true
  def handle_call({:balance, agent_id}, _from, state) do
    balance = Map.get(state.balances, agent_id, 0)
    {:reply, balance, state}
  end

  @impl true
  def handle_call(:summary, _from, state) do
    summary = %{
      total_supply: state.total_supply,
      circulating: state.circulating,
      burned: state.burned,
      num_accounts: map_size(state.balances),
      velocity: calculate_velocity(state),
      last_mint: state.last_mint
    }

    {:reply, summary, state}
  end

  # Private helpers

  defp authorized_to_mint?(authorization, state) do
    # Check if authorization comes from minting authority
    case authorization do
      %{authority: authority, signature: _sig} ->
        authority == state.minting_authority

      _ ->
        false
    end
  end

  defp calculate_velocity(_state) do
    # Simplified velocity calculation
    # In production, would track transfers over time
    1.0
  end

  defp emit_telemetry(event, metadata) do
    :telemetry.execute(
      [:indrajaal, :compute, :credits, event],
      %{count: 1},
      metadata
    )
  end
end
