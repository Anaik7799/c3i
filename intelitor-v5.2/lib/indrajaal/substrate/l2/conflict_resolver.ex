defmodule Indrajaal.Substrate.L2.ConflictResolver do
  @moduledoc """
  L2 Conflict Resolver — priority-based arbitration for competing resource claims.

  Pure module (no process, no side effects) that implements a deterministic
  priority arbitration algorithm for resolving conflicts between competing
  resource claims.  Higher priority wins; ties are broken by claim timestamp
  (earlier wins).

  ## Algorithm (Priority Arbitration)
  1. Each claim carries a priority (integer, higher = more important) and a
     timestamp.
  2. `resolve/2` compares two claims and returns the winning claim together
     with the loser.
  3. `register_claim/3` appends a claim to a claim-list for a named resource
     and returns the updated list.
  4. `pending_conflicts/1` scans a claim-list and returns pairs that conflict
     (i.e., different claimants for the same resource).
  5. `history/1` returns the list of previously resolved claims (passed in as
     the history accumulator).

  ## STAMP Constraints
  - SC-S2-001: S2 coordination subsystem constraints — ENFORCED
  - SC-S2-002: Conflict detection mandatory — ENFORCED
  - SC-S2-003: Priority-based arbitration — ENFORCED
  - SC-S2-004: Deterministic resolution — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type resource_id :: atom() | binary()
  @type claimant_id :: atom() | binary()
  @type priority :: integer()

  @type claim :: %{
          resource: resource_id(),
          claimant: claimant_id(),
          priority: priority(),
          claimed_at: DateTime.t()
        }

  @type resolution :: %{
          winner: claim(),
          loser: claim(),
          reason: :higher_priority | :earlier_claim,
          resolved_at: DateTime.t()
        }

  @type claim_list :: [claim()]
  @type history :: [resolution()]

  # ── Public API ───────────────────────────────────────────────────────

  @doc """
  Resolve a conflict between two claims.  Returns `{:ok, resolution}` where
  resolution identifies the winner and loser, or `{:error, :same_claimant}`
  when both claims come from the same claimant.
  """
  @spec resolve(claim(), claim()) :: {:ok, resolution()} | {:error, :same_claimant}
  def resolve(%{claimant: c} = _a, %{claimant: c} = _b) do
    {:error, :same_claimant}
  end

  def resolve(claim_a, claim_b) do
    {winner, loser, reason} = arbitrate(claim_a, claim_b)

    resolution = %{
      winner: winner,
      loser: loser,
      reason: reason,
      resolved_at: DateTime.utc_now()
    }

    {:ok, resolution}
  end

  @doc """
  Register a new claim for `resource` by `claimant` with `priority` in the
  given claim list.  Returns the updated claim list.
  """
  @spec register_claim(claim_list(), resource_id(), claimant_id(), priority()) :: claim_list()
  def register_claim(claims, resource, claimant, priority)
      when is_list(claims) do
    claim = %{
      resource: resource,
      claimant: claimant,
      priority: priority,
      claimed_at: DateTime.utc_now()
    }

    [claim | claims]
  end

  @doc """
  Returns all conflicting claim pairs (same resource, different claimants) in
  the given claim list.  Each element of the returned list is a
  `{claim_a, claim_b}` tuple.
  """
  @spec pending_conflicts(claim_list()) :: [{claim(), claim()}]
  def pending_conflicts(claims) when is_list(claims) do
    claims
    |> Enum.group_by(& &1.resource)
    |> Enum.flat_map(fn {_resource, group} ->
      group
      |> Enum.uniq_by(& &1.claimant)
      |> combinations_2()
      |> Enum.reject(fn {a, b} -> a.claimant == b.claimant end)
    end)
  end

  @doc """
  Returns the history list (identity function — provided for API symmetry so
  callers do not need to pattern-match on the accumulator directly).
  """
  @spec history(history()) :: history()
  def history(hist) when is_list(hist), do: hist

  # ── Private ──────────────────────────────────────────────────────────

  @spec arbitrate(claim(), claim()) :: {claim(), claim(), :higher_priority | :earlier_claim}
  defp arbitrate(a, b) do
    cond do
      a.priority > b.priority ->
        {a, b, :higher_priority}

      b.priority > a.priority ->
        {b, a, :higher_priority}

      DateTime.compare(a.claimed_at, b.claimed_at) in [:lt, :eq] ->
        {a, b, :earlier_claim}

      true ->
        {b, a, :earlier_claim}
    end
  end

  @spec combinations_2([any()]) :: [{any(), any()}]
  defp combinations_2([]), do: []
  defp combinations_2([_]), do: []

  defp combinations_2([h | t]) do
    pairs = Enum.map(t, fn x -> {h, x} end)
    pairs ++ combinations_2(t)
  end
end
