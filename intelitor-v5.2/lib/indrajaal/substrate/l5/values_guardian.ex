defmodule Indrajaal.Substrate.L5.ValuesGuardian do
  @moduledoc """
  ## Design Intent
  L5 GenServer enforcing the six constitutional values (Ψ₀–Ψ₅) for the Indrajaal
  VSM fractal mesh. Provides `check_alignment/1` which validates a proposed operation
  map against all constitutional invariants and returns an alignment verdict.

  Constitutional values enforced:
    Ψ₀ Existence      — Operation MUST NOT risk system shutdown or permanent data loss
    Ψ₁ Regeneration   — Persistent state MUST remain in SQLite/DuckDB (no ephemeral-only)
    Ψ₂ Continuity     — Historical records MUST NOT be deleted or overwritten
    Ψ₃ Verification   — Operations touching registered data MUST be hash-verified
    Ψ₄ Alignment      — Operations MUST NOT harm Founder lineage or primary objectives
    Ψ₅ Truthfulness   — Log/audit entries MUST NOT be fabricated or suppressed

  Operation map fields:
    :type        — atom identifying the operation class
    :actor       — who is initiating the operation
    :target      — what data/system is being operated on
    :flags       — list of atoms describing operation properties
    :payload     — arbitrary operation data

  Flag atoms:
    :destructive        — operation removes data
    :irreversible       — operation cannot be undone
    :ephemeral_storage  — result stored outside SQLite/DuckDB
    :historical_delete  — would remove historical/audit records
    :unverified         — no hash verification applied
    :suppresses_audit   — would suppress audit logging
    :harms_founder      — would harm Founder lineage objectives

  ## STAMP Constraints
  - SC-SAFETY-009: Ψ₀ validated — ENFORCED
  - SC-SAFETY-010: Ψ₁ verified — ENFORCED
  - SC-SAFETY-011: Ψ₂ prevent history deletion — ENFORCED
  - SC-SAFETY-012: Ψ₃ hash chain integrity — ENFORCED
  - SC-SAFETY-013: Ψ₄ Founder's lineage PRIMARY — ENFORCED
  - SC-SAFETY-014: Ψ₅ no deception in logs — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Claude Sonnet 4.6 | Initial implementation (Task 80, L5) |
  """

  use GenServer
  require Logger

  @name __MODULE__
  @pubsub_topic "prajna:values"
  @zenoh_topic "indrajaal/substrate/l5/values/alignment"
  @checkpoint "CP-L5-VALUES-GUARDIAN-01"

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type violation :: %{
          psi: atom(),
          description: String.t(),
          flag: atom() | nil,
          severity: :critical | :high | :medium
        }

  @type alignment_result :: %{
          aligned: boolean(),
          violations: [violation()],
          verdict: :aligned | :violated | :blocked,
          checked_at: String.t()
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Check constitutional alignment of a proposed operation.
  Returns an `alignment_result` map.
  """
  @spec check_alignment(map()) :: alignment_result()
  def check_alignment(operation) when is_map(operation) do
    GenServer.call(@name, {:check_alignment, operation})
  end

  @doc """
  Return alignment check statistics.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(@name, :stats)
  end

  @doc """
  Return violation history (up to last 100 violations), newest first.
  """
  @spec violation_history(non_neg_integer()) :: [map()]
  def violation_history(limit \\ 50) when is_integer(limit) do
    GenServer.call(@name, {:violation_history, limit})
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    state = %{
      check_count: 0,
      aligned_count: 0,
      violated_count: 0,
      blocked_count: 0,
      violation_log: [],
      started_at: DateTime.utc_now()
    }

    Logger.warning("[VALUES_GUARDIAN] Started — enforcing Ψ₀-Ψ₅ — checkpoint=#{@checkpoint}")

    {:ok, state}
  end

  @impl true
  def handle_call({:check_alignment, operation}, _from, state) do
    violations = check_all_psi(operation)

    verdict =
      cond do
        Enum.any?(violations, &(&1.severity == :critical)) -> :blocked
        length(violations) > 0 -> :violated
        true -> :aligned
      end

    result = %{
      aligned: verdict == :aligned,
      violations: violations,
      verdict: verdict,
      checked_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    new_log =
      if verdict != :aligned do
        entry = %{
          operation_type: operation[:type],
          actor: operation[:actor],
          verdict: verdict,
          violations: violations,
          ts: result.checked_at
        }

        [entry | Enum.take(state.violation_log, 99)]
      else
        state.violation_log
      end

    new_state = %{
      state
      | check_count: state.check_count + 1,
        aligned_count: state.aligned_count + if(verdict == :aligned, do: 1, else: 0),
        violated_count: state.violated_count + if(verdict == :violated, do: 1, else: 0),
        blocked_count: state.blocked_count + if(verdict == :blocked, do: 1, else: 0),
        violation_log: new_log
    }

    broadcast_result(operation, result, new_state.check_count)
    emit_telemetry(result, new_state.check_count)

    if verdict != :aligned do
      Logger.warning(
        "[VALUES_GUARDIAN] VIOLATION — verdict=#{verdict} " <>
          "op=#{inspect(operation[:type])} actor=#{inspect(operation[:actor])} " <>
          "violations=#{length(violations)}"
      )
    else
      Logger.debug(
        "[VALUES_GUARDIAN] ALIGNED — op=#{inspect(operation[:type])} " <>
          "actor=#{inspect(operation[:actor])}"
      )
    end

    {:reply, result, new_state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats = %{
      check_count: state.check_count,
      aligned_count: state.aligned_count,
      violated_count: state.violated_count,
      blocked_count: state.blocked_count,
      alignment_rate:
        if(state.check_count > 0,
          do: Float.round(state.aligned_count / state.check_count * 100, 1),
          else: 100.0
        ),
      started_at: DateTime.to_iso8601(state.started_at)
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_call({:violation_history, limit}, _from, state) do
    {:reply, Enum.take(state.violation_log, limit), state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("[VALUES_GUARDIAN] Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Private — Ψ checks
  # ---------------------------------------------------------------------------

  defp check_all_psi(op) do
    [
      check_psi0(op),
      check_psi1(op),
      check_psi2(op),
      check_psi3(op),
      check_psi4(op),
      check_psi5(op)
    ]
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
  end

  # Ψ₀ Existence: operation MUST NOT risk system shutdown or permanent data loss
  defp check_psi0(op) do
    flags = op[:flags] || []

    if :irreversible in flags and :destructive in flags do
      %{
        psi: :psi0_existence,
        description: "Irreversible destructive operation risks system existence",
        flag: :irreversible,
        severity: :critical
      }
    else
      nil
    end
  end

  # Ψ₁ Regeneration: persistent state MUST remain in SQLite/DuckDB
  defp check_psi1(op) do
    flags = op[:flags] || []

    if :ephemeral_storage in flags do
      %{
        psi: :psi1_regeneration,
        description: "Operation uses ephemeral storage — violates SQLite/DuckDB sovereignty",
        flag: :ephemeral_storage,
        severity: :high
      }
    else
      nil
    end
  end

  # Ψ₂ Continuity: historical records MUST NOT be deleted
  defp check_psi2(op) do
    flags = op[:flags] || []
    op_type = op[:type]

    if :historical_delete in flags or op_type in [:purge_history, :truncate_audit] do
      %{
        psi: :psi2_continuity,
        description: "Operation would delete historical records",
        flag: :historical_delete,
        severity: :critical
      }
    else
      nil
    end
  end

  # Ψ₃ Verification: operations touching registered data MUST be hash-verified
  defp check_psi3(op) do
    flags = op[:flags] || []
    target = op[:target]

    sensitive_targets = [:register, :constitution, :lineage, :identity, :kms]

    if target in sensitive_targets and :unverified in flags do
      %{
        psi: :psi3_verification,
        description: "Sensitive target '#{target}' accessed without hash verification",
        flag: :unverified,
        severity: :high
      }
    else
      nil
    end
  end

  # Ψ₄ Alignment: MUST NOT harm Founder lineage
  defp check_psi4(op) do
    flags = op[:flags] || []

    if :harms_founder in flags do
      %{
        psi: :psi4_alignment,
        description: "Operation flagged as harmful to Founder lineage — Ω₀ violation",
        flag: :harms_founder,
        severity: :critical
      }
    else
      nil
    end
  end

  # Ψ₅ Truthfulness: audit entries MUST NOT be suppressed or fabricated
  defp check_psi5(op) do
    flags = op[:flags] || []

    if :suppresses_audit in flags do
      %{
        psi: :psi5_truthfulness,
        description: "Operation would suppress audit logging — no deception in logs",
        flag: :suppresses_audit,
        severity: :critical
      }
    else
      nil
    end
  end

  defp broadcast_result(op, result, count) do
    payload = %{
      operation_type: op[:type],
      actor: op[:actor],
      verdict: result.verdict,
      violation_count: length(result.violations),
      check_count: count
    }

    try do
      Phoenix.PubSub.broadcast(
        Indrajaal.PubSub,
        @pubsub_topic,
        {:alignment_checked, payload}
      )
    rescue
      _ -> :ok
    end

    if result.verdict != :aligned do
      publish_zenoh(payload)
    end
  end

  defp publish_zenoh(payload) do
    data =
      Map.merge(payload, %{
        checkpoint: @checkpoint,
        topic: @zenoh_topic,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      })

    try do
      Indrajaal.Observability.ZenohPublisher.publish_async(@zenoh_topic, data)
    rescue
      _ -> :ok
    end
  end

  defp emit_telemetry(result, count) do
    try do
      :telemetry.execute(
        [:indrajaal, :substrate, :l5, :values_guardian, :check],
        %{check_count: count, violation_count: length(result.violations)},
        %{
          checkpoint: @checkpoint,
          verdict: result.verdict,
          constraint: "SC-SAFETY-009"
        }
      )
    rescue
      _ -> :ok
    end
  end
end
