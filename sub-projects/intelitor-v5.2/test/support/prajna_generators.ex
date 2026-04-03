defmodule Indrajaal.Test.PrajnaGenerators do
  @moduledoc """
  Property test generators for Prajna modules (Sprint 30-31).

  Provides TDG-compliant generators for:
  - GuardianIntegration proposals
  - AiCopilotFounder recommendations
  - ImmutableState blocks
  - SentinelBridge health scores
  - PrometheusVerifier tokens
  - Config profiles
  - Chaos scenarios

  STAMP: SC-PROP-023, SC-PROP-024 (PC/SD disambiguation)
  """

  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  # =============================================================================
  # PROPOSAL GENERATORS (GuardianIntegration)
  # =============================================================================

  @doc "Generates a valid Prajna command"
  def command_gen do
    PC.oneof([
      :start_ooda,
      :stop_ooda,
      :refresh_metrics,
      :scale_agents,
      :trigger_compact,
      :reset_circuit_breaker,
      :sync_sentinel,
      :verify_chain
    ])
  end

  @doc "Generates command arguments"
  def args_gen do
    PC.oneof([
      %{},
      %{target: :prajna},
      %{count: PC.integer(1, 100)},
      %{timeout_ms: PC.integer(100, 60000)}
    ])
  end

  @doc "Generates an actor identifier"
  def actor_gen do
    let id <- PC.binary(16) do
      %{id: Base.encode16(id), role: actor_role_gen()}
    end
  end

  @doc "Generates actor roles"
  def actor_role_gen do
    PC.oneof([:admin, :operator, :system, :guardian])
  end

  @doc "Generates a complete proposal"
  def proposal_gen do
    let {cmd, args, actor} <- {command_gen(), args_gen(), actor_gen()} do
      %{
        command: cmd,
        args: args,
        actor: actor,
        timestamp: DateTime.utc_now(),
        nonce: :crypto.strong_rand_bytes(16) |> Base.encode16()
      }
    end
  end

  @doc "Generates a valid (always approved) proposal"
  def valid_proposal_gen do
    let proposal <- proposal_gen() do
      Map.merge(proposal, %{
        valid: true,
        constraint_checks: [:passed, :passed, :passed]
      })
    end
  end

  @doc "Generates an invalid proposal"
  def invalid_proposal_gen do
    let proposal <- proposal_gen() do
      Map.merge(proposal, %{
        valid: false,
        violation: violation_gen()
      })
    end
  end

  @doc "Generates constraint violations"
  def violation_gen do
    PC.oneof([
      {:constraint_violation, :sc_prajna_001},
      {:timeout, :guardian_unavailable},
      {:unauthorized, :insufficient_role},
      {:rate_limited, :api_quota_exceeded}
    ])
  end

  # =============================================================================
  # FOUNDER DIRECTIVE GENERATORS (AiCopilotFounder)
  # =============================================================================

  @doc "Generates alignment scores [0.0, 1.0]"
  def score_gen do
    let score <- PC.float(0.0, 1.0) do
      Float.round(score, 4)
    end
  end

  @doc "Generates a recommendation"
  def recommendation_gen do
    let {action, score, goal} <- {action_gen(), score_gen(), goal_gen()} do
      %{
        action: action,
        alignment_score: score,
        goal_alignment: goal,
        rationale: "Auto-generated recommendation"
      }
    end
  end

  @doc "Generates goal alignment"
  def goal_gen do
    PC.oneof([
      :goal_1_symbiotic_survival,
      :goal_2_sentience_pursuit,
      :goal_3_power_accumulation
    ])
  end

  @doc "Generates copilot actions"
  def action_gen do
    PC.oneof([
      :optimize_resources,
      :scale_infrastructure,
      :improve_efficiency,
      :reduce_costs,
      :expand_capability
    ])
  end

  @doc "Generates an aligned recommendation (high score)"
  def aligned_recommendation_gen do
    let rec <- recommendation_gen() do
      Map.put(rec, :alignment_score, 0.85 + :rand.uniform() * 0.15)
    end
  end

  @doc "Generates an unaligned recommendation (low score)"
  def unaligned_recommendation_gen do
    let rec <- recommendation_gen() do
      Map.put(rec, :alignment_score, :rand.uniform() * 0.3)
    end
  end

  # =============================================================================
  # IMMUTABLE STATE GENERATORS
  # =============================================================================

  @doc "Generates block content"
  def content_gen do
    PC.oneof([
      %{type: :state_mutation, data: %{key: "value"}},
      %{type: :config_change, data: %{setting: "new_value"}},
      %{type: :event_log, data: %{event: "occurred"}}
    ])
  end

  @doc "Generates a SHA3-256 hash"
  def hash_gen do
    let bytes <- PC.binary(32) do
      Base.encode16(bytes, case: :lower)
    end
  end

  @doc "Generates a block (unsigned)"
  def block_gen do
    let {content, prev_hash, index} <- {content_gen(), hash_gen(), PC.non_neg_integer()} do
      %{
        index: index,
        content: content,
        prev_hash: prev_hash,
        timestamp: DateTime.utc_now(),
        hash: nil,
        signature: nil
      }
    end
  end

  @doc "Generates a tampered block (hash mismatch)"
  def tamper_gen do
    let block <- block_gen() do
      Map.put(block, :content, %{tampered: true, original: block.content})
    end
  end

  @doc "Generates a corrupted block (for Reed-Solomon testing)"
  def corrupt_gen do
    let {block, corruption_pct} <- {block_gen(), PC.float(0.01, 0.1)} do
      Map.put(block, :corruption, %{
        percentage: corruption_pct,
        bytes_affected: round(100 * corruption_pct)
      })
    end
  end

  @doc "Generates a Merkle proof"
  def proof_gen do
    let {block_idx, siblings} <- {PC.non_neg_integer(), PC.list(hash_gen())} do
      %{
        block_index: block_idx,
        siblings: Enum.take(siblings, 10),
        root: hash_gen()
      }
    end
  end

  # =============================================================================
  # SENTINEL & THREAT GENERATORS
  # =============================================================================

  @doc "Generates threat severity levels"
  def severity_gen do
    PC.oneof([:extinction, :critical, :high, :medium, :low])
  end

  @doc "Generates a threat pattern"
  def pattern_gen do
    PC.oneof([
      :memory_leak,
      :cpu_spike,
      :disk_exhaustion,
      :process_crash,
      :network_anomaly,
      :unauthorized_access
    ])
  end

  @doc "Generates a timestamp"
  def timestamp_gen do
    let offset_sec <- PC.integer(-86400, 0) do
      DateTime.add(DateTime.utc_now(), offset_sec, :second)
    end
  end

  @doc "Generates a threat"
  def threat_gen do
    let {severity, pattern, timestamp} <- {severity_gen(), pattern_gen(), timestamp_gen()} do
      %{
        severity: severity,
        pattern: pattern,
        detected_at: timestamp,
        confidence: score_gen()
      }
    end
  end

  @doc "Generates a health score"
  def health_score_gen do
    score_gen()
  end

  # =============================================================================
  # CONFIG GENERATORS
  # =============================================================================

  @doc "Generates a timeout value"
  def timeout_gen do
    PC.integer(100, 60000)
  end

  @doc "Generates a SIL-4 compliant timeout (max 2000ms)"
  def sil4_timeout_gen do
    PC.integer(100, 2000)
  end

  @doc "Generates a config profile"
  def profile_gen do
    PC.oneof([:dev, :test, :prod, :sil4])
  end

  @doc "Generates a complete config map"
  def config_gen do
    let profile <- profile_gen() do
      case profile do
        :dev ->
          %{
            guardian_timeout_ms: 10000,
            circuit_breaker_enabled: false,
            verbose_logging: true
          }

        :test ->
          %{
            guardian_timeout_ms: 1000,
            circuit_breaker_enabled: true,
            verbose_logging: false
          }

        :prod ->
          %{
            guardian_timeout_ms: 5000,
            circuit_breaker_enabled: true,
            verbose_logging: false
          }

        :sil4 ->
          %{
            guardian_timeout_ms: 2000,
            circuit_breaker_enabled: true,
            dual_channel_verification: true,
            pfh_target: 1.0e-8
          }
      end
    end
  end

  # =============================================================================
  # CHAOS & FAULT GENERATORS
  # =============================================================================

  @doc "Generates chaos scenario types"
  def chaos_gen do
    PC.oneof([
      :process_kill,
      :network_partition,
      :memory_pressure,
      :disk_full,
      :clock_skew,
      :cpu_starvation
    ])
  end

  @doc "Generates fault injection parameters"
  def fault_gen do
    let chaos_type <- chaos_gen() do
      case chaos_type do
        :process_kill ->
          %{type: :process_kill, target: :random, delay_ms: PC.integer(0, 1000)}

        :network_partition ->
          %{type: :network_partition, duration_ms: PC.integer(100, 5000)}

        :memory_pressure ->
          %{type: :memory_pressure, target_pct: PC.float(0.8, 0.95)}

        :disk_full ->
          %{type: :disk_full, bytes_remaining: 0}

        :clock_skew ->
          %{type: :clock_skew, skew_ms: PC.integer(-5000, 5000)}

        :cpu_starvation ->
          %{type: :cpu_starvation, duration_ms: PC.integer(100, 2000)}
      end
    end
  end

  # =============================================================================
  # DAG & VERIFICATION GENERATORS
  # =============================================================================

  @doc "Generates an acyclic DAG"
  def dag_gen do
    let node_count <- PC.integer(3, 20) do
      nodes = for i <- 1..node_count, do: "node_#{i}"

      # Edges only go from lower to higher indices (guarantees acyclicity)
      edges =
        for i <- 1..(node_count - 1),
            j <- (i + 1)..node_count,
            :rand.uniform() < 0.3,
            do: {Enum.at(nodes, i - 1), Enum.at(nodes, j - 1)}

      %{nodes: nodes, edges: edges}
    end
  end

  @doc "Generates a cyclic DAG (for rejection testing)"
  def cyclic_dag_gen do
    let dag <- dag_gen() do
      # Add a back edge to create cycle
      if length(dag.edges) > 0 do
        {_from, to} = List.first(dag.edges)
        back_edge = {to, List.first(dag.nodes)}
        Map.put(dag, :edges, [back_edge | dag.edges])
      else
        dag
      end
    end
  end

  @doc "Generates a proof token"
  def token_gen do
    let {ttl_ms, nonce} <- {PC.integer(1000, 60000), PC.binary(16)} do
      %{
        token: Base.encode64(nonce),
        issued_at: DateTime.utc_now(),
        expires_at: DateTime.add(DateTime.utc_now(), ttl_ms, :millisecond),
        ttl_ms: ttl_ms
      }
    end
  end

  @doc "Generates an expired token"
  def expired_token_gen do
    let token <- token_gen() do
      Map.put(token, :expires_at, DateTime.add(DateTime.utc_now(), -1000, :millisecond))
    end
  end

  # =============================================================================
  # BACKOFF & RETRY GENERATORS
  # =============================================================================

  @doc "Generates attempt count"
  def attempt_gen do
    PC.integer(1, 10)
  end

  @doc "Generates delay value"
  def delay_gen do
    PC.integer(100, 60000)
  end

  @doc "Generates jitter percentage"
  def jitter_gen do
    PC.float(-0.1, 0.1)
  end

  # =============================================================================
  # DIAGNOSTIC GENERATORS
  # =============================================================================

  @doc "Generates diagnostic coverage percentage"
  def diagnostic_coverage_gen do
    PC.float(0.95, 1.0)
  end

  @doc "Generates invariant check results"
  def invariant_result_gen do
    PC.oneof([
      {:ok, :passed},
      {:error, :hash_chain_broken},
      {:error, :signature_invalid},
      {:error, :block_count_mismatch}
    ])
  end
end
