defmodule Indrajaal.Federation.ConsensusCoordinator do
  @moduledoc """
  ## Design Intent

  L6 Federation Layer — cross-holon consensus coordinator for federated
  decisions requiring 2-out-of-3 (2oo3) voting.

  The ConsensusCoordinator implements the 2oo3 voting protocol for
  safety-critical federated decisions. Proposals flow through a defined
  lifecycle: `:proposed` → `:voting` → `:accepted` or `:rejected`. Each
  voting round has a hard 30-second timeout after which the proposal is
  finalized based on votes received.

  Core responsibilities:
  - Manages proposal lifecycle with atomic state transitions
  - Enforces 2oo3 (2-of-3) voting threshold (SC-CONSENSUS-001)
  - Times out voting rounds after 30 s (SC-CONSENSUS-003)
  - Publishes consensus results via PubSub `"federation:consensus"`
  - Tracks active and completed proposal history

  ## 2oo3 Voting Protocol

  A proposal is `:accepted` when at least 2 out of the 3 most recently
  active voters approve it within the voting window. If fewer than 2
  affirmative votes are received by the deadline the proposal is
  `:rejected`.

  ```
  Proposal lifecycle:
    :proposed → :voting (first vote received or timer starts)
              → :accepted (≥2 approvals before timeout)
              → :rejected  (timeout or ≥2 rejections)
  ```

  ## STAMP Constraints

  - SC-CONSENSUS-001: 2oo3 voting MANDATORY for P0 (safety-critical)
    decisions in the federation layer.
  - SC-CONSENSUS-002: Each chamber has Constitutional veto — proposals
    that are vetoed by the ConstitutionalGovernor MUST NOT be submitted
    here; callers are responsible for upstream veto checks.
  - SC-CONSENSUS-003: Voting timeout MUST be < 30 s per chamber.
  - SC-SIL4-006: 2oo3 voting MANDATORY for production actuations.
  - SC-QUORUM-001: Two-out-of-three voting MANDATORY for safety-critical
    decisions.

  ## Change History

  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Code Evolution Agent | Initial implementation — L6 consensus coordinator |
  """

  use GenServer
  require Logger

  @pubsub_topic "federation:consensus"

  # 2oo3 threshold: need at least this many approvals
  @min_approvals 2

  # Total voters assumed in 2oo3 model
  @total_voters 3

  # Voting round timeout (SC-CONSENSUS-003: < 30 s)
  @voting_timeout_ms 28_000

  # Keep completed proposals in memory (ring buffer)
  @history_max 100

  # ─── Types ───────────────────────────────────────────────────────────────────

  @type proposal_status :: :proposed | :voting | :accepted | :rejected

  @type vote_decision :: :approve | :reject | :abstain

  @type vote :: %{
          voter_id: String.t(),
          decision: vote_decision(),
          timestamp: DateTime.t()
        }

  @type proposal :: %{
          id: String.t(),
          type: atom(),
          subject: term(),
          proposer: String.t(),
          status: proposal_status(),
          votes: %{String.t() => vote()},
          proposed_at: DateTime.t(),
          voting_started_at: DateTime.t() | nil,
          finalized_at: DateTime.t() | nil,
          result: :accepted | :rejected | nil
        }

  @type consensus_result :: %{
          proposal_id: String.t(),
          result: :accepted | :rejected,
          approvals: non_neg_integer(),
          rejections: non_neg_integer(),
          abstentions: non_neg_integer(),
          quorum_met: boolean(),
          finalized_at: DateTime.t()
        }

  @type t :: %{
          proposals: %{String.t() => proposal()},
          completed: [consensus_result()],
          total_proposed: non_neg_integer(),
          total_accepted: non_neg_integer(),
          total_rejected: non_neg_integer(),
          total_timed_out: non_neg_integer(),
          started_at: DateTime.t()
        }

  # ─── Public API ──────────────────────────────────────────────────────────────

  @doc "Start the ConsensusCoordinator GenServer."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Submit a new proposal for 2oo3 consensus voting.

  Returns `{:ok, proposal_id}` immediately. The result is published
  asynchronously to PubSub `"federation:consensus"` when voting
  concludes.
  """
  @spec propose(atom(), term(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def propose(type, subject, proposer) when is_atom(type) and is_binary(proposer) do
    GenServer.call(__MODULE__, {:propose, type, subject, proposer})
  end

  @doc """
  Submit a vote on an active proposal.

  Returns `:ok` if the vote was recorded, or `{:error, reason}` if the
  proposal is not in `:voting` status or not found.
  """
  @spec vote(String.t(), String.t(), vote_decision()) :: :ok | {:error, term()}
  def vote(proposal_id, voter_id, decision)
      when is_binary(proposal_id) and is_binary(voter_id) and
             decision in [:approve, :reject, :abstain] do
    GenServer.call(__MODULE__, {:vote, proposal_id, voter_id, decision})
  end

  @doc "Get a proposal by ID."
  @spec get_proposal(String.t()) :: {:ok, proposal()} | {:error, :not_found}
  def get_proposal(proposal_id) when is_binary(proposal_id) do
    GenServer.call(__MODULE__, {:get_proposal, proposal_id})
  end

  @doc "List all proposals with a given status (or all active if `nil`)."
  @spec list_proposals(proposal_status() | nil) :: [proposal()]
  def list_proposals(status \\ nil) do
    GenServer.call(__MODULE__, {:list_proposals, status})
  end

  @doc "List the most recent completed consensus results."
  @spec completed_results(non_neg_integer()) :: [consensus_result()]
  def completed_results(limit \\ 20) do
    GenServer.call(__MODULE__, {:completed_results, limit})
  end

  @doc "Get coordinator statistics."
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # ─── GenServer Callbacks ──────────────────────────────────────────────────────

  @impl true
  def init(_opts) do
    Phoenix.PubSub.subscribe(Indrajaal.PubSub, @pubsub_topic)

    state = %{
      proposals: %{},
      completed: [],
      total_proposed: 0,
      total_accepted: 0,
      total_rejected: 0,
      total_timed_out: 0,
      started_at: DateTime.utc_now()
    }

    Logger.info(
      "[ConsensusCoordinator] Online — 2oo3 voting (min_approvals=#{@min_approvals}/#{@total_voters}) " <>
        "timeout=#{@voting_timeout_ms}ms — SC-CONSENSUS-001, SC-QUORUM-001"
    )

    {:ok, state}
  end

  @impl true
  def handle_call({:propose, type, subject, proposer}, _from, state) do
    proposal_id = generate_proposal_id()
    now = DateTime.utc_now()

    proposal = %{
      id: proposal_id,
      type: type,
      subject: subject,
      proposer: proposer,
      status: :proposed,
      votes: %{},
      proposed_at: now,
      voting_started_at: nil,
      finalized_at: nil,
      result: nil
    }

    # Immediately transition to :voting and start the timeout timer
    voting_proposal = %{proposal | status: :voting, voting_started_at: DateTime.utc_now()}

    Process.send_after(self(), {:voting_timeout, proposal_id}, @voting_timeout_ms)

    new_proposals = Map.put(state.proposals, proposal_id, voting_proposal)
    new_state = %{state | proposals: new_proposals, total_proposed: state.total_proposed + 1}

    publish_proposal_event(:voting_started, voting_proposal)

    Logger.info(
      "[ConsensusCoordinator] NEW proposal=#{proposal_id} type=#{type} " <>
        "proposer=#{proposer} — voting window #{@voting_timeout_ms}ms"
    )

    {:reply, {:ok, proposal_id}, new_state}
  end

  @impl true
  def handle_call({:vote, proposal_id, voter_id, decision}, _from, state) do
    case Map.get(state.proposals, proposal_id) do
      nil ->
        {:reply, {:error, :proposal_not_found}, state}

      %{status: :voting} = proposal ->
        vote = %{
          voter_id: voter_id,
          decision: decision,
          timestamp: DateTime.utc_now()
        }

        updated_votes = Map.put(proposal.votes, voter_id, vote)
        updated_proposal = %{proposal | votes: updated_votes}

        # Check if 2oo3 threshold already met — early finalization
        {finalized_state, reply} =
          maybe_finalize_early(updated_proposal, state, proposal_id)

        {:reply, reply, finalized_state}

      %{status: status} ->
        {:reply, {:error, {:voting_closed, status}}, state}
    end
  end

  @impl true
  def handle_call({:get_proposal, proposal_id}, _from, state) do
    case Map.get(state.proposals, proposal_id) do
      nil -> {:reply, {:error, :not_found}, state}
      proposal -> {:reply, {:ok, proposal}, state}
    end
  end

  @impl true
  def handle_call({:list_proposals, nil}, _from, state) do
    proposals = state.proposals |> Map.values()
    {:reply, proposals, state}
  end

  @impl true
  def handle_call({:list_proposals, status}, _from, state) do
    proposals =
      state.proposals
      |> Map.values()
      |> Enum.filter(&(&1.status == status))

    {:reply, proposals, state}
  end

  @impl true
  def handle_call({:completed_results, limit}, _from, state) do
    results = Enum.take(state.completed, limit)
    {:reply, results, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    active_count = state.proposals |> Map.values() |> Enum.count(&(&1.status == :voting))

    stats = %{
      active_proposals: active_count,
      total_proposed: state.total_proposed,
      total_accepted: state.total_accepted,
      total_rejected: state.total_rejected,
      total_timed_out: state.total_timed_out,
      acceptance_rate: acceptance_rate(state),
      completed_history_length: length(state.completed),
      min_approvals: @min_approvals,
      total_voters: @total_voters,
      voting_timeout_ms: @voting_timeout_ms,
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at)
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_info({:voting_timeout, proposal_id}, state) do
    case Map.get(state.proposals, proposal_id) do
      %{status: :voting} = proposal ->
        new_state = finalize_proposal(proposal, state, :timeout)

        Logger.info(
          "[ConsensusCoordinator] TIMEOUT proposal=#{proposal_id} — " <>
            "SC-CONSENSUS-003 (voting window expired)"
        )

        {:noreply, new_state}

      _ ->
        # Already finalized by early exit — ignore
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:consensus_event, _event}, state) do
    # Received our own broadcast or a peer broadcast — no action needed
    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("[ConsensusCoordinator] Unhandled message: #{inspect(msg)}")
    {:noreply, state}
  end

  # ─── Private Helpers ─────────────────────────────────────────────────────────

  # Check for 2oo3 early finalization after each vote
  defp maybe_finalize_early(proposal, state, proposal_id) do
    {approvals, rejections, _abstentions} = count_votes(proposal.votes)

    updated_proposals = Map.put(state.proposals, proposal_id, proposal)
    interim_state = %{state | proposals: updated_proposals}

    cond do
      # 2oo3 threshold met — accept immediately
      approvals >= @min_approvals ->
        new_state = finalize_proposal(proposal, interim_state, :accepted)

        Logger.info(
          "[ConsensusCoordinator] ACCEPTED proposal=#{proposal_id} " <>
            "(#{approvals}/#{@total_voters} approvals ≥ #{@min_approvals}) — SC-QUORUM-001"
        )

        {new_state, :ok}

      # Enough rejections to be impossible — reject immediately
      rejections > @total_voters - @min_approvals ->
        new_state = finalize_proposal(proposal, interim_state, :rejected)

        Logger.info(
          "[ConsensusCoordinator] REJECTED proposal=#{proposal_id} " <>
            "(#{rejections} rejection(s) exceed threshold)"
        )

        {new_state, :ok}

      # Keep voting
      true ->
        {interim_state, :ok}
    end
  end

  defp finalize_proposal(proposal, state, trigger) do
    {approvals, rejections, abstentions} = count_votes(proposal.votes)

    result =
      case trigger do
        :accepted -> :accepted
        :rejected -> :rejected
        :timeout -> if approvals >= @min_approvals, do: :accepted, else: :rejected
      end

    quorum_met = approvals >= @min_approvals

    finalized_proposal = %{
      proposal
      | status: result,
        finalized_at: DateTime.utc_now(),
        result: result
    }

    consensus_result = %{
      proposal_id: proposal.id,
      result: result,
      approvals: approvals,
      rejections: rejections,
      abstentions: abstentions,
      quorum_met: quorum_met,
      finalized_at: DateTime.utc_now()
    }

    new_proposals = Map.put(state.proposals, proposal.id, finalized_proposal)

    new_completed =
      [consensus_result | state.completed]
      |> Enum.take(@history_max)

    timed_out_delta = if trigger == :timeout, do: 1, else: 0

    new_state = %{
      state
      | proposals: new_proposals,
        completed: new_completed,
        total_accepted: state.total_accepted + if(result == :accepted, do: 1, else: 0),
        total_rejected: state.total_rejected + if(result == :rejected, do: 1, else: 0),
        total_timed_out: state.total_timed_out + timed_out_delta
    }

    publish_consensus_result(consensus_result)

    new_state
  end

  defp count_votes(votes) do
    Enum.reduce(votes, {0, 0, 0}, fn {_id, vote}, {ap, rj, ab} ->
      case vote.decision do
        :approve -> {ap + 1, rj, ab}
        :reject -> {ap, rj + 1, ab}
        :abstain -> {ap, rj, ab + 1}
      end
    end)
  end

  defp publish_proposal_event(event, proposal) do
    message = %{
      event: event,
      proposal_id: proposal.id,
      type: proposal.type,
      status: proposal.status,
      timestamp: DateTime.utc_now()
    }

    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      @pubsub_topic,
      {:consensus_event, message}
    )
  end

  defp publish_consensus_result(result) do
    message = %{
      event: :consensus_finalized,
      proposal_id: result.proposal_id,
      result: result.result,
      approvals: result.approvals,
      rejections: result.rejections,
      abstentions: result.abstentions,
      quorum_met: result.quorum_met,
      timestamp: result.finalized_at
    }

    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      @pubsub_topic,
      {:consensus_result, message}
    )

    Logger.info(
      "[ConsensusCoordinator] CONSENSUS proposal=#{result.proposal_id} " <>
        "result=#{result.result} approvals=#{result.approvals}/#{@total_voters} " <>
        "quorum=#{result.quorum_met} — SC-CONSENSUS-001"
    )
  end

  defp acceptance_rate(%{total_proposed: 0}), do: 0.0

  defp acceptance_rate(%{total_proposed: total, total_accepted: accepted}) do
    Float.round(accepted / total * 100.0, 2)
  end

  defp generate_proposal_id do
    bytes = :crypto.strong_rand_bytes(8)
    "cns_#{Base.encode16(bytes, case: :lower)}"
  end
end
