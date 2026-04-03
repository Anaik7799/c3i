defmodule Indrajaal.Coordination.ConsensusProtocol do
  @moduledoc """
  Consensus Protocol — L5 Coordination Layer

  Implements 2-out-of-3 (2oo3) voting consensus across multiple channels:
  Guardian, Sentinel, and Cortex. Designed for safety-critical decisions
  that require distributed agreement before execution.

  ## STAMP Constraints
  - SC-CONSENSUS-001: 2oo3 voting MANDATORY for P0 decisions
  - SC-CONSENSUS-002: Each chamber has Constitutional veto
  - SC-CONSENSUS-003: Timeout < 30s per chamber
  - SC-QUORUM-001: Two-out-of-three voting MANDATORY for safety-critical decisions
  - SC-SIL4-006: 2oo3 voting MANDATORY for production actuations
  - SC-ORCH-014: Event log append-only

  ## Voting Channels
  1. **Guardian** — Constitutional safety guardian
  2. **Sentinel** — Immune system anomaly detector
  3. **Cortex** — AI advisory subsystem

  ## Decision Protocol
  1. Initiator broadcasts proposal to all channels
  2. Each channel votes within timeout window
  3. 2/3 agreement required to pass
  4. Any channel may veto with CONSTITUTIONAL flag (overrides quorum)
  5. All votes recorded in ETS for audit

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Claude Sonnet 4.6 | Initial implementation (L5 morphogenesis) |
  """

  use GenServer

  require Logger

  @name __MODULE__
  @timeout_ms 30_000
  @channels [:guardian, :sentinel, :cortex]
  @pubsub_topic "consensus:votes"
  @table :consensus_log

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type proposal_id :: String.t()
  @type channel :: :guardian | :sentinel | :cortex
  @type vote :: :approve | :reject | :veto
  @type decision :: :passed | :rejected | :vetoed | :timeout

  @type proposal :: %{
          id: proposal_id(),
          action: atom(),
          payload: map(),
          initiator: String.t(),
          timestamp: non_neg_integer()
        }

  @type vote_record :: %{
          proposal_id: proposal_id(),
          channel: channel(),
          vote: vote(),
          reason: String.t(),
          timestamp: non_neg_integer()
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Initiate a consensus vote on a proposed action.
  Returns the decision after all channels have voted or timeout.
  """
  @spec propose(atom(), map(), String.t()) :: {:ok, decision()} | {:error, term()}
  def propose(action, payload \\ %{}, initiator \\ "system") do
    GenServer.call(
      @name,
      {:propose, action, payload, initiator},
      @timeout_ms + 1_000
    )
  end

  @doc "Cast a vote for a pending proposal."
  @spec cast_vote(proposal_id(), channel(), vote(), String.t()) :: :ok | {:error, :not_found}
  def cast_vote(proposal_id, channel, vote, reason \\ "") do
    GenServer.cast(@name, {:cast_vote, proposal_id, channel, vote, reason})
  end

  @doc "Get the vote log for a proposal."
  @spec get_votes(proposal_id()) :: [vote_record()]
  def get_votes(proposal_id) do
    GenServer.call(@name, {:get_votes, proposal_id})
  end

  @doc "Get all recent decisions (up to last 100)."
  @spec decision_log() :: [map()]
  def decision_log do
    GenServer.call(@name, :decision_log)
  end

  # ---------------------------------------------------------------------------
  # GenServer Callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :public, :bag, read_concurrency: true])

    state = %{
      pending: %{},
      decision_log: []
    }

    Phoenix.PubSub.subscribe(Indrajaal.PubSub, @pubsub_topic)

    Logger.info("[ConsensusProtocol] Started — channels=#{inspect(@channels)} [SC-CONSENSUS-001]")

    {:ok, state}
  end

  @impl true
  def handle_call({:propose, action, payload, initiator}, from, state) do
    proposal_id = generate_id()

    proposal = %{
      id: proposal_id,
      action: action,
      payload: payload,
      initiator: initiator,
      timestamp: System.system_time(:millisecond)
    }

    Logger.info(
      "[ConsensusProtocol] Proposal #{proposal_id}: #{action} by #{initiator} [SC-CONSENSUS-001]"
    )

    broadcast_proposal(proposal)

    timer = Process.send_after(self(), {:vote_timeout, proposal_id}, @timeout_ms)

    pending_entry = %{
      proposal: proposal,
      votes: %{},
      from: from,
      timer: timer
    }

    state2 = put_in(state, [:pending, proposal_id], pending_entry)

    {:noreply, state2}
  end

  @impl true
  def handle_call({:get_votes, proposal_id}, _from, state) do
    votes =
      :ets.lookup(@table, proposal_id)
      |> Enum.map(fn {_id, record} -> record end)

    {:reply, votes, state}
  end

  @impl true
  def handle_call(:decision_log, _from, state) do
    {:reply, state.decision_log, state}
  end

  @impl true
  def handle_cast({:cast_vote, proposal_id, channel, vote, reason}, state) do
    case Map.get(state.pending, proposal_id) do
      nil ->
        Logger.debug("[ConsensusProtocol] Vote for unknown proposal #{proposal_id} — ignored")
        {:noreply, state}

      pending_entry ->
        record = %{
          proposal_id: proposal_id,
          channel: channel,
          vote: vote,
          reason: reason,
          timestamp: System.system_time(:millisecond)
        }

        :ets.insert(@table, {proposal_id, record})

        votes2 = Map.put(pending_entry.votes, channel, vote)
        pending_entry2 = %{pending_entry | votes: votes2}
        state2 = put_in(state, [:pending, proposal_id], pending_entry2)

        state3 =
          if all_channels_voted?(votes2) do
            finalize_decision(state2, proposal_id, pending_entry2)
          else
            state2
          end

        {:noreply, state3}
    end
  end

  @impl true
  def handle_info({:vote_timeout, proposal_id}, state) do
    case Map.get(state.pending, proposal_id) do
      nil ->
        {:noreply, state}

      pending_entry ->
        Logger.warning(
          "[ConsensusProtocol] Timeout for proposal #{proposal_id} [SC-CONSENSUS-003]"
        )

        state2 = finalize_with_decision(state, proposal_id, pending_entry, :timeout)
        {:noreply, state2}
    end
  end

  @impl true
  def handle_info({:consensus_vote, proposal_id, channel, vote, reason}, state) do
    cast_vote(proposal_id, channel, vote, reason)
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # ---------------------------------------------------------------------------
  # Decision Logic
  # ---------------------------------------------------------------------------

  defp finalize_decision(state, proposal_id, pending_entry) do
    decision = compute_decision(pending_entry.votes)
    finalize_with_decision(state, proposal_id, pending_entry, decision)
  end

  defp finalize_with_decision(state, proposal_id, pending_entry, decision) do
    Process.cancel_timer(pending_entry.timer)

    log_entry = %{
      proposal_id: proposal_id,
      proposal: pending_entry.proposal,
      votes: pending_entry.votes,
      decision: decision,
      timestamp: System.system_time(:millisecond)
    }

    Logger.info(
      "[ConsensusProtocol] Decision: #{decision} for #{proposal_id} " <>
        "(votes: #{inspect(pending_entry.votes)}) [SC-CONSENSUS-001]"
    )

    :telemetry.execute(
      [:indrajaal, :coordination, :consensus, :decision],
      %{vote_count: map_size(pending_entry.votes)},
      %{proposal_id: proposal_id, decision: decision, action: pending_entry.proposal.action}
    )

    GenServer.reply(pending_entry.from, {:ok, decision})

    state2 = %{state | pending: Map.delete(state.pending, proposal_id)}
    log_trimmed = Enum.take([log_entry | state2.decision_log], 100)
    %{state2 | decision_log: log_trimmed}
  rescue
    _ -> %{state | pending: Map.delete(state.pending, proposal_id)}
  end

  defp compute_decision(votes) do
    # Veto by any channel is constitutional override
    if Enum.any?(votes, fn {_, v} -> v == :veto end) do
      :vetoed
    else
      approvals = Enum.count(votes, fn {_, v} -> v == :approve end)
      total = map_size(votes)

      # 2oo3: need 2 approvals out of (up to) 3 channels
      if total >= 2 and approvals * 2 >= total do
        :passed
      else
        :rejected
      end
    end
  end

  defp all_channels_voted?(votes) do
    Enum.all?(@channels, &Map.has_key?(votes, &1))
  end

  defp broadcast_proposal(proposal) do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      @pubsub_topic,
      {:consensus_proposal, proposal}
    )
  rescue
    _ -> :ok
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
