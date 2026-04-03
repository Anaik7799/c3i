defmodule Indrajaal.Substrate.L4.ThreatModeler do
  @moduledoc """
  L4 Threat Modeler — STRIDE-based threat assessment for system operations.

  Performs automated threat modeling using the STRIDE taxonomy:
  - Spoofing: Identity falsification
  - Tampering: Data modification
  - Repudiation: Action denial
  - Information Disclosure: Data leaks
  - Denial of Service: Availability attacks
  - Elevation of Privilege: Authorization bypass

  Each operation is scored across all 6 categories, producing a composite
  threat score and prioritized mitigation list.

  ## STAMP Constraints
  - SC-SAFETY-006: Anomaly detection for suspicious patterns
  - SC-IMMUNE-001: Threat detection mandatory
  """

  @type threat_category ::
          :spoofing
          | :tampering
          | :repudiation
          | :information_disclosure
          | :denial_of_service
          | :elevation_of_privilege

  @type threat_score :: %{
          category: threat_category(),
          likelihood: float(),
          impact: float(),
          risk: float(),
          mitigations: [String.t()]
        }

  @type assessment :: %{
          operation: String.t(),
          scores: [threat_score()],
          composite_risk: float(),
          timestamp: DateTime.t()
        }

  @categories [
    :spoofing,
    :tampering,
    :repudiation,
    :information_disclosure,
    :denial_of_service,
    :elevation_of_privilege
  ]

  @spec assess(String.t(), map()) :: assessment()
  def assess(operation, context \\ %{}) do
    scores = Enum.map(@categories, &score_category(&1, operation, context))
    composite = Enum.map(scores, & &1.risk) |> Enum.max()

    %{
      operation: operation,
      scores: scores,
      composite_risk: Float.round(composite, 3),
      timestamp: DateTime.utc_now()
    }
  end

  @spec high_risk?(assessment()) :: boolean()
  def high_risk?(assessment), do: assessment.composite_risk > 0.7

  @spec categories() :: [threat_category()]
  def categories, do: @categories

  @spec top_threats(assessment(), non_neg_integer()) :: [threat_score()]
  def top_threats(assessment, n \\ 3) do
    assessment.scores
    |> Enum.sort_by(& &1.risk, :desc)
    |> Enum.take(n)
  end

  # ── Scoring ──────────────────────────────────────────────────────────

  defp score_category(:spoofing, operation, context) do
    likelihood = if has_auth?(context), do: 0.2, else: 0.8
    impact = if String.contains?(operation, "control"), do: 0.9, else: 0.5
    build_score(:spoofing, likelihood, impact, ["Require ProofToken", "Mutual TLS"])
  end

  defp score_category(:tampering, operation, context) do
    likelihood = if has_integrity_check?(context), do: 0.1, else: 0.7
    impact = if String.contains?(operation, "state"), do: 0.9, else: 0.4
    build_score(:tampering, likelihood, impact, ["HMAC verification", "Immutable Register"])
  end

  defp score_category(:repudiation, _operation, context) do
    likelihood = if has_audit?(context), do: 0.1, else: 0.6
    impact = 0.5
    build_score(:repudiation, likelihood, impact, ["Append-only audit log", "Digital signatures"])
  end

  defp score_category(:information_disclosure, operation, _context) do
    likelihood = if String.contains?(operation, "query"), do: 0.5, else: 0.2
    impact = if String.contains?(operation, "kms"), do: 0.95, else: 0.4

    build_score(:information_disclosure, likelihood, impact, [
      "Encryption at rest",
      "Access control"
    ])
  end

  defp score_category(:denial_of_service, _operation, context) do
    likelihood = if has_rate_limit?(context), do: 0.2, else: 0.6
    impact = 0.7

    build_score(:denial_of_service, likelihood, impact, [
      "Circuit breaker",
      "Rate limiting",
      "Load shedding"
    ])
  end

  defp score_category(:elevation_of_privilege, operation, context) do
    likelihood = if has_rbac?(context), do: 0.15, else: 0.7
    impact = if String.contains?(operation, "guardian"), do: 0.95, else: 0.6

    build_score(:elevation_of_privilege, likelihood, impact, [
      "RBAC enforcement",
      "Guardian approval"
    ])
  end

  defp build_score(category, likelihood, impact, mitigations) do
    %{
      category: category,
      likelihood: Float.round(likelihood, 3),
      impact: Float.round(impact, 3),
      risk: Float.round(likelihood * impact, 3),
      mitigations: mitigations
    }
  end

  defp has_auth?(ctx), do: Map.get(ctx, :authenticated, false)
  defp has_integrity_check?(ctx), do: Map.get(ctx, :integrity_verified, false)
  defp has_audit?(ctx), do: Map.get(ctx, :audit_enabled, true)
  defp has_rate_limit?(ctx), do: Map.get(ctx, :rate_limited, false)
  defp has_rbac?(ctx), do: Map.get(ctx, :rbac_enforced, false)
end
