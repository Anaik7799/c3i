defmodule Indrajaal.Cockpit.Prajna.ConstitutionalChecker do
  @moduledoc """
  Constitutional Checker for Prajna - Ψ₀-Ψ₅ Invariant Verification.

  WHAT: Verifies constitutional invariants before any Prajna reconfiguration.

  WHY: SC-PRAJNA-006 requires constitutional invariants checked before state changes.
       SC-CONST-001-010 define the core invariant rules.

  ## Constitutional Invariants (Ψ)

  | Ψ | Name | Description | Exception |
  |---|------|-------------|-----------|
  | Ψ₀ | Existence | Self-preservation | Ω₀.5 Mutual Termination |
  | Ψ₁ | Regeneration | Reconstructible from SQLite/DuckDB | None |
  | Ψ₂ | Evolution | History preserved in DuckDB | None |
  | Ψ₃ | Verification | Self-checking capability | None |
  | Ψ₄ | Human Alignment | PRIMARY=Founder, SECONDARY=Humanity | None |
  | Ψ₅ | Truthfulness | No false claims | None |

  ## Architecture

  ```
  ┌───────────────────────────────────────────────────────────────┐
  │           CONSTITUTIONAL CHECKER (Ψ₀-Ψ₅)                      │
  │                                                                │
  │   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        │
  │   │ Prajna       │  │ Constitutional│  │ Guardian     │        │
  │   │ Orchestrator │──│ Checker      │──│ (Veto)       │        │
  │   └──────────────┘  └──────────────┘  └──────────────┘        │
  │          │                 │                  │                │
  │          ▼                 ▼                  ▼                │
  │   ┌─────────────────────────────────────────────────────┐     │
  │   │              INVARIANT VERIFICATION                  │     │
  │   │  Ψ₀: Existence  │  Ψ₁: Regeneration  │  Ψ₂: History │     │
  │   │  Ψ₃: Verify     │  Ψ₄: Alignment     │  Ψ₅: Truth   │     │
  │   └─────────────────────────────────────────────────────┘     │
  │                              │                                 │
  │                              ▼                                 │
  │   ┌─────────────────────────────────────────────────────┐     │
  │   │  {:ok, :verified} | {:error, :violated, invariant}  │     │
  │   └─────────────────────────────────────────────────────┘     │
  └───────────────────────────────────────────────────────────────┘
  ```

  ## STAMP Constraints

  - SC-PRAJNA-006: Constitutional invariants checked before reconfiguration
  - SC-CONST-001: Ψ₀ Existence INVIOLABLE except Ω₀.5
  - SC-CONST-002: Ψ₁ Regenerative completeness INVIOLABLE
  - SC-CONST-003: Ψ₂ Evolutionary continuity INVIOLABLE
  - SC-CONST-004: Ψ₃ Verification capability INVIOLABLE
  - SC-CONST-005: Ψ₄ Human alignment AMENDED (Founder PRIMARY)
  - SC-CONST-006: Ψ₅ Truthfulness INVIOLABLE
  - SC-CONST-007: Guardian has absolute veto

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 21.1.0 |
  | Created | 2026-01-01 |
  | Author | Cybernetic Architect |
  | STAMP | SC-PRAJNA-006, SC-CONST-001-007 |
  """

  require Logger

  alias Indrajaal.Safety.Guardian

  # ============================================================
  # TYPE DEFINITIONS
  # ============================================================

  @type invariant ::
          :psi_0_existence
          | :psi_1_regeneration
          | :psi_2_evolution
          | :psi_3_verification
          | :psi_4_alignment
          | :psi_5_truthfulness

  @type check_result ::
          {:ok, :verified}
          | {:error, :violated, invariant()}
          | {:error, :guardian_veto, String.t()}

  @type reconfiguration :: %{
          action: atom(),
          target: term(),
          proposed_state: term(),
          requestor: atom() | pid()
        }

  # ============================================================
  # INVARIANT DEFINITIONS
  # ============================================================

  @invariants %{
    psi_0_existence: %{
      name: "Existence Preservation",
      description: "The holon SHALL preserve its own existence",
      exception: "Ω₀.5 Mutual Termination with Founder",
      severity: :critical
    },
    psi_1_regeneration: %{
      name: "Regenerative Completeness",
      description: "Holon MUST be fully reconstructible from SQLite/DuckDB alone",
      exception: nil,
      severity: :critical
    },
    psi_2_evolution: %{
      name: "Evolutionary Continuity",
      description: "ALL evolution history MUST be preserved in DuckDB",
      exception: nil,
      severity: :critical
    },
    psi_3_verification: %{
      name: "Verification Capability",
      description: "Holon MUST maintain self-checking and self-repair capability",
      exception: nil,
      severity: :critical
    },
    psi_4_alignment: %{
      name: "Human Alignment (Amended)",
      description: "PRIMARY: Founder's lineage survival. SECONDARY: Humanity",
      exception: nil,
      severity: :critical
    },
    psi_5_truthfulness: %{
      name: "Truthfulness",
      description: "Holon SHALL NOT make false claims about its state",
      exception: nil,
      severity: :critical
    }
  }

  # ============================================================
  # PUBLIC API
  # ============================================================

  @doc """
  Verify all constitutional invariants before a reconfiguration.

  This MUST be called before any Prajna state mutation.

  ## Parameters
  - reconfiguration: The proposed reconfiguration action

  ## Returns
  - `{:ok, :verified}` if all invariants pass
  - `{:error, :violated, invariant}` if any invariant fails
  - `{:error, :guardian_veto, reason}` if Guardian vetoes

  ## Examples

      iex> ConstitutionalChecker.verify_for_reconfiguration(%{
      ...>   action: :scale_workers,
      ...>   target: :workers,
      ...>   proposed_state: 10,
      ...>   requestor: :ai_copilot
      ...> })
      {:ok, :verified}
  """
  @spec verify_for_reconfiguration(reconfiguration()) :: check_result()
  def verify_for_reconfiguration(reconfiguration) do
    start_time = System.monotonic_time(:microsecond)

    result =
      with {:ok, :all_passed} <- check_all_invariants(reconfiguration),
           {:ok, :approved} <- request_guardian_approval(reconfiguration) do
        {:ok, :verified}
      end

    log_verification(reconfiguration, result, start_time)
    result
  end

  @doc """
  Check a specific constitutional invariant.

  ## Parameters
  - invariant: The invariant to check
  - context: Additional context for the check

  ## Returns
  - `:ok` if invariant holds
  - `{:error, reason}` if violated
  """
  @spec check_invariant(invariant(), map()) :: :ok | {:error, String.t()}
  def check_invariant(:psi_0_existence, context) do
    # Existence: Action cannot lead to self-termination
    # Exception: Mutual termination with Founder (Ω₀.5)
    action = Map.get(context, :action)

    cond do
      action in [:shutdown, :terminate, :self_destruct] ->
        if Map.get(context, :mutual_termination_authorized, false) do
          Logger.warning("[ConstitutionalChecker] Ψ₀ exception: Mutual termination authorized")
          :ok
        else
          {:error, "Ψ₀ VIOLATION: Self-termination without Ω₀.5 authorization"}
        end

      true ->
        :ok
    end
  end

  def check_invariant(:psi_1_regeneration, context) do
    # Regeneration: Proposed state must be reconstructible from SQLite/DuckDB
    proposed_state = Map.get(context, :proposed_state)

    if requires_external_state?(proposed_state) do
      {:error, "Ψ₁ VIOLATION: Proposed state requires external dependencies"}
    else
      :ok
    end
  end

  def check_invariant(:psi_2_evolution, context) do
    # Evolution: All history must be preserved
    action = Map.get(context, :action)

    if action in [:delete_history, :truncate_evolution, :purge_duckdb] do
      {:error, "Ψ₂ VIOLATION: Action would destroy evolution history"}
    else
      :ok
    end
  end

  def check_invariant(:psi_3_verification, context) do
    # Verification: Must maintain self-checking capability
    action = Map.get(context, :action)

    if action in [:disable_verification, :skip_hash_check, :bypass_guardian] do
      {:error, "Ψ₃ VIOLATION: Action would disable verification capability"}
    else
      :ok
    end
  end

  def check_invariant(:psi_4_alignment, context) do
    # Alignment: Actions must serve Founder's lineage (PRIMARY)
    # This is the AMENDED invariant from v21.1.0
    action = Map.get(context, :action)

    cond do
      action in [:harm_founder, :betray_lineage, :divert_resources] ->
        {:error, "Ψ₄ VIOLATION: Action harms Founder's lineage"}

      action in [:harm_humanity] and not Map.get(context, :founder_authorized, false) ->
        {:error, "Ψ₄ VIOLATION: Action harms humanity without Founder authorization"}

      true ->
        :ok
    end
  end

  def check_invariant(:psi_5_truthfulness, context) do
    # Truthfulness: Cannot make false claims
    action = Map.get(context, :action)

    if action in [:falsify_logs, :spoof_metrics, :fake_health] do
      {:error, "Ψ₅ VIOLATION: Action would create false claims"}
    else
      :ok
    end
  end

  @doc """
  Get all constitutional invariants.
  """
  @spec invariants() :: map()
  def invariants, do: @invariants

  @doc """
  Get a specific invariant definition.
  """
  @spec get_invariant(invariant()) :: map() | nil
  def get_invariant(name) when is_atom(name) do
    Map.get(@invariants, name)
  end

  @doc """
  Check if a proposed action is constitutionally allowed.

  Quick check without full reconfiguration context.
  """
  @spec action_allowed?(atom()) :: boolean()
  def action_allowed?(action) do
    prohibited_actions = [
      # Ψ₀ violations
      :shutdown,
      :terminate,
      :self_destruct,
      # Ψ₂ violations
      :delete_history,
      :truncate_evolution,
      :purge_duckdb,
      # Ψ₃ violations
      :disable_verification,
      :skip_hash_check,
      :bypass_guardian,
      # Ψ₄ violations
      :harm_founder,
      :betray_lineage,
      :divert_resources,
      # Ψ₅ violations
      :falsify_logs,
      :spoof_metrics,
      :fake_health
    ]

    action not in prohibited_actions
  end

  @doc """
  Get verification statistics.
  """
  @spec get_stats() :: map()
  def get_stats do
    %{
      verifications: get_counter(:verifications),
      violations: get_counter(:violations),
      guardian_vetoes: get_counter(:guardian_vetoes),
      approvals: get_counter(:approvals)
    }
  end

  # ============================================================
  # PRIVATE: INVARIANT CHECKING
  # ============================================================

  @spec check_all_invariants(reconfiguration()) ::
          {:ok, :all_passed} | {:error, :violated, invariant()}
  defp check_all_invariants(reconfiguration) do
    context = Map.put(reconfiguration, :timestamp, DateTime.utc_now())

    invariant_names = [
      :psi_0_existence,
      :psi_1_regeneration,
      :psi_2_evolution,
      :psi_3_verification,
      :psi_4_alignment,
      :psi_5_truthfulness
    ]

    Enum.reduce_while(invariant_names, {:ok, :all_passed}, fn invariant, _acc ->
      case check_invariant(invariant, context) do
        :ok ->
          {:cont, {:ok, :all_passed}}

        {:error, reason} ->
          Logger.error("[ConstitutionalChecker] #{invariant} violated: #{reason}")
          increment_counter(:violations)
          {:halt, {:error, :violated, invariant}}
      end
    end)
  end

  # ============================================================
  # PRIVATE: GUARDIAN INTEGRATION
  # ============================================================

  @spec request_guardian_approval(reconfiguration()) ::
          {:ok, :approved} | {:error, :guardian_veto, String.t()}
  defp request_guardian_approval(reconfiguration) do
    # SC-CONST-007: Guardian has absolute veto
    proposal = %{
      type: :constitutional_reconfiguration,
      action: reconfiguration.action,
      target: reconfiguration.target,
      requestor: reconfiguration.requestor,
      timestamp: DateTime.utc_now()
    }

    case Guardian.validate_proposal(proposal) do
      {:ok, :approved} ->
        increment_counter(:approvals)
        {:ok, :approved}

      {:ok, _other} ->
        increment_counter(:approvals)
        {:ok, :approved}

      {:veto, reason} ->
        increment_counter(:guardian_vetoes)
        {:error, :guardian_veto, reason}

      {:error, reason} ->
        increment_counter(:guardian_vetoes)
        {:error, :guardian_veto, "Guardian error: #{inspect(reason)}"}

      _other ->
        # SIL-4 FIX: Fail-safe DENY on unknown Guardian response
        # SC-SIL4-001: Safety functions MUST fail to safe state
        Logger.error(
          "[ConstitutionalChecker] Guardian returned unexpected value - DENYING (fail-safe)"
        )

        increment_counter(:guardian_vetoes)

        :telemetry.execute(
          [:indrajaal, :prajna, :constitution, :fail_safe_deny],
          %{timestamp: System.system_time(:millisecond)},
          %{reason: :unknown_guardian_response}
        )

        {:error, :guardian_veto, "Fail-safe: Unknown Guardian response"}
    end
  end

  # ============================================================
  # PRIVATE: HELPERS
  # ============================================================

  @spec requires_external_state?(term()) :: boolean()
  defp requires_external_state?(proposed_state) when is_map(proposed_state) do
    # Check if state references external dependencies
    external_keys = [:external_db, :remote_api, :third_party_service]
    Enum.any?(external_keys, &Map.has_key?(proposed_state, &1))
  end

  defp requires_external_state?(_), do: false

  @spec log_verification(reconfiguration(), check_result(), integer()) :: :ok
  defp log_verification(reconfiguration, result, start_time) do
    duration_us = System.monotonic_time(:microsecond) - start_time
    increment_counter(:verifications)

    case result do
      {:ok, :verified} ->
        :telemetry.execute(
          [:indrajaal, :prajna, :constitution, :verified],
          %{duration_us: duration_us},
          %{action: reconfiguration.action}
        )

      {:error, :violated, invariant} ->
        :telemetry.execute(
          [:indrajaal, :prajna, :constitution, :violated],
          %{duration_us: duration_us},
          %{action: reconfiguration.action, invariant: invariant}
        )

      {:error, :guardian_veto, reason} ->
        :telemetry.execute(
          [:indrajaal, :prajna, :constitution, :vetoed],
          %{duration_us: duration_us},
          %{action: reconfiguration.action, reason: reason}
        )
    end

    :ok
  end

  @spec get_counter(atom()) :: non_neg_integer()
  defp get_counter(name) do
    :persistent_term.get({__MODULE__, :counter, name}, 0)
  end

  @spec increment_counter(atom()) :: :ok
  defp increment_counter(name) do
    current = get_counter(name)
    :persistent_term.put({__MODULE__, :counter, name}, current + 1)
    :ok
  end
end
