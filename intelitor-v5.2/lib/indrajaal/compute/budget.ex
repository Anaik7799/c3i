defmodule Indrajaal.Compute.Budget do
  @moduledoc """
  Budget Management - Agent Budget Enforcement for v20.0.0

  Implements budget tracking and enforcement:
  - Budget allocation per agent
  - Spending tracking
  - Overspend prevention
  - Budget alerts

  ## Budget Model

  Budget = {allocated, spent, remaining, period}

  Constraint: spent ≤ allocated (enforced)

  ## Budget Periods
  - **Hourly**: Short-term operational budget
  - **Daily**: Standard working budget
  - **Weekly**: Planning horizon budget
  - **Monthly**: Strategic budget

  ## STAMP Constraints
  - SC-BUD-001: Spending MUST NOT exceed budget
  - SC-BUD-002: Budget alerts at 80% threshold
  - SC-BUD-003: Emergency reserve MUST be maintained
  - SC-BUD-004: Budget history MUST be auditable
  """

  use GenServer
  require Logger

  @type agent_id :: String.t()
  @type budget_period :: :hourly | :daily | :weekly | :monthly

  @type budget :: %{
          agent_id: agent_id(),
          period: budget_period(),
          allocated: non_neg_integer(),
          spent: non_neg_integer(),
          reserved: non_neg_integer(),
          started_at: DateTime.t(),
          expires_at: DateTime.t()
        }

  @type state :: %{
          budgets: map(),
          history: [map()],
          config: map()
        }

  # Alert threshold (80%)
  @alert_threshold 0.80

  # Emergency reserve (10%)
  @emergency_reserve 0.10

  # History retention
  @max_history 10_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Allocates budget to an agent.
  """
  @spec allocate(agent_id(), non_neg_integer(), budget_period()) ::
          {:ok, budget()} | {:error, term()}
  def allocate(agent_id, amount, period \\ :daily) do
    GenServer.call(__MODULE__, {:allocate, agent_id, amount, period})
  end

  @doc """
  Gets current budget for an agent.
  """
  @spec get(agent_id()) :: {:ok, budget()} | {:error, :not_found}
  def get(agent_id) do
    GenServer.call(__MODULE__, {:get, agent_id})
  end

  @doc """
  Gets remaining budget for an agent.
  """
  @spec remaining(agent_id()) :: {:ok, non_neg_integer()} | {:error, :not_found}
  def remaining(agent_id) do
    GenServer.call(__MODULE__, {:remaining, agent_id})
  end

  @doc """
  Checks if agent can spend amount.
  """
  @spec can_spend?(agent_id(), non_neg_integer()) :: boolean()
  def can_spend?(agent_id, amount) do
    GenServer.call(__MODULE__, {:can_spend, agent_id, amount})
  end

  @doc """
  Records spending against budget.
  """
  @spec spend(agent_id(), non_neg_integer(), String.t()) ::
          {:ok, non_neg_integer()} | {:error, term()}
  def spend(agent_id, amount, reason \\ nil) do
    GenServer.call(__MODULE__, {:spend, agent_id, amount, reason})
  end

  @doc """
  Reserves budget for upcoming expense.
  """
  @spec reserve(agent_id(), non_neg_integer()) ::
          {:ok, non_neg_integer()} | {:error, term()}
  def reserve(agent_id, amount) do
    GenServer.call(__MODULE__, {:reserve, agent_id, amount})
  end

  @doc """
  Releases a reservation.
  """
  @spec release(agent_id(), non_neg_integer()) :: :ok
  def release(agent_id, amount) do
    GenServer.cast(__MODULE__, {:release, agent_id, amount})
  end

  @doc """
  Gets budget utilization for an agent.
  """
  @spec utilization(agent_id()) :: {:ok, float()} | {:error, :not_found}
  def utilization(agent_id) do
    GenServer.call(__MODULE__, {:utilization, agent_id})
  end

  @doc """
  Gets spending history.
  """
  @spec history(agent_id(), Keyword.t()) :: [map()]
  def history(agent_id, opts \\ []) do
    GenServer.call(__MODULE__, {:history, agent_id, opts})
  end

  @doc """
  Gets budget summary for all agents.
  """
  @spec summary() :: map()
  def summary do
    GenServer.call(__MODULE__, :summary)
  end

  # GenServer callbacks

  @impl true
  def init(opts) do
    state = %{
      budgets: %{},
      history: [],
      config: %{
        alert_threshold: Keyword.get(opts, :alert_threshold, @alert_threshold),
        emergency_reserve: Keyword.get(opts, :emergency_reserve, @emergency_reserve)
      }
    }

    # Schedule periodic cleanup
    Process.send_after(self(), :cleanup_expired, 60_000)

    {:ok, state}
  end

  @impl true
  def handle_call({:allocate, agent_id, amount, period}, _from, state) do
    now = DateTime.utc_now()
    expires = calculate_expiry(now, period)

    budget = %{
      agent_id: agent_id,
      period: period,
      allocated: amount,
      spent: 0,
      reserved: 0,
      started_at: now,
      expires_at: expires
    }

    new_budgets = Map.put(state.budgets, agent_id, budget)

    Logger.info("Allocated #{amount} credits to #{agent_id} for #{period}")
    record_event(state, :allocated, agent_id, amount, nil)

    {:reply, {:ok, budget}, %{state | budgets: new_budgets}}
  end

  @impl true
  def handle_call({:get, agent_id}, _from, state) do
    case Map.get(state.budgets, agent_id) do
      nil -> {:reply, {:error, :not_found}, state}
      budget -> {:reply, {:ok, budget}, state}
    end
  end

  @impl true
  def handle_call({:remaining, agent_id}, _from, state) do
    case Map.get(state.budgets, agent_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      budget ->
        remaining = budget.allocated - budget.spent - budget.reserved
        {:reply, {:ok, max(0, remaining)}, state}
    end
  end

  @impl true
  def handle_call({:can_spend, agent_id, amount}, _from, state) do
    case Map.get(state.budgets, agent_id) do
      nil ->
        {:reply, false, state}

      budget ->
        available = budget.allocated - budget.spent - budget.reserved
        emergency = round(budget.allocated * state.config.emergency_reserve)
        can = available - emergency >= amount
        {:reply, can, state}
    end
  end

  @impl true
  def handle_call({:spend, agent_id, amount, reason}, _from, state) do
    with_budget(state, agent_id, fn budget ->
      available = calculate_available(budget)
      emergency = round(budget.allocated * state.config.emergency_reserve)

      # Check budget constraint (SC-BUD-001)
      if available - emergency < amount do
        {:reply, {:error, :insufficient_budget}, state}
      else
        new_spent = budget.spent + amount
        new_budget = %{budget | spent: new_spent}
        new_budgets = Map.put(state.budgets, agent_id, new_budget)

        # Check alert threshold (SC-BUD-002)
        utilization = new_spent / budget.allocated

        if utilization >= state.config.alert_threshold do
          Logger.warning("Budget alert: #{agent_id} at #{Float.round(utilization * 100, 1)}%")

          emit_alert(agent_id, utilization)
        end

        # Record history (SC-BUD-004)
        new_state = record_event(state, :spent, agent_id, amount, reason)
        new_state = %{new_state | budgets: new_budgets}

        remaining = budget.allocated - new_spent - budget.reserved
        {:reply, {:ok, remaining}, new_state}
      end
    end)
  end

  @impl true
  def handle_call({:reserve, agent_id, amount}, _from, state) do
    with_budget(state, agent_id, fn budget ->
      available = calculate_available(budget)

      if available < amount do
        {:reply, {:error, :insufficient_budget}, state}
      else
        new_reserved = budget.reserved + amount
        new_budget = %{budget | reserved: new_reserved}
        new_budgets = Map.put(state.budgets, agent_id, new_budget)

        {:reply, {:ok, amount}, %{state | budgets: new_budgets}}
      end
    end)
  end

  @impl true
  def handle_call({:utilization, agent_id}, _from, state) do
    case Map.get(state.budgets, agent_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      budget ->
        util = (budget.spent + budget.reserved) / max(budget.allocated, 1)
        {:reply, {:ok, Float.round(util, 3)}, state}
    end
  end

  @impl true
  def handle_call({:history, agent_id, opts}, _from, state) do
    limit = Keyword.get(opts, :limit, 100)

    history =
      state.history
      |> Enum.filter(&(&1.agent_id == agent_id))
      |> Enum.take(limit)

    {:reply, history, state}
  end

  @impl true
  def handle_call(:summary, _from, state) do
    summary =
      state.budgets
      |> Enum.into(%{}, fn {agent_id, budget} ->
        util = (budget.spent + budget.reserved) / max(budget.allocated, 1)

        {agent_id,
         %{
           allocated: budget.allocated,
           spent: budget.spent,
           reserved: budget.reserved,
           remaining: budget.allocated - budget.spent - budget.reserved,
           utilization: Float.round(util, 3),
           period: budget.period,
           expires_at: budget.expires_at
         }}
      end)

    {:reply, summary, state}
  end

  @impl true
  def handle_cast({:release, agent_id, amount}, state) do
    case Map.get(state.budgets, agent_id) do
      nil ->
        {:noreply, state}

      budget ->
        new_reserved = max(0, budget.reserved - amount)
        new_budget = %{budget | reserved: new_reserved}
        new_budgets = Map.put(state.budgets, agent_id, new_budget)
        {:noreply, %{state | budgets: new_budgets}}
    end
  end

  @impl true
  def handle_info(:cleanup_expired, state) do
    now = DateTime.utc_now()

    # Find and archive expired budgets
    {expired, active} =
      Enum.split_with(state.budgets, fn {_, budget} ->
        DateTime.compare(now, budget.expires_at) == :gt
      end)

    # Archive expired budgets
    archived_history =
      Enum.reduce(expired, state.history, fn {agent_id, budget}, history ->
        event = %{
          type: :expired,
          agent_id: agent_id,
          amount: budget.allocated,
          spent: budget.spent,
          timestamp: now,
          reason: "Period ended"
        }

        [event | Enum.take(history, @max_history - 1)]
      end)

    # Schedule next cleanup
    Process.send_after(self(), :cleanup_expired, 60_000)

    {:noreply, %{state | budgets: Map.new(active), history: archived_history}}
  end

  # Private helpers

  # DRY extraction: Calculate available budget (allocated - spent - reserved)
  defp calculate_available(budget) do
    budget.allocated - budget.spent - budget.reserved
  end

  # DRY extraction: Lookup budget with not-found handling
  defp with_budget(state, agent_id, success_fn) do
    case Map.get(state.budgets, agent_id) do
      nil -> {:reply, {:error, :no_budget}, state}
      budget -> success_fn.(budget)
    end
  end

  defp calculate_expiry(now, period) do
    seconds =
      case period do
        :hourly -> 3600
        :daily -> 86_400
        :weekly -> 604_800
        :monthly -> 2_592_000
      end

    DateTime.add(now, seconds, :second)
  end

  defp record_event(state, type, agent_id, amount, reason) do
    event = %{
      type: type,
      agent_id: agent_id,
      amount: amount,
      timestamp: DateTime.utc_now(),
      reason: reason
    }

    new_history = [event | Enum.take(state.history, @max_history - 1)]
    %{state | history: new_history}
  end

  defp emit_alert(agent_id, utilization) do
    :telemetry.execute(
      [:indrajaal, :compute, :budget, :alert],
      %{utilization: utilization},
      %{agent_id: agent_id}
    )
  end
end
