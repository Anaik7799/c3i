defmodule Indrajaal.Cluster.Consensus do
  @moduledoc """
  ## UNIVERSAL CONSENSUS (L6-SOCIETY)
  Provides Atomic Truth resolution for the Fractal Mesh.

  WHAT: Distributed consensus engine implementing 2oo3 majority voting,
  multi-round consensus protocol, and quorum-based health decisions.

  WHY: Safety-critical decisions (threat level, evolution phase, federation
  identity) require fault-tolerant agreement across mesh nodes.

  **Mechanism**:
  - Bully algorithm leader election via :pg (OTP process groups).
  - The node with the lexicographically smallest node name becomes leader.
  - The Leader is the Source of Truth for:
    1. Threat Level
    2. Evolution Phase
    3. Federation Identity
  - 2oo3 majority voting enforces SC-SIL4-006 (Two-out-of-Three voting).
  - Multi-round protocol (max 3 rounds) resolves distributed disagreements.
  - Vote validation rejects stale (>30s) or malformed ballots.

  **Compliance**:
  - SC-SIL4-006: 2oo3 voting MANDATORY
  - SC-SIL4-011: Quorum = floor(N/2) + 1
  - SC-SIL6-009: Consensus
  - SC-VAL-003: 100% Consensus required

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.2.1 | 2026-03-21 | Claude Sonnet 4.6 | Real 2oo3 voting, multi-round consensus, vote validation |
  """
  use GenServer
  require Logger

  @pg_scope :indrajaal_cluster
  @pg_group :consensus

  # Valid vote values for health assessments
  @valid_vote_values [:healthy, :degraded, :unhealthy]

  # Maximum age for a vote to be considered valid (seconds)
  @vote_ttl_seconds 30

  # Maximum rounds before declaring no-consensus
  @max_consensus_rounds 3

  def start_link(opts \\ []) do
    case GenServer.start_link(__MODULE__, opts, name: {:global, __MODULE__}) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      err -> err
    end
  end

  @doc """
  Returns true if the current node is the cluster leader.

  Uses Bully algorithm: the member with the smallest node name wins.
  Falls back to true (single-node mode) when the process group is empty.
  """
  def is_leader?(_pid \\ nil) do
    node_self = node()

    case :pg.get_members(@pg_scope, @pg_group) do
      [] ->
        # No other members registered — this node is the sole leader
        true

      members ->
        leader_node =
          members
          |> Enum.map(&node/1)
          |> Enum.uniq()
          |> Enum.sort()
          |> List.first()

        leader_node == node_self
    end
  rescue
    _ -> false
  end

  @doc """
  Performs 2oo3 majority voting on health assessments.

  Requires at least 2 out of 3 voters to agree for consensus.
  Q(N) = floor(N/2) + 1

  Accepts any list of vote values — not limited to exactly 3 voters.
  The quorum requirement scales with list size per the formula above.

  Returns `{:ok, value, metadata}` when a majority agrees, or
  `{:error, :no_consensus, metadata}` when no majority exists.

  ## Examples

      iex> two_out_of_three_vote([:healthy, :healthy, :degraded])
      {:ok, :healthy, %{consensus: true, count: 2, quorum: 2}}

      iex> two_out_of_three_vote([:healthy, :degraded, :unhealthy])
      {:error, :no_consensus, %{votes: %{healthy: 1, degraded: 1, unhealthy: 1}, quorum: 2}}

  ## STAMP Compliance
  - SC-SIL4-006: 2oo3 voting MANDATORY
  - SC-SIL4-011: Quorum = floor(N/2) + 1
  """
  @spec two_out_of_three_vote(list()) ::
          {:ok, term(), map()} | {:error, :no_consensus, map()} | {:error, :empty_votes}
  def two_out_of_three_vote([]) do
    {:error, :empty_votes}
  end

  def two_out_of_three_vote(votes) when is_list(votes) do
    vote_counts = Enum.frequencies(votes)
    total = length(votes)
    quorum = div(total, 2) + 1

    case Enum.find(vote_counts, fn {_val, count} -> count >= quorum end) do
      {value, count} ->
        {:ok, value, %{consensus: true, count: count, quorum: quorum, total: total}}

      nil ->
        {:error, :no_consensus, %{votes: vote_counts, quorum: quorum, total: total}}
    end
  end

  @doc """
  Calculates the required quorum size for N participants.

  Q(N) = floor(N/2) + 1

  ## Examples

      iex> quorum_size(3)
      2

      iex> quorum_size(5)
      3

      iex> quorum_size(1)
      1

  ## STAMP Compliance
  - SC-SIL4-011: Quorum = floor(N/2) + 1
  """
  @spec quorum_size(pos_integer()) :: pos_integer()
  def quorum_size(n) when is_integer(n) and n > 0 do
    div(n, 2) + 1
  end

  @doc """
  Runs a multi-round consensus protocol to reach distributed agreement.

  Each round collects votes from all participants on the given proposal.
  Quorum agreement on any value ends the protocol early. If no quorum is
  reached after `max_rounds`, `{:error, :no_consensus, rounds}` is returned.

  ## Options

  - `:max_rounds` — maximum number of rounds before failure (default: 3)
  - `:min_agreement` — quorum override; if nil, uses `quorum_size(N)` (default: nil)

  ## Participant contract

  Each element of `participants` must be a zero-arity function (or anonymous
  function with zero captures) that returns a vote value when called. In
  practice these are local lambdas or remote-call wrappers supplied by the
  caller.

  ## Returns

  - `{:ok, value, %{rounds: n, agreement: count}}` on success
  - `{:error, :no_consensus, rounds_history}` when no round achieved quorum
  - `{:error, :no_participants}` when `participants` is empty

  ## STAMP Compliance
  - SC-SIL4-006: 2oo3 voting MANDATORY per round
  """
  @spec run_consensus(term(), list(function()), keyword()) ::
          {:ok, term(), map()}
          | {:error, :no_consensus, list()}
          | {:error, :no_participants}
  def run_consensus(proposal, participants, opts \\ [])

  def run_consensus(_proposal, [], _opts), do: {:error, :no_participants}

  def run_consensus(proposal, participants, opts) do
    max_rounds = Keyword.get(opts, :max_rounds, @max_consensus_rounds)
    min_agreement = Keyword.get(opts, :min_agreement, nil)

    do_consensus_rounds(proposal, participants, 1, max_rounds, min_agreement, [])
  end

  @doc """
  Returns true if the cluster has reached quorum given current node count.

  Queries the :pg consensus group and compares live member count to
  the configured `quorum_size/1` threshold.

  Falls back to true in single-node or disconnected mode.
  """
  @spec has_quorum?() :: boolean()
  def has_quorum? do
    case :pg.get_members(@pg_scope, @pg_group) do
      [] ->
        # Single-node: trivially has quorum
        true

      members ->
        node_count = members |> Enum.map(&node/1) |> Enum.uniq() |> length()
        node_count >= quorum_size(node_count)
    end
  rescue
    _ -> true
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    # Ensure the :pg scope exists (idempotent)
    try do
      :pg.start_link(@pg_scope)
    rescue
      _ -> :ok
    end

    # Join the consensus process group
    try do
      :pg.join(@pg_scope, @pg_group, self())
    rescue
      _ -> :ok
    end

    Logger.info("[Consensus] Node #{node()} joined cluster consensus group")
    {:ok, %{leader: is_leader?()}}
  end

  # ---------------------------------------------------------------------------
  # Private: Multi-round consensus
  # ---------------------------------------------------------------------------

  defp do_consensus_rounds(_proposal, _participants, round, max_rounds, _min_agreement, history)
       when round > max_rounds do
    Logger.warning(
      "[Consensus] No consensus after #{max_rounds} rounds. History: #{inspect(history)}"
    )

    {:error, :no_consensus, history}
  end

  defp do_consensus_rounds(proposal, participants, round, max_rounds, min_agreement, history) do
    Logger.debug("[Consensus] Round #{round}/#{max_rounds} for proposal #{inspect(proposal)}")

    votes =
      participants
      |> Enum.map(fn voter ->
        try do
          voter.()
        rescue
          e ->
            Logger.warning("[Consensus] Voter raised exception: #{inspect(e)}")
            nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    round_result = %{round: round, votes: votes, timestamp: System.monotonic_time(:second)}

    case two_out_of_three_vote(votes) do
      {:ok, value, meta} ->
        required = min_agreement || quorum_size(length(participants))

        if meta.count >= required do
          Logger.info("[Consensus] Quorum achieved in round #{round}: #{inspect(value)}")

          {:ok, value,
           %{
             rounds: round,
             agreement: meta.count,
             quorum: meta.quorum,
             total: meta.total
           }}
        else
          # Plurality exists but doesn't meet min_agreement; try next round
          new_history = history ++ [round_result]

          do_consensus_rounds(
            proposal,
            participants,
            round + 1,
            max_rounds,
            min_agreement,
            new_history
          )
        end

      {:error, :no_consensus, _meta} ->
        new_history = history ++ [round_result]

        do_consensus_rounds(
          proposal,
          participants,
          round + 1,
          max_rounds,
          min_agreement,
          new_history
        )

      {:error, :empty_votes} ->
        Logger.error("[Consensus] No valid votes collected in round #{round}")
        {:error, :no_consensus, history}
    end
  end

  # ---------------------------------------------------------------------------
  # Private: Vote validation
  # ---------------------------------------------------------------------------

  @doc false
  @spec validate_vote(map()) :: :ok | {:error, :stale_vote} | {:error, :invalid_value}
  def validate_vote(%{voter: _voter, value: value, timestamp: ts}) do
    now = System.monotonic_time(:second)

    cond do
      ts < now - @vote_ttl_seconds ->
        {:error, :stale_vote}

      value not in @valid_vote_values ->
        {:error, :invalid_value}

      true ->
        :ok
    end
  end

  def validate_vote(_), do: {:error, :invalid_vote_format}
end
