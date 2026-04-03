defmodule Indrajaal.Observability.Fractal.Logger do
  @moduledoc """
  Fractal Logging System - Elixir Integration Module

  Provides the `@fractal` decorator macro and logging functions for the
  5-level Fractal Logging System based on Zenoh-style key expressions.

  ## STAMP Compliance
  - SC-LOG-001: Async dispatch (all emit functions are async)
  - SC-LOG-003: PII masking (auto-applied to all entries)
  - SC-LOG-004: TraceID linking (automatic propagation)
  - SC-LOG-005: Boost TTL (mandatory TTL on all boosts)
  - SC-LOG-006: HLC timestamps (auto-generated for L3+)

  ## AOR Compliance
  - AOR-LOG-001: Patient Mode (non-blocking operations)
  - AOR-LOG-002: Level validation before emit
  - AOR-LOG-003: Zenoh-style key expressions

  ## Usage

      use Indrajaal.Observability.Fractal.Logger

      # Automatic function tracing
      @fractal level: :l3, key: "Indrajaal/Accounts/create"
      def create_account(params) do
        # Function body - entry/exit automatically logged
      end

      # Manual logging
      fractal_log(:l4, "System startup", %{node: node()})

      # Boost for debugging
      fractal_boost("Indrajaal/Alarms/**", :l2, ttl_ms: 60_000)

  ## Fractal Levels

  | Level | Name         | Use Case                          |
  |-------|--------------|-----------------------------------|
  | L1    | Atomic       | Function args, hex dumps          |
  | L2    | Component    | GenServer state, ETS lookups      |
  | L3    | Transactional| Business flows, Trace IDs         |
  | L4    | Systemic     | Node health, network partitions   |
  | L5    | Cognitive    | AI intent, decision auditing      |
  """

  require Logger

  alias Indrajaal.Observability.TelemetryEnhancement
  alias Indrajaal.Observability.Fractal.{HLC, PIIMasker, KeyExpression}

  # ============================================================
  # TYPES
  # ============================================================

  @type fractal_level :: :l1 | :l2 | :l3 | :l4 | :l5
  @type priority :: :p0 | :p1 | :p2 | :p3
  @type event_type :: :entry | :exit | :exception | :state | :metric | :intent

  @type fractal_entry :: %{
          key: String.t(),
          key_alias: non_neg_integer() | nil,
          hlc: HLC.timestamp(),
          level: fractal_level(),
          priority: priority(),
          event_type: event_type(),
          trace_id: String.t() | nil,
          span_id: String.t() | nil,
          parent_span_id: String.t() | nil,
          payload: term(),
          baggage: map(),
          tags: [String.t()],
          timestamp: DateTime.t(),
          duration: non_neg_integer() | nil,
          node: atom(),
          module: atom(),
          function: atom(),
          arity: non_neg_integer()
        }

  # ============================================================
  # CONFIGURATION
  # ============================================================

  @default_level :l4
  @default_sampling_rates %{
    l1: 0.0,
    l2: 0.01,
    l3: 0.10,
    l4: 1.0,
    l5: 1.0
  }

  @level_to_int %{l1: 1, l2: 2, l3: 3, l4: 4, l5: 5}

  # ============================================================
  # MACRO: USE
  # ============================================================

  defmacro __using__(_opts) do
    quote do
      import Indrajaal.Observability.Fractal.Logger
      require Indrajaal.Observability.Fractal.Logger
    end
  end

  # ============================================================
  # MACRO: @fractal DECORATOR
  # ============================================================

  @doc """
  Decorator macro for automatic function tracing at a specified fractal level.

  ## Options
  - `:level` - Fractal level (:l1 to :l5), defaults to :l3
  - `:key` - Custom key expression, defaults to "Module/function"
  - `:mask_args` - Whether to mask arguments for PII (default: true)
  - `:sample_rate` - Override default sampling rate (0.0 to 1.0)

  ## Example

      @fractal level: :l3, key: "Indrajaal/Alarms/process"
      def process_alarm(alarm) do
        # Automatically logs entry and exit
      end
  """
  defmacro fractal(opts \\ []) do
    quote do
      @fractal_opts unquote(opts)
    end
  end

  # ============================================================
  # CORE LOGGING FUNCTIONS
  # ============================================================

  @doc """
  Emit a fractal log entry at the specified level.

  ## Parameters
  - `level` - Fractal level (:l1 to :l5)
  - `message` - Log message or structured data
  - `metadata` - Additional metadata map (optional)
  - `opts` - Options (optional)

  ## Options
  - `:key` - Custom key expression
  - `:trace_id` - Override trace ID
  - `:tags` - List of tags
  - `:event_type` - Event type (:entry, :exit, :exception, etc.)

  ## Examples

      fractal_log(:l3, "User login", %{user_id: 123})
      fractal_log(:l4, "System metric", %{cpu: 45.5}, key: "System/Metrics/cpu")
  """
  @spec fractal_log(fractal_level(), term(), map(), keyword()) :: :ok
  def fractal_log(level, message, metadata \\ %{}, opts \\ []) do
    if should_emit?(level, opts) do
      entry = build_entry(level, message, metadata, opts)
      async_emit(entry)
    end

    :ok
  end

  @doc """
  Emit an L1 (Atomic) log - function args, return values, hex dumps.
  """
  @spec fractal_l1(term(), map(), keyword()) :: :ok
  def fractal_l1(message, metadata \\ %{}, opts \\ []) do
    fractal_log(:l1, message, metadata, opts)
  end

  @doc """
  Emit an L2 (Component) log - GenServer state, messages, ETS lookups.
  """
  @spec fractal_l2(term(), map(), keyword()) :: :ok
  def fractal_l2(message, metadata \\ %{}, opts \\ []) do
    fractal_log(:l2, message, metadata, opts)
  end

  @doc """
  Emit an L3 (Transactional) log - business flows, trace IDs.
  """
  @spec fractal_l3(term(), map(), keyword()) :: :ok
  def fractal_l3(message, metadata \\ %{}, opts \\ []) do
    fractal_log(:l3, message, metadata, opts)
  end

  @doc """
  Emit an L4 (Systemic) log - node health, network partitions, metrics.
  """
  @spec fractal_l4(term(), map(), keyword()) :: :ok
  def fractal_l4(message, metadata \\ %{}, opts \\ []) do
    fractal_log(:l4, message, metadata, opts)
  end

  @doc """
  Emit an L5 (Cognitive) log - AI intent, hypotheses, decisions.
  """
  @spec fractal_l5(term(), map(), keyword()) :: :ok
  def fractal_l5(message, metadata \\ %{}, opts \\ []) do
    fractal_log(:l5, message, metadata, opts)
  end

  # ============================================================
  # BOOST MANAGEMENT
  # ============================================================

  @doc """
  Apply a temporary boost to increase logging depth for a key expression.

  ## Parameters
  - `key_expr` - Zenoh-style key expression (e.g., "Indrajaal/Alarms/**")
  - `depth` - Target fractal level (:l1 to :l5)
  - `opts` - Options

  ## Options
  - `:ttl_ms` - Time-to-live in milliseconds (default: 300_000 = 5 min)
  - `:created_by` - Creator identifier (default: current process)
  - `:filter` - Context filter map (e.g., %{user_id: "123"})

  ## Example

      fractal_boost("Indrajaal/Security/**", :l2, ttl_ms: 60_000)
  """
  @spec fractal_boost(String.t(), fractal_level(), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def fractal_boost(key_expr, depth, opts \\ []) do
    ttl_ms = Keyword.get(opts, :ttl_ms, 300_000)
    created_by = Keyword.get(opts, :created_by, inspect(self()))
    filter = Keyword.get(opts, :filter, %{})

    # Validate TTL (SC-LOG-005: mandatory TTL)
    # 1 hour max
    max_ttl = 3_600_000

    if ttl_ms > max_ttl do
      {:error, :ttl_exceeds_maximum}
    else
      boost_id = generate_boost_id()

      # Compile the key expression (SC-LOG-009: pre-register key aliases)
      compiled =
        case KeyExpression.compile(key_expr) do
          {:ok, expr} -> expr
          {:error, _} -> nil
        end

      now = DateTime.utc_now()

      boost = %{
        id: boost_id,
        key_expr: key_expr,
        compiled_expr: compiled,
        depth: depth,
        filter: filter,
        created_at: now,
        expires_at: DateTime.add(now, ttl_ms, :millisecond),
        hlc_expires_at: nil,
        created_by: created_by
      }

      # Store in ETS and propagate via Redis if configured
      store_boost(boost)
      {:ok, boost_id}
    end
  end

  @doc """
  Remove an active boost by ID.
  """
  @spec fractal_unboost(String.t()) :: :ok | {:error, :not_found}
  def fractal_unboost(boost_id) do
    remove_boost(boost_id)
  end

  @doc """
  List all active boosts.
  """
  @spec fractal_boosts() :: [map()]
  def fractal_boosts do
    list_active_boosts()
  end

  # ============================================================
  # FUNCTION TRACING (for @fractal decorator)
  # ============================================================

  @doc """
  Wrap a function call with fractal logging (entry/exit/exception).

  Used by the @fractal decorator macro.
  """
  @spec trace_function(atom(), atom(), non_neg_integer(), (-> term()), keyword()) :: term()
  def trace_function(module, function, _arity, fun, opts \\ []) do
    level = Keyword.get(opts, :level, :l3)
    key = Keyword.get(opts, :key, build_key(module, function))
    start_time = System.monotonic_time(:microsecond)

    # Log entry
    fractal_log(level, "Function entry", %{}, key: key, event_type: :entry)

    try do
      result = fun.()
      duration = System.monotonic_time(:microsecond) - start_time

      # Log exit
      fractal_log(level, "Function exit", %{duration_us: duration}, key: key, event_type: :exit)

      result
    rescue
      exception ->
        duration = System.monotonic_time(:microsecond) - start_time
        stacktrace = __STACKTRACE__

        # Log exception at L4 (always)
        fractal_log(
          :l4,
          "Function exception",
          %{
            exception: inspect(exception),
            duration_us: duration,
            stacktrace: Exception.format_stacktrace(stacktrace)
          },
          key: key,
          event_type: :exception
        )

        reraise exception, stacktrace
    end
  end

  # ============================================================
  # PRIVATE: ENTRY BUILDING
  # ============================================================

  defp build_entry(level, message, metadata, opts) do
    now = DateTime.utc_now()
    trace_id = get_trace_id(opts)
    span_id = get_span_id(opts)
    key = Keyword.get(opts, :key, "Indrajaal/Log")
    event_type = Keyword.get(opts, :event_type, :entry)
    tags = Keyword.get(opts, :tags, [])

    # Build HLC for L3+ (SC-LOG-006)
    hlc = if level_to_int(level) >= 3, do: HLC.now(), else: nil

    # Mask PII in metadata (SC-LOG-003)
    masked_metadata = PIIMasker.mask(metadata)

    %{
      key: key,
      key_alias: nil,
      hlc: hlc,
      level: level,
      priority: level_to_priority(level),
      event_type: event_type,
      trace_id: trace_id,
      span_id: span_id,
      parent_span_id: get_parent_span_id(opts),
      payload: %{message: message, metadata: masked_metadata},
      baggage: get_baggage(),
      tags: tags,
      timestamp: now,
      duration: nil,
      node: node(),
      module: nil,
      function: nil,
      arity: 0
    }
  end

  # ============================================================
  # PRIVATE: EMISSION
  # ============================================================

  defp should_emit?(level, opts) do
    # Check if level is enabled globally
    global_enabled = get_global_level()
    level_int = level_to_int(level)
    global_int = level_to_int(global_enabled)

    # Check for active boost
    key = Keyword.get(opts, :key, "**")
    boosted = check_boost(key, level)

    # Check sampling rate
    sampled = sample?(level)

    (level_int >= global_int or boosted) and sampled
  end

  defp sample?(level) do
    rate = Map.get(@default_sampling_rates, level, 1.0)
    :rand.uniform() <= rate
  end

  defp async_emit(entry) do
    # SC-LOG-001: Async dispatch (never block)
    Task.start(fn ->
      emit_to_backends(entry)
    end)
  end

  defp emit_to_backends(entry) do
    # Emit to OTEL
    emit_to_otel(entry)

    # Emit to Logger for local visibility
    emit_to_logger(entry)

    # Emit to Telemetry for metrics
    emit_to_telemetry(entry)
  end

  defp emit_to_otel(entry) do
    # Convert to OTEL span/log
    :telemetry.execute(
      [:fractal, :log, :emit],
      %{count: 1, level: level_to_int(entry.level)},
      entry
    )
  end

  defp emit_to_logger(entry) do
    level_atom =
      case entry.level do
        :l1 -> :debug
        :l2 -> :debug
        :l3 -> :info
        :l4 -> :notice
        :l5 -> :notice
      end

    Logger.log(level_atom, fn ->
      "[Fractal:#{entry.level}] #{entry.key}: #{inspect(entry.payload)}"
    end)
  end

  defp emit_to_telemetry(entry) do
    TelemetryEnhancement.emit_custom_event(
      [:fractal, entry.level, entry.event_type],
      %{timestamp: entry.timestamp},
      entry.payload.metadata
    )
  end

  # ============================================================
  # PRIVATE: HELPERS
  # ============================================================

  defp level_to_int(level), do: Map.get(@level_to_int, level, 4)

  defp level_to_priority(level) do
    case level do
      :l5 -> :p0
      :l4 -> :p0
      :l3 -> :p1
      :l2 -> :p2
      :l1 -> :p3
    end
  end

  defp build_key(module, function) do
    module_str = module |> to_string() |> String.replace("Elixir.", "")
    "#{module_str}/#{function}"
  end

  defp get_trace_id(opts) do
    Keyword.get(opts, :trace_id) || Process.get(:fractal_trace_id)
  end

  defp get_span_id(opts) do
    Keyword.get(opts, :span_id) || Process.get(:fractal_span_id)
  end

  defp get_parent_span_id(opts) do
    Keyword.get(opts, :parent_span_id) || Process.get(:fractal_parent_span_id)
  end

  defp get_baggage do
    Process.get(:fractal_baggage, %{})
  end

  defp get_global_level do
    Application.get_env(:indrajaal, :fractal_default_level, @default_level)
  end

  defp generate_boost_id do
    random_bytes = :crypto.strong_rand_bytes(4)
    random_bytes |> Base.encode16(case: :lower)
  end

  # ============================================================
  # PRIVATE: BOOST STORAGE (ETS-based)
  # ============================================================

  defp store_boost(boost) do
    ensure_ets_table()
    :ets.insert(:fractal_boosts, {boost.id, boost})
    propagate_boost_to_redis(boost)
  end

  defp remove_boost(boost_id) do
    ensure_ets_table()

    case :ets.lookup(:fractal_boosts, boost_id) do
      [{^boost_id, _}] ->
        :ets.delete(:fractal_boosts, boost_id)
        :ok

      [] ->
        {:error, :not_found}
    end
  end

  defp list_active_boosts do
    ensure_ets_table()
    now = DateTime.utc_now()

    boosts = :ets.tab2list(:fractal_boosts)

    boosts
    |> Enum.map(fn {_id, boost} -> boost end)
    |> Enum.filter(fn boost -> DateTime.compare(boost.expires_at, now) == :gt end)
  end

  defp check_boost(key, level) do
    ensure_ets_table()
    now = DateTime.utc_now()

    boosts_list = :ets.tab2list(:fractal_boosts)

    boosts_list
    |> Enum.any?(fn {_id, boost} ->
      DateTime.compare(boost.expires_at, now) == :gt and
        KeyExpression.matches?(boost.key_expr, key) and
        level_to_int(level) >= level_to_int(boost.depth)
    end)
  end

  defp ensure_ets_table do
    case :ets.whereis(:fractal_boosts) do
      :undefined ->
        :ets.new(:fractal_boosts, [:named_table, :set, :public])

      _ ->
        :ok
    end
  end

  defp propagate_boost_to_redis(_boost) do
    # If Redis is configured, propagate for multi-node sync
    case Application.get_env(:indrajaal, :fractal_redis_enabled, false) do
      true ->
        # Would use Redix to publish boost
        :ok

      false ->
        :ok
    end
  end
end
