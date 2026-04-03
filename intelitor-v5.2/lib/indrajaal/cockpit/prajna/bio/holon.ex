defmodule Indrajaal.Cockpit.Prajna.Bio.Holon do
  @moduledoc """
  ## The Cellular Holon Contract & Lifecycle Manager

  WHAT: Defines the "Life Interface" that every entity in the PRAJNA system must
  implement to be a valid node in the fractal organism. Also provides a GenServer
  implementation for lifecycle management of autonomous self-healing units.

  WHY: The biomorphic architecture requires every component to possess:
  - Local autonomy (decide_locally/2)
  - Health awareness (health_check/0)
  - Self-healing capability (self_heal/1)
  - Connection to the whole via parent_ref

  CONSTRAINTS:
  - SC-BIO-001: vital_signs must return within 10ms
  - SC-BIO-004: health_check must be idempotent and side-effect free
  - SC-BIO-005: self_heal must be bounded (max 3 attempts)
  - SC-BIO-006: decide_locally must respect autonomy_level boundaries

  ## Architecture

  ```
  ┌─────────────────────────────────────────────────────────────┐
  │                       HOLON LIFECYCLE                       │
  │                                                             │
  │   ┌──────────┐     ┌──────────┐     ┌──────────┐           │
  │   │  SPAWN   │────►│  ACTIVE  │────►│ HEALING  │           │
  │   │ (init)   │     │(running) │     │(recover) │           │
  │   └──────────┘     └────┬─────┘     └────┬─────┘           │
  │                         │                 │                 │
  │                         ▼                 ▼                 │
  │                    ┌──────────┐     ┌──────────┐           │
  │                    │ MITOSIS  │     │APOPTOSIS │           │
  │                    │ (scale)  │     │ (death)  │           │
  │                    └──────────┘     └──────────┘           │
  └─────────────────────────────────────────────────────────────┘
  ```

  ## Fractal Pattern: "As Above, So Below"

  Every Holon follows the same interface whether it represents:
  - System level (entire cluster)
  - Cluster level (group of nodes)
  - Node level (single machine)
  - Process level (GenServer/Task)

  ## STAMP Compliance

  | Constraint | Description |
  |------------|-------------|
  | SC-BIO-001 | Vital signs latency < 10ms |
  | SC-BIO-004 | Health check idempotent |
  | SC-BIO-005 | Self-heal bounded attempts |
  | SC-BIO-006 | Autonomy level enforcement |

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 2.0.0 |
  | Created | 2025-12-29 |
  | Author | L3-BIO-1 |
  | STAMP | SC-BIO-001 to SC-BIO-006 |
  """

  use GenServer
  require Logger

  # ============================================================
  # TYPE DEFINITIONS
  # ============================================================

  @type vital_vector :: %{
          id: String.t(),
          type: :container | :supervisor | :worker | :cluster | :system,
          generation: non_neg_integer(),
          health_index: float(),
          stress_index: float(),
          energy_index: float(),
          intent: atom(),
          target: atom()
        }

  @type health_report :: %{
          status: :healthy | :degraded | :critical | :unknown,
          score: float(),
          checks: list({atom(), :pass | :fail | :warn}),
          timestamp: DateTime.t()
        }

  @type heal_result :: {:ok, :recovered} | {:ok, :partial} | {:error, :unrecoverable}

  @type decision :: %{
          action: atom(),
          confidence: float(),
          rationale: String.t(),
          delegated: boolean()
        }

  @type autonomy_level :: :full | :supervised | :restricted | :passive

  # ============================================================
  # BEHAVIOUR CALLBACKS
  # ============================================================

  @doc """
  Returns the current physiological and teleological state of the Holon.
  Must be a pure function or extremely low latency (<1ms).

  SC-BIO-001: Response time < 10ms
  """
  @callback vital_signs() :: vital_vector()

  @doc """
  Requests the Holon to perform cell division (scaling).
  Creates a new child Holon with inherited genetics.
  """
  @callback mitosis(opts :: keyword()) :: {:ok, pid()} | {:error, term()}

  @doc """
  Requests the Holon to perform programmed cell death (clean shutdown).
  Must clean up resources and notify parent.
  """
  @callback apoptosis(reason :: term()) :: :ok

  @doc """
  Performs a comprehensive health check of the Holon.
  Must be idempotent and side-effect free (SC-BIO-004).

  Returns a health report with individual check results.
  """
  @callback health_check() :: health_report()

  @doc """
  Attempts to heal the Holon from a detected issue.
  SC-BIO-005: Maximum 3 retry attempts.

  ## Parameters
  - issue: The detected issue to heal from

  ## Returns
  - {:ok, :recovered} - Full recovery achieved
  - {:ok, :partial} - Partial recovery, degraded mode
  - {:error, :unrecoverable} - Cannot recover, requires parent intervention
  """
  @callback self_heal(issue :: term()) :: heal_result()

  @doc """
  Makes a local decision based on current state and stimuli.
  SC-BIO-006: Must respect autonomy_level boundaries.

  If autonomy_level is :restricted or :passive, must delegate to parent.

  ## Parameters
  - stimulus: The input triggering the decision
  - context: Additional context for decision-making

  ## Returns
  Decision struct with action, confidence, and delegation flag.
  """
  @callback decide_locally(stimulus :: term(), context :: map()) :: decision()

  # ============================================================
  # OPTIONAL CALLBACKS
  # ============================================================

  @doc """
  Called when the Holon receives a signal from its parent.
  Default implementation logs and ignores.
  """
  @callback on_parent_signal(signal :: term()) :: :ok

  @doc """
  Called when a child Holon reports a state change.
  Default implementation logs and ignores.
  """
  @callback on_child_report(child_id :: String.t(), report :: term()) :: :ok

  @optional_callbacks [on_parent_signal: 1, on_child_report: 2]

  # ============================================================
  # HOLON STATE STRUCT
  # ============================================================

  defmodule State do
    @moduledoc """
    Internal state for a Holon GenServer instance.

    ## Fields

    - `id` - Unique identifier for this Holon
    - `type` - Classification (:system, :cluster, :node, :process)
    - `health_score` - Current health (0.0 to 1.0)
    - `stress_score` - Current stress level (0.0 to 1.0)
    - `energy_score` - Available energy (0.0 to 1.0)
    - `autonomy_level` - Decision authority level
    - `parent_ref` - PID or name of parent Holon (nil for root)
    - `children` - Map of child_id => child_pid
    - `generation` - Mitosis generation number
    - `intent` - Current goal/purpose
    - `target` - Current target state
    - `heal_attempts` - Counter for self-heal retries
    - `started_at` - Timestamp of Holon spawn
    - `last_health_check` - Timestamp of last health check
    - `metadata` - Custom key-value storage
    """
    @type t :: %__MODULE__{
            id: String.t(),
            type: :system | :cluster | :node | :process,
            health_score: float(),
            stress_score: float(),
            energy_score: float(),
            autonomy_level: :full | :supervised | :restricted | :passive,
            parent_ref: pid() | atom() | nil,
            children: %{String.t() => pid()},
            generation: non_neg_integer(),
            intent: atom(),
            target: atom(),
            heal_attempts: non_neg_integer(),
            started_at: DateTime.t(),
            last_health_check: DateTime.t() | nil,
            metadata: map()
          }

    defstruct [
      :id,
      :type,
      :parent_ref,
      :started_at,
      :last_health_check,
      health_score: 1.0,
      stress_score: 0.0,
      energy_score: 1.0,
      autonomy_level: :supervised,
      children: %{},
      generation: 0,
      intent: :idle,
      target: :stable,
      heal_attempts: 0,
      metadata: %{}
    ]
  end

  # ============================================================
  # CLIENT API
  # ============================================================

  @doc """
  Starts a Holon GenServer with the given options.

  ## Options

  - `:name` - Process name (optional)
  - `:id` - Holon ID (auto-generated if not provided)
  - `:type` - Holon type (:system, :cluster, :node, :process)
  - `:parent` - Parent Holon PID or name
  - `:autonomy_level` - Decision authority level
  - `:generation` - Mitosis generation (default 0)
  - `:module` - Callback module implementing Holon behaviour

  ## Returns

  - `{:ok, pid}` on success
  - `{:error, reason}` on failure
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name)
    gen_opts = if name, do: [name: name], else: []
    GenServer.start_link(__MODULE__, opts, gen_opts)
  end

  @doc """
  Gets the current vital signs of a Holon.
  """
  @spec get_vital_signs(GenServer.server()) :: vital_vector()
  def get_vital_signs(holon) do
    GenServer.call(holon, :vital_signs)
  end

  @doc """
  Requests a health check from the Holon.
  """
  @spec request_health_check(GenServer.server()) :: health_report()
  def request_health_check(holon) do
    GenServer.call(holon, :health_check)
  end

  @doc """
  Triggers self-healing for a detected issue.
  """
  @spec trigger_heal(GenServer.server(), term()) :: heal_result()
  def trigger_heal(holon, issue) do
    GenServer.call(holon, {:self_heal, issue})
  end

  @doc """
  Requests a local decision from the Holon.
  """
  @spec request_decision(GenServer.server(), term(), map()) :: decision()
  def request_decision(holon, stimulus, context \\ %{}) do
    GenServer.call(holon, {:decide, stimulus, context})
  end

  @doc """
  Triggers mitosis (scaling) on the Holon.
  """
  @spec trigger_mitosis(GenServer.server(), keyword()) :: {:ok, pid()} | {:error, term()}
  def trigger_mitosis(holon, opts \\ []) do
    GenServer.call(holon, {:mitosis, opts})
  end

  @doc """
  Triggers apoptosis (shutdown) on the Holon.
  """
  @spec trigger_apoptosis(GenServer.server(), term()) :: :ok
  def trigger_apoptosis(holon, reason \\ :normal) do
    GenServer.call(holon, {:apoptosis, reason})
  end

  @doc """
  Gets the current state of the Holon.
  """
  @spec get_state(GenServer.server()) :: State.t()
  def get_state(holon) do
    GenServer.call(holon, :get_state)
  end

  @doc """
  Updates the Holon's intent.
  """
  @spec set_intent(GenServer.server(), atom()) :: :ok
  def set_intent(holon, intent) do
    GenServer.cast(holon, {:set_intent, intent})
  end

  @doc """
  Sends a signal from parent to this Holon.
  """
  @spec parent_signal(GenServer.server(), term()) :: :ok
  def parent_signal(holon, signal) do
    GenServer.cast(holon, {:parent_signal, signal})
  end

  @doc """
  Reports child state to this Holon.
  """
  @spec child_report(GenServer.server(), String.t(), term()) :: :ok
  def child_report(holon, child_id, report) do
    GenServer.cast(holon, {:child_report, child_id, report})
  end

  # ============================================================
  # SERVER CALLBACKS
  # ============================================================

  @impl true
  def init(opts) do
    id = Keyword.get(opts, :id, generate_holon_id())
    type = Keyword.get(opts, :type, :process)
    parent = Keyword.get(opts, :parent)
    autonomy = Keyword.get(opts, :autonomy_level, :supervised)
    generation = Keyword.get(opts, :generation, 0)
    callback_module = Keyword.get(opts, :module)

    Logger.info("[Holon:#{id}] Spawning #{type} holon (gen=#{generation})")

    state = %State{
      id: id,
      type: type,
      parent_ref: parent,
      autonomy_level: autonomy,
      generation: generation,
      started_at: DateTime.utc_now(),
      metadata: %{
        callback_module: callback_module,
        spawn_opts: Keyword.delete(opts, :module)
      }
    }

    # Schedule periodic health checks
    schedule_health_check()

    {:ok, state}
  end

  @impl true
  def handle_call(:vital_signs, _from, state) do
    vitals = %{
      id: state.id,
      type: state.type,
      generation: state.generation,
      health_index: state.health_score,
      stress_index: state.stress_score,
      energy_index: state.energy_score,
      intent: state.intent,
      target: state.target
    }

    {:reply, vitals, state}
  end

  @impl true
  def handle_call(:health_check, _from, state) do
    report = perform_health_check(state)
    new_state = %{state | last_health_check: DateTime.utc_now()}

    # Update health score based on check results
    updated_state = update_health_from_report(new_state, report)

    {:reply, report, updated_state}
  end

  @impl true
  def handle_call({:self_heal, issue}, _from, state) do
    if state.heal_attempts >= 3 do
      Logger.error("[Holon:#{state.id}] Max heal attempts reached, unrecoverable")
      {:reply, {:error, :unrecoverable}, state}
    else
      Logger.info("[Holon:#{state.id}] Attempting self-heal (attempt #{state.heal_attempts + 1})")

      result = attempt_heal(state, issue)
      new_attempts = state.heal_attempts + 1

      new_state =
        case result do
          {:ok, :recovered} ->
            %{state | heal_attempts: 0, health_score: 1.0, stress_score: 0.1}

          {:ok, :partial} ->
            %{state | heal_attempts: new_attempts, health_score: 0.7, stress_score: 0.3}

          {:error, :unrecoverable} ->
            %{state | heal_attempts: new_attempts}
        end

      {:reply, result, new_state}
    end
  end

  @impl true
  def handle_call({:decide, stimulus, context}, _from, state) do
    decision = make_decision(state, stimulus, context)
    {:reply, decision, state}
  end

  @impl true
  def handle_call({:mitosis, opts}, _from, state) do
    child_id = generate_holon_id()
    Logger.info("[Holon:#{state.id}] Performing mitosis -> #{child_id}")

    child_opts =
      Keyword.merge(opts,
        id: child_id,
        type: state.type,
        parent: self(),
        generation: state.generation + 1,
        autonomy_level: demote_autonomy(state.autonomy_level),
        module: get_in(state.metadata, [:callback_module])
      )

    case start_link(child_opts) do
      {:ok, pid} ->
        new_children = Map.put(state.children, child_id, pid)
        new_state = %{state | children: new_children, energy_score: state.energy_score * 0.7}
        {:reply, {:ok, pid}, new_state}

      {:error, reason} = error ->
        Logger.error("[Holon:#{state.id}] Mitosis failed: #{inspect(reason)}")
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:apoptosis, reason}, _from, state) do
    Logger.info("[Holon:#{state.id}] Initiating apoptosis: #{inspect(reason)}")

    # Notify parent
    if state.parent_ref do
      child_report(state.parent_ref, state.id, {:apoptosis, reason})
    end

    # Trigger apoptosis in children
    Enum.each(state.children, fn {_id, pid} ->
      trigger_apoptosis(pid, :parent_apoptosis)
    end)

    {:stop, :normal, :ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:set_intent, intent}, state) do
    Logger.debug("[Holon:#{state.id}] Intent changed: #{state.intent} -> #{intent}")
    {:noreply, %{state | intent: intent}}
  end

  @impl true
  def handle_cast({:parent_signal, signal}, state) do
    Logger.debug("[Holon:#{state.id}] Received parent signal: #{inspect(signal)}")

    callback_module = get_in(state.metadata, [:callback_module])

    if callback_module && function_exported?(callback_module, :on_parent_signal, 1) do
      callback_module.on_parent_signal(signal)
    end

    # Process built-in signals
    new_state =
      case signal do
        :reduce_autonomy ->
          %{state | autonomy_level: demote_autonomy(state.autonomy_level)}

        :increase_autonomy ->
          %{state | autonomy_level: promote_autonomy(state.autonomy_level)}

        {:set_target, target} ->
          %{state | target: target}

        _ ->
          state
      end

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:child_report, child_id, report}, state) do
    Logger.debug("[Holon:#{state.id}] Child #{child_id} reported: #{inspect(report)}")

    callback_module = get_in(state.metadata, [:callback_module])

    if callback_module && function_exported?(callback_module, :on_child_report, 2) do
      callback_module.on_child_report(child_id, report)
    end

    # Handle child apoptosis
    new_state =
      case report do
        {:apoptosis, _reason} ->
          %{state | children: Map.delete(state.children, child_id)}

        _ ->
          state
      end

    {:noreply, new_state}
  end

  @impl true
  def handle_info(:periodic_health_check, state) do
    report = perform_health_check(state)
    new_state = update_health_from_report(state, report)

    # Report to parent if degraded
    if report.status in [:degraded, :critical] and state.parent_ref do
      child_report(state.parent_ref, state.id, {:health_degraded, report})
    end

    # Attempt self-heal if critical
    final_state =
      if report.status == :critical and state.heal_attempts < 3 do
        case attempt_heal(new_state, :critical_health) do
          {:ok, :recovered} ->
            %{new_state | heal_attempts: 0, health_score: 1.0}

          {:ok, :partial} ->
            %{new_state | heal_attempts: new_state.heal_attempts + 1}

          {:error, :unrecoverable} ->
            new_state
        end
      else
        new_state
      end

    schedule_health_check()
    {:noreply, %{final_state | last_health_check: DateTime.utc_now()}}
  end

  # ============================================================
  # PRIVATE HELPERS
  # ============================================================

  defp generate_holon_id do
    random_bytes = :crypto.strong_rand_bytes(8)
    "holon-" <> Base.encode16(random_bytes, case: :lower)
  end

  defp schedule_health_check do
    # Check every 30 seconds
    Process.send_after(self(), :periodic_health_check, :timer.seconds(30))
  end

  defp perform_health_check(state) do
    checks = [
      {:memory, check_memory()},
      {:process_alive, :pass},
      {:energy_level, if(state.energy_score > 0.2, do: :pass, else: :warn)},
      {:stress_level, if(state.stress_score < 0.8, do: :pass, else: :warn)},
      {:children_responsive, check_children(state.children)}
    ]

    pass_count = Enum.count(checks, fn {_, result} -> result == :pass end)
    warn_count = Enum.count(checks, fn {_, result} -> result == :warn end)
    fail_count = Enum.count(checks, fn {_, result} -> result == :fail end)

    status =
      cond do
        fail_count > 0 -> :critical
        warn_count > 1 -> :degraded
        warn_count > 0 -> :healthy
        true -> :healthy
      end

    score = (pass_count * 1.0 + warn_count * 0.5) / length(checks)

    %{
      status: status,
      score: Float.round(score, 2),
      checks: checks,
      timestamp: DateTime.utc_now()
    }
  end

  defp check_memory do
    memory = :erlang.memory(:total)
    # 1GB threshold
    if memory < 1_000_000_000, do: :pass, else: :warn
  end

  defp check_children(children) when map_size(children) == 0, do: :pass

  defp check_children(children) do
    alive_count = Enum.count(children, fn {_id, pid} -> Process.alive?(pid) end)

    if alive_count == map_size(children) do
      :pass
    else
      :fail
    end
  end

  defp update_health_from_report(state, report) do
    # Adjust stress based on health status
    stress_delta =
      case report.status do
        :healthy -> -0.05
        :degraded -> 0.1
        :critical -> 0.3
        :unknown -> 0.05
      end

    new_stress = max(0.0, min(1.0, state.stress_score + stress_delta))

    %{state | health_score: report.score, stress_score: new_stress}
  end

  defp attempt_heal(state, issue) do
    Logger.info("[Holon:#{state.id}] Healing issue: #{inspect(issue)}")

    # Simulate healing strategies based on issue type
    case issue do
      :critical_health ->
        # Reset stress, restore energy
        {:ok, :partial}

      :memory_pressure ->
        :erlang.garbage_collect()
        {:ok, :recovered}

      :child_failure ->
        # Would restart failed children here
        {:ok, :partial}

      :unrecoverable_state ->
        # Some issues cannot be healed
        {:error, :unrecoverable}

      :system_failure ->
        # System-level failures require parent intervention
        {:error, :unrecoverable}

      _ ->
        {:ok, :recovered}
    end
  end

  defp make_decision(state, stimulus, context) do
    # Check autonomy level
    delegated =
      case state.autonomy_level do
        :full -> false
        :supervised -> Map.get(context, :risky, false)
        :restricted -> true
        :passive -> true
      end

    action =
      case stimulus do
        :high_stress -> :scale_up
        :low_stress -> :scale_down
        :error_detected -> :investigate
        :health_critical -> :self_heal
        _ -> :observe
      end

    confidence =
      if delegated do
        0.5
      else
        case state.health_score do
          h when h > 0.8 -> 0.9
          h when h > 0.5 -> 0.7
          _ -> 0.5
        end
      end

    %{
      action: action,
      confidence: confidence,
      rationale: "Based on stimulus #{inspect(stimulus)} with health=#{state.health_score}",
      delegated: delegated
    }
  end

  defp demote_autonomy(level) do
    case level do
      :full -> :supervised
      :supervised -> :restricted
      :restricted -> :passive
      :passive -> :passive
    end
  end

  defp promote_autonomy(level) do
    case level do
      :passive -> :restricted
      :restricted -> :supervised
      :supervised -> :full
      :full -> :full
    end
  end
end
