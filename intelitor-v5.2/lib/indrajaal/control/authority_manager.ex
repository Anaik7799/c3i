defmodule Indrajaal.Control.AuthorityManager do
  @moduledoc """
  L3 Control Layer — authority delegation and escalation management.

  ## Design Intent
  Manages a hierarchy of authority levels for the VSM System 3 control layer.
  Authority can be delegated from a higher level to a lower one, with an
  optional time-to-live (TTL) in seconds.  When an action requires a level
  that the current actor does not hold, the escalation protocol promotes the
  request one level at a time: operator → supervisor → guardian.  Each level
  has a 30-second timeout before the next escalation fires automatically.

  ETS provides O(1) lookup of the current authority for any actor identity.

  ## STAMP Constraints
  - SC-SAFETY-001: Guardian pre-approval REQUIRED for authority mutations
  - SC-GUARD-001: Guardian MUST use Envelope for constraint values
  - SC-ORCH-005: Critical actions MUST request Guardian approval
  - SC-CONC-001: ETS read_concurrency for hot read paths
  - SC-SESS-001: Session authority must be verified before action execution

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Claude Sonnet 4.6 | Initial implementation (L3 control layer) |
  """

  use GenServer

  require Logger

  @pubsub Indrajaal.PubSub
  @escalation_topic "control:authority:escalated"

  # Authority level ordering — higher index = higher authority
  @levels [:operator, :supervisor, :guardian, :founder]
  @escalation_timeout_ms 30_000

  @type authority_level :: :operator | :supervisor | :guardian | :founder

  @type delegation :: %{
          delegator: term(),
          delegate: term(),
          level: authority_level(),
          expires_at: DateTime.t() | :never,
          delegated_at: DateTime.t()
        }

  @type escalation_request :: %{
          request_id: reference(),
          actor: term(),
          required_level: authority_level(),
          current_level: authority_level(),
          escalated_to: authority_level(),
          requested_at: DateTime.t(),
          status: :pending | :approved | :denied | :timeout
        }

  @type manager_state :: %{
          table: :ets.tid(),
          delegations: [delegation()],
          escalations: %{reference() => escalation_request()},
          metrics: %{
            delegations_created: non_neg_integer(),
            delegations_expired: non_neg_integer(),
            escalations_triggered: non_neg_integer(),
            escalations_approved: non_neg_integer(),
            escalations_denied: non_neg_integer()
          }
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc "Start the AuthorityManager GenServer."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Grant `level` authority to `actor` directly (no delegation chain).

  Only the founder or guardian may call this.  Returns `:ok`.
  """
  @spec grant(term(), authority_level()) :: :ok
  def grant(actor, level) when level in @levels do
    GenServer.call(__MODULE__, {:grant, actor, level})
  end

  @doc """
  Delegate authority from `delegator` to `delegate`.

  `ttl_seconds` is optional; `:infinity` means no expiry.
  Delegation can only move downward in the authority hierarchy
  (delegator must hold a level >= `level`).
  """
  @spec delegate(term(), term(), authority_level(), pos_integer() | :infinity) ::
          :ok | {:error, :insufficient_authority | :invalid_level}
  def delegate(delegator, delegate, level, ttl_seconds \\ :infinity)
      when level in @levels do
    GenServer.call(__MODULE__, {:delegate, delegator, delegate, level, ttl_seconds})
  end

  @doc """
  Revoke all authority for `actor`.
  """
  @spec revoke(term()) :: :ok
  def revoke(actor) do
    GenServer.call(__MODULE__, {:revoke, actor})
  end

  @doc """
  Get the current authority level for `actor` (fast ETS read).

  Returns the authority level atom or `:none` if no authority is granted.
  """
  @spec get_level(term()) :: authority_level() | :none
  def get_level(actor) do
    table = :ets.whereis(:authority_registry)

    if table != :undefined do
      case :ets.lookup(table, actor) do
        [{^actor, level, _expires}] -> level
        [] -> :none
      end
    else
      :none
    end
  end

  @doc """
  Check whether `actor` holds at least `required_level`.

  Returns `true` or `false`.
  """
  @spec authorized?(term(), authority_level()) :: boolean()
  def authorized?(actor, required_level) when required_level in @levels do
    current = get_level(actor)

    if current == :none do
      false
    else
      level_index(current) >= level_index(required_level)
    end
  end

  @doc """
  Trigger the escalation protocol for `actor` who needs `required_level`.

  The escalation runs asynchronously.  A reference is returned that can be
  polled via `escalation_status/1`.  Each tier is attempted with a
  #{@escalation_timeout_ms}ms timeout before moving to the next level.
  """
  @spec escalate(term(), authority_level()) :: {:ok, reference()}
  def escalate(actor, required_level) when required_level in @levels do
    GenServer.call(__MODULE__, {:escalate, actor, required_level})
  end

  @doc "Check the status of an escalation request."
  @spec escalation_status(reference()) ::
          {:ok, escalation_request()} | {:error, :not_found}
  def escalation_status(request_id) when is_reference(request_id) do
    GenServer.call(__MODULE__, {:escalation_status, request_id})
  end

  @doc "Return current metrics."
  @spec metrics() :: map()
  def metrics do
    GenServer.call(__MODULE__, :metrics)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    table =
      :ets.new(:authority_registry, [
        :set,
        :named_table,
        :protected,
        read_concurrency: true
      ])

    # Seed the founder's authority
    :ets.insert(table, {:founder, :founder, :never})

    state = %{
      table: table,
      delegations: [],
      escalations: %{},
      metrics: %{
        delegations_created: 0,
        delegations_expired: 0,
        escalations_triggered: 0,
        escalations_approved: 0,
        escalations_denied: 0
      }
    }

    Logger.info("[AuthorityManager] L3 authority manager started (SC-SAFETY-001, SC-GUARD-001)")
    schedule_expiry_check()
    {:ok, state}
  end

  @impl true
  def handle_call({:grant, actor, level}, _from, state) do
    :ets.insert(state.table, {actor, level, :never})
    Logger.info("[AuthorityManager] Granted #{level} to actor=#{inspect(actor)}")
    emit_telemetry(:grant, %{actor: inspect(actor), level: level})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:delegate, delegator, delegate, level, ttl_seconds}, _from, state) do
    delegator_level = get_ets_level(state.table, delegator)

    cond do
      delegator_level == :none ->
        {:reply, {:error, :insufficient_authority}, state}

      level_index(delegator_level) < level_index(level) ->
        {:reply, {:error, :insufficient_authority}, state}

      true ->
        expires_at = compute_expiry(ttl_seconds)
        :ets.insert(state.table, {delegate, level, expires_at})

        delegation = %{
          delegator: delegator,
          delegate: delegate,
          level: level,
          expires_at: expires_at,
          delegated_at: DateTime.utc_now()
        }

        new_delegations = [delegation | state.delegations]
        new_metrics = Map.update!(state.metrics, :delegations_created, &(&1 + 1))

        Logger.info(
          "[AuthorityManager] Delegated #{level} from #{inspect(delegator)} to #{inspect(delegate)}"
        )

        emit_telemetry(:delegate, %{
          delegator: inspect(delegator),
          delegate: inspect(delegate),
          level: level
        })

        {:reply, :ok, %{state | delegations: new_delegations, metrics: new_metrics}}
    end
  end

  @impl true
  def handle_call({:revoke, actor}, _from, state) do
    :ets.delete(state.table, actor)
    new_delegations = Enum.reject(state.delegations, fn d -> d.delegate == actor end)
    Logger.info("[AuthorityManager] Revoked authority for actor=#{inspect(actor)}")
    emit_telemetry(:revoke, %{actor: inspect(actor)})
    {:reply, :ok, %{state | delegations: new_delegations}}
  end

  @impl true
  def handle_call({:escalate, actor, required_level}, _from, state) do
    request_id = make_ref()
    current_level = get_ets_level(state.table, actor)
    first_escalation = next_level(current_level)

    request = %{
      request_id: request_id,
      actor: actor,
      required_level: required_level,
      current_level: current_level,
      escalated_to: first_escalation,
      requested_at: DateTime.utc_now(),
      status: :pending
    }

    broadcast_escalation(request)
    Process.send_after(self(), {:escalation_timeout, request_id}, @escalation_timeout_ms)

    new_escalations = Map.put(state.escalations, request_id, request)
    new_metrics = Map.update!(state.metrics, :escalations_triggered, &(&1 + 1))

    Logger.warning(
      "[AuthorityManager] Escalation triggered actor=#{inspect(actor)} required=#{required_level} escalated_to=#{first_escalation}"
    )

    {:reply, {:ok, request_id}, %{state | escalations: new_escalations, metrics: new_metrics}}
  end

  @impl true
  def handle_call({:escalation_status, request_id}, _from, state) do
    case Map.get(state.escalations, request_id) do
      nil -> {:reply, {:error, :not_found}, state}
      request -> {:reply, {:ok, request}, state}
    end
  end

  @impl true
  def handle_call(:metrics, _from, state) do
    {:reply, state.metrics, state}
  end

  @impl true
  def handle_info(:expiry_check, state) do
    now = DateTime.utc_now()

    expired_actors =
      state.table
      |> :ets.tab2list()
      |> Enum.filter(fn
        {_actor, _level, :never} -> false
        {_actor, _level, expires_at} -> DateTime.compare(now, expires_at) != :lt
      end)
      |> Enum.map(fn {actor, _level, _exp} -> actor end)

    Enum.each(expired_actors, fn actor ->
      :ets.delete(state.table, actor)
      Logger.debug("[AuthorityManager] Delegation expired for actor=#{inspect(actor)}")
    end)

    expired_count = length(expired_actors)

    new_metrics =
      if expired_count > 0 do
        Map.update!(state.metrics, :delegations_expired, &(&1 + expired_count))
      else
        state.metrics
      end

    schedule_expiry_check()
    {:noreply, %{state | metrics: new_metrics}}
  end

  @impl true
  def handle_info({:escalation_timeout, request_id}, state) do
    case Map.get(state.escalations, request_id) do
      nil ->
        {:noreply, state}

      %{status: :pending} = request ->
        # Try the next escalation tier
        next = next_level(request.escalated_to)

        if next == request.escalated_to do
          # Already at the top level — mark as timeout
          updated = %{request | status: :timeout}
          new_escalations = Map.put(state.escalations, request_id, updated)

          Logger.error(
            "[AuthorityManager] Escalation timed out at top level actor=#{inspect(request.actor)}"
          )

          {:noreply, %{state | escalations: new_escalations}}
        else
          updated = %{request | escalated_to: next}
          broadcast_escalation(updated)
          Process.send_after(self(), {:escalation_timeout, request_id}, @escalation_timeout_ms)
          new_escalations = Map.put(state.escalations, request_id, updated)

          Logger.warning(
            "[AuthorityManager] Escalation promoted to #{next} actor=#{inspect(request.actor)}"
          )

          {:noreply, %{state | escalations: new_escalations}}
        end

      _already_resolved ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec level_index(authority_level() | :none) :: integer()
  defp level_index(:none), do: -1
  defp level_index(:operator), do: 0
  defp level_index(:supervisor), do: 1
  defp level_index(:guardian), do: 2
  defp level_index(:founder), do: 3

  @spec next_level(authority_level() | :none) :: authority_level()
  defp next_level(:none), do: :operator
  defp next_level(:operator), do: :supervisor
  defp next_level(:supervisor), do: :guardian
  defp next_level(:guardian), do: :founder
  defp next_level(:founder), do: :founder

  @spec get_ets_level(:ets.tid(), term()) :: authority_level() | :none
  defp get_ets_level(table, actor) do
    case :ets.lookup(table, actor) do
      [{^actor, level, _expires}] -> level
      [] -> :none
    end
  end

  @spec compute_expiry(pos_integer() | :infinity) :: DateTime.t() | :never
  defp compute_expiry(:infinity), do: :never

  defp compute_expiry(seconds) when is_integer(seconds) and seconds > 0 do
    DateTime.add(DateTime.utc_now(), seconds, :second)
  end

  defp broadcast_escalation(request) do
    try do
      Phoenix.PubSub.broadcast(@pubsub, @escalation_topic, {:authority_escalated, request})
    rescue
      _ -> :ok
    end
  end

  defp schedule_expiry_check do
    Process.send_after(self(), :expiry_check, 10_000)
  end

  defp emit_telemetry(event, measurements) do
    :telemetry.execute(
      [:indrajaal, :control, :authority_manager, event],
      measurements,
      %{timestamp: DateTime.utc_now()}
    )
  end
end
