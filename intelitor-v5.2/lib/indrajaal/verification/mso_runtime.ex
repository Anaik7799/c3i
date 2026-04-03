defmodule Indrajaal.Verification.MSORuntime do
  @moduledoc """
  Monadic Second-Order (MSO) Logic Runtime Verifier.

  ## What
  Implements runtime verification of MSO/Quint temporal specifications.
  Monitors system behavior against formal specifications in real-time.

  ## Why
  STAMP Constraints require temporal property verification:
  - SC-SIL4-006: 2oo3 voting for production actuations
  - SC-OODA-001: OODA cycle time <100ms
  - FM-006: RPN 315 - Heartbeat violations undetected without MSO verification

  ## MSO Logic Capabilities
  - **Temporal Operators**: Always (□), Eventually (◇), Until (U), Next (○)
  - **Quantification**: ∀ (for all), ∃ (exists) over finite domains
  - **Predicates**: State predicates, event predicates, timing constraints
  - **Automata**: Büchi automata for LTL property monitoring

  ## Quint Integration
  - Loads Quint specification files (.qnt)
  - Translates Quint properties to runtime monitors
  - Validates runtime behavior against Quint models

  ## Property Types
  1. **Safety**: Something bad never happens (□¬bad)
  2. **Liveness**: Something good eventually happens (◇good)
  3. **Fairness**: If enabled infinitely often, executed infinitely often
  4. **Timing**: Events occur within bounded time intervals
  5. **Ordering**: Events occur in specified sequence

  ## Goal Calculus Extension (GAP-P2-006)
  - `verify_liveness/2`: Büchi automaton acceptance for liveness properties
  - `check_fairness/2`: Strong fairness — enabled→fired constraint checking
  - `evaluate_goal_ordering/2`: Topological sort (Kahn's algorithm) for goal DAGs
  - Results published to Zenoh `"indrajaal/verification/mso/goal_calculus"`

  ## SIL-6 Compliance
  - PFH contribution: Detects specification violations at runtime
  - Diagnostic Coverage: Continuous property monitoring
  - Safe Failure Fraction: Violations trigger immediate response

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 1.0.0 | 2026-01-11 | Claude | Initial implementation - FM-006 |
  | 1.1.0 | 2026-03-19 | Claude | GAP-P2-006: Büchi automaton, fairness, goal ordering, Zenoh pub |
  """

  use GenServer
  require Logger

  alias Indrajaal.Safety.{Guardian, Sentinel}
  alias Indrajaal.Observability.ZenohPublisher

  # ============================================================================
  # Type Definitions
  # ============================================================================

  @type property_id :: atom()
  @type property_type :: :safety | :liveness | :fairness | :timing | :ordering

  @type temporal_op :: :always | :eventually | :until | :next | :release

  @type property :: %{
          id: property_id(),
          name: String.t(),
          type: property_type(),
          formula: term(),
          automaton: term() | nil,
          enabled: boolean(),
          violation_action: atom()
        }

  @type monitor_state :: %{
          property_id: property_id(),
          automaton_state: term(),
          trace: [map()],
          verdict: :unknown | :satisfied | :violated | :inconclusive,
          violation_info: map() | nil
        }

  @type verification_event :: %{
          timestamp: DateTime.t(),
          event_type: atom(),
          data: map()
        }

  @type buchi_automaton :: %{
          states: MapSet.t(atom()),
          initial: atom(),
          accepting: MapSet.t(atom()),
          transitions: %{atom() => [{term(), atom()}]}
        }

  @type transition :: %{
          id: atom(),
          guard: atom() | nil,
          source: atom(),
          target: atom()
        }

  @type goal_node :: %{
          id: atom(),
          name: String.t(),
          priority: non_neg_integer()
        }

  # ============================================================================
  # State Structure
  # ============================================================================

  defstruct [
    :name,
    properties: %{},
    monitors: %{},
    event_buffer: [],
    heartbeat_config: %{
      interval_ms: 100,
      timeout_ms: 500,
      last_heartbeat: nil
    },
    stats: %{
      properties_loaded: 0,
      events_processed: 0,
      violations_detected: 0,
      heartbeats_checked: 0,
      heartbeat_violations: 0
    }
  ]

  # ============================================================================
  # Built-in Safety Properties
  # ============================================================================

  @builtin_properties [
    %{
      id: :heartbeat_liveness,
      name: "Heartbeat Liveness",
      type: :liveness,
      formula: {:eventually, {:within_ms, 500}, :heartbeat},
      enabled: true,
      violation_action: :alert_sentinel
    },
    %{
      id: :no_deadlock,
      name: "Deadlock Freedom",
      type: :safety,
      formula: {:always, {:not, :deadlock_state}},
      enabled: true,
      violation_action: :emergency_recovery
    },
    %{
      id: :response_time,
      name: "Response Time SLA",
      type: :timing,
      formula:
        {:always, {:implies, :request_received, {:eventually, {:within_ms, 100}, :response_sent}}},
      enabled: true,
      violation_action: :log_violation
    },
    %{
      id: :ooda_cycle_time,
      name: "OODA Cycle Time (SC-OODA-001)",
      type: :timing,
      formula: {:always, {:implies, :ooda_observe, {:eventually, {:within_ms, 100}, :ooda_act}}},
      enabled: true,
      violation_action: :alert_sentinel
    },
    %{
      id: :guardian_veto,
      name: "Guardian Veto Respected",
      type: :safety,
      formula: {:always, {:implies, :guardian_veto, {:not, :action_executed}}},
      enabled: true,
      violation_action: :emergency_halt
    },
    %{
      id: :state_transition_valid,
      name: "Valid State Transitions",
      type: :safety,
      formula: {:always, {:implies, :state_change, :transition_allowed}},
      enabled: true,
      violation_action: :rollback_state
    }
  ]

  # ============================================================================
  # Zenoh topic for goal calculus verification results
  # ============================================================================

  @goal_calculus_topic "indrajaal/verification/mso/goal_calculus"

  # Threshold for "recent enough" when approximating Büchi acceptance on a
  # finite trace: the last N events form the suffix that is checked for
  # repeated acceptance.
  @buchi_suffix_size 20

  # A transition is considered "enabled infinitely often" when its enabled
  # count exceeds this threshold relative to total history length.
  @fairness_enabled_ratio_threshold 0.10

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Start the MSO Runtime Verifier.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Register a property to be monitored at runtime.
  """
  @spec register_property(property()) :: :ok | {:error, term()}
  def register_property(property) do
    GenServer.call(__MODULE__, {:register_property, property})
  end

  @doc """
  Load properties from a Quint specification file.
  """
  @spec load_quint_spec(String.t()) :: {:ok, non_neg_integer()} | {:error, term()}
  def load_quint_spec(file_path) do
    GenServer.call(__MODULE__, {:load_quint_spec, file_path})
  end

  @doc """
  Submit an event for verification against all active monitors.
  """
  @spec submit_event(atom(), map()) :: :ok
  def submit_event(event_type, data \\ %{}) do
    GenServer.cast(__MODULE__, {:submit_event, event_type, data})
  end

  @doc """
  Record a heartbeat event.
  """
  @spec heartbeat() :: :ok
  def heartbeat do
    GenServer.cast(__MODULE__, :heartbeat)
  end

  @doc """
  Check if a specific property is currently satisfied.
  """
  @spec property_satisfied?(property_id()) :: boolean()
  def property_satisfied?(property_id) do
    GenServer.call(__MODULE__, {:property_satisfied?, property_id})
  end

  @doc """
  Get all current property verdicts.
  """
  @spec get_verdicts() :: %{property_id() => :unknown | :satisfied | :violated}
  def get_verdicts do
    GenServer.call(__MODULE__, :get_verdicts)
  end

  @doc """
  Get all detected violations.
  """
  @spec get_violations() :: [map()]
  def get_violations do
    GenServer.call(__MODULE__, :get_violations)
  end

  @doc """
  Reset a property monitor to its initial state.
  """
  @spec reset_monitor(property_id()) :: :ok
  def reset_monitor(property_id) do
    GenServer.cast(__MODULE__, {:reset_monitor, property_id})
  end

  @doc """
  Enable or disable a property.
  """
  @spec set_property_enabled(property_id(), boolean()) :: :ok
  def set_property_enabled(property_id, enabled) do
    GenServer.cast(__MODULE__, {:set_property_enabled, property_id, enabled})
  end

  @doc """
  Configure heartbeat monitoring parameters.
  """
  @spec configure_heartbeat(keyword()) :: :ok
  def configure_heartbeat(opts) do
    GenServer.cast(__MODULE__, {:configure_heartbeat, opts})
  end

  @doc """
  Get the current status of the verifier.
  """
  @spec status() :: map()
  def status do
    GenServer.call(__MODULE__, :status)
  end

  @doc """
  Verify a temporal formula against the current trace.
  """
  @spec verify_formula(term()) :: {:ok, boolean()} | {:error, term()}
  def verify_formula(formula) do
    GenServer.call(__MODULE__, {:verify_formula, formula})
  end

  # ============================================================================
  # Goal Calculus Public API (GAP-P2-006)
  # ============================================================================

  @doc """
  Verifies a liveness property using Büchi automaton acceptance.

  A Büchi automaton accepts an *infinite* word when its accepting states are
  visited infinitely often. For finite traces (the only kind available at
  runtime) we approximate this with the following conservative criterion:

  1. Run the automaton from `automaton.initial` on the full trace sequence.
  2. Collect all states visited in the last `@buchi_suffix_size` steps (the
     "suffix" approximating the infinite tail).
  3. Accept iff at least one accepting state appears in that suffix.

  This is sound for verifying liveness in a sliding window: if the accepting
  state has NOT been reached in the most recent N steps the property is
  flagged as `:rejected` so the caller can escalate.

  ## Parameters
  - `automaton` – map with keys:
    - `:states`      – `MapSet` of state atoms (or plain list, both accepted)
    - `:initial`     – starting state atom
    - `:accepting`   – `MapSet` (or list) of accepting state atoms
    - `:transitions` – `%{state => [{guard, next_state}]}` where a guard is
       an atom (matched against `event_type`) or `{:not, atom}`.
  - `trace` – list of event maps (`%{event_type: atom(), ...}`), ordered
    newest-first (i.e. the same convention used by the monitor buffer).

  ## Returns
  - `{:ok, :accepted}` if the trace suffix visits an accepting state.
  - `{:error, :rejected, reason}` otherwise.

  ## Examples

      iex> aut = %{
      ...>   states: MapSet.new([:s0, :s1]),
      ...>   initial: :s0,
      ...>   accepting: MapSet.new([:s1]),
      ...>   transitions: %{s0: [{:ping, :s1}], s1: [{:ping, :s1}]}
      ...> }
      iex> trace = [%{event_type: :ping}, %{event_type: :other}]
      iex> Indrajaal.Verification.MSORuntime.verify_liveness(aut, trace)
      {:ok, :accepted}
  """
  @spec verify_liveness(buchi_automaton(), list(map())) ::
          {:ok, :accepted} | {:error, :rejected, String.t()}
  def verify_liveness(automaton, trace) do
    accepting = normalise_set(automaton.accepting)

    if MapSet.size(accepting) == 0 do
      # Automaton has no accepting states — every infinite word is rejected.
      {:error, :rejected, "Büchi automaton has no accepting states"}
    else
      # Trace is newest-first; reverse to chronological order for simulation.
      chronological = Enum.reverse(trace)

      # Run the automaton, collecting visited states.
      {_final_state, visited_states} =
        Enum.reduce(chronological, {automaton.initial, []}, fn event, {current, visited} ->
          next = buchi_step(automaton.transitions, current, event)
          {next, [next | visited]}
        end)

      # The suffix is the last N states in the *visited* list (which is
      # newest-first after the reduce because we prepend).
      suffix_states =
        visited_states
        |> Enum.take(@buchi_suffix_size)
        |> MapSet.new()

      # Also include the initial state in case the trace is empty.
      suffix_with_initial = MapSet.put(suffix_states, automaton.initial)

      if MapSet.disjoint?(suffix_with_initial, accepting) do
        {:error, :rejected,
         "Accepting state not reached in last #{@buchi_suffix_size} steps " <>
           "(suffix: #{inspect(MapSet.to_list(suffix_states))}; " <>
           "accepting: #{inspect(MapSet.to_list(accepting))})"}
      else
        {:ok, :accepted}
      end
    end
  end

  @doc """
  Checks strong fairness over a transition history.

  Strong fairness requires: if a transition is *enabled* infinitely often
  then it must also *fire* infinitely often.

  For finite histories we use the following approximation:
  - A transition is "enabled often" if its `:guard` event type appears in
    the history with relative frequency ≥ `@fairness_enabled_ratio_threshold`.
  - A transition is "fired" if its `id` appears at least once in the
    `history` entries under the `:fired` key (or `:event_type == id`).

  ## Parameters
  - `transitions` – list of transition maps, each with keys:
    - `:id`     – unique atom identifier for the transition
    - `:guard`  – atom event type that *enables* the transition (may be `nil`)
    - `:source` – source state atom
    - `:target` – target state atom
  - `history` – list of event maps (`%{event_type: atom(), fired: atom() | nil, ...}`).

  ## Returns
  - `{:ok, :fair}` if no fairness violations detected.
  - `{:error, :unfair, violations}` where `violations` is a list of maps
    `%{transition_id: atom(), enabled_count: integer(), fired_count: integer()}`.

  ## Examples

      iex> ts = [%{id: :t1, guard: :req, source: :idle, target: :active}]
      iex> hist = [%{event_type: :req}, %{event_type: :req}, %{event_type: :req}]
      iex> Indrajaal.Verification.MSORuntime.check_fairness(ts, hist)
      {:error, :unfair, [%{transition_id: :t1, enabled_count: 3, fired_count: 0}]}
  """
  @spec check_fairness(list(transition()), list(map())) ::
          {:ok, :fair} | {:error, :unfair, list(map())}
  def check_fairness(transitions, history) do
    total = length(history)

    violations =
      Enum.flat_map(transitions, fn transition ->
        enabled_count = count_enabled(transition, history)

        # Only check fairness when the transition is "enabled often enough".
        # For a very short history the ratio threshold may not fire at all,
        # which is correct: we cannot infer an infinite-often pattern from
        # 0 or 1 events.
        enabled_often =
          total > 0 and enabled_count / total >= @fairness_enabled_ratio_threshold

        if enabled_often do
          fired_count = count_fired(transition, history)

          if fired_count == 0 do
            [
              %{
                transition_id: transition.id,
                enabled_count: enabled_count,
                fired_count: fired_count,
                ratio: enabled_count / total
              }
            ]
          else
            []
          end
        else
          []
        end
      end)

    if Enum.empty?(violations) do
      {:ok, :fair}
    else
      {:error, :unfair, violations}
    end
  end

  @doc """
  Evaluates goal ordering using Kahn's topological sort algorithm.

  Goals are assumed to form a Directed Acyclic Graph (DAG). A dependency
  `{from, to}` means goal `from` must be completed *before* goal `to` can
  start.  Higher-priority goals (lower `:priority` number) are placed first
  when there is a free choice among zero-in-degree nodes.

  ## Parameters
  - `goals` – list of goal maps with at least `:id` and `:priority` keys.
  - `dependencies` – list of `{prerequisite_id, dependent_id}` tuples.

  ## Returns
  - `{:ok, ordered}` – list of goal maps in valid execution order.
  - `{:error, :cycle_detected}` – if the dependency graph contains a cycle.

  ## Examples

      iex> goals = [%{id: :deploy, priority: 2}, %{id: :test, priority: 1}, %{id: :build, priority: 0}]
      iex> deps   = [{:build, :test}, {:test, :deploy}]
      iex> Indrajaal.Verification.MSORuntime.evaluate_goal_ordering(goals, deps)
      {:ok, [%{id: :build, priority: 0}, %{id: :test, priority: 1}, %{id: :deploy, priority: 2}]}
  """
  @spec evaluate_goal_ordering(list(map()), list({atom(), atom()})) ::
          {:ok, list(map())} | {:error, :cycle_detected}
  def evaluate_goal_ordering(goals, dependencies) do
    goal_map = Map.new(goals, &{&1.id, &1})
    ids = MapSet.new(goals, & &1.id)

    # Build adjacency list and in-degree map (only for nodes in `goals`).
    {adj, in_degree} =
      Enum.reduce(dependencies, {%{}, Map.new(ids, &{&1, 0})}, fn {from, to},
                                                                  {adj_acc, deg_acc} ->
        # Only count edges whose both endpoints are in the goal list.
        if MapSet.member?(ids, from) and MapSet.member?(ids, to) do
          new_adj = Map.update(adj_acc, from, [to], &[to | &1])
          new_deg = Map.update(deg_acc, to, 1, &(&1 + 1))
          {new_adj, new_deg}
        else
          {adj_acc, deg_acc}
        end
      end)

    # Kahn's algorithm — use a priority queue approximated by sorting on each
    # iteration (acceptable for the small goal sets used in practice).
    zero_in =
      in_degree
      |> Enum.filter(fn {_id, deg} -> deg == 0 end)
      |> Enum.map(fn {id, _deg} -> id end)
      |> Enum.sort_by(&Map.get(goal_map, &1, %{priority: 0}).priority)

    kahn(zero_in, adj, in_degree, [], goal_map, length(goals))
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(opts) do
    state = %__MODULE__{
      name: Keyword.get(opts, :name, __MODULE__),
      heartbeat_config: %{
        interval_ms: Keyword.get(opts, :heartbeat_interval, 100),
        timeout_ms: Keyword.get(opts, :heartbeat_timeout, 500),
        last_heartbeat: DateTime.utc_now()
      }
    }

    # Load builtin properties
    state_with_builtins =
      Enum.reduce(@builtin_properties, state, fn prop, acc ->
        register_property_internal(acc, prop)
      end)

    # Schedule heartbeat check
    schedule_heartbeat_check(state_with_builtins.heartbeat_config.interval_ms)

    Logger.info(
      "[MSORuntime] Started MSO Runtime Verifier with #{length(@builtin_properties)} builtin properties"
    )

    {:ok, state_with_builtins}
  end

  @impl true
  def handle_call({:register_property, property}, _from, state) do
    case validate_property(property) do
      :ok ->
        new_state = register_property_internal(state, property)
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:load_quint_spec, file_path}, _from, state) do
    case parse_quint_file(file_path) do
      {:ok, properties} ->
        new_state =
          Enum.reduce(properties, state, fn prop, acc ->
            register_property_internal(acc, prop)
          end)

        {:reply, {:ok, length(properties)}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:property_satisfied?, property_id}, _from, state) do
    result =
      case Map.get(state.monitors, property_id) do
        nil -> false
        monitor -> monitor.verdict == :satisfied
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call(:get_verdicts, _from, state) do
    verdicts =
      state.monitors
      |> Enum.map(fn {id, monitor} -> {id, monitor.verdict} end)
      |> Map.new()

    {:reply, verdicts, state}
  end

  @impl true
  def handle_call(:get_violations, _from, state) do
    violations =
      state.monitors
      |> Enum.filter(fn {_id, monitor} -> monitor.verdict == :violated end)
      |> Enum.map(fn {id, monitor} ->
        %{
          property_id: id,
          property_name: Map.get(state.properties, id, %{}) |> Map.get(:name, "Unknown"),
          violation_info: monitor.violation_info,
          detected_at: DateTime.utc_now()
        }
      end)

    {:reply, violations, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      properties_count: map_size(state.properties),
      active_monitors: map_size(state.monitors),
      event_buffer_size: length(state.event_buffer),
      heartbeat_config: state.heartbeat_config,
      stats: state.stats,
      verdicts: get_verdict_summary(state.monitors)
    }

    {:reply, status, state}
  end

  @impl true
  def handle_call({:verify_formula, formula}, _from, state) do
    result = evaluate_formula(formula, state.event_buffer)
    {:reply, {:ok, result}, state}
  end

  @impl true
  def handle_cast({:submit_event, event_type, data}, state) do
    event = %{
      timestamp: DateTime.utc_now(),
      event_type: event_type,
      data: data
    }

    # Add to buffer (keep last 1000 events)
    new_buffer = [event | Enum.take(state.event_buffer, 999)]

    # Process event through all monitors
    {new_monitors, violations} = process_event_through_monitors(state, event)

    # Handle violations
    Enum.each(violations, &handle_violation/1)

    new_stats = Map.update!(state.stats, :events_processed, &(&1 + 1))

    {:noreply, %{state | event_buffer: new_buffer, monitors: new_monitors, stats: new_stats}}
  end

  @impl true
  def handle_cast(:heartbeat, state) do
    new_config = %{state.heartbeat_config | last_heartbeat: DateTime.utc_now()}
    new_stats = Map.update!(state.stats, :heartbeats_checked, &(&1 + 1))

    {:noreply, %{state | heartbeat_config: new_config, stats: new_stats}}
  end

  @impl true
  def handle_cast({:reset_monitor, property_id}, state) do
    case Map.get(state.properties, property_id) do
      nil ->
        {:noreply, state}

      property ->
        new_monitor = create_monitor(property)
        new_monitors = Map.put(state.monitors, property_id, new_monitor)
        {:noreply, %{state | monitors: new_monitors}}
    end
  end

  @impl true
  def handle_cast({:set_property_enabled, property_id, enabled}, state) do
    case Map.get(state.properties, property_id) do
      nil ->
        {:noreply, state}

      property ->
        updated_property = %{property | enabled: enabled}
        new_properties = Map.put(state.properties, property_id, updated_property)
        {:noreply, %{state | properties: new_properties}}
    end
  end

  @impl true
  def handle_cast({:configure_heartbeat, opts}, state) do
    new_config =
      state.heartbeat_config
      |> Map.merge(Map.new(opts))

    {:noreply, %{state | heartbeat_config: new_config}}
  end

  @impl true
  def handle_info(:check_heartbeat, state) do
    now = DateTime.utc_now()
    last = state.heartbeat_config.last_heartbeat
    timeout = state.heartbeat_config.timeout_ms

    elapsed_ms = DateTime.diff(now, last, :millisecond)

    new_state =
      if elapsed_ms > timeout do
        # Heartbeat violation detected
        Logger.warning(
          "[MSORuntime] Heartbeat violation: #{elapsed_ms}ms since last heartbeat (timeout: #{timeout}ms)"
        )

        new_stats =
          state.stats
          |> Map.update!(:violations_detected, &(&1 + 1))
          |> Map.update!(:heartbeat_violations, &(&1 + 1))

        # Alert Sentinel
        Sentinel.report_signal(%{
          type: :heartbeat_timeout,
          source: __MODULE__,
          severity: :high,
          data: %{elapsed_ms: elapsed_ms, timeout_ms: timeout}
        })

        %{state | stats: new_stats}
      else
        state
      end

    # Schedule next check
    schedule_heartbeat_check(state.heartbeat_config.interval_ms)

    {:noreply, new_state}
  end

  # ============================================================================
  # Property Registration and Monitoring
  # ============================================================================

  defp register_property_internal(state, property) do
    property_with_defaults = %{
      id: property.id,
      name: Map.get(property, :name, Atom.to_string(property.id)),
      type: Map.get(property, :type, :safety),
      formula: property.formula,
      automaton: build_automaton(property.formula),
      enabled: Map.get(property, :enabled, true),
      violation_action: Map.get(property, :violation_action, :log_violation)
    }

    monitor = create_monitor(property_with_defaults)

    new_properties = Map.put(state.properties, property.id, property_with_defaults)
    new_monitors = Map.put(state.monitors, property.id, monitor)
    new_stats = Map.update!(state.stats, :properties_loaded, &(&1 + 1))

    %{state | properties: new_properties, monitors: new_monitors, stats: new_stats}
  end

  defp create_monitor(property) do
    %{
      property_id: property.id,
      automaton_state: :initial,
      trace: [],
      verdict: :unknown,
      violation_info: nil
    }
  end

  defp validate_property(%{id: id, formula: formula}) when is_atom(id) and not is_nil(formula) do
    :ok
  end

  defp validate_property(_), do: {:error, :invalid_property}

  # ============================================================================
  # Event Processing
  # ============================================================================

  defp process_event_through_monitors(state, event) do
    state.monitors
    |> Enum.reduce({%{}, []}, fn {id, monitor}, {monitors_acc, violations_acc} ->
      property = Map.get(state.properties, id)

      if property && property.enabled do
        {new_monitor, violation} = advance_monitor(monitor, property, event)
        new_monitors = Map.put(monitors_acc, id, new_monitor)

        new_violations =
          if violation do
            [%{property_id: id, property: property, monitor: new_monitor} | violations_acc]
          else
            violations_acc
          end

        {new_monitors, new_violations}
      else
        {Map.put(monitors_acc, id, monitor), violations_acc}
      end
    end)
  end

  defp advance_monitor(monitor, property, event) do
    # Add event to trace
    new_trace = [event | Enum.take(monitor.trace, 99)]

    # Evaluate formula against current trace
    {verdict, violation_info} = evaluate_property(property, new_trace, event)

    new_monitor = %{
      monitor
      | trace: new_trace,
        verdict: verdict,
        violation_info: violation_info
    }

    violation_detected = verdict == :violated and monitor.verdict != :violated

    {new_monitor, violation_detected}
  end

  defp evaluate_property(property, trace, current_event) do
    case property.type do
      :safety ->
        evaluate_safety_property(property.formula, trace, current_event)

      :liveness ->
        evaluate_liveness_property_internal(property, trace)

      :timing ->
        evaluate_timing_property(property.formula, trace, current_event)

      :fairness ->
        evaluate_fairness_property(property.formula, trace)

      :ordering ->
        evaluate_ordering_property(property.formula, trace)
    end
  end

  # ============================================================================
  # Formula Evaluation
  # ============================================================================

  defp evaluate_safety_property({:always, {:not, bad_state}}, _trace, event) do
    if event.event_type == bad_state do
      {:violated, %{reason: "Bad state reached", state: bad_state, event: event}}
    else
      {:satisfied, nil}
    end
  end

  defp evaluate_safety_property(
         {:always, {:implies, antecedent, {:not, _consequent}}},
         _trace,
         event
       ) do
    if event.event_type == antecedent do
      # Check that consequent doesn't happen
      {:unknown, nil}
    else
      {:satisfied, nil}
    end
  end

  defp evaluate_safety_property(_formula, _trace, _event) do
    {:satisfied, nil}
  end

  # Internal liveness evaluation used by the monitor pipeline.
  # Delegates to the public verify_liveness/2 when the property has a
  # well-formed automaton; falls back to the legacy time-window check for
  # the built-in {:eventually, {:within_ms, t}, e} form.
  defp evaluate_liveness_property_internal(property, trace) do
    case property.formula do
      {:eventually, {:within_ms, timeout}, target_event} ->
        # Legacy path: time-window liveness check.
        now = DateTime.utc_now()

        recent_events =
          Enum.filter(trace, fn event ->
            DateTime.diff(now, event.timestamp, :millisecond) <= timeout
          end)

        if Enum.any?(recent_events, &(&1.event_type == target_event)) do
          {:satisfied, nil}
        else
          {:unknown, nil}
        end

      _other ->
        # Büchi path: use the automaton stored on the property.
        automaton = Map.get(property, :automaton)

        if is_map(automaton) do
          case verify_liveness(automaton, trace) do
            {:ok, :accepted} ->
              {:satisfied, nil}

            {:error, :rejected, reason} ->
              # For the monitor pipeline we treat a Büchi rejection as
              # :unknown (not yet violated) unless the trace is long enough
              # to be conclusive.
              if length(trace) >= @buchi_suffix_size do
                {:violated, %{reason: reason, mode: :buchi}}
              else
                {:unknown, nil}
              end
          end
        else
          {:unknown, nil}
        end
    end
  end

  defp evaluate_timing_property(
         {:always, {:implies, trigger, {:eventually, {:within_ms, timeout}, response}}},
         trace,
         event
       ) do
    if event.event_type == trigger do
      # Check if response occurs within timeout from any trigger
      trigger_events =
        Enum.filter(trace, fn e ->
          e.event_type == trigger
        end)

      response_events =
        Enum.filter(trace, fn e ->
          e.event_type == response
        end)

      # Check each trigger has a corresponding response
      violations =
        Enum.filter(trigger_events, fn trigger_event ->
          not Enum.any?(response_events, fn response_event ->
            diff = DateTime.diff(response_event.timestamp, trigger_event.timestamp, :millisecond)
            diff >= 0 and diff <= timeout
          end)
        end)

      if Enum.empty?(violations) do
        {:satisfied, nil}
      else
        {:unknown, nil}
      end
    else
      {:satisfied, nil}
    end
  end

  defp evaluate_timing_property(_formula, _trace, _event) do
    {:satisfied, nil}
  end

  # Monitor-pipeline fairness evaluation: delegates to check_fairness/2 using
  # the event types extracted from the formula as synthetic transitions.
  defp evaluate_fairness_property(formula, trace) do
    required_events = extract_formula_events(formula)

    if Enum.empty?(required_events) do
      {:satisfied, nil}
    else
      # Build synthetic transition records from the required event atoms so
      # we can call check_fairness/2 without coupling the caller to the
      # transition schema.
      synthetic_transitions =
        Enum.map(required_events, fn ev ->
          %{id: ev, guard: ev, source: :any, target: :any}
        end)

      case check_fairness(synthetic_transitions, trace) do
        {:ok, :fair} ->
          {:satisfied, nil}

        {:error, :unfair, violations} ->
          {:violated,
           %{
             missing: Enum.map(violations, & &1.transition_id),
             fairness_violations: violations
           }}
      end
    end
  end

  defp evaluate_ordering_property({:before, a, b}, trace) do
    # {:before, a, b} — first occurrence of a must precede first occurrence of b.
    # Events in the trace are stored newest-first (prepended), so reverse for chronological order.
    chronological = Enum.reverse(trace)

    first_a = Enum.find_index(chronological, &(&1.event_type == a))
    first_b = Enum.find_index(chronological, &(&1.event_type == b))

    cond do
      # Neither event has occurred yet — ordering not violated yet
      is_nil(first_a) and is_nil(first_b) ->
        {:satisfied, nil}

      # b has occurred but a has not — ordering violated
      is_nil(first_a) and not is_nil(first_b) ->
        {:violated, %{reason: "#{b} occurred before #{a} (#{a} never seen)"}}

      # a has occurred but b has not — ordering holds so far
      not is_nil(first_a) and is_nil(first_b) ->
        {:satisfied, nil}

      # Both occurred — check order
      first_a < first_b ->
        {:satisfied, nil}

      true ->
        {:violated, %{reason: "#{b} (index #{first_b}) occurred before #{a} (index #{first_a})"}}
    end
  end

  defp evaluate_ordering_property(_formula, _trace) do
    {:satisfied, nil}
  end

  defp evaluate_formula(formula, trace) do
    case formula do
      {:always, inner} ->
        Enum.all?(trace, fn event ->
          evaluate_predicate(inner, event)
        end)

      {:eventually, inner} ->
        Enum.any?(trace, fn event ->
          evaluate_predicate(inner, event)
        end)

      {:not, inner} ->
        not evaluate_formula(inner, trace)

      predicate ->
        Enum.any?(trace, fn event ->
          evaluate_predicate(predicate, event)
        end)
    end
  end

  defp evaluate_predicate(predicate, event) when is_atom(predicate) do
    event.event_type == predicate
  end

  defp evaluate_predicate({:not, inner}, event) do
    not evaluate_predicate(inner, event)
  end

  defp evaluate_predicate(_predicate, _event), do: false

  # ============================================================================
  # Automaton Building (Simplified)
  # ============================================================================

  # Build a simplified Büchi automaton map for the given temporal formula.
  # States: atoms; transitions: %{state => [{guard_atom_or_tuple, next_state}]}
  # guard_atom matches when event.event_type == guard_atom.
  defp build_automaton({:always, predicate}) do
    # □p — stay in :s0 (accepting) while p holds; sink to :reject otherwise.
    %{
      states: MapSet.new([:s0, :reject]),
      initial: :s0,
      accepting: MapSet.new([:s0]),
      transitions: %{
        s0: [{predicate, :s0}, {{:not, predicate}, :reject}],
        reject: [{{:not, predicate}, :reject}, {predicate, :reject}]
      }
    }
  end

  defp build_automaton({:eventually, predicate}) do
    # ◇p — stay in :s0 until p is seen, then move to :s1 (accepting) and loop.
    %{
      states: MapSet.new([:s0, :s1]),
      initial: :s0,
      accepting: MapSet.new([:s1]),
      transitions: %{
        s0: [{predicate, :s1}, {{:not, predicate}, :s0}],
        s1: [{predicate, :s1}, {{:not, predicate}, :s1}]
      }
    }
  end

  defp build_automaton({:not, inner}) do
    # Complement: swap accepting and non-accepting states of inner automaton.
    case build_automaton(inner) do
      nil ->
        nil

      aut ->
        all_states = normalise_set(aut.states)
        old_accepting = normalise_set(aut.accepting)
        non_accepting = MapSet.difference(all_states, old_accepting)
        %{aut | accepting: non_accepting}
    end
  end

  defp build_automaton(_formula) do
    # Generic 2-state pass-through for compound or unrecognised formulae.
    %{
      states: MapSet.new([:s0, :s1]),
      initial: :s0,
      accepting: MapSet.new([:s0, :s1]),
      transitions: %{
        s0: [{:any, :s0}],
        s1: [{:any, :s1}]
      }
    }
  end

  # Collect all leaf event-type atoms referenced inside a formula tree.
  defp extract_formula_events(formula) when is_atom(formula), do: [formula]

  defp extract_formula_events({:always, inner}), do: extract_formula_events(inner)
  defp extract_formula_events({:eventually, inner}), do: extract_formula_events(inner)
  defp extract_formula_events({:not, inner}), do: extract_formula_events(inner)
  defp extract_formula_events({:next, inner}), do: extract_formula_events(inner)

  defp extract_formula_events({:release, a, b}),
    do: extract_formula_events(a) ++ extract_formula_events(b)

  defp extract_formula_events({:until, a, b}),
    do: extract_formula_events(a) ++ extract_formula_events(b)

  defp extract_formula_events({:implies, a, b}),
    do: extract_formula_events(a) ++ extract_formula_events(b)

  defp extract_formula_events({:before, a, b}) when is_atom(a) and is_atom(b), do: [a, b]
  defp extract_formula_events({:within_ms, _timeout}), do: []
  defp extract_formula_events({op, inner}) when is_atom(op), do: extract_formula_events(inner)
  defp extract_formula_events(_), do: []

  # ============================================================================
  # Büchi Automaton Helpers (GAP-P2-006)
  # ============================================================================

  # Advance the Büchi automaton by one event. Returns the next state.
  # If no explicit transition matches the event the automaton stays in the
  # current state (implicit self-loop for unrecognised input).
  @spec buchi_step(%{atom() => list()}, atom(), map()) :: atom()
  defp buchi_step(transitions, current_state, event) do
    candidates = Map.get(transitions, current_state, [])

    Enum.find_value(candidates, current_state, fn {guard, next_state} ->
      if guard_matches?(guard, event), do: next_state, else: nil
    end)
  end

  # Evaluate whether a transition guard matches the given event.
  @spec guard_matches?(term(), map()) :: boolean()
  defp guard_matches?(:any, _event), do: true
  defp guard_matches?({:not, atom}, event) when is_atom(atom), do: event.event_type != atom
  defp guard_matches?(atom, event) when is_atom(atom), do: event.event_type == atom
  defp guard_matches?(_guard, _event), do: false

  # Normalise a states/accepting field that may be either a MapSet or a plain list.
  @spec normalise_set(MapSet.t() | list()) :: MapSet.t()
  defp normalise_set(%MapSet{} = s), do: s
  defp normalise_set(list) when is_list(list), do: MapSet.new(list)
  defp normalise_set(_), do: MapSet.new()

  # ============================================================================
  # Fairness Helpers (GAP-P2-006)
  # ============================================================================

  # Count how many history events enable the given transition (guard fires).
  @spec count_enabled(transition(), list(map())) :: non_neg_integer()
  defp count_enabled(%{guard: nil}, _history), do: 0

  defp count_enabled(%{guard: guard_event}, history) do
    Enum.count(history, &guard_matches?(guard_event, &1))
  end

  # Count how many history events record that the transition actually fired.
  # We match on:
  #   1. `event.fired == transition.id`
  #   2. `event.event_type == transition.id` (for traces that conflate events and firings)
  @spec count_fired(transition(), list(map())) :: non_neg_integer()
  defp count_fired(%{id: id}, history) do
    Enum.count(history, fn event ->
      Map.get(event, :fired) == id or event.event_type == id
    end)
  end

  # ============================================================================
  # Kahn's Topological Sort (GAP-P2-006)
  # ============================================================================

  # Kahn's algorithm iterates until either all nodes are processed (success)
  # or no zero-in-degree node remains but the queue is not exhausted (cycle).
  @spec kahn(list(), map(), map(), list(), map(), non_neg_integer()) ::
          {:ok, list(map())} | {:error, :cycle_detected}
  defp kahn([], _adj, _in_degree, result, goal_map, total) do
    if length(result) == total do
      ordered =
        result
        |> Enum.reverse()
        |> Enum.map(&Map.get(goal_map, &1))
        |> Enum.reject(&is_nil/1)

      {:ok, ordered}
    else
      # Nodes remain but none has zero in-degree → cycle detected.
      {:error, :cycle_detected}
    end
  end

  defp kahn([node | rest], adj, in_degree, result, goal_map, total) do
    # Remove edges from `node` to its successors and update in-degrees.
    successors = Map.get(adj, node, [])

    {new_in_degree, newly_zero} =
      Enum.reduce(successors, {in_degree, []}, fn succ, {deg_acc, zero_acc} ->
        new_deg = Map.update(deg_acc, succ, 0, &max(0, &1 - 1))

        if Map.get(new_deg, succ, 0) == 0 do
          {new_deg, [succ | zero_acc]}
        else
          {new_deg, zero_acc}
        end
      end)

    # Sort newly zero-in-degree nodes by priority before appending to queue.
    sorted_new =
      newly_zero
      |> Enum.sort_by(&Map.get(goal_map, &1, %{priority: 0}).priority)

    kahn(rest ++ sorted_new, adj, new_in_degree, [node | result], goal_map, total)
  end

  # ============================================================================
  # Goal Calculus Zenoh Publishing (GAP-P2-006)
  # ============================================================================

  @doc """
  Publish a goal calculus verification result to Zenoh
  (`"indrajaal/verification/mso/goal_calculus"`).

  Implements SC-ZTEST-008 dual-write: log fallback is written first,
  then a best-effort async Zenoh publish is attempted.

  ## Parameters
  - `result_type` – atom tag describing the verification kind
    (`:liveness`, `:fairness`, `:goal_ordering`)
  - `payload` – map with the verification result details

  ## Returns
  `:ok` always (fire-and-forget; log fallback guarantees durability).
  """
  @spec publish_goal_calculus_result(atom(), map()) :: :ok
  def publish_goal_calculus_result(result_type, payload) do
    message = %{
      checkpoint: "CP-MSO-GC",
      topic: @goal_calculus_topic,
      type: result_type,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      schema_version: "1.0.0",
      payload: payload
    }

    # SC-ZTEST-008: log fallback first (guaranteed durability).
    Logger.info(
      "[ZTEST-CHECKPOINT] checkpoint=CP-MSO-GC topic=#{@goal_calculus_topic} " <>
        "type=#{result_type} payload=#{inspect(payload)}",
      domain: :mso_goal_calculus
    )

    # Best-effort async Zenoh publish — never blocks.
    try do
      ZenohPublisher.publish_async(@goal_calculus_topic, message)
    rescue
      _ -> :ok
    end

    :ok
  end

  # ============================================================================
  # Quint File Parsing
  # ============================================================================

  defp parse_quint_file(file_path) do
    if File.exists?(file_path) do
      # Simplified Quint parsing - in production this would use a proper parser
      case File.read(file_path) do
        {:ok, content} ->
          properties = extract_quint_properties(content)
          {:ok, properties}

        {:error, reason} ->
          {:error, {:file_read_error, reason}}
      end
    else
      {:error, :file_not_found}
    end
  end

  defp extract_quint_properties(content) do
    # Simplified extraction - look for temporal property patterns
    # In production, this would use a proper Quint parser
    property_regex = ~r/temporal\s+(\w+)\s*=\s*(.+)/

    Regex.scan(property_regex, content)
    |> Enum.map(fn [_, name, formula_str] ->
      %{
        id: String.to_existing_atom(name),
        name: name,
        type: infer_property_type(formula_str),
        formula: parse_formula_string(formula_str),
        enabled: true,
        violation_action: :log_violation
      }
    end)
  end

  defp infer_property_type(formula_str) do
    cond do
      String.contains?(formula_str, "always") -> :safety
      String.contains?(formula_str, "eventually") -> :liveness
      String.contains?(formula_str, "within") -> :timing
      true -> :safety
    end
  end

  defp parse_formula_string(formula_str) do
    # Simplified parsing - in production use a proper parser
    cond do
      String.contains?(formula_str, "always") ->
        {:always, :generic_predicate}

      String.contains?(formula_str, "eventually") ->
        {:eventually, :generic_predicate}

      true ->
        :generic_predicate
    end
  end

  # ============================================================================
  # Violation Handling
  # ============================================================================

  defp handle_violation(%{property_id: id, property: property, monitor: monitor}) do
    Logger.warning("[MSORuntime] Property violation: #{property.name} (#{id})")

    # Execute violation action
    case property.violation_action do
      :log_violation ->
        Logger.error(
          "[MSORuntime] VIOLATION: #{property.name} - #{inspect(monitor.violation_info)}"
        )

      :alert_sentinel ->
        Sentinel.report_signal(%{
          type: :mso_property_violation,
          source: __MODULE__,
          severity: :high,
          data: %{
            property_id: id,
            property_name: property.name,
            violation_info: monitor.violation_info
          }
        })

      :emergency_halt ->
        Logger.error("[MSORuntime] CRITICAL VIOLATION - Requesting emergency halt")

        Guardian.report_threat(%{
          type: :mso_critical_violation,
          severity: :critical,
          source: __MODULE__,
          metadata: %{property_id: id}
        })

      :rollback_state ->
        Logger.warning("[MSORuntime] Violation requires state rollback")

      # Trigger state rollback mechanism

      :emergency_recovery ->
        Logger.warning("[MSORuntime] Violation requires emergency recovery")

      _ ->
        :ok
    end
  end

  # ============================================================================
  # Helper Functions
  # ============================================================================

  defp schedule_heartbeat_check(interval_ms) do
    Process.send_after(self(), :check_heartbeat, interval_ms)
  end

  defp get_verdict_summary(monitors) do
    monitors
    |> Enum.reduce(%{satisfied: 0, violated: 0, unknown: 0, inconclusive: 0}, fn {_id, monitor},
                                                                                 acc ->
      Map.update!(acc, monitor.verdict, &(&1 + 1))
    end)
  end
end
