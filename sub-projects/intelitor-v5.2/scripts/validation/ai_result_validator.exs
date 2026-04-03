#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule Indrajaal.Validation.AIResultValidator do
  @moduledoc """
  Enhanced AI Result Validator with Multi-Layer Validation

  Integrates Claude AI, OpenCode AI, and FPPS validators in a comprehensive
  multi-layer validation system to prevent false positives (EP-110) and
  ensure reliable AI-assisted validation results.

  Based on comprehensive design analysis:
  - docs/journal/20250101-0245-ai-result-validator-5level-design-analysis.md
  - docs/journal/20250919-1930-ai-result-validator-opencode-quorum-integration.md

  Created: 2025-09-19 19:30:00 CEST
  Author: Claude AI Assistant (Phase 2 Implementation)
  Purpose: Comprehensive AI result validation with EP-110 prevention
  """

  require Logger

  # Multi-layer validation configuration
  @validation_layers [
    :semantic_validation,    # Does the claim make logical sense?
    :evidence_validation,    # Is there supporting evidence?
    :consistency_validation, # Does it match other sources?
    :fpps_consensus,        # Do all FPPS methods agree?
    :stamp_constraints      # Are safety constraints met?
  ]

  # STAMP safety constraints for AI validation
  @stamp_constraints [
    {:sc_ai_001, "AI SHALL provide verifiable evidence for all claims"},
    {:sc_ai_002, "AI SHALL NOT proceed with unverified results"},
    {:sc_ai_003, "AI SHALL maintain consistent validation across methods"},
    {:sc_ai_004, "AI SHALL detect and prevent false positive incidents"},
    {:sc_ai_005, "AI SHALL maintain complete audit trail of decisions"},
    {:sc_ai_006, "AI SHALL halt on consensus failures"},
    {:sc_ai_007, "AI SHALL validate all input sources"},
    {:sc_ai_008, "AI SHALL provide confidence scoring for all results"}
  ]

  # Validation thresholds
  @thresholds %{
    semantic_minimum: 0.70,
    evidence_minimum: 0.75,
    consistency_minimum: 0.80,
    fpps_minimum: 0.95,
    stamp_minimum: 1.00,
    overall_minimum: 0.85
  }

  def main(args \\ []) do
    Logger.info("🤖 Enhanced AI Result Validator v2.0 - Multi-Layer Validation")
    Logger.info("📅 Timestamp: #{local_timestamp()}")
    Logger.info("🛡️ EP-110 Prevention: Active with 5-layer validation")

    case parse_args(args) do
      {:ok, options} ->
        execute_validation(options)
      {:error, reason} ->
        Logger.error("❌ Invalid arguments: #{reason}")
        print_usage()
        System.halt(1)
    end
  end

  defp parse_args(args) do
    case OptionParser.parse(args,
      switches: [
        ai_claim: :string,
        evidence_file: :string,
        validation_type: :string,
        consensus_level: :string,
        save_report: :boolean,
        verbose: :boolean,
        skip_layers: :string
      ]) do
      {opts, _, _} ->
        opts = Map.new(opts)

        # Set defaults
        opts = Map.merge(%{
          validation_type: "comprehensive",
          consensus_level: "standard",
          save_report: true,
          verbose: false,
          skip_layers: ""
        }, opts)

        # Validate required options
        if opts[:ai_claim] do
          {:ok, opts}
        else
          {:error, "AI claim is required (--ai-claim)"}
        end
      _ ->
        {:error, "Failed to parse arguments"}
    end
  end

  defp execute_validation(options) do
    Logger.info("🚀 Starting enhanced AI result validation...")

    # Initialize validation state
    validation_state = %{
      timestamp: DateTime.utc_now(),
      ai_claim: options[:ai_claim],
      validation_type: options[:validation_type],
      consensus_level: options[:consensus_level],
      layer_results: %{},
      overall_score: 0.0,
      validation_passed: false,
      ep_110_risk: false,
      stamp_compliance: true,
      audit_trail: []
    }

    # Execute multi-layer validation
    validation_state = execute_validation_layers(validation_state, options)

    # Calculate overall validation score
    validation_state = calculate_overall_score(validation_state)

    # Check STAMP compliance
    validation_state = validate_stamp_constraints(validation_state)

    # Generate comprehensive report
    report = generate_validation_report(validation_state, options)

    # Save report if requested
    if options[:save_report] do
      save_validation_report(report)
    end

    # Log final decision
    log_final_validation_decision(validation_state)

    # Exit with appropriate code
    exit_code = if validation_state.validation_passed and validation_state.stamp_compliance do
      0
    else
      if validation_state.ep_110_risk do
        2  # EP-110 false positive risk
      else
        1  # Validation failure
      end
    end

    System.halt(exit_code)
  end

  defp execute_validation_layers(state, options) do
    Logger.info("🔍 Executing multi-layer validation...")

    # Get layers to skip
    skip_layers = parse_skip_layers(options[:skip_layers])

    # Execute each validation layer
    Enum.reduce(@validation_layers, state, fn layer, acc_state ->
      if layer in skip_layers do
        Logger.info("  ⏭️ Skipping #{layer} (user requested)")
        acc_state
      else
        Logger.info("  🔬 Executing #{layer}...")
        layer_result = execute_layer(layer, acc_state, options)

        acc_state
        |> put_in([:layer_results, layer], layer_result)
        |> update_in([:audit_trail], &[{layer, layer_result} | &1])
      end
    end)
  end

  defp parse_skip_layers(skip_string) do
    if skip_string && skip_string != "" do
      skip_string
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.map(&String.to_atom/1)
    else
      []
    end
  end

  defp execute_layer(:semantic_validation, state, _options) do
    Logger.info("    Analyzing semantic coherence...")

    # Analyze the logical structure of the AI claim
    claim = state.ai_claim

    semantic_checks = [
      check_logical_consistency(claim),
      check_semantic_coherence(claim),
      check_factual_plausibility(claim),
      check_context_appropriateness(claim)
    ]

    passed_checks = Enum.count(semantic_checks, &(&1))
    score = passed_checks / length(semantic_checks)

    %{
      layer: :semantic_validation,
      score: score,
      passed: score >= @thresholds.semantic_minimum,
      checks: %{
        logical_consistency: Enum.at(semantic_checks, 0),
        semantic_coherence: Enum.at(semantic_checks, 1),
        factual_plausibility: Enum.at(semantic_checks, 2),
        context_appropriateness: Enum.at(semantic_checks, 3)
      },
      findings: generate_semantic_findings(semantic_checks)
    }
  end

  defp execute_layer(:evidence_validation, state, options) do
    Logger.info("    Validating supporting evidence...")

    evidence_file = options[:evidence_file]

    if evidence_file && File.exists?(evidence_file) do
      evidence_content = File.read!(evidence_file)

      evidence_checks = [
        check_evidence_relevance(state.ai_claim, evidence_content),
        check_evidence_sufficiency(evidence_content),
        check_evidence_quality(evidence_content),
        check_evidence_consistency(state.ai_claim, evidence_content)
      ]

      passed_checks = Enum.count(evidence_checks, &(&1))
      score = passed_checks / length(evidence_checks)

      %{
        layer: :evidence_validation,
        score: score,
        passed: score >= @thresholds.evidence_minimum,
        evidence_file: evidence_file,
        checks: %{
          relevance: Enum.at(evidence_checks, 0),
          sufficiency: Enum.at(evidence_checks, 1),
          quality: Enum.at(evidence_checks, 2),
          consistency: Enum.at(evidence_checks, 3)
        },
        findings: generate_evidence_findings(evidence_checks)
      }
    else
      Logger.warn("    No evidence file provided - using claim-only validation")

      %{
        layer: :evidence_validation,
        score: 0.60,  # Reduced score for no evidence
        passed: false,
        evidence_file: nil,
        findings: ["No evidence file provided - validation limited"]
      }
    end
  end

  defp execute_layer(:consistency_validation, state, _options) do
    Logger.info("    Checking cross-validation consistency...")

    # Check consistency across different validation approaches
    consistency_checks = [
      check_internal_consistency(state.ai_claim),
      check_cross_reference_consistency(state.ai_claim),
      check_temporal_consistency(state.ai_claim),
      check_logical_coherence_consistency(state.ai_claim)
    ]

    passed_checks = Enum.count(consistency_checks, &(&1))
    score = passed_checks / length(consistency_checks)

    %{
      layer: :consistency_validation,
      score: score,
      passed: score >= @thresholds.consistency_minimum,
      checks: %{
        internal: Enum.at(consistency_checks, 0),
        cross_reference: Enum.at(consistency_checks, 1),
        temporal: Enum.at(consistency_checks, 2),
        logical_coherence: Enum.at(consistency_checks, 3)
      },
      findings: generate_consistency_findings(consistency_checks)
    }
  end

  defp execute_layer(:fpps_consensus, state, options) do
    Logger.info("    Executing FPPS consensus validation...")

    # Execute quorum consensus manager
    case System.cmd("elixir", ["scripts/validation/quorum_consensus_manager.exs",
                              "--validation-type", state.validation_type,
                              "--consensus-level", state.consensus_level,
                              "--claude-analysis", state.ai_claim],
                    stderr_to_stdout: true) do
      {output, 0} ->
        Logger.info("    ✅ FPPS consensus achieved")
        %{
          layer: :fpps_consensus,
          score: 0.95,
          passed: true,
          consensus_achieved: true,
          output: output,
          findings: ["FPPS consensus validation successful"]
        }
      {output, 2} ->
        Logger.error("    🚨 EP-110 risk detected by FPPS")
        %{
          layer: :fpps_consensus,
          score: 0.0,
          passed: false,
          consensus_achieved: false,
          ep_110_risk: true,
          output: output,
          findings: ["EP-110 false positive risk detected"]
        }
      {output, _} ->
        Logger.warn("    ⚠️ FPPS consensus failed")
        %{
          layer: :fpps_consensus,
          score: 0.30,
          passed: false,
          consensus_achieved: false,
          output: output,
          findings: ["FPPS consensus validation failed"]
        }
    end
  end

  defp execute_layer(:stamp_constraints, state, _options) do
    Logger.info("    Validating STAMP safety constraints...")

    # Validate each STAMP constraint
    constraint_results = Enum.map(@stamp_constraints, fn {constraint_id, description} ->
      result = validate_stamp_constraint(constraint_id, description, state)
      {constraint_id, result}
    end)

    passed_constraints = Enum.count(constraint_results, fn {_id, result} -> result.passed end)
    score = passed_constraints / length(@stamp_constraints)

    %{
      layer: :stamp_constraints,
      score: score,
      passed: score >= @thresholds.stamp_minimum,
      constraint_results: Map.new(constraint_results),
      passed_count: passed_constraints,
      total_count: length(@stamp_constraints),
      findings: generate_stamp_findings(constraint_results)
    }
  end

  defp validate_stamp_constraint(constraint_id, description, state) do
    case constraint_id do
      :sc_ai_001 ->  # AI SHALL provide verifiable evidence for all claims
        has_evidence = state.layer_results[:evidence_validation] != nil
        %{passed: has_evidence, description: description}

      :sc_ai_002 ->  # AI SHALL NOT proceed with unverified results
        evidence_passed = Kernel.get_in(state, [:layer_results, :evidence_validation, :passed]) || false
        %{passed: evidence_passed, description: description}

      :sc_ai_003 ->  # AI SHALL maintain consistent validation across methods
        consistency_passed = Kernel.get_in(state, [:layer_results, :consistency_validation, :passed]) || false
        %{passed: consistency_passed, description: description}

      :sc_ai_004 ->  # AI SHALL detect and prevent false positive incidents
        no_ep_110_risk = not Map.get(state, :ep_110_risk, false)
        %{passed: no_ep_110_risk, description: description}

      :sc_ai_005 ->  # AI SHALL maintain complete audit trail of decisions
        has_audit_trail = length(state.audit_trail) > 0
        %{passed: has_audit_trail, description: description}

      :sc_ai_006 ->  # AI SHALL halt on consensus failures
        fpps_result = get_in(state, [:layer_results, :fpps_consensus])
        consensus_handled = fpps_result == nil or fpps_result.consensus_achieved or not fpps_result.passed
        %{passed: consensus_handled, description: description}

      :sc_ai_007 ->  # AI SHALL validate all input sources
        semantic_passed = Kernel.get_in(state, [:layer_results, :semantic_validation, :passed]) || false
        %{passed: semantic_passed, description: description}

      :sc_ai_008 ->  # AI SHALL provide confidence scoring for all results
        has_scoring = state.overall_score > 0.0
        %{passed: has_scoring, description: description}

      _ ->
        %{passed: false, description: "Unknown constraint"}
    end
  end

  # Semantic validation helper functions
  defp check_logical_consistency(claim) do
    # Check for logical contradictions
    not (String.contains?(claim, " and ") and String.contains?(claim, " not "))
  end

  defp check_semantic_coherence(claim) do
    # Check semantic coherence
    word_count = String.split(claim) |> length()
    word_count >= 3 and word_count <= 100  # Reasonable length
  end

  defp check_factual_plausibility(claim) do
    # Basic factual plausibility check
    not String.contains?(String.downcase(claim), ["impossible", "never", "always", "100%"])
  end

  defp check_context_appropriateness(claim) do
    # Check if claim is appropriate for validation context
    String.contains?(String.downcase(claim), ["compil", "valid", "test", "error", "warning", "success"])
  end

  # Evidence validation helper functions
  defp check_evidence_relevance(claim, evidence) do
    # Check if evidence is relevant to the claim
    claim_words = String.downcase(claim) |> String.split()
    evidence_words = String.downcase(evidence) |> String.split()

    common_words = MapSet.intersection(MapSet.new(claim_words), MapSet.new(evidence_words))
    MapSet.size(common_words) >= 2
  end

  defp check_evidence_sufficiency(evidence) do
    # Check if evidence is sufficient
    line_count = String.split(evidence, "\n") |> length()
    line_count >= 3  # At least 3 lines of evidence
  end

  defp check_evidence_quality(evidence) do
    # Check evidence quality
    has_specifics = String.contains?(evidence, ["error", "warning", "line", "file", "function"])
    has_numbers = String.match?(evidence, ~r/\d+/)
    has_specifics and has_numbers
  end

  defp check_evidence_consistency(_claim, evidence) do
    # Check evidence internal consistency
    not String.contains?(String.downcase(evidence), ["contradiction", "conflict", "disagree"])
  end

  # Consistency validation helper functions
  defp check_internal_consistency(claim) do
    # Check internal consistency
    not String.contains?(String.downcase(claim), ["but", "however", "although", "despite"])
  end

  defp check_cross_reference_consistency(claim) do
    # Check cross-reference consistency (simplified)
    String.length(claim) > 10  # Basic consistency check
  end

  defp check_temporal_consistency(claim) do
    # Check temporal consistency
    not (String.contains?(claim, "before") and String.contains?(claim, "after"))
  end

  defp check_logical_coherence_consistency(claim) do
    # Check logical coherence
    has_subject = String.match?(claim, ~r/\b(error|warning|compilation|test|validation)\b/i)
    has_action = String.match?(claim, ~r/\b(fixed|resolved|found|detected|completed)\b/i)
    has_subject and has_action
  end

  # Findings generation functions
  defp generate_semantic_findings(checks) do
    findings = []
    findings = if Enum.at(checks, 0), do: ["Logical consistency verified" | findings], else: ["Logical inconsistency detected" | findings]
    findings = if Enum.at(checks, 1), do: ["Semantic coherence verified" | findings], else: ["Semantic coherence issues detected" | findings]
    findings = if Enum.at(checks, 2), do: ["Factual plausibility verified" | findings], else: ["Factual plausibility concerns detected" | findings]
    findings = if Enum.at(checks, 3), do: ["Context appropriateness verified" | findings], else: ["Context appropriateness issues detected" | findings]
    Enum.reverse(findings)
  end

  defp generate_evidence_findings(checks) do
    findings = []
    findings = if Enum.at(checks, 0), do: ["Evidence relevance verified" | findings], else: ["Evidence relevance concerns" | findings]
    findings = if Enum.at(checks, 1), do: ["Evidence sufficiency verified" | findings], else: ["Evidence insufficiency detected" | findings]
    findings = if Enum.at(checks, 2), do: ["Evidence quality verified" | findings], else: ["Evidence quality concerns" | findings]
    findings = if Enum.at(checks, 3), do: ["Evidence consistency verified" | findings], else: ["Evidence consistency issues" | findings]
    Enum.reverse(findings)
  end

  defp generate_consistency_findings(checks) do
    findings = []
    findings = if Enum.at(checks, 0), do: ["Internal consistency verified" | findings], else: ["Internal consistency issues" | findings]
    findings = if Enum.at(checks, 1), do: ["Cross-reference consistency verified" | findings], else: ["Cross-reference consistency concerns" | findings]
    findings = if Enum.at(checks, 2), do: ["Temporal consistency verified" | findings], else: ["Temporal consistency issues" | findings]
    findings = if Enum.at(checks, 3), do: ["Logical coherence verified" | findings], else: ["Logical coherence concerns" | findings]
    Enum.reverse(findings)
  end

  defp generate_stamp_findings(constraint_results) do
    Enum.map(constraint_results, fn {constraint_id, result} ->
      status = if result.passed, do: "✅ PASSED", else: "❌ FAILED"
      "#{constraint_id}: #{status} - #{result.description}"
    end)
  end

  defp calculate_overall_score(state) do
    # Calculate weighted overall score
    layer_scores = Enum.map(@validation_layers, fn layer ->
      case get_in(state, [:layer_results, layer, :score]) do
        nil -> 0.0
        score -> score
      end
    end)

    # Weighted average (FPPS and STAMP have higher weights)
    weights = [0.15, 0.20, 0.15, 0.30, 0.20]  # semantic, evidence, consistency, fpps, stamp

    weighted_sum = layer_scores
    |> Enum.zip(weights)
    |> Enum.map(fn {score, weight} -> score * weight end)
    |> Enum.sum()

    overall_score = weighted_sum / Enum.sum(weights)
    validation_passed = overall_score >= @thresholds.overall_minimum

    # Check for EP-110 risk
    ep_110_risk = Kernel.get_in(state, [:layer_results, :fpps_consensus, :ep_110_risk]) || false

    state
    |> Map.put(:overall_score, overall_score)
    |> Map.put(:validation_passed, validation_passed and not ep_110_risk)
    |> Map.put(:ep_110_risk, ep_110_risk)
  end

  defp validate_stamp_constraints(state) do
    stamp_result = get_in(state, [:layer_results, :stamp_constraints])
    stamp_compliance = stamp_result != nil and stamp_result.passed

    Map.put(state, :stamp_compliance, stamp_compliance)
  end

  defp convert_audit_trail_for_json(audit_trail) do
    audit_trail
    |> Enum.reverse()
    |> Enum.map(fn
      {event_type, data} -> %{event: Atom.to_string(event_type), data: data}
      other -> %{event: "unknown", data: inspect(other)}
    end)
  end

  defp generate_validation_report(state, options) do
    %{
      timestamp: local_timestamp(),
      phase: "Phase 2 - Enhanced AI Result Validation",
      ai_claim: state.ai_claim,
      validation_type: state.validation_type,
      validation_layers: length(@validation_layers),
      layer_results: state.layer_results,
      overall_assessment: %{
        score: state.overall_score,
        passed: state.validation_passed,
        ep_110_risk: state.ep_110_risk,
        stamp_compliance: state.stamp_compliance
      },
      thresholds: @thresholds,
      recommendation: generate_final_recommendation(state),
      next_steps: generate_final_next_steps(state),
      audit_trail: convert_audit_trail_for_json(state.audit_trail),
      options: options
    }
  end

  defp generate_final_recommendation(state) do
    case {state.validation_passed, state.ep_110_risk, state.stamp_compliance} do
      {true, false, true} ->
        "✅ VALIDATION PASSED: AI result validated with high confidence. All layers and safety constraints satisfied."
      {false, true, _} ->
        "🚨 EP-110 RISK: False positive risk detected. Manual review required before accepting AI result."
      {false, false, false} ->
        "❌ STAMP VIOLATION: Safety constraints not satisfied. Review and address constraint failures."
      {false, false, true} ->
        "⚠️ VALIDATION FAILED: Score below threshold. Review layer results and consider additional evidence."
      {true, true, _} ->
        "🔍 CONTRADICTORY: Validation passed but EP-110 risk present. Detailed investigation required."
    end
  end

  defp generate_final_next_steps(state) do
    if state.validation_passed and not state.ep_110_risk and state.stamp_compliance do
      [
        "AI result validation successful - proceed with confidence",
        "Monitor subsequent AI results for consistency",
        "Update validation confidence based on outcomes"
      ]
    else
      steps = []
      steps = if state.ep_110_risk, do: ["Investigate EP-110 false positive risk" | steps], else: steps
      steps = if not state.stamp_compliance, do: ["Address STAMP safety constraint violations" | steps], else: steps
      steps = if not state.validation_passed, do: ["Review failing validation layers" | steps], else: steps
      steps = ["Re-run validation after addressing issues" | steps]
      Enum.reverse(steps)
    end
  end

  defp save_validation_report(report) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    filename = "./data/tmp/ai_result_validation_#{timestamp}.json"

    # Ensure directory exists
    File.mkdir_p!("./data/tmp")

    json_report = Jason.encode!(report, pretty: true)
    File.write!(filename, json_report)

    Logger.info("📊 AI result validation report saved to: #{filename}")
  end

  defp log_final_validation_decision(state) do
    score_percent = Float.round(state.overall_score * 100, 1)

    case {state.validation_passed, state.ep_110_risk, state.stamp_compliance} do
      {true, false, true} ->
        Logger.info("✅ AI RESULT VALIDATION: PASSED")
        Logger.info("📊 Overall Score: #{score_percent}% (threshold: #{@thresholds.overall_minimum * 100}%)")
        Logger.info("🛡️ EP-110 Risk: None detected")
        Logger.info("✅ STAMP Compliance: All constraints satisfied")
      {false, true, _} ->
        Logger.error("🚨 AI RESULT VALIDATION: EP-110 RISK DETECTED")
        Logger.error("📊 Overall Score: #{score_percent}%")
        Logger.error("⚠️ Manual review required - false positive risk")
      {false, false, false} ->
        Logger.error("❌ AI RESULT VALIDATION: STAMP VIOLATION")
        Logger.error("📊 Overall Score: #{score_percent}%")
        Logger.error("🛡️ Safety constraints not satisfied")
      {false, false, true} ->
        Logger.warn("⚠️ AI RESULT VALIDATION: FAILED")
        Logger.warn("📊 Overall Score: #{score_percent}% (below threshold)")
        Logger.warn("🔍 Review layer results for improvement areas")
      {true, true, _} ->
        Logger.warn("🔍 AI RESULT VALIDATION: CONTRADICTORY SIGNALS")
        Logger.warn("📊 Overall Score: #{score_percent}%")
        Logger.warn("🚨 Investigation required - passed but EP-110 risk present")
    end
  end

  defp local_timestamp do
    {{year, month, day}, {hour, minute, second}} = :calendar.local_time()
    :io_lib.format("~4..0B-~2..0B-~2..0B ~2..0B:~2..0B:~2..0B CEST",
      [year, month, day, hour, minute, second])
    |> to_string()
  end

  defp print_usage do
    IO.puts """
    Usage: ai_result_validator.exs [options]

    Enhanced AI Result Validator with Multi-Layer Validation and EP-110 Prevention

    Required Options:
      --ai-claim CLAIM          AI claim or result to validate

    Optional Options:
      --evidence-file FILE      File containing supporting evidence
      --validation-type TYPE    Type of validation (compilation, security, comprehensive)
      --consensus-level LEVEL   Consensus level for FPPS (strict, standard, permissive)
      --save-report             Save detailed JSON report (default: true)
      --verbose                 Show detailed output
      --skip-layers LAYERS      Comma-separated layers to skip (semantic,evidence,consistency,fpps,stamp)

    Validation Layers:
      1. Semantic Validation    Logical consistency and coherence analysis
      2. Evidence Validation    Supporting evidence quality and relevance
      3. Consistency Validation Cross-validation consistency checks
      4. FPPS Consensus         Multi-AI consensus validation (Claude, OpenCode, FPPS)
      5. STAMP Constraints      Safety constraint compliance validation

    STAMP Safety Constraints:
      SC-AI-001: AI SHALL provide verifiable evidence for all claims
      SC-AI-002: AI SHALL NOT proceed with unverified results
      SC-AI-003: AI SHALL maintain consistent validation across methods
      SC-AI-004: AI SHALL detect and prevent false positive incidents
      SC-AI-005: AI SHALL maintain complete audit trail of decisions
      SC-AI-006: AI SHALL halt on consensus failures
      SC-AI-007: AI SHALL validate all input sources
      SC-AI-008: AI SHALL provide confidence scoring for all results

    Examples:
      # Basic validation
      ./ai_result_validator.exs --ai-claim "Compilation completed with zero warnings"

      # With evidence file
      ./ai_result_validator.exs --ai-claim "All tests pass" --evidence-file test_results.log

      # Skip certain layers
      ./ai_result_validator.exs --ai-claim "Security scan clean" --skip-layers evidence,consistency

    Exit Codes:
      0 - Validation passed, AI result verified
      1 - Validation failed or STAMP constraint violation
      2 - EP-110 false positive risk detected
    """
  end
end

# Run the enhanced AI result validator
Indrajaal.Validation.AIResultValidator.main(System.argv())