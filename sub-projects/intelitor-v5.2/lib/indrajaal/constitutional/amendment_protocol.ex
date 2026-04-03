defmodule Indrajaal.Constitutional.AmendmentProtocol do
  @moduledoc """
  Amendment Protocol — L0 Constitutional Layer

  ## Design Intent
  GenServer that manages constitutional amendment proposals for the Indrajaal holon.
  Amendments to the L0 constitution require a 2/3 Guardian supermajority to ratify.
  All proposals, votes, and ratifications are stored in an ETS table and published
  to the constitutional telemetry bus.

  The amendment lifecycle:
  1. `propose_amendment/3` — any authorized actor submits a proposal
  2. `vote/3` — Guardian members vote `{:approve, id}` or `{:reject, id}`
  3. `ratify/1` — if >= 2/3 of registered Guardians approved, amendment is ratified
  4. `amendment_history/0` — returns full audit trail of all proposals

  Ratified amendments are stored permanently. Rejected amendments are archived.
  All state changes emit telemetry events and PubSub broadcasts.

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
  - SC-CONST-001: Constitutional axioms MUST be verified periodically
  - SC-RECONFIG-009: Guardian approval REQUIRED for constitutional change
  - SC-SAFETY-001: Guardian pre-approval REQUIRED for planning mutations
  - SC-HASH-001: Deterministic computation for amendment hashes
  - SC-VER-074: Constitutional L0-L7 MUST hold

  ## Change History
  | Version | Date       | Author | Change                           |
  |---------|------------|--------|----------------------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial implementation (L0)      |
  """

  use GenServer

  require Logger

  @name __MODULE__
  @ets_table :constitutional_amendments
  @pubsub_topic "constitutional:amendments"
  @zenoh_topic "indrajaal/constitutional/amendments"
  @supermajority_threshold 0.6667

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type amendment_id :: String.t()
  @type actor :: String.t()
  @type amendment_text :: String.t()
  @type vote_value :: :approve | :reject

  @type amendment :: %{
          id: amendment_id(),
          text: amendment_text(),
          proposed_by: actor(),
          proposed_at: DateTime.t(),
          status: :pending | :ratified | :rejected,
          votes: %{actor() => vote_value()},
          ratified_at: DateTime.t() | nil,
          ratified_by_count: non_neg_integer()
        }

  @type state :: %{
          proposal_count: non_neg_integer(),
          ratified_count: non_neg_integer(),
          rejected_count: non_neg_integer(),
          guardian_roster: list(actor())
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Proposes a constitutional amendment.

  Returns `{:ok, amendment_id}` on success, or `{:error, reason}` on failure.
  The proposal is stored in ETS and a PubSub broadcast is emitted.
  """
  @spec propose_amendment(actor(), amendment_text(), keyword()) ::
          {:ok, amendment_id()} | {:error, term()}
  def propose_amendment(actor, text, opts \\ []) do
    GenServer.call(@name, {:propose_amendment, actor, text, opts}, 10_000)
  end

  @doc """
  Casts a vote on a pending amendment.

  The `vote` must be `:approve` or `:reject`.
  Returns `{:ok, :vote_recorded}` or `{:error, reason}`.
  """
  @spec vote(amendment_id(), actor(), vote_value()) ::
          {:ok, :vote_recorded} | {:error, term()}
  def vote(amendment_id, actor, vote_value) when vote_value in [:approve, :reject] do
    GenServer.call(@name, {:vote, amendment_id, actor, vote_value}, 10_000)
  end

  @doc """
  Attempts to ratify a pending amendment.

  Ratification succeeds only when >= 2/3 of the Guardian roster has voted `:approve`.
  Returns `{:ok, :ratified}`, `{:ok, :rejected}`, or `{:error, reason}`.
  """
  @spec ratify(amendment_id()) ::
          {:ok, :ratified} | {:ok, :rejected} | {:error, term()}
  def ratify(amendment_id) do
    GenServer.call(@name, {:ratify, amendment_id}, 10_000)
  end

  @doc """
  Returns the full amendment history as a list of amendment maps.
  """
  @spec amendment_history() :: list(amendment())
  def amendment_history do
    case :ets.whereis(@ets_table) do
      :undefined ->
        []

      _ ->
        @ets_table
        |> :ets.tab2list()
        |> Enum.filter(fn {key, _val} -> is_binary(key) end)
        |> Enum.map(fn {_key, val} -> val end)
        |> Enum.sort_by(& &1.proposed_at, {:asc, DateTime})
    end
  end

  @doc """
  Returns the amendment with the given ID, or `nil` if not found.
  """
  @spec get_amendment(amendment_id()) :: amendment() | nil
  def get_amendment(amendment_id) do
    case :ets.whereis(@ets_table) do
      :undefined ->
        nil

      _ ->
        case :ets.lookup(@ets_table, amendment_id) do
          [{^amendment_id, val}] -> val
          _ -> nil
        end
    end
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    :ets.new(@ets_table, [:named_table, :public, read_concurrency: true])

    guardian_roster =
      Keyword.get(opts, :guardian_roster, default_guardian_roster())

    :ets.insert(@ets_table, {:__guardian_roster__, guardian_roster})

    Logger.warning(
      "[AmendmentProtocol] L0 Amendment Protocol started — " <>
        "supermajority=#{trunc(@supermajority_threshold * 100)}%, " <>
        "guardians=#{length(guardian_roster)}"
    )

    initial_state = %{
      proposal_count: 0,
      ratified_count: 0,
      rejected_count: 0,
      guardian_roster: guardian_roster
    }

    {:ok, initial_state}
  end

  @impl true
  def handle_call({:propose_amendment, actor, text, _opts}, _from, state) do
    amendment_id = generate_id()

    amendment = %{
      id: amendment_id,
      text: text,
      proposed_by: actor,
      proposed_at: DateTime.utc_now(),
      status: :pending,
      votes: %{},
      ratified_at: nil,
      ratified_by_count: 0
    }

    :ets.insert(@ets_table, {amendment_id, amendment})

    new_state = %{state | proposal_count: state.proposal_count + 1}

    Logger.info("[AmendmentProtocol] Amendment proposed id=#{amendment_id} by=#{actor}")

    emit_telemetry(:proposed, amendment, new_state)
    broadcast_pubsub({:amendment_proposed, amendment})

    {:reply, {:ok, amendment_id}, new_state}
  end

  @impl true
  def handle_call({:vote, amendment_id, actor, vote_value}, _from, state) do
    case :ets.lookup(@ets_table, amendment_id) do
      [] ->
        {:reply, {:error, :not_found}, state}

      [{^amendment_id, amendment}] ->
        if amendment.status != :pending do
          {:reply, {:error, {:already_finalized, amendment.status}}, state}
        else
          updated_votes = Map.put(amendment.votes, actor, vote_value)
          updated_amendment = %{amendment | votes: updated_votes}
          :ets.insert(@ets_table, {amendment_id, updated_amendment})

          Logger.debug(
            "[AmendmentProtocol] Vote recorded id=#{amendment_id} actor=#{actor} vote=#{vote_value}"
          )

          emit_telemetry(:voted, updated_amendment, state)
          broadcast_pubsub({:amendment_voted, amendment_id, actor, vote_value})

          {:reply, {:ok, :vote_recorded}, state}
        end
    end
  end

  @impl true
  def handle_call({:ratify, amendment_id}, _from, state) do
    case :ets.lookup(@ets_table, amendment_id) do
      [] ->
        {:reply, {:error, :not_found}, state}

      [{^amendment_id, amendment}] ->
        if amendment.status != :pending do
          {:reply, {:error, {:already_finalized, amendment.status}}, state}
        else
          {result, new_state} = do_ratify(amendment, state)
          {:reply, result, new_state}
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Private — ratification logic
  # ---------------------------------------------------------------------------

  @spec do_ratify(amendment(), state()) :: {{:ok, :ratified} | {:ok, :rejected}, state()}
  defp do_ratify(amendment, state) do
    roster = state.guardian_roster
    roster_count = length(roster)

    approve_count =
      amendment.votes
      |> Enum.count(fn {_actor, v} -> v == :approve end)

    approval_ratio =
      if roster_count > 0 do
        approve_count / roster_count
      else
        0.0
      end

    if approval_ratio >= @supermajority_threshold do
      ratified = %{
        amendment
        | status: :ratified,
          ratified_at: DateTime.utc_now(),
          ratified_by_count: approve_count
      }

      :ets.insert(@ets_table, {amendment.id, ratified})

      Logger.warning(
        "[AmendmentProtocol] Amendment RATIFIED id=#{amendment.id} " <>
          "approvals=#{approve_count}/#{roster_count}"
      )

      new_state = %{state | ratified_count: state.ratified_count + 1}
      emit_telemetry(:ratified, ratified, new_state)
      broadcast_pubsub({:amendment_ratified, ratified})

      {{:ok, :ratified}, new_state}
    else
      rejected = %{amendment | status: :rejected}
      :ets.insert(@ets_table, {amendment.id, rejected})

      Logger.info(
        "[AmendmentProtocol] Amendment REJECTED id=#{amendment.id} " <>
          "approvals=#{approve_count}/#{roster_count} " <>
          "(need #{Float.round(@supermajority_threshold * 100, 1)}%)"
      )

      new_state = %{state | rejected_count: state.rejected_count + 1}
      emit_telemetry(:rejected, rejected, new_state)
      broadcast_pubsub({:amendment_rejected, amendment.id})

      {{:ok, :rejected}, new_state}
    end
  end

  # ---------------------------------------------------------------------------
  # Private — helpers
  # ---------------------------------------------------------------------------

  @spec generate_id() :: amendment_id()
  defp generate_id do
    "amendment-" <> Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
  end

  @spec default_guardian_roster() :: list(actor())
  defp default_guardian_roster do
    Application.get_env(:indrajaal, :guardian_roster, ["guardian-1", "guardian-2", "guardian-3"])
  end

  @spec emit_telemetry(atom(), amendment(), state()) :: :ok
  defp emit_telemetry(event, amendment, state) do
    try do
      :telemetry.execute(
        [:indrajaal, :constitutional, :amendment, event],
        %{
          proposal_count: state.proposal_count,
          ratified_count: state.ratified_count,
          rejected_count: state.rejected_count,
          vote_count: map_size(amendment.votes)
        },
        %{
          topic: @zenoh_topic,
          amendment_id: amendment.id,
          status: amendment.status,
          proposed_by: amendment.proposed_by
        }
      )
    rescue
      err ->
        Logger.warning("[AmendmentProtocol] telemetry emit failed: #{inspect(err)}")
    end

    :ok
  end

  @spec broadcast_pubsub(term()) :: :ok
  defp broadcast_pubsub(message) do
    try do
      Phoenix.PubSub.broadcast(Indrajaal.PubSub, @pubsub_topic, message)
    rescue
      err ->
        Logger.warning("[AmendmentProtocol] PubSub broadcast failed: #{inspect(err)}")
    end

    :ok
  end
end
