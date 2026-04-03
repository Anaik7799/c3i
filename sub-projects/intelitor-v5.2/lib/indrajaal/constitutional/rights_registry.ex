defmodule Indrajaal.Constitutional.RightsRegistry do
  @moduledoc """
  Rights Registry — L0 Constitutional Layer

  ## Design Intent
  GenServer that tracks holon rights and privileges granted by the Indrajaal constitution.
  Rights are granted to actors (agents, operators, subsystems) by a granting authority.
  Each right has an optional expiry time; expired rights are automatically pruned.

  The registry provides:
  - `grant_right/3`  — grant a named right to an actor
  - `revoke_right/2` — revoke a right from an actor
  - `has_right?/2`   — check if an actor currently holds a right
  - `list_rights/1`  — enumerate all rights held by an actor

  All mutations emit telemetry events and PubSub broadcasts so the cockpit
  dashboard can reflect real-time rights state.

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
  - SC-CONST-002: Rights MUST be tracked in authoritative registry
  - SC-VER-074: Constitutional L0-L7 MUST hold
  - SC-AUTH-001: Authorization decisions use rights registry
  - SC-AUTHZ-001: All right grants MUST be logged
  - SC-SAFETY-005: Access control enforced — quarantined actors blocked

  ## Change History
  | Version | Date       | Author | Change                           |
  |---------|------------|--------|----------------------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial implementation (L0)      |
  """

  use GenServer

  require Logger

  @name __MODULE__
  @ets_table :constitutional_rights
  @pubsub_topic "constitutional:rights"
  @zenoh_topic "indrajaal/constitutional/rights"
  @prune_interval_ms 60_000

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type actor :: String.t()
  @type right_name :: atom() | String.t()
  @type grant_opts :: keyword()

  @type right_entry :: %{
          actor: actor(),
          right: right_name(),
          granted_by: actor(),
          granted_at: DateTime.t(),
          expires_at: DateTime.t() | nil,
          metadata: map()
        }

  @type state :: %{
          grant_count: non_neg_integer(),
          revoke_count: non_neg_integer(),
          prune_count: non_neg_integer()
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Grants a right to an actor.

  Options:
  - `:granted_by` (String.t) — authority granting the right (default: "system")
  - `:expires_in_ms` (non_neg_integer) — TTL in milliseconds (default: nil = permanent)
  - `:metadata` (map) — optional key-value metadata

  Returns `{:ok, right_entry()}` on success.
  """
  @spec grant_right(actor(), right_name(), grant_opts()) ::
          {:ok, right_entry()} | {:error, term()}
  def grant_right(actor, right, opts \\ []) do
    GenServer.call(@name, {:grant_right, actor, right, opts}, 10_000)
  end

  @doc """
  Revokes a right from an actor.

  Returns `{:ok, :revoked}` if the right existed and was revoked,
  `{:ok, :not_found}` if the actor did not hold that right.
  """
  @spec revoke_right(actor(), right_name()) ::
          {:ok, :revoked} | {:ok, :not_found} | {:error, term()}
  def revoke_right(actor, right) do
    GenServer.call(@name, {:revoke_right, actor, right}, 10_000)
  end

  @doc """
  Returns `true` if the actor currently holds the given right and it has not expired.
  """
  @spec has_right?(actor(), right_name()) :: boolean()
  def has_right?(actor, right) do
    case :ets.whereis(@ets_table) do
      :undefined ->
        false

      _ ->
        key = ets_key(actor, right)

        case :ets.lookup(@ets_table, key) do
          [{^key, entry}] -> not expired?(entry)
          _ -> false
        end
    end
  end

  @doc """
  Returns all non-expired rights held by the given actor.
  """
  @spec list_rights(actor()) :: list(right_entry())
  def list_rights(actor) do
    case :ets.whereis(@ets_table) do
      :undefined ->
        []

      _ ->
        @ets_table
        |> :ets.tab2list()
        |> Enum.filter(fn {key, entry} ->
          is_tuple(key) and
            elem(key, 0) == actor and
            not expired?(entry)
        end)
        |> Enum.map(fn {_key, entry} -> entry end)
        |> Enum.sort_by(& &1.granted_at, {:asc, DateTime})
    end
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    :ets.new(@ets_table, [:named_table, :public, read_concurrency: true])
    schedule_prune()

    Logger.warning(
      "[RightsRegistry] L0 Rights Registry started — prune_interval=#{@prune_interval_ms}ms"
    )

    initial_state = %{
      grant_count: 0,
      revoke_count: 0,
      prune_count: 0
    }

    {:ok, initial_state}
  end

  @impl true
  def handle_call({:grant_right, actor, right, opts}, _from, state) do
    granted_by = Keyword.get(opts, :granted_by, "system")
    expires_in_ms = Keyword.get(opts, :expires_in_ms, nil)
    metadata = Keyword.get(opts, :metadata, %{})

    expires_at =
      if is_integer(expires_in_ms) do
        DateTime.add(DateTime.utc_now(), expires_in_ms, :millisecond)
      else
        nil
      end

    entry = %{
      actor: actor,
      right: right,
      granted_by: granted_by,
      granted_at: DateTime.utc_now(),
      expires_at: expires_at,
      metadata: metadata
    }

    key = ets_key(actor, right)
    :ets.insert(@ets_table, {key, entry})

    new_state = %{state | grant_count: state.grant_count + 1}

    Logger.info(
      "[RightsRegistry] Right granted actor=#{actor} right=#{inspect(right)} by=#{granted_by}"
    )

    emit_telemetry(:granted, entry, new_state)
    broadcast_pubsub({:right_granted, entry})

    {:reply, {:ok, entry}, new_state}
  end

  @impl true
  def handle_call({:revoke_right, actor, right}, _from, state) do
    key = ets_key(actor, right)

    {result, new_state} =
      case :ets.lookup(@ets_table, key) do
        [] ->
          {{:ok, :not_found}, state}

        [{^key, entry}] ->
          :ets.delete(@ets_table, key)
          next_state = %{state | revoke_count: state.revoke_count + 1}

          Logger.info("[RightsRegistry] Right revoked actor=#{actor} right=#{inspect(right)}")

          emit_telemetry(:revoked, entry, next_state)
          broadcast_pubsub({:right_revoked, actor, right})

          {{:ok, :revoked}, next_state}
      end

    {:reply, result, new_state}
  end

  @impl true
  def handle_info(:prune_expired, state) do
    pruned = prune_expired_entries()
    schedule_prune()

    new_state = %{state | prune_count: state.prune_count + pruned}

    if pruned > 0 do
      Logger.debug("[RightsRegistry] Pruned #{pruned} expired rights")
    end

    {:noreply, new_state}
  end

  # ---------------------------------------------------------------------------
  # Private — helpers
  # ---------------------------------------------------------------------------

  @spec ets_key(actor(), right_name()) :: {actor(), right_name()}
  defp ets_key(actor, right), do: {actor, right}

  @spec expired?(right_entry()) :: boolean()
  defp expired?(%{expires_at: nil}), do: false

  defp expired?(%{expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :gt
  end

  @spec prune_expired_entries() :: non_neg_integer()
  defp prune_expired_entries do
    case :ets.whereis(@ets_table) do
      :undefined ->
        0

      _ ->
        expired_keys =
          @ets_table
          |> :ets.tab2list()
          |> Enum.filter(fn {key, entry} -> is_tuple(key) and expired?(entry) end)
          |> Enum.map(fn {key, _entry} -> key end)

        Enum.each(expired_keys, fn key -> :ets.delete(@ets_table, key) end)
        length(expired_keys)
    end
  end

  defp schedule_prune do
    Process.send_after(self(), :prune_expired, @prune_interval_ms)
  end

  @spec emit_telemetry(atom(), right_entry(), state()) :: :ok
  defp emit_telemetry(event, entry, state) do
    try do
      :telemetry.execute(
        [:indrajaal, :constitutional, :rights, event],
        %{
          grant_count: state.grant_count,
          revoke_count: state.revoke_count
        },
        %{
          topic: @zenoh_topic,
          actor: entry.actor,
          right: inspect(entry.right),
          granted_by: entry.granted_by
        }
      )
    rescue
      err ->
        Logger.warning("[RightsRegistry] telemetry emit failed: #{inspect(err)}")
    end

    :ok
  end

  @spec broadcast_pubsub(term()) :: :ok
  defp broadcast_pubsub(message) do
    try do
      Phoenix.PubSub.broadcast(Indrajaal.PubSub, @pubsub_topic, message)
    rescue
      err ->
        Logger.warning("[RightsRegistry] PubSub broadcast failed: #{inspect(err)}")
    end

    :ok
  end
end
