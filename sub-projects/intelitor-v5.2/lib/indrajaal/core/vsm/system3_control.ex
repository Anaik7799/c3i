defmodule Indrajaal.Core.VSM.System3Control do
  @moduledoc """
  VSM System 3: Control - The Guard for v20.0.0

  System 3 handles resource management and operational control:
  - Enforces resource budgets
  - Monitors S1 operations
  - Triggers interventions when needed
  - Reports to S4/S5 on anomalies

  ## Responsibilities
  - Budget enforcement (CPU, memory, network)
  - Operation rate limiting
  - Anomaly detection
  - Escalation to higher systems

  ## STAMP Constraints
  - SC-S3-001: Budget MUST be enforced atomically
  - SC-S3-002: Over-budget MUST trigger immediate throttling
  - SC-S3-003: Anomalies MUST be reported within 10ms
  - SC-S3-004: Control actions MUST be logged
  - SC-FOUNDER-016: Priority 0 (Ω₀) SHALL pre-empt all other resource allocations

  ## Category Theory
  S3 forms a State Monad:
  - get : State s a (read current budget state)
  - put : s → State s () (update budget state)
  - modify : (s → s) → State s () (modify budget state)
  """

  require Logger

  alias Indrajaal.Core.Holon
  alias Indrajaal.Core.Holon.Metrics

  @type resource_type :: :cpu | :memory | :network | :disk | :operations

  @type budget :: %{
          resource_type => %{
            limit: number(),
            used: number(),
            reserved: number()
          }
        }

  @type control_state :: %{
          budget: budget(),
          over_budget: boolean(),
          throttled: boolean(),
          violations: non_neg_integer(),
          last_check: DateTime.t() | nil
        }

  @doc """
  Creates a new control state with default budgets.
  """
  @spec new(Keyword.t()) :: control_state()
  def new(opts \\ []) do
    %{
      budget: %{
        cpu: %{limit: Keyword.get(opts, :cpu_limit, 100), used: 0, reserved: 0},
        memory: %{limit: Keyword.get(opts, :memory_limit, 1_000_000_000), used: 0, reserved: 0},
        network: %{limit: Keyword.get(opts, :network_limit, 10_000_000), used: 0, reserved: 0},
        disk: %{limit: Keyword.get(opts, :disk_limit, 10_000_000_000), used: 0, reserved: 0},
        operations: %{limit: Keyword.get(opts, :ops_limit, 1000), used: 0, reserved: 0}
      },
      over_budget: false,
      throttled: false,
      violations: 0,
      last_check: nil
    }
  end

  @doc """
  Checks if the current usage is within budget.
  """
  @spec check_budget(control_state()) :: {:within_budget | :over_budget, control_state()}
  def check_budget(state) do
    over_budget =
      Enum.any?(state.budget, fn {_resource, %{limit: limit, used: used, reserved: reserved}} ->
        used + reserved > limit
      end)

    new_state = %{
      state
      | over_budget: over_budget,
        violations: if(over_budget, do: state.violations + 1, else: state.violations),
        last_check: DateTime.utc_now()
    }

    if over_budget do
      {:over_budget, new_state}
    else
      {:within_budget, new_state}
    end
  end

  @doc """
  Records resource usage.
  """
  @spec record_usage(control_state(), resource_type(), number()) :: control_state()
  def record_usage(state, resource_type, amount) do
    update_budget(state, resource_type, fn budget ->
      %{budget | used: budget.used + amount}
    end)
  end

  @doc """
  Reserves resources for future use.
  Priority 0 (Ω₀) can pre-empt other resources.
  """
  @spec reserve(control_state(), resource_type(), number(), non_neg_integer()) ::
          {:ok, control_state()} | {:error, :insufficient_budget}
  def reserve(state, resource_type, amount, priority \\ 3) do
    budget = Map.get(state.budget, resource_type)
    available = budget.limit - budget.used - budget.reserved

    cond do
      amount <= available ->
        new_state =
          update_budget(state, resource_type, fn b ->
            %{b | reserved: b.reserved + amount}
          end)

        {:ok, new_state}

      priority == 0 ->
        # Ω₀ Pre-emption logic
        Logger.info("S3: Priority 0 (Ω₀) pre-emption triggered for #{resource_type}")
        preempt_resources(state, resource_type, amount)

      true ->
        {:error, :insufficient_budget}
    end
  end

  defp preempt_resources(state, resource_type, amount) do
    # In a simplified simulation, we 'reclaim' from reserved first
    # In full biomorphic implementation, this would trigger apoptosis/eviction

    # We force the reservation for Ω₀ regardless of budget
    # but log the 'overage' as a metabolic stress signal
    new_state =
      update_budget(state, resource_type, fn b ->
        %{b | reserved: b.reserved + amount}
      end)

    Indrajaal.Observability.FractalLogger.spine("System3Control", "Ω₀ Pre-emption Executed", %{
      resource: resource_type,
      amount: amount
    })

    {:ok, %{new_state | over_budget: true}}
  end

  @doc """
  Releases reserved resources.
  """
  @spec release(control_state(), resource_type(), number()) :: control_state()
  def release(state, resource_type, amount) do
    update_budget(state, resource_type, fn budget ->
      %{budget | reserved: max(0, budget.reserved - amount)}
    end)
  end

  @doc """
  Resets usage counters (called periodically).
  """
  @spec reset_usage(control_state()) :: control_state()
  def reset_usage(state) do
    new_budget =
      Enum.into(state.budget, %{}, fn {resource, budget} ->
        {resource, %{budget | used: 0}}
      end)

    %{state | budget: new_budget}
  end

  @doc """
  Applies throttling if over budget.
  """
  @spec apply_throttling(control_state()) :: control_state()
  def apply_throttling(%{over_budget: true} = state) do
    Logger.warning("S3: Applying throttling due to budget violation")
    %{state | throttled: true}
  end

  def apply_throttling(state), do: %{state | throttled: false}

  @doc """
  Returns the utilization percentage for a resource.
  """
  @spec utilization(control_state(), resource_type()) :: float()
  def utilization(state, resource_type) do
    budget = Map.get(state.budget, resource_type)
    (budget.used + budget.reserved) / budget.limit * 100
  end

  @doc """
  Returns the available capacity for a resource.
  """
  @spec available(control_state(), resource_type()) :: number()
  def available(state, resource_type) do
    budget = Map.get(state.budget, resource_type)
    budget.limit - budget.used - budget.reserved
  end

  @doc """
  Emits budget metrics.
  """
  @spec emit_metrics(control_state(), Holon.holon_id(), Holon.layer()) :: :ok
  def emit_metrics(state, holon_id, layer) do
    usage = %{
      cpu_util: utilization(state, :cpu),
      memory_util: utilization(state, :memory),
      operations: Map.get(state.budget, :operations).used
    }

    Metrics.emit_budget(holon_id, layer, not state.over_budget, usage)
  end

  @doc """
  Returns a summary of the control state.
  """
  @spec summary(control_state()) :: map()
  def summary(state) do
    %{
      over_budget: state.over_budget,
      throttled: state.throttled,
      violations: state.violations,
      utilization: %{
        cpu: utilization(state, :cpu),
        memory: utilization(state, :memory),
        network: utilization(state, :network),
        operations: utilization(state, :operations)
      }
    }
  end

  # Private helpers

  defp update_budget(state, resource_type, update_fn) do
    current = Map.get(state.budget, resource_type)
    updated = update_fn.(current)
    %{state | budget: Map.put(state.budget, resource_type, updated)}
  end
end
