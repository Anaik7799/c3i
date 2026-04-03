defmodule Indrajaal.Substrate.L6.DiplomacyEngine do
  @moduledoc """
  ## Design Intent
  L6 substrate Diplomacy Engine — pure functional inter-holon diplomatic protocol.
  Models the negotiation of treaties, accords, and standing agreements between
  holons in a federation. Uses a utility-maximizing proposal evaluation function
  to determine whether to accept, counter-propose, or reject an incoming
  diplomatic proposal.

  Proposal evaluation (BATNA-relative utility):
    utility = Σ(term_weight × term_value) − acceptance_cost
    accept if utility ≥ batna_threshold

  Counter-proposal generation: adjusts lowest-value terms upward by 10%.

  Diplomatic states: :neutral → :negotiating → :allied | :adversarial

  ## STAMP Constraints
  - SC-FED-001: No modification of node constitutions — ENFORCED
  - SC-FED-002: Maintain node autonomy — ENFORCED
  - SC-FED-005: Membership management maintained — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @max_active_negotiations 16
  @max_treaties 64
  @batna_default 0.4
  @acceptance_cost 0.05

  @type holon_id :: String.t()
  @type term_key :: atom()

  @type proposal :: %{
          from: holon_id(),
          to: holon_id(),
          terms: %{term_key() => float()},
          round: pos_integer()
        }

  @type treaty :: %{
          id: String.t(),
          parties: [holon_id()],
          terms: %{term_key() => float()},
          utility: float(),
          ratified_at: integer()
        }

  @type relation_state :: :neutral | :negotiating | :allied | :adversarial

  @type t :: %__MODULE__{
          holon_id: holon_id(),
          batna_threshold: float(),
          term_weights: %{term_key() => float()},
          active_negotiations: %{holon_id() => proposal()},
          treaties: [treaty()],
          relations: %{holon_id() => relation_state()}
        }

  defstruct holon_id: "holon_0",
            batna_threshold: @batna_default,
            term_weights: %{},
            active_negotiations: %{},
            treaties: [],
            relations: %{}

  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    holon_id = Keyword.get(opts, :holon_id, "holon_0")
    batna = Keyword.get(opts, :batna_threshold, @batna_default)
    weights = Keyword.get(opts, :term_weights, %{resource: 0.4, autonomy: 0.4, scope: 0.2})

    cond do
      not is_binary(holon_id) ->
        {:error, "holon_id must be a string"}

      not is_number(batna) or batna < 0.0 or batna > 1.0 ->
        {:error, "batna_threshold must be a float in [0.0, 1.0]"}

      not is_map(weights) ->
        {:error, "term_weights must be a map"}

      true ->
        {:ok,
         %__MODULE__{
           holon_id: holon_id,
           batna_threshold: batna,
           term_weights: weights
         }}
    end
  end

  @doc """
  Evaluate an incoming proposal. Returns `{:accept, state}`, `{:counter, proposal, state}`,
  or `{:reject, reason, state}`.
  """
  @spec evaluate_proposal(t(), proposal()) ::
          {:accept, t()} | {:counter, proposal(), t()} | {:reject, String.t(), t()}
  def evaluate_proposal(%__MODULE__{} = state, proposal) do
    cond do
      map_size(state.active_negotiations) >= @max_active_negotiations ->
        {:reject, "negotiation capacity reached", state}

      proposal.to != state.holon_id ->
        {:reject, "proposal not addressed to this holon", state}

      true ->
        utility = compute_utility(proposal.terms, state.term_weights)
        new_state = register_negotiation(state, proposal)

        cond do
          utility >= state.batna_threshold ->
            finalized = finalize_treaty(new_state, proposal, utility)
            {:accept, finalized}

          utility >= state.batna_threshold * 0.6 ->
            counter = counter_propose(proposal, state.holon_id)
            {:counter, counter, new_state}

          true ->
            closed = close_negotiation(new_state, proposal.from, :adversarial)

            {:reject, "utility #{Float.round(utility, 3)} below BATNA #{state.batna_threshold}",
             closed}
        end
    end
  end

  @doc """
  Return the current diplomatic relation with a peer holon.
  """
  @spec relation_with(t(), holon_id()) :: relation_state()
  def relation_with(%__MODULE__{} = state, peer_id) when is_binary(peer_id) do
    Map.get(state.relations, peer_id, :neutral)
  end

  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    %{
      holon_id: state.holon_id,
      batna_threshold: state.batna_threshold,
      active_negotiations: map_size(state.active_negotiations),
      treaty_count: length(state.treaties),
      allied_peers: state.relations |> Enum.count(fn {_, r} -> r == :allied end),
      adversarial_peers: state.relations |> Enum.count(fn {_, r} -> r == :adversarial end)
    }
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp compute_utility(terms, weights) do
    weighted_sum =
      Enum.reduce(terms, 0.0, fn {key, value}, acc ->
        w = Map.get(weights, key, 0.1)
        acc + w * clamp(value, 0.0, 1.0)
      end)

    max(weighted_sum - @acceptance_cost, 0.0)
  end

  defp register_negotiation(state, proposal) do
    relations = Map.put(state.relations, proposal.from, :negotiating)
    negotiations = Map.put(state.active_negotiations, proposal.from, proposal)
    %{state | relations: relations, active_negotiations: negotiations}
  end

  defp finalize_treaty(state, proposal, utility) do
    id = :crypto.strong_rand_bytes(6) |> Base.encode16(case: :lower)
    now = System.monotonic_time(:second)

    treaty = %{
      id: id,
      parties: [state.holon_id, proposal.from],
      terms: proposal.terms,
      utility: Float.round(utility, 4),
      ratified_at: now
    }

    treaties = Enum.take([treaty | state.treaties], @max_treaties)
    closed = close_negotiation(state, proposal.from, :allied)
    %{closed | treaties: treaties}
  end

  defp counter_propose(original_proposal, from_id) do
    improved_terms =
      Map.new(original_proposal.terms, fn {k, v} ->
        {k, Float.round(min(v * 1.10, 1.0), 3)}
      end)

    %{
      original_proposal
      | from: from_id,
        to: original_proposal.from,
        terms: improved_terms,
        round: original_proposal.round + 1
    }
  end

  defp close_negotiation(state, peer_id, outcome) do
    negotiations = Map.delete(state.active_negotiations, peer_id)
    relations = Map.put(state.relations, peer_id, outcome)
    %{state | active_negotiations: negotiations, relations: relations}
  end

  defp clamp(v, lo, hi) when is_number(v), do: v |> max(lo) |> min(hi)
  defp clamp(_v, lo, _hi), do: lo
end
