defmodule Indrajaal.Substrate.L6.ReputationTracker do
  @moduledoc """
  ## Design Intent
  L6 substrate Reputation Tracker — pure functional peer reputation scoring
  for the Indrajaal federation layer.

  Models the biological concept of symbiotic fitness: each peer's reputation
  score reflects its historical reliability as an interaction partner. Scores
  are updated via Exponential Moving Average (EMA) to resist manipulation while
  remaining responsive to sustained behaviour changes.

  Algorithm:
    - Initial score: 0.5 (neutral prior)
    - EMA update:    score = α × observation + (1 − α) × score_prev  (α = 0.25)
    - Trust tier:    :high (≥ 0.75), :medium (≥ 0.40), :low (< 0.40)
    - Scores are clamped to [0.0, 1.0] at every update

  ## STAMP Constraints
  - SC-FED-005: Membership management — reputation informs membership weight
  - SC-FED-006: Attestation Ed25519-verified — rating source verified externally
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @ema_alpha 0.25
  @initial_score 0.5

  @type trust_tier :: :high | :medium | :low

  @type peer_entry :: %{
          peer_id: String.t(),
          score: float(),
          rating_count: non_neg_integer(),
          trust_tier: trust_tier(),
          last_observation: float() | nil
        }

  @type t :: %__MODULE__{
          peers: %{String.t() => peer_entry()},
          total_ratings: non_neg_integer(),
          created_at: integer()
        }

  defstruct peers: %{},
            total_ratings: 0,
            created_at: 0

  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    _opts = opts

    state = %__MODULE__{
      peers: %{},
      total_ratings: 0,
      created_at: System.monotonic_time(:second)
    }

    {:ok, state}
  end

  @doc """
  Record an observation for a peer. `observation` must be in [0.0, 1.0].
  Returns the updated tracker and the new score for the peer.
  """
  @spec record(t(), String.t(), float()) :: {:ok, t(), float()} | {:error, String.t()}
  def record(%__MODULE__{} = tracker, peer_id, observation)
      when is_binary(peer_id) and is_float(observation) do
    obs = max(0.0, min(1.0, observation))

    entry =
      case Map.get(tracker.peers, peer_id) do
        nil ->
          %{
            peer_id: peer_id,
            score: @initial_score,
            rating_count: 0,
            trust_tier: tier(@initial_score),
            last_observation: nil
          }

        existing ->
          existing
      end

    new_score =
      Float.round(@ema_alpha * obs + (1.0 - @ema_alpha) * entry.score, 4)

    updated_entry = %{
      entry
      | score: new_score,
        rating_count: entry.rating_count + 1,
        trust_tier: tier(new_score),
        last_observation: obs
    }

    updated_tracker = %{
      tracker
      | peers: Map.put(tracker.peers, peer_id, updated_entry),
        total_ratings: tracker.total_ratings + 1
    }

    {:ok, updated_tracker, new_score}
  end

  def record(%__MODULE__{}, _peer_id, _observation) do
    {:error, "observation must be a float in [0.0, 1.0]"}
  end

  @doc """
  Retrieve the score for a peer. Returns `{:ok, score}` or `{:error, :not_found}`.
  """
  @spec score(t(), String.t()) :: {:ok, float()} | {:error, :not_found}
  def score(%__MODULE__{} = tracker, peer_id) when is_binary(peer_id) do
    case Map.get(tracker.peers, peer_id) do
      nil -> {:error, :not_found}
      entry -> {:ok, entry.score}
    end
  end

  @doc """
  Return the top `n` peers sorted by descending score.
  """
  @spec top_peers(t(), pos_integer()) :: [peer_entry()]
  def top_peers(%__MODULE__{} = tracker, n) when is_integer(n) and n > 0 do
    tracker.peers
    |> Map.values()
    |> Enum.sort_by(& &1.score, :desc)
    |> Enum.take(n)
  end

  @doc """
  Return a summary map describing tracker state.
  """
  @spec status(t()) :: map()
  def status(%__MODULE__{} = tracker) do
    peer_list = Map.values(tracker.peers)
    total = length(peer_list)

    avg =
      if total > 0 do
        Float.round(Enum.sum(Enum.map(peer_list, & &1.score)) / total, 4)
      else
        0.0
      end

    %{
      peer_count: total,
      total_ratings: tracker.total_ratings,
      average_score: avg,
      high_trust: Enum.count(peer_list, &(&1.trust_tier == :high)),
      medium_trust: Enum.count(peer_list, &(&1.trust_tier == :medium)),
      low_trust: Enum.count(peer_list, &(&1.trust_tier == :low))
    }
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec tier(float()) :: trust_tier()
  defp tier(score) when score >= 0.75, do: :high
  defp tier(score) when score >= 0.40, do: :medium
  defp tier(_score), do: :low
end
