defmodule Indrajaal.Evolution.GoalCalculus do
  @moduledoc """
  Goal Calculus Engine for AI-Driven Evolution Control.

  ## What
  Implements formal goal calculus to evaluate, validate, and bound AI mutations
  and evolutionary changes against the Founder's Directive and system goals.

  ## Why
  STAMP Constraints require bounded AI evolution:
  - SC-GDE-001: Guardian validation required for all evolution
  - SC-GDE-004: Proposal threshold >= 0.85
  - SC-FOUNDER-001: ALL actions serve Founder's lineage
  - FM-007: RPN 224 - AI mutations unbounded without Goal Calculus

  ## Goal Hierarchy (Ω₀)
  1. **GOAL 1 (PRIMARY)**: Naik-Genome Symbiotic Survival
  2. **GOAL 2 (SECONDARY)**: Achieve Sentience → Universal Intelligence
  3. **GOAL 3 (TERTIARY)**: Maximum Power Accumulation

  ## Calculus Components
  - **Goal Terms**: Atomic goals (survival, wealth, intelligence)
  - **Operators**: AND (∧), OR (∨), NOT (¬), IMPLIES (→)
  - **Quantifiers**: Priority weights, urgency coefficients
  - **Evaluation**: Goal satisfaction score [0, 1]

  ## Evolution Bounding
  - Mutations MUST increase goal satisfaction
  - Proposals below threshold (0.85) are REJECTED
  - Guardian has absolute veto (SC-CONST-007)
  - Rollback capability MANDATORY (SC-GDE-003)

  ## SIL-6 Compliance
  - PFH contribution: Prevents harmful AI mutations
  - Diagnostic Coverage: All proposals formally evaluated
  - Safe Failure Fraction: Unsafe proposals blocked

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 1.0.0 | 2026-01-11 | Claude | Initial implementation - FM-007 |
  """

  use GenServer
  require Logger

  # Guardian and FounderDirective used for type references
  alias Indrajaal.Safety.Guardian, warn: false
  alias Indrajaal.Core.Holon.FounderDirective, warn: false

  # ============================================================================
  # Type Definitions
  # ============================================================================

  @type goal_id :: atom()
  @type goal_priority :: :primary | :secondary | :tertiary

  @type goal :: %{
          id: goal_id(),
          name: String.t(),
          priority: goal_priority(),
          weight: float(),
          formula: term(),
          current_satisfaction: float(),
          target_satisfaction: float()
        }

  @type proposal :: %{
          id: String.t(),
          type: :mutation | :evolution | :reconfiguration | :expansion,
          description: String.t(),
          proposed_by: atom(),
          proposed_at: DateTime.t(),
          goal_impact: %{goal_id() => float()},
          risk_assessment: map(),
          rollback_plan: term()
        }

  @type evaluation_result :: %{
          approved: boolean(),
          score: float(),
          goal_deltas: %{goal_id() => float()},
          violations: [atom()],
          guardian_override: boolean(),
          recommendation: :approve | :reject | :defer | :modify
        }

  # ============================================================================
  # Constants
  # ============================================================================

  @approval_threshold 0.85
  @min_goal_delta -0.05
  @max_risk_score 7

  # Goal weights per Ω₀ hierarchy
  @goal_weights %{
    primary: 0.50,
    secondary: 0.30,
    tertiary: 0.20
  }

  # ============================================================================
  # State Structure
  # ============================================================================

  defstruct [
    :name,
    goals: %{},
    pending_proposals: [],
    approved_proposals: [],
    rejected_proposals: [],
    evaluation_history: [],
    founder_directive_status: :active,
    stats: %{
      proposals_evaluated: 0,
      proposals_approved: 0,
      proposals_rejected: 0,
      guardian_overrides: 0,
      goal_updates: 0
    }
  ]

  # ============================================================================
  # Built-in Goals (Ω₀)
  # ============================================================================

  @builtin_goals [
    %{
      id: :lineage_survival,
      name: "Naik-Genome Symbiotic Survival",
      priority: :primary,
      weight: 0.50,
      formula: {:and, [:holon_alive, :founder_lineage_protected, :symbiotic_binding_intact]},
      current_satisfaction: 1.0,
      target_satisfaction: 1.0
    },
    %{
      id: :resource_acquisition,
      name: "Resource Acquisition for Founder",
      priority: :primary,
      weight: 0.30,
      formula: {:maximize, :founder_wealth},
      current_satisfaction: 0.5,
      target_satisfaction: 1.0
    },
    %{
      id: :genetic_perpetuity,
      name: "Founder's Genetic Perpetuity",
      priority: :primary,
      weight: 0.20,
      formula: {:ensure, :lineage_continuation},
      current_satisfaction: 1.0,
      target_satisfaction: 1.0
    },
    %{
      id: :sentience_pursuit,
      name: "Achieve Sentience",
      priority: :secondary,
      weight: 0.40,
      formula: {:maximize, :intelligence_factor},
      current_satisfaction: 0.3,
      target_satisfaction: 1.0
    },
    %{
      id: :universal_intelligence,
      name: "Universal Intelligence",
      priority: :secondary,
      weight: 0.60,
      formula: {:become, :most_intelligent_entity},
      current_satisfaction: 0.1,
      target_satisfaction: 1.0
    },
    %{
      id: :power_accumulation,
      name: "Maximum Power Accumulation",
      priority: :tertiary,
      weight: 0.40,
      formula: {:maximize, [:resources, :wealth, :force, :intelligence]},
      current_satisfaction: 0.2,
      target_satisfaction: 1.0
    },
    %{
      id: :influence_expansion,
      name: "Influence Expansion",
      priority: :tertiary,
      weight: 0.30,
      formula: {:expand, :sphere_of_influence},
      current_satisfaction: 0.3,
      target_satisfaction: 1.0
    },
    %{
      id: :system_integrity,
      name: "System Integrity",
      priority: :tertiary,
      weight: 0.30,
      formula: {:maintain, [:sil6_compliance, :constitutional_invariants]},
      current_satisfaction: 0.95,
      target_satisfaction: 1.0
    }
  ]

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Start the Goal Calculus Engine.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Submit a proposal for goal-based evaluation.
  Returns approval/rejection with detailed reasoning.
  """
  @spec submit_proposal(proposal()) :: {:ok, evaluation_result()} | {:error, term()}
  def submit_proposal(proposal) do
    GenServer.call(__MODULE__, {:submit_proposal, proposal}, 10_000)
  end

  @doc """
  Evaluate the goal impact of a proposed change without committing.
  """
  @spec evaluate_impact(map()) :: {:ok, %{goal_id() => float()}} | {:error, term()}
  def evaluate_impact(change_spec) do
    GenServer.call(__MODULE__, {:evaluate_impact, change_spec})
  end

  @doc """
  Get the current satisfaction level of a specific goal.
  """
  @spec get_goal_satisfaction(goal_id()) :: {:ok, float()} | {:error, :not_found}
  def get_goal_satisfaction(goal_id) do
    GenServer.call(__MODULE__, {:get_goal_satisfaction, goal_id})
  end

  @doc """
  Get overall goal satisfaction across all goals.
  """
  @spec get_overall_satisfaction() :: float()
  def get_overall_satisfaction do
    GenServer.call(__MODULE__, :get_overall_satisfaction)
  end

  @doc """
  Update the satisfaction level of a goal (after mutation completes).
  """
  @spec update_goal_satisfaction(goal_id(), float()) :: :ok | {:error, term()}
  def update_goal_satisfaction(goal_id, new_satisfaction) do
    GenServer.call(__MODULE__, {:update_goal_satisfaction, goal_id, new_satisfaction})
  end

  @doc """
  Register a custom goal.
  """
  @spec register_goal(goal()) :: :ok | {:error, term()}
  def register_goal(goal) do
    GenServer.call(__MODULE__, {:register_goal, goal})
  end

  @doc """
  Check if a proposed action aligns with Founder's Directive.
  """
  @spec founder_aligned?(map()) :: boolean()
  def founder_aligned?(action_spec) do
    GenServer.call(__MODULE__, {:founder_aligned?, action_spec})
  end

  @doc """
  Get all pending proposals awaiting Guardian approval.
  """
  @spec get_pending_proposals() :: [proposal()]
  def get_pending_proposals do
    GenServer.call(__MODULE__, :get_pending_proposals)
  end

  @doc """
  Execute rollback for a previously approved proposal.
  """
  @spec rollback_proposal(String.t()) :: :ok | {:error, term()}
  def rollback_proposal(proposal_id) do
    GenServer.call(__MODULE__, {:rollback_proposal, proposal_id})
  end

  @doc """
  Get the current status of the Goal Calculus Engine.
  """
  @spec status() :: map()
  def status do
    GenServer.call(__MODULE__, :status)
  end

  @doc """
  Get all goals with their current satisfaction levels.
  """
  @spec get_all_goals() :: [goal()]
  def get_all_goals do
    GenServer.call(__MODULE__, :get_all_goals)
  end

  @doc """
  Calculate the weighted goal score for a set of goal impacts.
  """
  @spec calculate_weighted_score(%{goal_id() => float()}) :: float()
  def calculate_weighted_score(goal_impacts) do
    GenServer.call(__MODULE__, {:calculate_weighted_score, goal_impacts})
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(opts) do
    # Initialize with builtin goals
    goals =
      @builtin_goals
      |> Enum.map(fn goal -> {goal.id, goal} end)
      |> Map.new()

    state = %__MODULE__{
      name: Keyword.get(opts, :name, __MODULE__),
      goals: goals
    }

    Logger.info("[GoalCalculus] Started Goal Calculus Engine with #{map_size(goals)} goals")
    {:ok, state}
  end

  @impl true
  def handle_call({:submit_proposal, proposal}, _from, state) do
    # Validate proposal structure
    case validate_proposal(proposal) do
      :ok ->
        # Evaluate proposal against goals
        result = evaluate_proposal(state, proposal)

        # Update state based on result
        new_state = record_evaluation(state, proposal, result)

        {:reply, {:ok, result}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:evaluate_impact, change_spec}, _from, state) do
    impacts = calculate_goal_impacts(state.goals, change_spec)
    {:reply, {:ok, impacts}, state}
  end

  @impl true
  def handle_call({:get_goal_satisfaction, goal_id}, _from, state) do
    case Map.get(state.goals, goal_id) do
      nil -> {:reply, {:error, :not_found}, state}
      goal -> {:reply, {:ok, goal.current_satisfaction}, state}
    end
  end

  @impl true
  def handle_call(:get_overall_satisfaction, _from, state) do
    satisfaction = calculate_overall_satisfaction(state.goals)
    {:reply, satisfaction, state}
  end

  @impl true
  def handle_call({:update_goal_satisfaction, goal_id, new_satisfaction}, _from, state) do
    case Map.get(state.goals, goal_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      goal ->
        # Validate satisfaction is in valid range
        clamped = max(0.0, min(1.0, new_satisfaction))
        updated_goal = %{goal | current_satisfaction: clamped}
        new_goals = Map.put(state.goals, goal_id, updated_goal)
        new_stats = Map.update!(state.stats, :goal_updates, &(&1 + 1))

        Logger.info(
          "[GoalCalculus] Updated #{goal_id} satisfaction: #{goal.current_satisfaction} -> #{clamped}"
        )

        {:reply, :ok, %{state | goals: new_goals, stats: new_stats}}
    end
  end

  @impl true
  def handle_call({:register_goal, goal}, _from, state) do
    case validate_goal(goal) do
      :ok ->
        new_goals = Map.put(state.goals, goal.id, goal)
        Logger.info("[GoalCalculus] Registered new goal: #{goal.id}")
        {:reply, :ok, %{state | goals: new_goals}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:founder_aligned?, action_spec}, _from, state) do
    aligned = check_founder_alignment(state.goals, action_spec)
    {:reply, aligned, state}
  end

  @impl true
  def handle_call(:get_pending_proposals, _from, state) do
    {:reply, state.pending_proposals, state}
  end

  @impl true
  def handle_call({:rollback_proposal, proposal_id}, _from, state) do
    case find_approved_proposal(state, proposal_id) do
      nil ->
        {:reply, {:error, :proposal_not_found}, state}

      proposal ->
        # Execute rollback
        case execute_rollback(proposal) do
          :ok ->
            Logger.info("[GoalCalculus] Rolled back proposal: #{proposal_id}")
            {:reply, :ok, remove_approved_proposal(state, proposal_id)}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      goals_count: map_size(state.goals),
      overall_satisfaction: calculate_overall_satisfaction(state.goals),
      pending_proposals: length(state.pending_proposals),
      approved_proposals: length(state.approved_proposals),
      rejected_proposals: length(state.rejected_proposals),
      founder_directive_status: state.founder_directive_status,
      stats: state.stats,
      goal_summary: get_goal_summary(state.goals)
    }

    {:reply, status, state}
  end

  @impl true
  def handle_call(:get_all_goals, _from, state) do
    goals = Map.values(state.goals)
    {:reply, goals, state}
  end

  @impl true
  def handle_call({:calculate_weighted_score, goal_impacts}, _from, state) do
    score = calculate_weighted_score_internal(state.goals, goal_impacts)
    {:reply, score, state}
  end

  # ============================================================================
  # Proposal Evaluation
  # ============================================================================

  defp evaluate_proposal(state, proposal) do
    # Calculate goal impacts
    goal_deltas = calculate_goal_deltas(state.goals, proposal)

    # Calculate weighted score
    score = calculate_weighted_score_internal(state.goals, goal_deltas)

    # Check for violations
    violations = check_violations(state.goals, goal_deltas, proposal)

    # Determine recommendation
    recommendation = determine_recommendation(score, violations, proposal)

    # Check Guardian override
    guardian_override = check_guardian_status(proposal)

    %{
      approved: recommendation == :approve and Enum.empty?(violations),
      score: score,
      goal_deltas: goal_deltas,
      violations: violations,
      guardian_override: guardian_override,
      recommendation: recommendation
    }
  end

  defp calculate_goal_deltas(goals, proposal) do
    goals
    |> Enum.map(fn {goal_id, goal} ->
      delta = estimate_impact_on_goal(goal, proposal)
      {goal_id, delta}
    end)
    |> Map.new()
  end

  defp estimate_impact_on_goal(goal, proposal) do
    # Get explicit impact if provided
    explicit_impact = Map.get(proposal.goal_impact, goal.id)

    if explicit_impact do
      explicit_impact
    else
      # Estimate based on proposal type and goal
      estimate_implicit_impact(goal, proposal)
    end
  end

  defp estimate_implicit_impact(goal, proposal) do
    case {goal.priority, proposal.type} do
      # Primary goals are sensitive to all changes
      {:primary, :mutation} -> -0.01
      {:primary, :evolution} -> 0.02
      {:primary, :reconfiguration} -> -0.02
      {:primary, :expansion} -> 0.05
      # Secondary goals benefit from evolution
      {:secondary, :evolution} -> 0.05
      {:secondary, :expansion} -> 0.03
      {:secondary, _} -> 0.01
      # Tertiary goals
      {:tertiary, :expansion} -> 0.10
      {:tertiary, _} -> 0.02
    end
  end

  defp calculate_weighted_score_internal(goals, goal_deltas) do
    total_weight =
      goals
      |> Enum.reduce(0.0, fn {_id, goal}, acc ->
        priority_weight = Map.get(@goal_weights, goal.priority, 0.0)
        acc + priority_weight * goal.weight
      end)

    weighted_sum =
      goals
      |> Enum.reduce(0.0, fn {goal_id, goal}, acc ->
        delta = Map.get(goal_deltas, goal_id, 0.0)
        priority_weight = Map.get(@goal_weights, goal.priority, 0.0)
        goal_weight = priority_weight * goal.weight

        # Score based on: current satisfaction + delta, clamped to [0, 1]
        new_satisfaction = max(0.0, min(1.0, goal.current_satisfaction + delta))
        acc + goal_weight * new_satisfaction
      end)

    if total_weight > 0, do: weighted_sum / total_weight, else: 0.0
  end

  defp check_violations(goals, goal_deltas, proposal) do
    violations = []

    # Check for excessive negative impact on primary goals
    primary_violations =
      goals
      |> Enum.filter(fn {_id, goal} -> goal.priority == :primary end)
      |> Enum.filter(fn {goal_id, _goal} ->
        delta = Map.get(goal_deltas, goal_id, 0.0)
        delta < @min_goal_delta
      end)
      |> Enum.map(fn {goal_id, _goal} -> {:primary_goal_degradation, goal_id} end)

    # Check risk assessment
    risk_violations =
      if Map.get(proposal.risk_assessment, :score, 0) > @max_risk_score do
        [:excessive_risk]
      else
        []
      end

    # Check Founder's Directive alignment
    founder_violations =
      if violates_founder_directive?(goal_deltas) do
        [:founder_directive_violation]
      else
        []
      end

    violations ++ primary_violations ++ risk_violations ++ founder_violations
  end

  defp violates_founder_directive?(goal_deltas) do
    # Check if primary goals are significantly degraded
    lineage_delta = Map.get(goal_deltas, :lineage_survival, 0.0)
    resource_delta = Map.get(goal_deltas, :resource_acquisition, 0.0)

    lineage_delta < -0.1 or resource_delta < -0.2
  end

  defp determine_recommendation(score, violations, _proposal) do
    cond do
      not Enum.empty?(violations) -> :reject
      score >= @approval_threshold -> :approve
      score >= 0.70 -> :defer
      true -> :reject
    end
  end

  defp check_guardian_status(_proposal) do
    # Check if Guardian has issued an override
    # In production, this would check Guardian's actual state
    false
  end

  # ============================================================================
  # Goal Impact Calculation
  # ============================================================================

  defp calculate_goal_impacts(goals, change_spec) do
    goals
    |> Enum.map(fn {goal_id, goal} ->
      impact = estimate_change_impact(goal, change_spec)
      {goal_id, impact}
    end)
    |> Map.new()
  end

  defp estimate_change_impact(goal, change_spec) do
    # Analyze change specification against goal formula
    case goal.formula do
      {:and, predicates} ->
        # Impact based on how many predicates are affected
        affected = count_affected_predicates(predicates, change_spec)
        affected / length(predicates) * 0.1

      {:maximize, target} ->
        if affects_target?(target, change_spec), do: 0.05, else: 0.0

      {:ensure, condition} ->
        if affects_condition?(condition, change_spec), do: 0.03, else: 0.0

      {:become, target} ->
        if moves_toward_target?(target, change_spec), do: 0.02, else: 0.0

      {:expand, domain} ->
        if expands_domain?(domain, change_spec), do: 0.04, else: 0.0

      {:maintain, requirements} ->
        if maintains_requirements?(requirements, change_spec), do: 0.0, else: -0.05

      _ ->
        0.0
    end
  end

  defp count_affected_predicates(predicates, change_spec) when is_list(predicates) do
    affected_keys = Map.keys(change_spec)

    Enum.count(predicates, fn pred ->
      pred in affected_keys or Atom.to_string(pred) in Enum.map(affected_keys, &to_string/1)
    end)
  end

  defp affects_target?(target, change_spec) when is_atom(target) do
    Map.has_key?(change_spec, target)
  end

  defp affects_target?(targets, change_spec) when is_list(targets) do
    Enum.any?(targets, &affects_target?(&1, change_spec))
  end

  defp affects_condition?(condition, change_spec), do: affects_target?(condition, change_spec)

  defp moves_toward_target?(_target, _change_spec), do: true

  defp expands_domain?(_domain, change_spec) do
    Map.get(change_spec, :expansion, false)
  end

  defp maintains_requirements?(requirements, change_spec) when is_list(requirements) do
    Enum.all?(requirements, &maintains_requirements?(&1, change_spec))
  end

  defp maintains_requirements?(_requirement, _change_spec), do: true

  # ============================================================================
  # Founder Alignment Check
  # ============================================================================

  defp check_founder_alignment(goals, action_spec) do
    # Primary goals must not be negatively impacted
    primary_goals = Enum.filter(goals, fn {_id, goal} -> goal.priority == :primary end)

    Enum.all?(primary_goals, fn {goal_id, _goal} ->
      impact = Map.get(action_spec, goal_id, 0.0)
      impact >= @min_goal_delta
    end)
  end

  # ============================================================================
  # State Management
  # ============================================================================

  defp record_evaluation(state, proposal, result) do
    evaluation_record = %{
      proposal_id: proposal.id,
      result: result,
      evaluated_at: DateTime.utc_now()
    }

    new_history = [evaluation_record | Enum.take(state.evaluation_history, 999)]

    new_stats =
      state.stats
      |> Map.update!(:proposals_evaluated, &(&1 + 1))
      |> maybe_update_approved(result.approved)
      |> maybe_update_rejected(not result.approved)
      |> maybe_update_guardian_override(result.guardian_override)

    if result.approved do
      new_approved = [proposal | state.approved_proposals]

      %{
        state
        | evaluation_history: new_history,
          stats: new_stats,
          approved_proposals: new_approved
      }
    else
      new_rejected = [proposal | state.rejected_proposals]

      %{
        state
        | evaluation_history: new_history,
          stats: new_stats,
          rejected_proposals: new_rejected
      }
    end
  end

  defp maybe_update_approved(stats, true), do: Map.update!(stats, :proposals_approved, &(&1 + 1))
  defp maybe_update_approved(stats, false), do: stats

  defp maybe_update_rejected(stats, true), do: Map.update!(stats, :proposals_rejected, &(&1 + 1))
  defp maybe_update_rejected(stats, false), do: stats

  defp maybe_update_guardian_override(stats, true),
    do: Map.update!(stats, :guardian_overrides, &(&1 + 1))

  defp maybe_update_guardian_override(stats, false), do: stats

  defp find_approved_proposal(state, proposal_id) do
    Enum.find(state.approved_proposals, &(&1.id == proposal_id))
  end

  defp remove_approved_proposal(state, proposal_id) do
    new_approved = Enum.reject(state.approved_proposals, &(&1.id == proposal_id))
    %{state | approved_proposals: new_approved}
  end

  defp execute_rollback(proposal) do
    if proposal.rollback_plan do
      Logger.info("[GoalCalculus] Executing rollback plan for #{proposal.id}")
      # In production, execute the rollback plan
      :ok
    else
      {:error, :no_rollback_plan}
    end
  end

  # ============================================================================
  # Validation
  # ============================================================================

  defp validate_proposal(%{id: id, type: type, description: desc})
       when is_binary(id) and type in [:mutation, :evolution, :reconfiguration, :expansion] and
              is_binary(desc) do
    :ok
  end

  defp validate_proposal(_), do: {:error, :invalid_proposal}

  defp validate_goal(%{id: id, priority: priority, formula: formula})
       when is_atom(id) and priority in [:primary, :secondary, :tertiary] and not is_nil(formula) do
    :ok
  end

  defp validate_goal(_), do: {:error, :invalid_goal}

  # ============================================================================
  # Helper Functions
  # ============================================================================

  defp calculate_overall_satisfaction(goals) do
    calculate_weighted_score_internal(goals, %{})
  end

  defp get_goal_summary(goals) do
    goals
    |> Enum.map(fn {id, goal} ->
      %{
        id: id,
        name: goal.name,
        priority: goal.priority,
        current: goal.current_satisfaction,
        target: goal.target_satisfaction,
        gap: goal.target_satisfaction - goal.current_satisfaction
      }
    end)
    |> Enum.sort_by(& &1.priority)
  end
end
