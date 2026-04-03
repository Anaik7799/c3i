defmodule Indrajaal.Observability.Fractal.ContentRouter do
  @moduledoc """
  Content Router for intelligent log backend selection.

  Routes logs to appropriate storage based on fractal level, content type, and retention.
  Supports multi-cast to multiple backends with Zenoh-style key expression matching.

  ## STAMP Compliance

  - SC-LOG-001: Async dispatch (never block)
  - SC-LOG-006: L3+ logs MUST use HLC timestamps
  - SC-LOG-010: L1/L2 ephemeral, L4/L5 persistent

  ## Default Routing Rules

  - `Indrajaal/**/L5` -> SIEM + SigNoz (dual write)
  - `Indrajaal/Security/**` -> SIEM
  - `Indrajaal/**/error` -> ErrorTracker
  - Default -> SigNoz only

  ## Performance

  - Target: < 1us per route decision
  - O(1) for exact matches via ETS lookup
  - O(n) for wildcard matching (n = number of rules)
  """

  use GenServer
  require Logger

  alias Indrajaal.Observability.Fractal.KeyExpression

  # ============================================================
  # TYPES
  # ============================================================

  @type backend ::
          :memory
          | :wal
          | :timescale_db
          | :postgresql
          | :object_store
          | :otlp
          | :signoz
          | :siem
          | :error_tracker
          | :console
          | :blockchain_ledger
          | :zenoh
          | {:custom, String.t()}

  @type retention_policy :: %{
          min_retention: non_neg_integer(),
          max_retention: non_neg_integer(),
          archive_on_expiry: boolean(),
          compression_level: non_neg_integer()
        }

  @type routing_rule :: %{
          id: String.t(),
          key_expr: String.t(),
          compiled_expr: map() | nil,
          min_level: atom(),
          max_level: atom(),
          backends: [backend()],
          retention: retention_policy(),
          priority: integer(),
          enabled: boolean()
        }

  @type routing_decision :: %{
          backends: [backend()],
          retention: retention_policy(),
          matched_rule: String.t() | nil,
          should_emit: boolean()
        }

  # ============================================================
  # CONSTANTS
  # ============================================================

  @level_to_int %{l1: 1, l2: 2, l3: 3, l4: 4, l5: 5}

  @default_retention_by_level %{
    l1: %{
      min_retention: 5 * 60_000,
      max_retention: 60 * 60_000,
      archive_on_expiry: false,
      compression_level: 0
    },
    l2: %{
      min_retention: 60 * 60_000,
      max_retention: 24 * 60 * 60_000,
      archive_on_expiry: false,
      compression_level: 1
    },
    l3: %{
      min_retention: 7 * 24 * 60 * 60_000,
      max_retention: 30 * 24 * 60 * 60_000,
      archive_on_expiry: true,
      compression_level: 6
    },
    l4: %{
      min_retention: 30 * 24 * 60 * 60_000,
      max_retention: 365 * 24 * 60 * 60_000,
      archive_on_expiry: true,
      compression_level: 9
    },
    l5: %{
      min_retention: 365 * 24 * 60 * 60_000,
      max_retention: 3650 * 24 * 60 * 60_000,
      archive_on_expiry: true,
      compression_level: 9
    }
  }

  @default_backends_by_level %{
    # SC-ZENOH-INT-001: All levels route to Zenoh for real-time streaming
    l1: [:memory, :otlp, :zenoh],
    l2: [:wal, :otlp, :zenoh],
    l3: [:timescale_db, :otlp, :zenoh],
    l4: [:postgresql, :timescale_db, :otlp, :zenoh],
    l5: [:postgresql, :object_store, :otlp, :zenoh]
  }

  # ============================================================
  # CLIENT API
  # ============================================================

  @doc """
  Start the ContentRouter GenServer.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Route a log entry to appropriate backends.

  This is the HOT PATH - must complete in < 1us for optimal performance.
  Uses ETS for O(1) lookups where possible.

  ## Parameters

  - `entry` - Fractal log entry map with :key, :level fields

  ## Returns

  - `routing_decision()` with selected backends and retention policy
  """
  @spec route(map()) :: routing_decision()
  def route(entry) do
    ensure_started()
    do_route(entry)
  end

  @doc """
  Route multiple entries in a batch (more efficient for bulk operations).
  """
  @spec route_batch([map()]) :: [{map(), routing_decision()}]
  def route_batch(entries) when is_list(entries) do
    Enum.map(entries, fn entry -> {entry, route(entry)} end)
  end

  @doc """
  Add a new routing rule.
  """
  @spec add_rule(routing_rule()) :: :ok | {:error, term()}
  def add_rule(rule) do
    ensure_started()
    GenServer.call(__MODULE__, {:add_rule, rule})
  end

  @doc """
  Remove a routing rule by ID.
  """
  @spec remove_rule(String.t()) :: :ok | {:error, :not_found}
  def remove_rule(rule_id) do
    ensure_started()
    GenServer.call(__MODULE__, {:remove_rule, rule_id})
  end

  @doc """
  Enable or disable a rule.
  """
  @spec set_rule_enabled(String.t(), boolean()) :: :ok | {:error, :not_found}
  def set_rule_enabled(rule_id, enabled) do
    ensure_started()
    GenServer.call(__MODULE__, {:set_rule_enabled, rule_id, enabled})
  end

  @doc """
  Get all routing rules.
  """
  @spec get_rules() :: [routing_rule()]
  def get_rules do
    ensure_started()

    :fractal_routing_rules
    |> :ets.tab2list()
    |> Enum.map(fn {_id, rule} -> rule end)
  end

  @doc """
  Set backend health status.
  """
  @spec set_backend_health(backend(), boolean()) :: :ok
  def set_backend_health(backend, healthy) do
    ensure_started()
    :ets.insert(:fractal_backend_health, {backend, healthy})
    :ok
  end

  @doc """
  Check if a backend is healthy.
  """
  @spec backend_healthy?(backend()) :: boolean()
  def backend_healthy?(backend) do
    ensure_started()

    case :ets.lookup(:fractal_backend_health, backend) do
      [{^backend, healthy}] -> healthy
      # Assume healthy if unknown
      [] -> true
    end
  end

  @doc """
  Get all healthy backends.
  """
  @spec healthy_backends() :: [backend()]
  def healthy_backends do
    ensure_started()

    :fractal_backend_health
    |> :ets.tab2list()
    |> Enum.filter(fn {_b, healthy} -> healthy end)
    |> Enum.map(fn {b, _} -> b end)
  end

  @doc """
  Get router statistics.
  """
  @spec get_stats() :: map()
  def get_stats do
    ensure_started()
    GenServer.call(__MODULE__, :get_stats)
  end

  @doc """
  Reset statistics counters.
  """
  @spec reset_stats() :: :ok
  def reset_stats do
    ensure_started()
    GenServer.cast(__MODULE__, :reset_stats)
  end

  @doc """
  Initialize with default routing rules.
  """
  @spec initialize_with_defaults() :: :ok
  def initialize_with_defaults do
    ensure_started()

    # Security audit rule - highest priority
    add_rule(security_audit_rule())

    # L5 cognitive logs to SIEM + SigNoz (dual write)
    add_rule(l5_dual_write_rule())

    # Error tracking rule
    add_rule(error_tracking_rule())

    # Alarms rule
    add_rule(alarms_rule())

    # Cognitive/AI rule
    add_rule(cognitive_rule())

    # BlockchainLedger rule for immutable L5 audit trails
    add_rule(blockchain_audit_rule())

    # Debug/ephemeral rule (lowest priority catch-all)
    add_rule(debug_rule())

    :ok
  end

  @doc """
  Create rule for blockchain-backed immutable audit logs.
  """
  @spec blockchain_audit_rule() :: routing_rule()
  def blockchain_audit_rule do
    %{
      id: "blockchain-audit",
      key_expr: "Indrajaal/Audit/**",
      compiled_expr: nil,
      min_level: :l5,
      max_level: :l5,
      backends: [:blockchain_ledger, :postgresql, :object_store],
      retention: %{
        # 10 years
        min_retention: 3650 * 24 * 60 * 60_000,
        # 20 years
        max_retention: 7300 * 24 * 60 * 60_000,
        archive_on_expiry: true,
        compression_level: 9
      },
      # High priority after security-audit
      priority: 98,
      enabled: true
    }
  end

  # ============================================================
  # PREDEFINED RULES
  # ============================================================

  @doc """
  Create rule for security audit logs.
  """
  @spec security_audit_rule() :: routing_rule()
  def security_audit_rule do
    %{
      id: "security-audit",
      key_expr: "Indrajaal/Security/**",
      compiled_expr: nil,
      min_level: :l3,
      max_level: :l5,
      backends: [:siem, :postgresql, :object_store, :otlp],
      retention: %{
        min_retention: 365 * 24 * 60 * 60_000,
        max_retention: 3650 * 24 * 60 * 60_000,
        archive_on_expiry: true,
        compression_level: 9
      },
      priority: 100,
      enabled: true
    }
  end

  @doc """
  Create rule for L5 logs requiring dual write to SIEM and SigNoz.
  """
  @spec l5_dual_write_rule() :: routing_rule()
  def l5_dual_write_rule do
    %{
      id: "l5-dual-write",
      key_expr: "Indrajaal/**/L5",
      compiled_expr: nil,
      min_level: :l5,
      max_level: :l5,
      backends: [:siem, :signoz, :postgresql, :object_store],
      retention: %{
        min_retention: 365 * 24 * 60 * 60_000,
        max_retention: 3650 * 24 * 60 * 60_000,
        archive_on_expiry: true,
        compression_level: 9
      },
      priority: 95,
      enabled: true
    }
  end

  @doc """
  Create rule for error tracking.
  """
  @spec error_tracking_rule() :: routing_rule()
  def error_tracking_rule do
    %{
      id: "error-tracking",
      key_expr: "Indrajaal/**/error",
      compiled_expr: nil,
      min_level: :l1,
      max_level: :l5,
      backends: [:error_tracker, :postgresql, :otlp],
      retention: %{
        min_retention: 30 * 24 * 60 * 60_000,
        max_retention: 365 * 24 * 60 * 60_000,
        archive_on_expiry: true,
        compression_level: 6
      },
      priority: 90,
      enabled: true
    }
  end

  @doc """
  Create rule for alarm processing.
  """
  @spec alarms_rule() :: routing_rule()
  def alarms_rule do
    %{
      id: "alarms",
      key_expr: "Indrajaal/Alarms/**",
      compiled_expr: nil,
      min_level: :l3,
      max_level: :l5,
      backends: [:timescale_db, :postgresql, :otlp],
      retention: %{
        min_retention: 30 * 24 * 60 * 60_000,
        max_retention: 365 * 24 * 60 * 60_000,
        archive_on_expiry: true,
        compression_level: 6
      },
      priority: 80,
      enabled: true
    }
  end

  @doc """
  Create rule for cognitive/AI logs.
  """
  @spec cognitive_rule() :: routing_rule()
  def cognitive_rule do
    %{
      id: "cognitive",
      key_expr: "Indrajaal/Cortex/**",
      compiled_expr: nil,
      min_level: :l4,
      max_level: :l5,
      backends: [:postgresql, :timescale_db, :object_store],
      retention: %{
        min_retention: 90 * 24 * 60 * 60_000,
        max_retention: 730 * 24 * 60 * 60_000,
        archive_on_expiry: true,
        compression_level: 9
      },
      priority: 85,
      enabled: true
    }
  end

  @doc """
  Create rule for debug/ephemeral logs.
  """
  @spec debug_rule() :: routing_rule()
  def debug_rule do
    %{
      id: "debug",
      key_expr: "**",
      compiled_expr: nil,
      min_level: :l1,
      max_level: :l2,
      backends: [:memory, :console],
      retention: %{
        min_retention: 5 * 60_000,
        max_retention: 60 * 60_000,
        archive_on_expiry: false,
        compression_level: 0
      },
      priority: 1,
      enabled: true
    }
  end

  # ============================================================
  # GENSERVER CALLBACKS
  # ============================================================

  @impl true
  def init(_opts) do
    # Create ETS tables for fast lookups
    create_ets_tables()

    # Initialize backend health
    initialize_backend_health()

    state = %{
      route_count: 0,
      fallback_count: 0,
      started_at: DateTime.utc_now()
    }

    Logger.info("[ContentRouter] Initialized successfully")
    {:ok, state}
  end

  @impl true
  def handle_call({:add_rule, rule}, _from, state) do
    # Compile key expression
    compiled =
      case KeyExpression.compile(rule.key_expr) do
        {:ok, expr} -> expr
        {:error, _} -> nil
      end

    rule_with_compiled = Map.put(rule, :compiled_expr, compiled)
    :ets.insert(:fractal_routing_rules, {rule.id, rule_with_compiled})

    # Emit telemetry
    :telemetry.execute(
      [:fractal, :router, :rule_added],
      %{count: 1},
      %{rule_id: rule.id, key_expr: rule.key_expr}
    )

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:remove_rule, rule_id}, _from, state) do
    case :ets.lookup(:fractal_routing_rules, rule_id) do
      [{^rule_id, _}] ->
        :ets.delete(:fractal_routing_rules, rule_id)
        {:reply, :ok, state}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:set_rule_enabled, rule_id, enabled}, _from, state) do
    case :ets.lookup(:fractal_routing_rules, rule_id) do
      [{^rule_id, rule}] ->
        updated = Map.put(rule, :enabled, enabled)
        :ets.insert(:fractal_routing_rules, {rule_id, updated})
        {:reply, :ok, state}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    rules = :ets.tab2list(:fractal_routing_rules)
    enabled_rules = Enum.count(rules, fn {_id, r} -> r.enabled end)
    healthy = healthy_backends()

    stats = %{
      route_count: state.route_count,
      fallback_count: state.fallback_count,
      rule_count: length(rules),
      enabled_rules: enabled_rules,
      healthy_backends: length(healthy),
      total_backends: :ets.info(:fractal_backend_health, :size),
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at)
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_cast(:reset_stats, state) do
    {:noreply, %{state | route_count: 0, fallback_count: 0}}
  end

  @impl true
  def handle_cast({:update_stats, :fallback}, state) do
    {:noreply, %{state | fallback_count: state.fallback_count + 1}}
  end

  @impl true
  def handle_cast({:update_stats, :route}, state) do
    {:noreply, %{state | route_count: state.route_count + 1}}
  end

  @impl true
  def handle_info(:cleanup_expired, state) do
    # Periodic cleanup of stale data if needed
    {:noreply, state}
  end

  # ============================================================
  # PRIVATE: ROUTING LOGIC
  # ============================================================

  defp do_route(entry) do
    key = Map.get(entry, :key, "")
    level = Map.get(entry, :level, :l4)

    # Find matching rule
    case find_matching_rule(key, level) do
      nil ->
        # Use defaults based on level
        default_routing(level)

      rule ->
        # Filter backends by health
        healthy_backends = filter_healthy_backends(rule.backends)

        # Fallback if no healthy backends
        final_backends =
          if Enum.empty?(healthy_backends) do
            update_fallback_count()
            [:console]
          else
            healthy_backends
          end

        %{
          backends: final_backends,
          retention: rule.retention,
          matched_rule: rule.id,
          should_emit: true
        }
    end
  end

  defp find_matching_rule(key, level) do
    level_int = level_to_int(level)

    :fractal_routing_rules
    |> :ets.tab2list()
    |> Enum.filter(fn {_id, rule} ->
      rule.enabled and
        level_int >= level_to_int(rule.min_level) and
        level_int <= level_to_int(rule.max_level) and
        matches_key_expr?(rule, key)
    end)
    |> Enum.sort_by(fn {_id, rule} -> -rule.priority end)
    |> List.first()
    |> case do
      nil -> nil
      {_id, rule} -> rule
    end
  end

  defp matches_key_expr?(rule, key) do
    case rule.compiled_expr do
      nil ->
        # Fallback to simple matching
        String.starts_with?(key, rule.key_expr) or rule.key_expr == "**"

      compiled ->
        KeyExpression.matches?(compiled, key)
    end
  end

  defp filter_healthy_backends(backends) do
    Enum.filter(backends, fn backend ->
      case :ets.lookup(:fractal_backend_health, backend) do
        [{^backend, healthy}] -> healthy
        [] -> true
      end
    end)
  end

  defp default_routing(level) do
    default_backends = Map.get(@default_backends_by_level, level, [:otlp])
    healthy_backends = filter_healthy_backends(default_backends)

    retention = Map.get(@default_retention_by_level, level, @default_retention_by_level[:l3])

    %{
      backends: if(Enum.empty?(healthy_backends), do: [:console], else: healthy_backends),
      retention: retention,
      matched_rule: nil,
      should_emit: true
    }
  end

  defp level_to_int(level), do: Map.get(@level_to_int, level, 4)

  defp update_fallback_count do
    # Update via GenServer to maintain state
    GenServer.cast(__MODULE__, {:update_stats, :fallback})
  end

  # ============================================================
  # PRIVATE: ETS INITIALIZATION
  # ============================================================

  defp create_ets_tables do
    # Rules table
    case :ets.whereis(:fractal_routing_rules) do
      :undefined ->
        :ets.new(:fractal_routing_rules, [:named_table, :set, :public, read_concurrency: true])

      _ ->
        :ok
    end

    # Backend health table
    case :ets.whereis(:fractal_backend_health) do
      :undefined ->
        :ets.new(:fractal_backend_health, [:named_table, :set, :public, read_concurrency: true])

      _ ->
        :ok
    end
  end

  defp initialize_backend_health do
    # All supported backends including BlockchainLedger for immutable L5 audit trails
    # and Zenoh for real-time streaming to F# cockpit (SC-ZENOH-INT-001)
    backends = [
      :memory,
      :wal,
      :timescale_db,
      :postgresql,
      :object_store,
      :otlp,
      :signoz,
      :siem,
      :error_tracker,
      :console,
      :blockchain_ledger,
      :zenoh
    ]

    Enum.each(backends, fn backend ->
      :ets.insert(:fractal_backend_health, {backend, true})
    end)
  end

  defp ensure_started do
    case Process.whereis(__MODULE__) do
      nil ->
        # Start if not running (for testing or lazy initialization)
        case start_link([]) do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
          error -> error
        end

      _pid ->
        :ok
    end
  end
end
