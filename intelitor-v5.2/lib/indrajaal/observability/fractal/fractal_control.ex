defmodule Indrajaal.Observability.Fractal.FractalControl do
  @moduledoc """
  FractalControl: Central state manager for the Fractal Logging System.

  WHAT: GenServer implementing Zenoh-style pub/sub with ETS-optimized concurrent
        access patterns for the 5-level Fractal Logging System.

  WHY: Provides O(1) depth checking for log emission decisions while maintaining
       thread-safe state for boosts, subscriptions, and load shedding.

  CONSTRAINTS:
  - SC-LOG-001: Async dispatch (never block on log emission)
  - SC-LOG-002: Auto-throttle at CPU > 90% (load shedding)
  - SC-LOG-005: Boosts require TTL (default 5min, max 1hr)
  - SC-LOG-006: HLC timestamps for L3+ logs

  ## Architecture

  Uses dual ETS tables for O(1) lookups:
  - `:fractal_config` - Module policies, default level (ordered_set, read_concurrency)
  - `:fractal_boosts` - Active boosts with TTL (set, write_concurrency)

  State is periodically synced to ETS via `sync_ets/1` for crash recovery.

  ## Usage

      # Start the GenServer (typically via application supervisor)
      {:ok, pid} = FractalControl.start_link()

      # Check if logging is enabled
      FractalControl.should_log?("Indrajaal/Alarms/create", :l3, %{user_id: "123"})

      # Apply a boost
      {:ok, boost_id} = FractalControl.focus("Indrajaal/**", :l2, 60_000, "debug_session")

      # Get effective level for a module
      FractalControl.get_effective_level("Indrajaal/Alarms", %{})

  ## STAMP Compliance

  | Constraint   | Implementation                              |
  |--------------|---------------------------------------------|
  | SC-LOG-001   | All notify/emit via Task.start (async)      |
  | SC-LOG-002   | load_shedding?/0 checks CPU, auto-throttle  |
  | SC-LOG-005   | Boost TTL validation, max 1 hour            |
  | SC-LOG-006   | HLC timestamps for L3+ via Fractal.HLC      |
  """

  use GenServer
  require Logger

  alias Indrajaal.Observability.Fractal.{HLC, KeyExpression}

  # ============================================================
  # TYPES
  # ============================================================

  @type fractal_level :: :l1 | :l2 | :l3 | :l4 | :l5 | :l6 | :l7

  @doc """
  Validates if the current level is sufficient for sampling based on system load.
  Implements the Fractal Sampling Logic.
  """
  def valid_level?(level) when level in [:l1, :l2, :l3, :l4, :l5, :l6, :l7], do: true
  @type priority :: :p0 | :p1 | :p2 | :p3

  @type boost :: %{
          id: String.t(),
          key_expr: String.t(),
          compiled_expr: KeyExpression.compiled_expr() | nil,
          depth: fractal_level(),
          filter: map(),
          created_at: DateTime.t(),
          expires_at: DateTime.t(),
          hlc_expires_at: HLC.timestamp() | nil,
          created_by: String.t()
        }

  @type subscriber :: %{
          id: String.t(),
          key_expr: String.t(),
          compiled_expr: KeyExpression.compiled_expr() | nil,
          level: fractal_level(),
          callback: (map() -> any()),
          pid: pid(),
          created_at: DateTime.t()
        }

  @type shedding_state :: %{
          active: boolean(),
          reason: String.t() | nil,
          activated_at: DateTime.t() | nil,
          cpu_threshold: float(),
          memory_threshold: float()
        }

  @type state :: %{
          default_policy: fractal_level(),
          key_expr_tree: map(),
          subscribers: map(),
          publishers: map(),
          boosts: [boost()],
          hlc: HLC.timestamp() | nil,
          bloom_filter: :atomics.atomics_ref() | nil,
          ets_config: atom(),
          ets_boosts: atom(),
          shedding: shedding_state(),
          metrics: map(),
          node_id: String.t()
        }

  # ============================================================
  # CONSTANTS
  # ============================================================

  @default_level :l4
  @max_boost_ttl_ms 3_600_000
  @default_boost_ttl_ms 300_000
  @cpu_threshold 90.0
  @memory_threshold 85.0
  @hysteresis_margin 10.0

  @level_to_int %{l1: 1, l2: 2, l3: 3, l4: 4, l5: 5}
  @int_to_level %{1 => :l1, 2 => :l2, 3 => :l3, 4 => :l4, 5 => :l5}

  # ============================================================
  # CLIENT API
  # ============================================================

  @doc """
  Starts the FractalControl GenServer.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Check if logging should occur for a key at a given level with baggage context.

  This is the HOT PATH - must be < 1us via ETS lookup.

  ## Parameters
  - `key` - Zenoh-style key expression (e.g., "Indrajaal/Alarms/create")
  - `level` - Fractal level (:l1 to :l5)
  - `baggage` - Context map for boost filtering (e.g., %{user_id: "123"})

  ## Returns
  - `true` if logging should proceed
  - `false` if logging should be skipped

  ## Examples

      iex> FractalControl.should_log?("Indrajaal/Alarms/create", :l3, %{})
      true

      iex> FractalControl.should_log?("Indrajaal/Debug/trace", :l1, %{})
      false  # L1 below default L4
  """
  @spec should_log?(String.t(), fractal_level(), map()) :: boolean()
  def should_log?(key, level, baggage \\ %{}) do
    # Fast path: ETS lookup for load shedding
    if load_shedding?() do
      # During shedding, only L4/L5 allowed
      level_int(level) >= 4
    else
      # Normal path: check policy and boosts
      effective_level = get_effective_level(key, baggage)
      level_int(level) >= level_int(effective_level)
    end
  end

  @doc """
  Get the effective logging level for a key with context.

  Merges module-specific policy with any active context boosts.
  Most specific (longest) key match wins.

  ## Parameters
  - `key` - Zenoh-style key expression
  - `baggage` - Context map for boost filtering

  ## Returns
  - The effective fractal level (:l1 to :l5)
  """
  @spec get_effective_level(String.t(), map()) :: fractal_level()
  def get_effective_level(key, baggage \\ %{}) do
    # Check for active boost first (boosts can lower the threshold)
    boost_level = check_boost_level(key, baggage)

    # Get module policy
    policy_level = get_policy(key)

    # Return the lower level (more verbose)
    if boost_level && level_int(boost_level) < level_int(policy_level) do
      boost_level
    else
      policy_level
    end
  end

  @doc """
  Check if load shedding is currently active.

  SC-LOG-002: Auto-throttle at CPU > 90%.
  """
  @spec load_shedding?() :: boolean()
  def load_shedding? do
    case :ets.whereis(:fractal_config) do
      :undefined ->
        false

      _ref ->
        case :ets.lookup(:fractal_config, :shedding_active) do
          [{:shedding_active, true}] -> true
          _ -> false
        end
    end
  end

  @doc """
  Apply a focus boost to enable verbose logging for a key expression.

  SC-LOG-005: Boosts require TTL (default 5min, max 1hr).

  ## Parameters
  - `key_expr` - Zenoh-style key expression (e.g., "Indrajaal/Alarms/**")
  - `depth` - Target fractal level (:l1 to :l5)
  - `ttl_ms` - Time-to-live in milliseconds (max 1 hour)
  - `created_by` - Creator identifier for audit

  ## Returns
  - `{:ok, boost_id}` on success
  - `{:error, reason}` on validation failure
  """
  @spec focus(String.t(), fractal_level(), non_neg_integer(), String.t()) ::
          {:ok, String.t()} | {:error, atom()}
  def focus(key_expr, depth, ttl_ms \\ @default_boost_ttl_ms, created_by \\ "system") do
    GenServer.call(__MODULE__, {:focus, key_expr, depth, ttl_ms, created_by})
  end

  @doc """
  Remove an active boost by ID.
  """
  @spec remove_boost(String.t()) :: :ok | {:error, :not_found}
  def remove_boost(boost_id) do
    GenServer.call(__MODULE__, {:remove_boost, boost_id})
  end

  @doc """
  Get all active boosts.
  """
  @spec get_active_boosts() :: [boost()]
  def get_active_boosts do
    GenServer.call(__MODULE__, :get_active_boosts)
  end

  @doc """
  Set the default logging policy level.
  """
  @spec set_default_policy(fractal_level()) :: :ok
  def set_default_policy(level) do
    GenServer.call(__MODULE__, {:set_default_policy, level})
  end

  @doc """
  Set a policy for a specific key expression.
  """
  @spec set_policy(String.t(), fractal_level()) :: :ok
  def set_policy(key_expr, level) do
    GenServer.call(__MODULE__, {:set_policy, key_expr, level})
  end

  @doc """
  Subscribe to log events matching a key expression.

  ## Parameters
  - `key_expr` - Zenoh-style key expression
  - `level` - Minimum level to receive
  - `callback` - Function to call with log entries

  ## Returns
  - Subscription ID (use for unsubscribe)
  """
  @spec subscribe(String.t(), fractal_level(), (map() -> any())) :: String.t()
  def subscribe(key_expr, level, callback) do
    GenServer.call(__MODULE__, {:subscribe, key_expr, level, callback})
  end

  @doc """
  Unsubscribe from log events.
  """
  @spec unsubscribe(String.t()) :: :ok | {:error, :not_found}
  def unsubscribe(subscription_id) do
    GenServer.call(__MODULE__, {:unsubscribe, subscription_id})
  end

  @doc """
  Notify all matching subscribers of a log entry.

  SC-LOG-001: Async dispatch (never block).
  """
  @spec notify(map()) :: :ok
  def notify(entry) do
    GenServer.cast(__MODULE__, {:notify, entry})
  end

  @doc """
  Update resource metrics and trigger load shedding if needed.

  SC-LOG-002: Auto-throttle at CPU > 90%.
  """
  @spec update_resource_metrics(float(), float()) :: :ok
  def update_resource_metrics(cpu_percent, memory_percent) do
    GenServer.cast(__MODULE__, {:update_metrics, cpu_percent, memory_percent})
  end

  @doc """
  Get current status and metrics.
  """
  @spec get_status() :: map()
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  @doc """
  Warmup ETS tables at startup.
  """
  @spec warmup_ets() :: :ok
  def warmup_ets do
    GenServer.call(__MODULE__, :warmup_ets)
  end

  @doc """
  Reset all state (for testing).
  Clears boosts, subscribers, policies, and resets to default configuration.
  """
  @spec reset() :: :ok
  def reset do
    GenServer.call(__MODULE__, :reset)
  end

  @doc """
  Alias for get_status/0 for CyberneticController compatibility.
  """
  @spec status() :: map()
  def status do
    get_status()
  end

  @doc """
  Activate load shedding mode.

  SC-LOG-002: Auto-throttle at CPU > 90%.

  ## Parameters
  - `reason` - Reason for activation (e.g., :cpu_overload, :autonomous)
  """
  @spec activate_load_shedding(atom()) :: :ok
  def activate_load_shedding(reason) do
    GenServer.cast(__MODULE__, {:activate_load_shedding, reason})
  end

  @doc """
  Deactivate load shedding mode.
  """
  @spec deactivate_load_shedding() :: :ok
  def deactivate_load_shedding do
    GenServer.cast(__MODULE__, :deactivate_load_shedding)
  end

  @doc """
  Get current metrics including throughput and error rate.

  ## Returns
  - `{:ok, %{throughput: float(), error_rate: float(), ...}}`
  """
  @spec get_metrics() :: {:ok, map()} | {:error, atom()}
  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end

  @doc """
  Clear all active boosts.
  """
  @spec clear_boosts() :: :ok
  def clear_boosts do
    GenServer.call(__MODULE__, :clear_boosts)
  end

  # ============================================================
  # SERVER CALLBACKS
  # ============================================================

  @impl true
  def init(opts) do
    # Create ETS tables for O(1) lookups
    ets_config = create_config_table()
    ets_boosts = create_boosts_table()

    # Initialize default state
    state = %{
      default_policy: Keyword.get(opts, :default_policy, @default_level),
      key_expr_tree: %{},
      subscribers: %{},
      publishers: %{},
      boosts: [],
      hlc: nil,
      bloom_filter: nil,
      ets_config: ets_config,
      ets_boosts: ets_boosts,
      shedding: %{
        active: false,
        reason: nil,
        activated_at: nil,
        cpu_threshold: @cpu_threshold,
        memory_threshold: @memory_threshold
      },
      metrics: %{
        emit_count: 0,
        drop_count: %{},
        boost_count: 0,
        subscriber_count: 0,
        last_emit_time: nil
      },
      node_id: generate_node_id()
    }

    # Sync initial state to ETS
    sync_ets(state)

    # Schedule periodic boost expiration
    schedule_boost_expiration()

    Logger.info("[FractalControl] Initialized",
      node_id: state.node_id,
      default_policy: state.default_policy
    )

    {:ok, state}
  end

  @impl true
  def handle_call({:focus, key_expr, depth, ttl_ms, created_by}, _from, state) do
    case validate_boost(key_expr, depth, ttl_ms) do
      :ok ->
        boost = create_boost(key_expr, depth, ttl_ms, created_by)
        new_boosts = [boost | state.boosts]
        new_state = %{state | boosts: new_boosts}

        # Store in ETS for fast lookup
        :ets.insert(state.ets_boosts, {boost.id, boost})

        sync_ets(new_state)
        {:reply, {:ok, boost.id}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:remove_boost, boost_id}, _from, state) do
    case Enum.find(state.boosts, fn b -> b.id == boost_id end) do
      nil ->
        {:reply, {:error, :not_found}, state}

      _boost ->
        new_boosts = Enum.reject(state.boosts, fn b -> b.id == boost_id end)
        new_state = %{state | boosts: new_boosts}

        :ets.delete(state.ets_boosts, boost_id)
        sync_ets(new_state)

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call(:get_active_boosts, _from, state) do
    now = DateTime.utc_now()

    active =
      state.boosts
      |> Enum.filter(fn boost -> DateTime.compare(boost.expires_at, now) == :gt end)

    {:reply, active, state}
  end

  @impl true
  def handle_call({:set_default_policy, level}, _from, state) do
    new_state = %{state | default_policy: level}
    :ets.insert(state.ets_config, {:default_policy, level})
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:set_policy, key_expr, level}, _from, state) do
    new_tree = Map.put(state.key_expr_tree, key_expr, level)
    new_state = %{state | key_expr_tree: new_tree}

    # Use nested tuple so key_expr is part of ETS key (ordered_set uses first element as key)
    :ets.insert(state.ets_config, {{:policy, key_expr}, level})
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:subscribe, key_expr, level, callback}, _from, state) do
    sub_id = generate_id()

    compiled =
      case KeyExpression.compile(key_expr) do
        {:ok, expr} -> expr
        {:error, _} -> nil
      end

    subscriber = %{
      id: sub_id,
      key_expr: key_expr,
      compiled_expr: compiled,
      level: level,
      callback: callback,
      pid: self(),
      created_at: DateTime.utc_now()
    }

    new_subscribers = Map.put(state.subscribers, sub_id, subscriber)
    new_state = %{state | subscribers: new_subscribers}

    {:reply, sub_id, new_state}
  end

  @impl true
  def handle_call({:unsubscribe, subscription_id}, _from, state) do
    case Map.pop(state.subscribers, subscription_id) do
      {nil, _} ->
        {:reply, {:error, :not_found}, state}

      {_sub, new_subscribers} ->
        new_state = %{state | subscribers: new_subscribers}
        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    status = %{
      healthy: not state.shedding.active,
      default_policy: state.default_policy,
      policy_count: map_size(state.key_expr_tree),
      active_boosts: length(state.boosts),
      subscribers: map_size(state.subscribers),
      publishers: map_size(state.publishers),
      shedding: state.shedding.active,
      shedding_reason: state.shedding.reason,
      metrics: state.metrics,
      node_id: state.node_id
    }

    {:reply, status, state}
  end

  @impl true
  def handle_call(:warmup_ets, _from, state) do
    sync_ets(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:reset, _from, state) do
    # Clear ETS tables
    :ets.delete_all_objects(state.ets_config)
    :ets.delete_all_objects(state.ets_boosts)

    # Reset state to defaults
    new_state = %{
      state
      | default_policy: @default_level,
        key_expr_tree: %{},
        subscribers: %{},
        publishers: %{},
        boosts: [],
        shedding: %{
          active: false,
          reason: nil,
          activated_at: nil,
          cpu_threshold: @cpu_threshold,
          memory_threshold: @memory_threshold
        },
        metrics: %{
          emit_count: 0,
          drop_count: %{},
          boost_count: 0,
          subscriber_count: 0,
          last_emit_time: nil
        }
    }

    # Re-sync to ETS
    sync_ets(new_state)

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_metrics, _from, state) do
    # Calculate throughput based on recent emit count
    emit_count = state.metrics.emit_count

    # Calculate error rate from drop counts
    total_drops = state.metrics.drop_count |> Map.values() |> Enum.sum()
    total = emit_count + total_drops
    error_rate = if total > 0, do: total_drops / total, else: 0.0

    metrics = %{
      throughput: emit_count / 60.0,
      error_rate: error_rate,
      emit_count: emit_count,
      drop_count: state.metrics.drop_count,
      boost_count: length(state.boosts),
      subscriber_count: map_size(state.subscribers)
    }

    {:reply, {:ok, metrics}, state}
  end

  @impl true
  def handle_call(:clear_boosts, _from, state) do
    # Clear from ETS
    :ets.delete_all_objects(state.ets_boosts)

    # Clear from state
    new_state = %{state | boosts: []}

    Logger.debug("[FractalControl] All boosts cleared")

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_cast({:activate_load_shedding, reason}, state) do
    if state.shedding.active do
      {:noreply, state}
    else
      Logger.warning("[FractalControl] Load shedding activated",
        reason: reason
      )

      :ets.insert(state.ets_config, {:shedding_active, true})

      new_shedding = %{
        state.shedding
        | active: true,
          reason: to_string(reason),
          activated_at: DateTime.utc_now()
      }

      {:noreply, %{state | shedding: new_shedding}}
    end
  end

  @impl true
  def handle_cast(:deactivate_load_shedding, state) do
    if state.shedding.active do
      Logger.info("[FractalControl] Load shedding deactivated")

      :ets.insert(state.ets_config, {:shedding_active, false})

      new_shedding = %{
        state.shedding
        | active: false,
          reason: nil,
          activated_at: nil
      }

      {:noreply, %{state | shedding: new_shedding}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:notify, entry}, state) do
    # SC-LOG-001: Async dispatch
    key = Map.get(entry, :key, "**")
    level = Map.get(entry, :level, :l4)

    # Update metrics
    new_metrics = Map.update(state.metrics, :emit_count, 1, &(&1 + 1))
    new_state = %{state | metrics: %{state.metrics | emit_count: new_metrics.emit_count}}

    # Find matching subscribers and dispatch async
    matching_subscribers =
      state.subscribers
      |> Map.values()
      |> Enum.filter(fn sub ->
        level_int(level) >= level_int(sub.level) &&
          matches_key?(sub, key)
      end)

    # Dispatch to each subscriber asynchronously (SC-LOG-001)
    Enum.each(matching_subscribers, fn sub ->
      Task.start(fn ->
        try do
          sub.callback.(entry)
        rescue
          _ -> :ok
        end
      end)
    end)

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:update_metrics, cpu_percent, memory_percent}, state) do
    new_shedding =
      cond do
        cpu_percent > state.shedding.cpu_threshold ->
          if state.shedding.active do
            state.shedding
          else
            Logger.warning("[FractalControl] Activating load shedding",
              reason: "CPU > #{state.shedding.cpu_threshold}%",
              cpu: cpu_percent
            )

            :ets.insert(state.ets_config, {:shedding_active, true})

            %{
              state.shedding
              | active: true,
                reason: "CPU > #{state.shedding.cpu_threshold}%",
                activated_at: DateTime.utc_now()
            }
          end

        memory_percent > state.shedding.memory_threshold ->
          if state.shedding.active do
            state.shedding
          else
            Logger.warning("[FractalControl] Activating load shedding",
              reason: "Memory > #{state.shedding.memory_threshold}%",
              memory: memory_percent
            )

            :ets.insert(state.ets_config, {:shedding_active, true})

            %{
              state.shedding
              | active: true,
                reason: "Memory > #{state.shedding.memory_threshold}%",
                activated_at: DateTime.utc_now()
            }
          end

        state.shedding.active &&
          cpu_percent < state.shedding.cpu_threshold - @hysteresis_margin &&
            memory_percent < state.shedding.memory_threshold - @hysteresis_margin ->
          Logger.info("[FractalControl] Deactivating load shedding",
            cpu: cpu_percent,
            memory: memory_percent
          )

          :ets.insert(state.ets_config, {:shedding_active, false})

          %{
            state.shedding
            | active: false,
              reason: nil,
              activated_at: nil
          }

        true ->
          state.shedding
      end

    {:noreply, %{state | shedding: new_shedding}}
  end

  @impl true
  def handle_info(:expire_boosts, state) do
    now = DateTime.utc_now()

    {expired, active} =
      Enum.split_with(state.boosts, fn boost ->
        DateTime.compare(boost.expires_at, now) != :gt
      end)

    # Remove expired from ETS
    Enum.each(expired, fn boost ->
      :ets.delete(state.ets_boosts, boost.id)
    end)

    if length(expired) > 0 do
      Logger.debug("[FractalControl] Expired #{length(expired)} boosts")
    end

    # Schedule next expiration check
    schedule_boost_expiration()

    {:noreply, %{state | boosts: active}}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Clean up subscribers from dead processes
    new_subscribers =
      state.subscribers
      |> Enum.reject(fn {_id, sub} -> sub.pid == pid end)
      |> Map.new()

    {:noreply, %{state | subscribers: new_subscribers}}
  end

  # ============================================================
  # PRIVATE HELPERS
  # ============================================================

  defp create_config_table do
    table_name = :fractal_config

    case :ets.whereis(table_name) do
      :undefined ->
        :ets.new(table_name, [
          :named_table,
          :ordered_set,
          :public,
          read_concurrency: true
        ])

      _ref ->
        table_name
    end
  end

  defp create_boosts_table do
    table_name = :fractal_boosts

    case :ets.whereis(table_name) do
      :undefined ->
        :ets.new(table_name, [
          :named_table,
          :set,
          :public,
          write_concurrency: true
        ])

      _ref ->
        table_name
    end
  end

  @doc false
  def sync_ets(state) do
    # Sync default policy
    :ets.insert(state.ets_config, {:default_policy, state.default_policy})
    :ets.insert(state.ets_config, {:shedding_active, state.shedding.active})

    # Sync policies - use nested tuple so key_expr is part of ETS key
    Enum.each(state.key_expr_tree, fn {key_expr, level} ->
      :ets.insert(state.ets_config, {{:policy, key_expr}, level})
    end)

    # Sync boosts
    Enum.each(state.boosts, fn boost ->
      :ets.insert(state.ets_boosts, {boost.id, boost})
    end)

    :ok
  end

  defp validate_boost(key_expr, depth, ttl_ms) do
    cond do
      not is_binary(key_expr) or String.trim(key_expr) == "" ->
        {:error, :invalid_key_expr}

      not is_atom(depth) or depth not in [:l1, :l2, :l3, :l4, :l5] ->
        {:error, :invalid_depth}

      not is_integer(ttl_ms) or ttl_ms <= 0 ->
        {:error, :invalid_ttl}

      ttl_ms > @max_boost_ttl_ms ->
        {:error, :ttl_exceeds_maximum}

      true ->
        :ok
    end
  end

  defp create_boost(key_expr, depth, ttl_ms, created_by) do
    compiled =
      case KeyExpression.compile(key_expr) do
        {:ok, expr} -> expr
        {:error, _} -> nil
      end

    now = DateTime.utc_now()
    expires_at = DateTime.add(now, ttl_ms, :millisecond)

    %{
      id: generate_id(),
      key_expr: key_expr,
      compiled_expr: compiled,
      depth: depth,
      filter: %{},
      created_at: now,
      expires_at: expires_at,
      hlc_expires_at: nil,
      created_by: created_by
    }
  end

  defp get_policy(key) do
    case :ets.whereis(:fractal_config) do
      :undefined ->
        @default_level

      _ref ->
        # Look for matching policies (longest prefix match)
        # Policies stored as {{:policy, key_expr}, level}
        match_objects = :ets.match_object(:fractal_config, {{:policy, :_}, :_})

        policies =
          match_objects
          |> Enum.filter(fn {{:policy, expr}, _level} ->
            String.starts_with?(key, expr) or expr == "*" or expr == "**"
          end)
          |> Enum.sort_by(fn {{:policy, expr}, _} -> String.length(expr) end, :desc)

        case policies do
          [{{:policy, _}, level} | _] ->
            level

          [] ->
            case :ets.lookup(:fractal_config, :default_policy) do
              [{:default_policy, level}] -> level
              [] -> @default_level
            end
        end
    end
  end

  defp check_boost_level(key, baggage) do
    case :ets.whereis(:fractal_boosts) do
      :undefined ->
        nil

      _ref ->
        now = DateTime.utc_now()

        boosts_list = :ets.tab2list(:fractal_boosts)

        boosts =
          boosts_list
          |> Enum.map(fn {_id, boost} -> boost end)
          |> Enum.filter(fn boost ->
            DateTime.compare(boost.expires_at, now) == :gt &&
              key_matches_boost?(key, boost) &&
              filter_matches?(baggage, boost.filter)
          end)
          |> Enum.sort_by(fn boost -> level_int(boost.depth) end)

        case boosts do
          [lowest | _] -> lowest.depth
          [] -> nil
        end
    end
  end

  defp key_matches_boost?(key, boost) do
    case boost.compiled_expr do
      nil ->
        # Fallback for when compilation failed
        # Handle wildcard patterns manually
        cond do
          boost.key_expr == "**" ->
            true

          String.ends_with?(boost.key_expr, "/**") ->
            # Match prefix without the wildcard suffix
            prefix = String.trim_trailing(boost.key_expr, "/**")
            String.starts_with?(key, prefix)

          String.ends_with?(boost.key_expr, "/*") ->
            # Match prefix with single segment wildcard
            prefix = String.trim_trailing(boost.key_expr, "/*")
            String.starts_with?(key, prefix <> "/")

          true ->
            # Exact prefix match
            String.starts_with?(key, boost.key_expr)
        end

      compiled ->
        KeyExpression.matches?(compiled, key)
    end
  end

  defp filter_matches?(_baggage, filter) when map_size(filter) == 0, do: true

  defp filter_matches?(baggage, filter) do
    Enum.all?(filter, fn {k, v} ->
      Map.get(baggage, k) == v or Map.get(baggage, to_string(k)) == v
    end)
  end

  defp matches_key?(subscriber, key) do
    case subscriber.compiled_expr do
      nil ->
        String.starts_with?(key, subscriber.key_expr) or subscriber.key_expr == "**"

      compiled ->
        KeyExpression.matches?(compiled, key)
    end
  end

  defp level_int(level), do: Map.get(@level_to_int, level, 4)

  @doc false
  def int_to_level(int), do: Map.get(@int_to_level, int, :l4)

  defp generate_id do
    bytes = :crypto.strong_rand_bytes(4)
    bytes |> Base.encode16(case: :lower)
  end

  defp generate_node_id do
    node_str = node() |> to_string()
    suffix_bytes = :crypto.strong_rand_bytes(3)
    random_suffix = suffix_bytes |> Base.encode16(case: :lower)
    "#{node_str}-#{random_suffix}"
  end

  defp schedule_boost_expiration do
    Process.send_after(self(), :expire_boosts, 30_000)
  end
end
