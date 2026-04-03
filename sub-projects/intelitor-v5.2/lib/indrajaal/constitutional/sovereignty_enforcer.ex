defmodule Indrajaal.Constitutional.SovereigntyEnforcer do
  @moduledoc """
  Sovereignty Enforcer — L0 Constitutional Layer

  ## Design Intent
  GenServer that enforces Ω₇ — Holon State Sovereignty. The sovereign mandate is:

  > Authoritative holon state ≡ SQLite ∪ DuckDB ONLY. PostgreSQL ∩ HolonState ≡ ∅.

  This module validates all state access requests, maintains a registry of sovereign
  stores (SQLite/DuckDB paths), detects sovereignty violations (attempts to read/write
  holon state from non-sovereign backends), and emits audit events for each violation.

  The enforcer acts as a constitutional firewall. It does not block I/O directly
  but records, audits, and alerts on any detected violation pattern.

  ## Human-Specified Intent
  <!-- HUMAN-ONLY: DO NOT AUTO-MODIFY -->
  <!-- Last modified by: [Pending Human Author] on [TBD] -->

  ### Functional Intent
  [What this module MUST do from the human operator's perspective]

  ### UX Requirements
  [How the module MUST feel and behave for the operator]

  ### Safety Requirements
  [Non-negotiable safety behaviors]

  ### Override Instructions
  [Any instructions that override agent-generated behavior]
  <!-- END HUMAN-ONLY -->

  ## STAMP Constraints
  - SC-HOLON-009: SQLite/DuckDB is the ONLY source of truth for holon state
  - SC-STATE-001: Atomic state updates via sovereign stores only
  - SC-STATE-003: All state transitions MUST be logged
  - SC-XHOLON-001: Isolated database files per holon
  - SC-XHOLON-003: Cross-holon access via Zenoh ONLY
  - SC-SAFETY-010: Ψ₁ (Regeneration) verified — SQLite/DuckDB storage
  - Ω₇ (Holon State Sovereignty): Non-negotiable constitutional axiom

  ## Change History
  | Version | Date       | Author | Change                           |
  |---------|------------|--------|----------------------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial implementation (L0)      |
  """

  use GenServer

  require Logger

  @name __MODULE__
  @ets_table :sovereignty_registry
  @pubsub_topic "constitutional:sovereignty"
  @zenoh_topic "indrajaal/constitutional/sovereignty"
  @audit_interval_ms 30_000

  # Backend types that are sovereign (permitted for holon state)
  @sovereign_backends [:sqlite, :duckdb, :exqlite, :duckdbex]

  # Backend types that are non-sovereign (MUST NOT hold holon state)
  @non_sovereign_backends [:postgres, :postgresql, :mysql, :mssql, :redis]

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type backend :: atom()
  @type store_path :: String.t()
  @type actor :: String.t()
  @type access_type :: :read | :write | :delete | :migrate

  @type store_entry :: %{
          path: store_path(),
          backend: backend(),
          registered_by: actor(),
          registered_at: DateTime.t(),
          is_sovereign: boolean()
        }

  @type violation_record :: %{
          actor: actor(),
          backend: backend(),
          access_type: access_type(),
          detail: String.t(),
          detected_at: DateTime.t()
        }

  @type validation_result :: :sovereign | {:violation, String.t()}

  @type state :: %{
          validation_count: non_neg_integer(),
          violation_count: non_neg_integer(),
          audit_count: non_neg_integer()
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Validates that a state access request is sovereign (SC-HOLON-009).

  Returns `:sovereign` if the backend is permitted, or `{:violation, reason}` if not.
  All calls are logged and metrics emitted.

  - `actor` — the component/process requesting access
  - `backend` — the storage backend being accessed (e.g., `:postgres`, `:sqlite`)
  """
  @spec validate_state_access(actor(), backend()) :: validation_result()
  def validate_state_access(actor, backend) do
    GenServer.call(@name, {:validate_state_access, actor, backend}, 5_000)
  end

  @doc """
  Registers a sovereign store in the registry.

  Only `:sqlite` and `:duckdb` backends are accepted. Attempting to register a
  non-sovereign backend returns `{:error, :non_sovereign_backend}`.

  Returns `{:ok, store_entry()}` or `{:error, reason}`.
  """
  @spec register_sovereign_store(store_path(), keyword()) ::
          {:ok, store_entry()} | {:error, term()}
  def register_sovereign_store(path, opts \\ []) do
    GenServer.call(@name, {:register_sovereign_store, path, opts}, 10_000)
  end

  @doc """
  Runs a full sovereignty audit over all registered stores and returns a report.
  """
  @spec audit_sovereignty() :: map()
  def audit_sovereignty do
    GenServer.call(@name, :audit_sovereignty, 15_000)
  end

  @doc """
  Records a sovereignty violation detected outside the enforcer.

  Use this when the detecting system cannot use `validate_state_access/2` directly.
  Returns `{:ok, :recorded}`.
  """
  @spec block_violation(map()) :: {:ok, :recorded} | {:error, term()}
  def block_violation(violation_attrs) do
    GenServer.call(@name, {:block_violation, violation_attrs}, 10_000)
  end

  @doc """
  Returns the accumulated sovereignty violation history.
  """
  @spec violation_history() :: list(violation_record())
  def violation_history do
    case :ets.whereis(@ets_table) do
      :undefined ->
        []

      _ ->
        case :ets.lookup(@ets_table, :__violation_history__) do
          [{:__violation_history__, history}] -> history
          _ -> []
        end
    end
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    :ets.new(@ets_table, [:named_table, :public, read_concurrency: true])
    :ets.insert(@ets_table, {:__violation_history__, []})

    # Seed sovereign stores from application config or opts
    initial_stores = Keyword.get(opts, :initial_stores, [])

    Enum.each(initial_stores, fn {path, backend} ->
      seed_store(path, backend)
    end)

    schedule_audit()

    Logger.warning(
      "[SovereigntyEnforcer] L0 Sovereignty Enforcer started — " <>
        "sovereign_backends=#{inspect(@sovereign_backends)}"
    )

    initial_state = %{
      validation_count: 0,
      violation_count: 0,
      audit_count: 0
    }

    {:ok, initial_state}
  end

  @impl true
  def handle_call({:validate_state_access, actor, backend}, _from, state) do
    {result, new_state} = do_validate(actor, backend, :read, state)
    {:reply, result, new_state}
  end

  @impl true
  def handle_call({:register_sovereign_store, path, opts}, _from, state) do
    backend = Keyword.get(opts, :backend, :sqlite)
    registered_by = Keyword.get(opts, :registered_by, "system")

    if backend in @sovereign_backends do
      entry = %{
        path: path,
        backend: backend,
        registered_by: registered_by,
        registered_at: DateTime.utc_now(),
        is_sovereign: true
      }

      :ets.insert(@ets_table, {{:store, path}, entry})

      Logger.info(
        "[SovereigntyEnforcer] Sovereign store registered path=#{path} backend=#{backend}"
      )

      emit_telemetry(:store_registered, entry, state)
      broadcast_pubsub({:sovereign_store_registered, entry})

      {:reply, {:ok, entry}, state}
    else
      violation_msg =
        "Attempt to register non-sovereign backend #{backend} as sovereign store (path=#{path}). " <>
          "Ω₇: Only #{inspect(@sovereign_backends)} are sovereign. SC-HOLON-009."

      Logger.error("[SovereigntyEnforcer] " <> violation_msg)

      {:reply, {:error, :non_sovereign_backend}, state}
    end
  end

  @impl true
  def handle_call(:audit_sovereignty, _from, state) do
    report = do_audit()
    new_state = %{state | audit_count: state.audit_count + 1}
    emit_telemetry(:audit_completed, %{}, new_state)
    {:reply, report, new_state}
  end

  @impl true
  def handle_call({:block_violation, attrs}, _from, state) do
    violation = %{
      actor: Map.get(attrs, :actor, "unknown"),
      backend: Map.get(attrs, :backend, :unknown),
      access_type: Map.get(attrs, :access_type, :unknown),
      detail: Map.get(attrs, :detail, "External violation reported"),
      detected_at: DateTime.utc_now()
    }

    append_violation(violation)

    new_state = %{state | violation_count: state.violation_count + 1}

    Logger.error(
      "[SovereigntyEnforcer] External violation recorded actor=#{violation.actor} " <>
        "backend=#{violation.backend} detail=#{violation.detail}"
    )

    emit_telemetry(:violation_blocked, %{}, new_state)
    broadcast_pubsub({:sovereignty_violation, violation})

    {:reply, {:ok, :recorded}, new_state}
  end

  @impl true
  def handle_info(:run_audit, state) do
    _report = do_audit()
    schedule_audit()
    new_state = %{state | audit_count: state.audit_count + 1}
    {:noreply, new_state}
  end

  # ---------------------------------------------------------------------------
  # Private — validation logic
  # ---------------------------------------------------------------------------

  @spec do_validate(actor(), backend(), access_type(), state()) ::
          {validation_result(), state()}
  defp do_validate(actor, backend, access_type, state) do
    new_validation_count = state.validation_count + 1

    if backend in @non_sovereign_backends do
      violation_msg =
        "SC-HOLON-009 VIOLATION: actor=#{actor} attempted #{access_type} via " <>
          "non-sovereign backend=#{backend}. Ω₇ mandates SQLite/DuckDB ONLY."

      violation = %{
        actor: actor,
        backend: backend,
        access_type: access_type,
        detail: violation_msg,
        detected_at: DateTime.utc_now()
      }

      append_violation(violation)

      new_state = %{
        state
        | validation_count: new_validation_count,
          violation_count: state.violation_count + 1
      }

      Logger.error("[SovereigntyEnforcer] " <> violation_msg)

      emit_telemetry(:violation_detected, %{}, new_state)
      broadcast_pubsub({:sovereignty_violation, violation})

      {{:violation, violation_msg}, new_state}
    else
      new_state = %{state | validation_count: new_validation_count}

      Logger.debug("[SovereigntyEnforcer] Access SOVEREIGN actor=#{actor} backend=#{backend}")

      {:sovereign, new_state}
    end
  end

  @spec do_audit() :: map()
  defp do_audit do
    stores = list_all_stores()
    violations = violation_history()

    sovereign_stores = Enum.filter(stores, & &1.is_sovereign)
    non_sovereign_stores = Enum.reject(stores, & &1.is_sovereign)

    report = %{
      timestamp: DateTime.utc_now(),
      total_stores: length(stores),
      sovereign_stores: length(sovereign_stores),
      non_sovereign_stores: length(non_sovereign_stores),
      violation_count: length(violations),
      sovereignty_intact: length(non_sovereign_stores) == 0,
      stores: Enum.map(sovereign_stores, fn s -> %{path: s.path, backend: s.backend} end)
    }

    if length(non_sovereign_stores) > 0 do
      Logger.error(
        "[SovereigntyEnforcer] AUDIT: #{length(non_sovereign_stores)} non-sovereign stores detected!"
      )

      broadcast_pubsub({:sovereignty_audit_failed, report})
    else
      Logger.debug(
        "[SovereigntyEnforcer] AUDIT PASS — #{length(sovereign_stores)} sovereign stores, " <>
          "#{length(violations)} cumulative violations"
      )
    end

    report
  end

  # ---------------------------------------------------------------------------
  # Private — helpers
  # ---------------------------------------------------------------------------

  @spec seed_store(store_path(), backend()) :: :ok
  defp seed_store(path, backend) do
    if backend in @sovereign_backends do
      entry = %{
        path: path,
        backend: backend,
        registered_by: "init",
        registered_at: DateTime.utc_now(),
        is_sovereign: true
      }

      :ets.insert(@ets_table, {{:store, path}, entry})
    end

    :ok
  end

  @spec list_all_stores() :: list(store_entry())
  defp list_all_stores do
    case :ets.whereis(@ets_table) do
      :undefined ->
        []

      _ ->
        @ets_table
        |> :ets.tab2list()
        |> Enum.filter(fn {key, _val} ->
          is_tuple(key) and tuple_size(key) == 2 and elem(key, 0) == :store
        end)
        |> Enum.map(fn {_key, val} -> val end)
    end
  end

  @spec append_violation(violation_record()) :: :ok
  defp append_violation(violation) do
    current =
      case :ets.lookup(@ets_table, :__violation_history__) do
        [{:__violation_history__, history}] -> history
        _ -> []
      end

    :ets.insert(@ets_table, {:__violation_history__, [violation | current]})
    :ok
  end

  defp schedule_audit do
    Process.send_after(self(), :run_audit, @audit_interval_ms)
  end

  @spec emit_telemetry(atom(), map(), state()) :: :ok
  defp emit_telemetry(event, _entry, state) do
    try do
      :telemetry.execute(
        [:indrajaal, :constitutional, :sovereignty, event],
        %{
          validation_count: state.validation_count,
          violation_count: state.violation_count,
          audit_count: state.audit_count
        },
        %{topic: @zenoh_topic}
      )
    rescue
      err ->
        Logger.warning("[SovereigntyEnforcer] telemetry emit failed: #{inspect(err)}")
    end

    :ok
  end

  @spec broadcast_pubsub(term()) :: :ok
  defp broadcast_pubsub(message) do
    try do
      Phoenix.PubSub.broadcast(Indrajaal.PubSub, @pubsub_topic, message)
    rescue
      err ->
        Logger.warning("[SovereigntyEnforcer] PubSub broadcast failed: #{inspect(err)}")
    end

    :ok
  end
end
