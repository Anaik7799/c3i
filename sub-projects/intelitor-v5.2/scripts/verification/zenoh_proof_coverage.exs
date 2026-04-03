#!/usr/bin/env elixir

# =============================================================================
# ZENOH FORMAL PROOF COVERAGE VERIFIER
# Purpose: Verify STAMP constraints are mapped to Agda theorems
# Version: 1.0.0
# Date: 2026-01-14
# =============================================================================

defmodule ZenohProofCoverage do
  @moduledoc """
  Verifies that all STAMP constraints for Zenoh integration have corresponding
  formal proofs in the Agda specification.

  ## Usage

      elixir scripts/verification/zenoh_proof_coverage.exs
      elixir scripts/verification/zenoh_proof_coverage.exs --verbose
      elixir scripts/verification/zenoh_proof_coverage.exs --json

  ## Exit Codes

  - 0: All constraints mapped, all critical proofs complete
  - 1: Missing constraint mappings
  - 2: Critical proofs have holes ({!!})
  - 3: Agda file not found or parse error
  """

  @agda_file "docs/formal_specs/zenoh/ZenohProofs.agda"

  # STAMP Constraint → Agda Theorem Mapping
  @constraint_mappings %{
    # L1 FFI Safety
    "SC-ZENOH-FFI-001" => "disposed-implies-zero-use",
    "SC-ZENOH-FFI-002" => "dispose-idempotent",
    "SC-ZENOH-FFI-003" => "double-free-prevented",

    # L6 Quorum
    "SC-OP-005:quorum-bounded" => "quorum-bounded",
    "SC-OP-005:quorum-positive" => "quorum-at-least-one",
    "SC-OP-005:quorum-3" => "quorum-3-is-2",
    "SC-OP-005:quorum-5" => "quorum-5-is-3",

    # L6 2oo3 Voting
    "SC-QUORUM-001:deterministic" => "vote2oo3-deterministic",
    "SC-QUORUM-001:symmetric" => "vote2oo3-symmetric-12",
    "SC-QUORUM-001:safety-true" => "vote2oo3-single-failure-safety-true",
    "SC-QUORUM-001:safety-false" => "vote2oo3-single-failure-safety-false",

    # L7 Federation
    "SC-FED-001:total-order" => "version-total",
    "SC-FED-001:reflexive" => "compatible-reflexive",
    "SC-FED-001:terminates" => "negotiation-terminates",

    # Constitutional
    "PSI-0:existence" => "system-exists-implies-valid",
    "PSI-2:continuity-grow" => "history-grows",
    "PSI-2:continuity-preserve" => "history-preserved",
    "PSI-3:verifiable" => "verifiable-system-verified"
  }

  # Critical theorems that MUST NOT have holes
  @critical_theorems [
    "disposed-implies-zero-use",
    "dispose-idempotent",
    "double-free-prevented",
    "quorum-bounded",
    "vote2oo3-deterministic",
    "vote2oo3-single-failure-safety-true"
  ]

  def main(args) do
    opts = parse_args(args)

    IO.puts("\n╔═══════════════════════════════════════════════════════════════════╗")
    IO.puts("║         ZENOH FORMAL PROOF COVERAGE VERIFICATION                  ║")
    IO.puts("╚═══════════════════════════════════════════════════════════════════╝\n")

    with {:ok, agda_content} <- read_agda_file(),
         {:ok, theorems} <- extract_theorems(agda_content),
         {:ok, holes} <- extract_holes(agda_content) do
      # Verification checks
      coverage_result = verify_coverage(theorems, opts)
      critical_result = verify_critical_theorems(theorems, holes, opts)
      completeness_result = calculate_completeness(theorems, holes, opts)

      # Generate report
      if opts[:json] do
        print_json_report(coverage_result, critical_result, completeness_result)
      else
        print_text_report(coverage_result, critical_result, completeness_result)
      end

      # Determine exit code
      exit_code = determine_exit_code(coverage_result, critical_result, completeness_result)
      System.halt(exit_code)
    else
      {:error, reason} ->
        IO.puts("❌ ERROR: #{reason}")
        System.halt(3)
    end
  end

  defp parse_args(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [verbose: :boolean, json: :boolean],
        aliases: [v: :verbose, j: :json]
      )

    opts
  end

  defp read_agda_file do
    case File.read(@agda_file) do
      {:ok, content} -> {:ok, content}
      {:error, _} -> {:error, "Could not read Agda file: #{@agda_file}"}
    end
  end

  defp extract_theorems(content) do
    # Match theorem definitions: "theorem-name : ..."
    theorem_regex = ~r/^([a-z][a-zA-Z0-9-]*)\s*:/m

    theorems =
      Regex.scan(theorem_regex, content)
      |> Enum.map(fn [_, name] -> name end)
      |> Enum.uniq()

    {:ok, theorems}
  end

  defp extract_holes(content) do
    # Count holes: {!!}
    hole_contexts =
      Regex.scan(~r/(\w+)[^{]*\{!!\}/m, content)
      |> Enum.map(fn [_, theorem_name] -> theorem_name end)

    {:ok, hole_contexts}
  end

  defp verify_coverage(theorems, opts) do
    results =
      Enum.map(@constraint_mappings, fn {constraint, theorem} ->
        exists = theorem in theorems
        {constraint, theorem, exists}
      end)

    mapped = Enum.count(results, fn {_, _, exists} -> exists end)
    total = length(results)

    if opts[:verbose] do
      IO.puts("📋 STAMP Constraint Coverage:\n")

      Enum.each(results, fn {constraint, theorem, exists} ->
        status = if exists, do: "✓", else: "✗"
        IO.puts("  #{status} #{constraint} → #{theorem}")
      end)

      IO.puts("")
    end

    %{
      mapped: mapped,
      total: total,
      percentage: Float.round(mapped / total * 100, 1),
      unmapped: Enum.filter(results, fn {_, _, exists} -> !exists end)
    }
  end

  defp verify_critical_theorems(theorems, holes, opts) do
    results =
      Enum.map(@critical_theorems, fn theorem ->
        exists = theorem in theorems
        has_hole = theorem in holes
        complete = exists && !has_hole
        {theorem, exists, has_hole, complete}
      end)

    complete = Enum.count(results, fn {_, _, _, complete} -> complete end)
    total = length(results)

    if opts[:verbose] do
      IO.puts("🔒 Critical Theorem Completeness:\n")

      Enum.each(results, fn {theorem, exists, has_hole, complete} ->
        status =
          cond do
            complete -> "✓"
            has_hole -> "⚠"
            !exists -> "✗"
          end

        note = if has_hole, do: " (has hole)", else: ""
        IO.puts("  #{status} #{theorem}#{note}")
      end)

      IO.puts("")
    end

    %{
      complete: complete,
      total: total,
      percentage: Float.round(complete / total * 100, 1),
      incomplete: Enum.filter(results, fn {_, _, _, complete} -> !complete end)
    }
  end

  defp calculate_completeness(theorems, holes, opts) do
    total_theorems = length(theorems)
    theorems_with_holes = length(holes)
    complete_theorems = total_theorems - theorems_with_holes

    if opts[:verbose] do
      IO.puts("📊 Overall Proof Completeness:\n")
      IO.puts("  Total theorems: #{total_theorems}")
      IO.puts("  Complete theorems: #{complete_theorems}")
      IO.puts("  Theorems with holes: #{theorems_with_holes}")
      IO.puts("")
    end

    %{
      total: total_theorems,
      complete: complete_theorems,
      holes: theorems_with_holes,
      percentage: Float.round(complete_theorems / total_theorems * 100, 1)
    }
  end

  defp print_text_report(coverage, critical, completeness) do
    IO.puts("╔═══════════════════════════════════════════════════════════════════╗")
    IO.puts("║                         VERIFICATION REPORT                       ║")
    IO.puts("╠═══════════════════════════════════════════════════════════════════╣")
    IO.puts("║")
    IO.puts("║  STAMP Constraint Coverage")
    IO.puts("║  ├─ Mapped: #{coverage.mapped}/#{coverage.total} (#{coverage.percentage}%)")

    if coverage.mapped == coverage.total do
      IO.puts("║  └─ Status: ✓ All constraints mapped")
    else
      IO.puts("║  └─ Status: ✗ #{length(coverage.unmapped)} constraints missing")

      Enum.each(coverage.unmapped, fn {constraint, _, _} ->
        IO.puts("║      - #{constraint}")
      end)
    end

    IO.puts("║")
    IO.puts("║  Critical Theorem Completeness")
    IO.puts("║  ├─ Complete: #{critical.complete}/#{critical.total} (#{critical.percentage}%)")

    if critical.complete == critical.total do
      IO.puts("║  └─ Status: ✓ All critical proofs complete")
    else
      IO.puts("║  └─ Status: ⚠ #{length(critical.incomplete)} critical proofs incomplete")

      Enum.each(critical.incomplete, fn {theorem, _, has_hole, _} ->
        reason = if has_hole, do: "has hole", else: "missing"
        IO.puts("║      - #{theorem} (#{reason})")
      end)
    end

    IO.puts("║")
    IO.puts("║  Overall Completeness")

    IO.puts(
      "║  ├─ Complete: #{completeness.complete}/#{completeness.total} (#{completeness.percentage}%)"
    )

    IO.puts("║  ├─ Holes: #{completeness.holes}")

    cond do
      completeness.percentage == 100 ->
        IO.puts("║  └─ Status: ✓ All proofs complete")

      completeness.percentage >= 85 ->
        IO.puts("║  └─ Status: ⚠ Acceptable (≥85%)")

      true ->
        IO.puts("║  └─ Status: ✗ Below threshold (<85%)")
    end

    IO.puts("║")
    IO.puts("╚═══════════════════════════════════════════════════════════════════╝\n")
  end

  defp print_json_report(coverage, critical, completeness) do
    report = %{
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      agda_file: @agda_file,
      coverage: coverage,
      critical: critical,
      completeness: completeness,
      verdict: determine_verdict(coverage, critical, completeness)
    }

    # Use simple text format since Jason may not be available
    IO.puts(inspect(report, pretty: true))
  end

  defp determine_exit_code(coverage, critical, completeness) do
    cond do
      coverage.mapped < coverage.total ->
        # Missing constraint mappings
        1

      critical.complete < critical.total ->
        # Critical proofs incomplete
        2

      completeness.percentage < 85 ->
        # Below completeness threshold
        2

      true ->
        # All good
        0
    end
  end

  defp determine_verdict(coverage, critical, completeness) do
    cond do
      coverage.mapped < coverage.total ->
        "FAIL: Missing constraint mappings"

      critical.complete < critical.total ->
        "WARN: Critical proofs incomplete"

      completeness.percentage < 85 ->
        "WARN: Completeness below threshold"

      completeness.percentage == 100 ->
        "PASS: Perfect - all proofs complete"

      true ->
        "PASS: Acceptable - all critical proofs complete"
    end
  end
end

# Run if invoked directly
if System.get_env("MIX_ENV") != "test" do
  ZenohProofCoverage.main(System.argv())
end
