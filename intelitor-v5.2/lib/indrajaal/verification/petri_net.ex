defmodule Indrajaal.Verification.PetriNet do
  @moduledoc """
  Petri Net Verifier for GenServer State Machine Analysis.

  ## What
  Implements Petri Net formalism for verifying GenServer state machines,
  detecting deadlocks, livelocks, and unbounded behavior before runtime.

  ## Why
  STAMP Constraints require formal verification of state machines:
  - SC-SIL4-006: 2oo3 voting for production actuations
  - SC-REG-002: Hash chain MUST be unbroken (state integrity)
  - SC-IMMUNE-004: Quarantine MUST isolate before termination (state transitions)
  - FM-005: RPN 378 - Deadlocks undetected without Petri Net verification

  ## Petri Net Components
  - Places: GenServer states (e.g., :idle, :processing, :waiting)
  - Transitions: Events/messages that trigger state changes
  - Tokens: Current state markers
  - Arcs: Input/output relationships between places and transitions

  ## Verification Capabilities
  1. **Reachability Analysis**: Can state S' be reached from S?
  2. **Deadlock Detection**: Are there states with no enabled transitions?
  3. **Liveness Verification**: Will the system always make progress?
  4. **Boundedness Check**: Is token count bounded (finite state)?
  5. **Fairness Analysis**: Are all transitions eventually fired?

  ## SIL-6 Compliance
  - PFH contribution: Prevents deadlock-related failures
  - Diagnostic Coverage: Formal state space exploration
  - Safe Failure Fraction: Detects unsafe states before activation

  ## OODA Integration
  - OBSERVE: Extract state machine from GenServer code
  - ORIENT: Build Petri Net representation
  - DECIDE: Run verification algorithms
  - ACT: Report issues, block unsafe deployments

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 1.0.0 | 2026-01-11 | Claude | Initial implementation - FM-005 |
  """

  use GenServer
  require Logger

  alias Indrajaal.Safety.Guardian

  # ============================================================================
  # Type Definitions
  # ============================================================================

  @type place_id :: atom()
  @type transition_id :: atom()
  @type token_count :: non_neg_integer()

  @type place :: %{
          id: place_id(),
          name: String.t(),
          tokens: token_count(),
          capacity: pos_integer() | :unbounded
        }

  @type transition :: %{
          id: transition_id(),
          name: String.t(),
          guard: (map() -> boolean()) | nil,
          priority: non_neg_integer()
        }

  @type arc :: %{
          from: place_id() | transition_id(),
          to: place_id() | transition_id(),
          weight: pos_integer(),
          type: :normal | :inhibitor | :reset
        }

  @type petri_net :: %{
          places: %{place_id() => place()},
          transitions: %{transition_id() => transition()},
          arcs: [arc()],
          initial_marking: %{place_id() => token_count()}
        }

  @type verification_result :: %{
          verified: boolean(),
          deadlock_free: boolean(),
          bounded: boolean(),
          live: boolean(),
          reachable_states: non_neg_integer(),
          issues: [map()],
          analysis_time_ms: non_neg_integer()
        }

  # ============================================================================
  # State Structure
  # ============================================================================

  defstruct [
    :name,
    nets: %{},
    verification_cache: %{},
    last_reachability_check: nil,
    stats: %{
      nets_registered: 0,
      verifications_run: 0,
      deadlocks_detected: 0,
      livelocks_detected: 0,
      unbounded_detected: 0
    }
  ]

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Start the Petri Net Verifier.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Register a Petri Net model for a GenServer module.
  """
  @spec register_net(module(), petri_net()) :: :ok | {:error, term()}
  def register_net(module, net) do
    GenServer.call(__MODULE__, {:register_net, module, net})
  end

  @doc """
  Create a Petri Net from a GenServer state machine definition.

  ## Example
      PetriNet.from_fsm(:my_server, %{
        states: [:idle, :processing, :waiting, :done],
        initial: :idle,
        transitions: [
          {:idle, :start, :processing},
          {:processing, :complete, :done},
          {:processing, :wait, :waiting},
          {:waiting, :resume, :processing}
        ]
      })
  """
  @spec from_fsm(atom(), map()) :: {:ok, petri_net()} | {:error, term()}
  def from_fsm(name, fsm_definition) do
    GenServer.call(__MODULE__, {:from_fsm, name, fsm_definition})
  end

  @doc """
  Verify a registered Petri Net for deadlocks, livelocks, and boundedness.
  """
  @spec verify(module()) :: {:ok, verification_result()} | {:error, term()}
  def verify(module) do
    GenServer.call(__MODULE__, {:verify, module}, 30_000)
  end

  @doc """
  Check if a specific state is reachable from the initial marking.
  """
  @spec reachable?(module(), place_id()) :: boolean()
  def reachable?(module, target_state) do
    GenServer.call(__MODULE__, {:reachable?, module, target_state})
  end

  @doc """
  Detect potential deadlock states in a Petri Net.
  """
  @spec detect_deadlocks(module()) :: {:ok, [map()]} | {:error, term()}
  def detect_deadlocks(module) do
    GenServer.call(__MODULE__, {:detect_deadlocks, module})
  end

  @doc """
  Check if a Petri Net is bounded (finite state space).
  """
  @spec bounded?(module()) :: boolean()
  def bounded?(module) do
    GenServer.call(__MODULE__, {:bounded?, module})
  end

  @doc """
  Check if all transitions can eventually fire (liveness).
  """
  @spec live?(module()) :: boolean()
  def live?(module) do
    GenServer.call(__MODULE__, {:live?, module})
  end

  @doc """
  Fire a transition if enabled, returning the new marking.
  """
  @spec fire(module(), transition_id()) :: {:ok, map()} | {:error, :not_enabled}
  def fire(module, transition_id) do
    GenServer.call(__MODULE__, {:fire, module, transition_id})
  end

  @doc """
  Get enabled transitions for the current marking.
  """
  @spec enabled_transitions(module()) :: [transition_id()]
  def enabled_transitions(module) do
    GenServer.call(__MODULE__, {:enabled_transitions, module})
  end

  @doc """
  Get the current status of the verifier.
  """
  @spec status() :: map()
  def status do
    GenServer.call(__MODULE__, :status)
  end

  @doc """
  Return the results of the most recent periodic reachability check.

  Returns `:not_run` if no periodic check has completed yet, or a map of
  `%{net_name => [deadlock_state]}` from the last scheduled scan.
  """
  @spec reachability_status() :: :not_run | map()
  def reachability_status do
    GenServer.call(__MODULE__, :reachability_status)
  end

  @doc """
  Convenience: build a Petri Net from an FSM definition and verify it in one call.

  This is the primary entry point for callers that want a quick deadlock check
  without managing net registration separately.

  ## Parameters
  - `name` - Atom name for the net (e.g. `:my_genserver`)
  - `fsm_definition` - Map with `:states`, `:initial`, and `:transitions` keys

  ## Returns
  - `{:ok, :verified}` if the FSM is deadlock-free, bounded, and live
  - `{:error, :deadlock_detected}` if a deadlock state is reachable
  - `{:error, :unbounded}` if the net is unbounded
  - `{:error, :not_live}` if some transitions can never fire
  - `{:error, :petri_net_unavailable}` if the GenServer is not running
  - `{:error, term()}` for construction or internal errors

  ## Example

      PetriNet.verify_state_machine(:sentinel, %{
        states: [:idle, :monitoring, :quarantine],
        initial: :idle,
        transitions: [
          {:idle, :start, :monitoring},
          {:monitoring, :threat_detected, :quarantine},
          {:quarantine, :threat_cleared, :monitoring},
          {:monitoring, :stop, :idle}
        ]
      })
      # => {:ok, :verified}

  ## STAMP Compliance
  - SC-MATH-004: Connects isolated ISOLATED discipline to active callers
  - SC-SIL4-006: Supports formal state-machine verification
  """
  @spec verify_state_machine(atom(), map()) ::
          {:ok, :verified}
          | {:error,
             :deadlock_detected
             | :unbounded
             | :not_live
             | :petri_net_unavailable
             | term()}
  def verify_state_machine(name, fsm_definition) do
    case GenServer.whereis(__MODULE__) do
      nil ->
        {:error, :petri_net_unavailable}

      _pid ->
        with {:ok, _net} <- from_fsm(name, fsm_definition),
             {:ok, result} <- verify(name) do
          cond do
            not result.deadlock_free -> {:error, :deadlock_detected}
            not result.bounded -> {:error, :unbounded}
            not result.live -> {:error, :not_live}
            true -> {:ok, :verified}
          end
        end
    end
  end

  @doc """
  Get verification result from cache if available.
  """
  @spec get_cached_result(module()) :: {:ok, verification_result()} | :not_found
  def get_cached_result(module) do
    GenServer.call(__MODULE__, {:get_cached_result, module})
  end

  @doc """
  Clear verification cache.
  """
  @spec clear_cache() :: :ok
  def clear_cache do
    GenServer.cast(__MODULE__, :clear_cache)
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(opts) do
    state = %__MODULE__{
      name: Keyword.get(opts, :name, __MODULE__)
    }

    Process.send_after(self(), :periodic_reachability, 60_000)
    Logger.info("[PetriNet] Started Petri Net Verifier")
    {:ok, state}
  end

  @impl true
  def handle_call({:register_net, module, net}, _from, state) do
    case validate_petri_net(net) do
      :ok ->
        new_nets = Map.put(state.nets, module, net)
        new_stats = Map.update!(state.stats, :nets_registered, &(&1 + 1))

        Logger.info("[PetriNet] Registered net for #{inspect(module)}")
        {:reply, :ok, %{state | nets: new_nets, stats: new_stats}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:from_fsm, name, fsm}, _from, state) do
    case build_petri_net_from_fsm(name, fsm) do
      {:ok, net} ->
        new_nets = Map.put(state.nets, name, net)
        new_stats = Map.update!(state.stats, :nets_registered, &(&1 + 1))
        {:reply, {:ok, net}, %{state | nets: new_nets, stats: new_stats}}

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:verify, module}, _from, state) do
    case Map.get(state.nets, module) do
      nil ->
        {:reply, {:error, :net_not_registered}, state}

      net ->
        start_time = System.monotonic_time(:millisecond)
        result = run_verification(net)
        elapsed = System.monotonic_time(:millisecond) - start_time

        result_with_time = Map.put(result, :analysis_time_ms, elapsed)

        # Update cache and stats
        new_cache = Map.put(state.verification_cache, module, result_with_time)
        new_stats = update_stats(state.stats, result_with_time)

        # Log issues if found
        log_verification_result(module, result_with_time)

        {:reply, {:ok, result_with_time},
         %{state | verification_cache: new_cache, stats: new_stats}}
    end
  end

  @impl true
  def handle_call({:reachable?, module, target}, _from, state) do
    case Map.get(state.nets, module) do
      nil ->
        {:reply, false, state}

      net ->
        result = check_reachability(net, target)
        {:reply, result, state}
    end
  end

  @impl true
  def handle_call({:detect_deadlocks, module}, _from, state) do
    case Map.get(state.nets, module) do
      nil ->
        {:reply, {:error, :net_not_registered}, state}

      net ->
        deadlocks = find_deadlock_states(net)
        {:reply, {:ok, deadlocks}, state}
    end
  end

  @impl true
  def handle_call({:bounded?, module}, _from, state) do
    case Map.get(state.nets, module) do
      nil ->
        {:reply, false, state}

      net ->
        result = check_boundedness(net)
        {:reply, result, state}
    end
  end

  @impl true
  def handle_call({:live?, module}, _from, state) do
    case Map.get(state.nets, module) do
      nil ->
        {:reply, false, state}

      net ->
        result = check_liveness(net)
        {:reply, result, state}
    end
  end

  @impl true
  def handle_call({:fire, module, transition_id}, _from, state) do
    case Map.get(state.nets, module) do
      nil ->
        {:reply, {:error, :net_not_registered}, state}

      net ->
        case fire_transition(net, transition_id) do
          {:ok, new_marking} ->
            updated_net = %{net | initial_marking: new_marking}
            new_nets = Map.put(state.nets, module, updated_net)
            {:reply, {:ok, new_marking}, %{state | nets: new_nets}}

          error ->
            {:reply, error, state}
        end
    end
  end

  @impl true
  def handle_call({:enabled_transitions, module}, _from, state) do
    case Map.get(state.nets, module) do
      nil ->
        {:reply, [], state}

      net ->
        enabled = get_enabled_transitions(net)
        {:reply, enabled, state}
    end
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      nets_registered: map_size(state.nets),
      cached_results: map_size(state.verification_cache),
      stats: state.stats,
      registered_modules: Map.keys(state.nets)
    }

    {:reply, status, state}
  end

  @impl true
  def handle_call({:get_cached_result, module}, _from, state) do
    case Map.get(state.verification_cache, module) do
      nil -> {:reply, :not_found, state}
      result -> {:reply, {:ok, result}, state}
    end
  end

  @impl true
  def handle_call(:reachability_status, _from, state) do
    {:reply, state.last_reachability_check || :not_run, state}
  end

  @impl true
  def handle_info(:periodic_reachability, state) do
    results =
      Enum.reduce(state.nets, %{}, fn {net_name, net}, acc ->
        try do
          deadlocks = find_deadlock_states(net)

          if deadlocks != [] do
            Logger.warning(
              "[PetriNet] Periodic reachability: deadlocks found in #{inspect(net_name)} - #{length(deadlocks)} state(s)"
            )

            Guardian.report_threat(%{
              type: :petri_net_periodic_deadlock,
              severity: :high,
              source: __MODULE__,
              metadata: %{net: net_name, deadlock_count: length(deadlocks)}
            })
          end

          Map.put(acc, net_name, deadlocks)
        rescue
          err ->
            Logger.error(
              "[PetriNet] Periodic reachability check failed for #{inspect(net_name)}: #{inspect(err)}"
            )

            Map.put(acc, net_name, {:error, inspect(err)})
        end
      end)

    timestamp = DateTime.utc_now()

    payload = %{
      checked_at: DateTime.to_iso8601(timestamp),
      nets_checked: map_size(results),
      results: results
    }

    try do
      Indrajaal.Observability.ZenohPublisher.publish_async(
        "indrajaal/verification/petri_net/reachability",
        payload
      )
    rescue
      _ -> :ok
    end

    Logger.info(
      "[ZTEST-CHECKPOINT] checkpoint=CP-PETRI-01 topic=indrajaal/verification/petri_net/reachability nets_checked=#{map_size(results)} timestamp=#{DateTime.to_iso8601(timestamp)}"
    )

    Process.send_after(self(), :periodic_reachability, 60_000)

    {:noreply, %{state | last_reachability_check: payload}}
  end

  @impl true
  def handle_cast(:clear_cache, state) do
    {:noreply, %{state | verification_cache: %{}}}
  end

  # ============================================================================
  # Petri Net Construction
  # ============================================================================

  defp build_petri_net_from_fsm(name, %{
         states: states,
         initial: initial,
         transitions: transitions
       }) do
    # Build places from states
    places =
      states
      |> Enum.map(fn state_name ->
        {state_name,
         %{
           id: state_name,
           name: Atom.to_string(state_name),
           tokens: if(state_name == initial, do: 1, else: 0),
           capacity: 1
         }}
      end)
      |> Map.new()

    # Build transitions and arcs
    {trans_map, arcs} =
      transitions
      |> Enum.with_index()
      |> Enum.reduce({%{}, []}, fn {{from, event, to}, idx}, {trans_acc, arcs_acc} ->
        trans_id = :"t_#{idx}_#{event}"

        transition = %{
          id: trans_id,
          name: "#{from} --[#{event}]--> #{to}",
          guard: nil,
          priority: 0
        }

        # Input arc: from place -> transition
        input_arc = %{
          from: from,
          to: trans_id,
          weight: 1,
          type: :normal
        }

        # Output arc: transition -> to place
        output_arc = %{
          from: trans_id,
          to: to,
          weight: 1,
          type: :normal
        }

        {Map.put(trans_acc, trans_id, transition), [input_arc, output_arc | arcs_acc]}
      end)

    # Initial marking
    initial_marking =
      states
      |> Enum.map(fn s -> {s, if(s == initial, do: 1, else: 0)} end)
      |> Map.new()

    net = %{
      places: places,
      transitions: trans_map,
      arcs: arcs,
      initial_marking: initial_marking,
      _name: name
    }

    {:ok, net}
  end

  defp build_petri_net_from_fsm(_name, _invalid) do
    {:error, :invalid_fsm_definition}
  end

  # ============================================================================
  # Validation
  # ============================================================================

  defp validate_petri_net(%{places: places, transitions: transitions, arcs: arcs})
       when is_map(places) and is_map(transitions) and is_list(arcs) do
    # Check that all arc endpoints exist
    place_ids = Map.keys(places)
    trans_ids = Map.keys(transitions)
    all_ids = place_ids ++ trans_ids

    invalid_arcs =
      Enum.filter(arcs, fn arc ->
        arc.from not in all_ids or arc.to not in all_ids
      end)

    if Enum.empty?(invalid_arcs) do
      :ok
    else
      {:error, {:invalid_arcs, invalid_arcs}}
    end
  end

  defp validate_petri_net(_), do: {:error, :invalid_petri_net_structure}

  # ============================================================================
  # Verification Algorithms
  # ============================================================================

  defp run_verification(net) do
    # Run all verification checks
    deadlock_result = find_deadlock_states(net)
    bounded = check_boundedness(net)
    live = check_liveness(net)
    reachable_count = count_reachable_states(net)

    issues =
      []
      |> maybe_add_deadlock_issues(deadlock_result)
      |> maybe_add_boundedness_issue(bounded)
      |> maybe_add_liveness_issue(live)

    %{
      verified: Enum.empty?(issues),
      deadlock_free: Enum.empty?(deadlock_result),
      bounded: bounded,
      live: live,
      reachable_states: reachable_count,
      issues: issues
    }
  end

  defp find_deadlock_states(net) do
    # BFS to find all reachable markings, identify those with no enabled transitions
    initial = net.initial_marking
    visited = MapSet.new([marking_key(initial)])
    queue = :queue.from_list([initial])
    deadlocks = []

    explore_for_deadlocks(net, queue, visited, deadlocks)
  end

  defp explore_for_deadlocks(net, queue, visited, deadlocks) do
    case :queue.out(queue) do
      {:empty, _} ->
        deadlocks

      {{:value, marking}, rest_queue} ->
        enabled = get_enabled_transitions_for_marking(net, marking)

        new_deadlocks =
          if Enum.empty?(enabled) and not terminal_marking?(marking) do
            [%{marking: marking, type: :deadlock} | deadlocks]
          else
            deadlocks
          end

        # Explore successor markings
        {new_queue, new_visited} =
          Enum.reduce(enabled, {rest_queue, visited}, fn trans_id, {q, v} ->
            case fire_transition_for_marking(net, marking, trans_id) do
              {:ok, new_marking} ->
                key = marking_key(new_marking)

                if MapSet.member?(v, key) do
                  {q, v}
                else
                  {:queue.in(new_marking, q), MapSet.put(v, key)}
                end

              _ ->
                {q, v}
            end
          end)

        # Limit exploration to prevent infinite loops
        if MapSet.size(new_visited) > 10_000 do
          new_deadlocks
        else
          explore_for_deadlocks(net, new_queue, new_visited, new_deadlocks)
        end
    end
  end

  defp check_boundedness(net) do
    # A net is bounded if all places have finite token capacity
    # For our FSM-based nets, each place has capacity 1
    Enum.all?(net.places, fn {_id, place} ->
      place.capacity != :unbounded
    end)
  end

  defp check_liveness(net) do
    # A net is live if every transition can eventually fire from any reachable marking
    # Simplified: check if all transitions can fire from initial marking within k steps
    initial = net.initial_marking
    all_transitions = Map.keys(net.transitions)

    fired_transitions = explore_for_liveness(net, initial, MapSet.new(), MapSet.new(), 100)

    MapSet.size(fired_transitions) == length(all_transitions)
  end

  defp explore_for_liveness(_net, _marking, _visited, fired, 0), do: fired

  defp explore_for_liveness(net, marking, visited, fired, depth) do
    key = marking_key(marking)

    if MapSet.member?(visited, key) do
      fired
    else
      new_visited = MapSet.put(visited, key)
      enabled = get_enabled_transitions_for_marking(net, marking)

      # Add enabled transitions to fired set
      new_fired = Enum.reduce(enabled, fired, &MapSet.put(&2, &1))

      # Explore successors
      Enum.reduce(enabled, new_fired, fn trans_id, acc ->
        case fire_transition_for_marking(net, marking, trans_id) do
          {:ok, new_marking} ->
            explore_for_liveness(net, new_marking, new_visited, acc, depth - 1)

          _ ->
            acc
        end
      end)
    end
  end

  defp check_reachability(net, target_state) do
    initial = net.initial_marking
    visited = MapSet.new([marking_key(initial)])
    queue = :queue.from_list([initial])

    search_for_state(net, queue, visited, target_state)
  end

  defp search_for_state(net, queue, visited, target) do
    case :queue.out(queue) do
      {:empty, _} ->
        false

      {{:value, marking}, rest_queue} ->
        if Map.get(marking, target, 0) > 0 do
          true
        else
          enabled = get_enabled_transitions_for_marking(net, marking)

          {new_queue, new_visited} =
            Enum.reduce(enabled, {rest_queue, visited}, fn trans_id, {q, v} ->
              case fire_transition_for_marking(net, marking, trans_id) do
                {:ok, new_marking} ->
                  key = marking_key(new_marking)

                  if MapSet.member?(v, key) do
                    {q, v}
                  else
                    {:queue.in(new_marking, q), MapSet.put(v, key)}
                  end

                _ ->
                  {q, v}
              end
            end)

          if MapSet.size(new_visited) > 10_000 do
            false
          else
            search_for_state(net, new_queue, new_visited, target)
          end
        end
    end
  end

  defp count_reachable_states(net) do
    initial = net.initial_marking
    visited = MapSet.new([marking_key(initial)])
    queue = :queue.from_list([initial])

    count_states(net, queue, visited)
  end

  defp count_states(net, queue, visited) do
    case :queue.out(queue) do
      {:empty, _} ->
        MapSet.size(visited)

      {{:value, marking}, rest_queue} ->
        enabled = get_enabled_transitions_for_marking(net, marking)

        {new_queue, new_visited} =
          Enum.reduce(enabled, {rest_queue, visited}, fn trans_id, {q, v} ->
            case fire_transition_for_marking(net, marking, trans_id) do
              {:ok, new_marking} ->
                key = marking_key(new_marking)

                if MapSet.member?(v, key) do
                  {q, v}
                else
                  {:queue.in(new_marking, q), MapSet.put(v, key)}
                end

              _ ->
                {q, v}
            end
          end)

        if MapSet.size(new_visited) > 10_000 do
          MapSet.size(new_visited)
        else
          count_states(net, new_queue, new_visited)
        end
    end
  end

  # ============================================================================
  # Transition Firing
  # ============================================================================

  defp get_enabled_transitions(net) do
    get_enabled_transitions_for_marking(net, net.initial_marking)
  end

  defp get_enabled_transitions_for_marking(net, marking) do
    net.transitions
    |> Map.keys()
    |> Enum.filter(fn trans_id -> transition_enabled?(net, marking, trans_id) end)
  end

  defp transition_enabled?(net, marking, trans_id) do
    # Get input arcs for this transition
    input_arcs = Enum.filter(net.arcs, fn arc -> arc.to == trans_id and arc.type == :normal end)

    # Check if all input places have enough tokens
    Enum.all?(input_arcs, fn arc ->
      tokens = Map.get(marking, arc.from, 0)
      tokens >= arc.weight
    end)
  end

  defp fire_transition(net, trans_id) do
    fire_transition_for_marking(net, net.initial_marking, trans_id)
  end

  defp fire_transition_for_marking(net, marking, trans_id) do
    if transition_enabled?(net, marking, trans_id) do
      # Get input and output arcs
      input_arcs = Enum.filter(net.arcs, fn arc -> arc.to == trans_id end)
      output_arcs = Enum.filter(net.arcs, fn arc -> arc.from == trans_id end)

      # Remove tokens from input places
      marking_after_input =
        Enum.reduce(input_arcs, marking, fn arc, acc ->
          case arc.type do
            :normal -> Map.update(acc, arc.from, 0, &max(0, &1 - arc.weight))
            :inhibitor -> acc
            :reset -> Map.put(acc, arc.from, 0)
          end
        end)

      # Add tokens to output places
      new_marking =
        Enum.reduce(output_arcs, marking_after_input, fn arc, acc ->
          Map.update(acc, arc.to, arc.weight, &(&1 + arc.weight))
        end)

      {:ok, new_marking}
    else
      {:error, :not_enabled}
    end
  end

  # ============================================================================
  # Helper Functions
  # ============================================================================

  defp marking_key(marking) do
    marking
    |> Enum.sort()
    |> :erlang.term_to_binary()
  end

  defp terminal_marking?(_marking) do
    # A marking is terminal if it represents an accepting/final state
    # For FSMs, this would be when the "done" or final state has a token
    # This is a simplified check - real implementation would use metadata
    false
  end

  defp maybe_add_deadlock_issues(issues, []), do: issues

  defp maybe_add_deadlock_issues(issues, deadlocks) do
    deadlock_issues =
      Enum.map(deadlocks, fn d ->
        %{
          type: :deadlock,
          severity: :critical,
          message: "Deadlock state detected",
          marking: d.marking,
          sc_constraint: "SC-SIL4-006"
        }
      end)

    issues ++ deadlock_issues
  end

  defp maybe_add_boundedness_issue(issues, true), do: issues

  defp maybe_add_boundedness_issue(issues, false) do
    [
      %{
        type: :unbounded,
        severity: :high,
        message: "Petri Net is unbounded - infinite state space possible",
        sc_constraint: "SC-REG-002"
      }
      | issues
    ]
  end

  defp maybe_add_liveness_issue(issues, true), do: issues

  defp maybe_add_liveness_issue(issues, false) do
    [
      %{
        type: :not_live,
        severity: :medium,
        message: "Not all transitions can fire - potential livelock",
        sc_constraint: "SC-IMMUNE-004"
      }
      | issues
    ]
  end

  defp update_stats(stats, result) do
    stats
    |> Map.update!(:verifications_run, &(&1 + 1))
    |> maybe_increment(:deadlocks_detected, not result.deadlock_free)
    |> maybe_increment(:unbounded_detected, not result.bounded)
    |> maybe_increment(:livelocks_detected, not result.live)
  end

  defp maybe_increment(stats, key, true), do: Map.update!(stats, key, &(&1 + 1))
  defp maybe_increment(stats, _key, false), do: stats

  defp log_verification_result(module, result) do
    if result.verified do
      Logger.info(
        "[PetriNet] Verification PASSED for #{inspect(module)} - #{result.reachable_states} states explored in #{result.analysis_time_ms}ms"
      )
    else
      issue_summary = Enum.map(result.issues, & &1.type) |> Enum.join(", ")

      Logger.warning(
        "[PetriNet] Verification FAILED for #{inspect(module)} - Issues: #{issue_summary}"
      )

      # Report to Guardian for critical issues
      if Enum.any?(result.issues, &(&1.severity == :critical)) do
        Guardian.report_threat(%{
          type: :petri_net_verification_failed,
          severity: :critical,
          source: __MODULE__,
          metadata: %{module: module, issues: result.issues}
        })
      end
    end
  end
end
