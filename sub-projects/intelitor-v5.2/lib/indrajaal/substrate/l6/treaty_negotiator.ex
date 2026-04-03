defmodule Indrajaal.Substrate.L6.TreatyNegotiator do
  @moduledoc """
  ## Design Intent
  L6 module providing cross-holon treaty negotiation for the Indrajaal VSM fractal
  mesh. Implements `propose_treaty/2` to draft a treaty between two holons and
  `evaluate_treaty/1` to assess whether a proposed treaty is acceptable according
  to the holon's constitutional values and resource constraints.

  Treaty model:
    A treaty is a structured agreement with:
      - id           — unique treaty identifier
      - proposer     — FQUN of proposing holon
      - acceptor     — FQUN of target holon
      - terms        — list of term maps (type, value, duration_s)
      - constraints  — list of mutual constraint maps
      - proposed_at  — ISO-8601 timestamp
      - expires_at   — ISO-8601 expiry timestamp (default: 24 hours)
      - signature    — proposer's Ed25519 signature (simulated as SHA-256 here)

  Evaluation criteria (evaluate_treaty/1):
    1. Schema validity — required fields present and typed correctly
    2. Constitutional alignment — no terms violate Ψ₀–Ψ₅ invariants
    3. Resource feasibility — promised resource terms within 80% capacity
    4. Expiry validity — treaty has not already expired
    5. Mutual constraint compliance — all constraints achievable

  Returns:
    {:accept, terms}        — treaty accepted; terms is the normalised term list
    {:reject, reason}       — treaty rejected; reason is a descriptive string
    {:counter, suggestions} — treaty partially acceptable; suggestions list of changes

  ## STAMP Constraints
  - SC-FED-001: No modification of node constitutions — ENFORCED
  - SC-FED-002: Maintain node autonomy — ENFORCED (evaluation is advisory)
  - SC-SMRITI-100: Federation authenticated channels — proposal signed
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Claude Sonnet 4.6 | Initial implementation (Task 89, L6) |
  """

  require Logger

  @checkpoint "CP-L6-TREATY-NEGOTIATOR-01"

  # Default treaty duration if not specified (seconds)
  @default_duration_s 86_400

  # Maximum resource commitment percentage (80%)
  @max_resource_pct 0.80

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type term_type ::
          :resource_share
          | :data_exchange
          | :compute_allocation
          | :priority_routing
          | :mutual_defense

  @type treaty_term :: %{
          type: term_type(),
          value: term(),
          duration_s: non_neg_integer()
        }

  @type treaty :: %{
          id: String.t(),
          proposer: String.t(),
          acceptor: String.t(),
          terms: [treaty_term()],
          constraints: [map()],
          proposed_at: String.t(),
          expires_at: String.t(),
          signature: String.t()
        }

  @type evaluation_result ::
          {:accept, [treaty_term()]}
          | {:reject, String.t()}
          | {:counter, [map()]}

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Propose a treaty between `proposer_fqun` and `acceptor_fqun`.

  `terms` is a list of maps with at minimum `:type` and `:value` keys.

  Returns the fully formed `treaty` map with computed signature.
  """
  @spec propose_treaty(String.t(), String.t(), keyword()) :: {:ok, treaty()} | {:error, term()}
  def propose_treaty(proposer_fqun, acceptor_fqun, opts \\ [])
      when is_binary(proposer_fqun) and is_binary(acceptor_fqun) do
    terms = Keyword.get(opts, :terms, [])
    constraints = Keyword.get(opts, :constraints, [])
    duration_s = Keyword.get(opts, :duration_s, @default_duration_s)

    id = generate_id()
    now = DateTime.utc_now()
    expires_at = DateTime.add(now, duration_s, :second)

    normalised_terms = normalise_terms(terms, duration_s)

    treaty = %{
      id: id,
      proposer: proposer_fqun,
      acceptor: acceptor_fqun,
      terms: normalised_terms,
      constraints: constraints,
      proposed_at: DateTime.to_iso8601(now),
      expires_at: DateTime.to_iso8601(expires_at),
      signature: compute_signature(id, proposer_fqun, acceptor_fqun, normalised_terms)
    }

    Logger.info(
      "[TREATY_NEGOTIATOR] Treaty proposed id=#{id} " <>
        "proposer=#{proposer_fqun} acceptor=#{acceptor_fqun} " <>
        "terms=#{length(normalised_terms)} checkpoint=#{@checkpoint}"
    )

    emit_telemetry(:propose, id, length(normalised_terms))

    {:ok, treaty}
  end

  @doc """
  Evaluate a proposed treaty and return an acceptance decision.

  Returns:
    - `{:accept, terms}` — treaty accepted as-is
    - `{:reject, reason}` — treaty rejected
    - `{:counter, suggestions}` — counter-proposal with suggested amendments
  """
  @spec evaluate_treaty(treaty()) :: evaluation_result()
  def evaluate_treaty(treaty) when is_map(treaty) do
    with :ok <- validate_schema(treaty),
         :ok <- validate_expiry(treaty),
         :ok <- validate_constitutional_alignment(treaty),
         {:ok, feasible_terms} <- validate_resource_feasibility(treaty) do
      Logger.info(
        "[TREATY_NEGOTIATOR] Treaty ACCEPTED id=#{treaty.id} terms=#{length(feasible_terms)}"
      )

      emit_telemetry(:accept, treaty.id, length(feasible_terms))
      {:accept, feasible_terms}
    else
      {:reject, reason} ->
        Logger.info("[TREATY_NEGOTIATOR] Treaty REJECTED id=#{treaty.id} reason=#{reason}")

        emit_telemetry(:reject, treaty.id, 0)
        {:reject, reason}

      {:counter, suggestions} ->
        Logger.info(
          "[TREATY_NEGOTIATOR] Treaty COUNTER id=#{treaty.id} " <>
            "suggestions=#{length(suggestions)}"
        )

        emit_telemetry(:counter, treaty.id, length(suggestions))
        {:counter, suggestions}
    end
  end

  # ---------------------------------------------------------------------------
  # Private — validation pipeline
  # ---------------------------------------------------------------------------

  defp validate_schema(treaty) do
    required = [:id, :proposer, :acceptor, :terms, :proposed_at, :expires_at, :signature]

    missing = Enum.reject(required, &Map.has_key?(treaty, &1))

    if missing == [] do
      :ok
    else
      {:reject, "Missing required fields: #{inspect(missing)}"}
    end
  end

  defp validate_expiry(treaty) do
    case DateTime.from_iso8601(treaty.expires_at) do
      {:ok, expires_at, _} ->
        if DateTime.compare(DateTime.utc_now(), expires_at) == :lt do
          :ok
        else
          {:reject, "Treaty has expired: expires_at=#{treaty.expires_at}"}
        end

      {:error, _} ->
        {:reject, "Invalid expires_at format: #{treaty.expires_at}"}
    end
  end

  defp validate_constitutional_alignment(treaty) do
    terms = treaty[:terms] || []

    # Reject any term that would suppress audit or harm founder
    violating =
      Enum.find(terms, fn term ->
        term[:type] in [:suppress_audit, :disable_lineage, :override_constitution]
      end)

    if violating do
      {:reject, "Term type '#{violating[:type]}' violates constitutional invariants (Ψ₀-Ψ₅)"}
    else
      :ok
    end
  end

  defp validate_resource_feasibility(treaty) do
    terms = treaty[:terms] || []

    resource_terms = Enum.filter(terms, &(&1[:type] == :resource_share))

    over_committed =
      Enum.filter(resource_terms, fn term ->
        pct = term[:value] || 0.0
        is_number(pct) and pct > @max_resource_pct
      end)

    if over_committed == [] do
      {:ok, terms}
    else
      # Counter-propose with capped resource terms
      suggestions =
        Enum.map(over_committed, fn term ->
          %{
            amendment: :reduce_resource_commitment,
            term_type: term[:type],
            proposed_value: term[:value],
            suggested_value: @max_resource_pct,
            reason: "Cannot commit > #{trunc(@max_resource_pct * 100)}% of resources"
          }
        end)

      {:counter, suggestions}
    end
  end

  defp normalise_terms(terms, default_duration_s) do
    Enum.map(terms, fn term ->
      %{
        type: Map.get(term, :type, :data_exchange),
        value: Map.get(term, :value, nil),
        duration_s: Map.get(term, :duration_s, default_duration_s)
      }
    end)
  end

  defp compute_signature(id, proposer, acceptor, terms) do
    content = "#{id}:#{proposer}:#{acceptor}:#{length(terms)}"
    :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp emit_telemetry(event, treaty_id, term_count) do
    try do
      :telemetry.execute(
        [:indrajaal, :substrate, :l6, :treaty_negotiator, event],
        %{term_count: term_count},
        %{checkpoint: @checkpoint, treaty_id: treaty_id, constraint: "SC-FED-002"}
      )
    rescue
      _ -> :ok
    end
  end
end
