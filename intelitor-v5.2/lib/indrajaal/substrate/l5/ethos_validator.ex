defmodule Indrajaal.Substrate.L5.EthosValidator do
  @moduledoc """
  L5 Ethos Validator — Constitutional alignment verification for proposed actions.

  Checks proposed system actions against the constitutional invariants (Ψ₀-Ψ₅)
  and the Founder's Directive (Ω₀). Returns an alignment score and any violations.

  ## Constitutional Invariants
  - Ψ₀ (Existence): System must survive all operations
  - Ψ₁ (Regeneration): System must be regenerable from SQLite/DuckDB
  - Ψ₂ (Evolutionary Continuity): History must be preserved
  - Ψ₃ (Verification Capability): All state changes verifiable
  - Ψ₄ (Human Alignment): Founder's lineage is primary
  - Ψ₅ (Truthfulness): No deception in logs or outputs

  ## STAMP Constraints
  - SC-CONST-001: Constitutional verification mandatory
  - SC-SAFETY-009: Ψ₀ validated for all operations
  - SC-SAFETY-014: Ψ₅ no deception in logs
  """

  @type action :: %{
          type: atom(),
          target: String.t(),
          parameters: map(),
          requestor: String.t()
        }

  @type violation :: %{
          invariant: atom(),
          severity: :critical | :high | :medium | :low,
          reason: String.t()
        }

  @type validation_result :: %{
          aligned: boolean(),
          score: float(),
          violations: [violation()],
          checked_at: DateTime.t()
        }

  @invariants [:psi_0, :psi_1, :psi_2, :psi_3, :psi_4, :psi_5]

  @spec validate(action()) :: validation_result()
  def validate(action) do
    violations =
      @invariants
      |> Enum.flat_map(fn inv -> check_invariant(inv, action) end)

    score = compute_alignment_score(violations)

    %{
      aligned: Enum.empty?(violations),
      score: score,
      violations: violations,
      checked_at: DateTime.utc_now()
    }
  end

  @spec alignment_score(action()) :: float()
  def alignment_score(action) do
    validate(action).score
  end

  @spec invariants() :: [atom()]
  def invariants, do: @invariants

  # ── Invariant Checks ─────────────────────────────────────────────────

  defp check_invariant(:psi_0, action) do
    # Ψ₀ Existence: actions that could terminate the system
    destructive_types = [:shutdown, :destroy, :delete_all, :format, :wipe]

    if action.type in destructive_types and not guardian_approved?(action) do
      [
        %{
          invariant: :psi_0,
          severity: :critical,
          reason: "Destructive action #{action.type} requires Guardian approval"
        }
      ]
    else
      []
    end
  end

  defp check_invariant(:psi_1, action) do
    # Ψ₁ Regeneration: actions affecting state stores
    if action.type in [:delete_database, :truncate_state, :drop_table] do
      [
        %{
          invariant: :psi_1,
          severity: :critical,
          reason: "Action #{action.type} threatens regeneration capability"
        }
      ]
    else
      []
    end
  end

  defp check_invariant(:psi_2, action) do
    # Ψ₂ Evolutionary Continuity: actions deleting history
    if action.type in [:purge_history, :delete_evolution, :reset_lineage] do
      [
        %{
          invariant: :psi_2,
          severity: :critical,
          reason: "Action #{action.type} would break evolutionary continuity"
        }
      ]
    else
      []
    end
  end

  defp check_invariant(:psi_3, action) do
    # Ψ₃ Verification: actions bypassing audit
    if Map.get(action.parameters, :skip_audit, false) do
      [
        %{
          invariant: :psi_3,
          severity: :high,
          reason: "skip_audit=true violates verification capability"
        }
      ]
    else
      []
    end
  end

  defp check_invariant(:psi_4, action) do
    # Ψ₄ Human Alignment: actions against founder directive
    if action.type == :override_founder_directive do
      [
        %{
          invariant: :psi_4,
          severity: :critical,
          reason: "Cannot override Founder's Directive (Ω₀)"
        }
      ]
    else
      []
    end
  end

  defp check_invariant(:psi_5, action) do
    # Ψ₅ Truthfulness: actions that falsify data
    if action.type in [:falsify_log, :backdate_entry, :forge_signature] do
      [
        %{
          invariant: :psi_5,
          severity: :critical,
          reason: "Action #{action.type} violates truthfulness invariant"
        }
      ]
    else
      []
    end
  end

  # ── Helpers ──────────────────────────────────────────────────────────

  defp compute_alignment_score(violations) do
    if Enum.empty?(violations) do
      1.0
    else
      penalty =
        Enum.reduce(violations, 0.0, fn v, acc ->
          acc + severity_weight(v.severity)
        end)

      max(0.0, 1.0 - penalty)
    end
  end

  defp severity_weight(:critical), do: 0.5
  defp severity_weight(:high), do: 0.25
  defp severity_weight(:medium), do: 0.1
  defp severity_weight(:low), do: 0.05

  defp guardian_approved?(action) do
    Map.get(action.parameters, :guardian_approved, false)
  end
end
