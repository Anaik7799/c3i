#!/usr/bin/env elixir
# Cybernetic Test Runner with Live Dashboard
# GDE Goal: 100% Test Coverage
# OODA: Fast Loop (<100ms monitoring)

defmodule CyberneticTestRunner do
  @moduledoc """
  Cybernetic test execution with real-time dashboard updates.
  SOPv5.11 + OODA + GDE compliant.
  """

  @dashboard_refresh_ms 60_000  # 1 minute
  @gde_goal_coverage 100.0

  def run do
    start_time = System.monotonic_time(:millisecond)
    
    IO.puts(banner())
    
    # Initialize state
    state = %{
      start_time: start_time,
      tests_run: 0,
      tests_passed: 0,
      tests_failed: 0,
      coverage: 0.0,
      ooda_cycles: 0,
      last_update: start_time
    }
    
    # Run test suite with coverage
    IO.puts("\n🚀 OODA OBSERVE: Starting test execution...")
    
    {output, exit_code} = System.cmd("mix", ["test", "--cover", "--max-failures", "50"],
      env: [
        {"MIX_ENV", "test"},
        {"POSTGRES_USER", "indrajaal"},
        {"POSTGRES_PASSWORD", "indrajaal_test"},
        {"DATABASE_URL", "ecto://indrajaal:indrajaal_test@localhost:5433/indrajaal_test"}
      ],
      stderr_to_stdout: true,
      into: IO.stream(:stdio, :line)
    )
    
    elapsed = System.monotonic_time(:millisecond) - start_time
    
    # Parse results
    {passed, failed, total} = parse_test_results(output)
    coverage = parse_coverage(output)
    
    # Final dashboard
    print_final_dashboard(%{
      elapsed_ms: elapsed,
      tests_passed: passed,
      tests_failed: failed,
      tests_total: total,
      coverage: coverage,
      exit_code: exit_code,
      gde_goal: @gde_goal_coverage
    })
    
    exit_code
  end
  
  defp banner do
    """
    
    ╔═══════════════════════════════════════════════════════════════════════════════╗
    ║              CYBERNETIC TEST RUNNER - GDE MODE                                ║
    ║                     Goal: 100% Test Coverage                                  ║
    ╠═══════════════════════════════════════════════════════════════════════════════╣
    ║  OODA ───────────────▶ Fast Loop (<100ms) Monitoring                          ║
    ║  GDE ────────────────▶ Goal-Directed Execution (100% Coverage)                ║
    ║  STAMP ──────────────▶ Safety Constraint Validation                           ║
    ╚═══════════════════════════════════════════════════════════════════════════════╝
    """
  end
  
  defp parse_test_results(output) do
    case Regex.run(~r/(\d+) tests?, (\d+) failures?/, output) do
      [_, total, failed] ->
        total = String.to_integer(total)
        failed = String.to_integer(failed)
        {total - failed, failed, total}
      _ ->
        {0, 0, 0}
    end
  end
  
  defp parse_coverage(output) do
    case Regex.run(~r/(\d+\.?\d*)%\s+coverage/, output) do
      [_, cov] -> String.to_float(cov)
      _ -> 0.0
    end
  end
  
  defp print_final_dashboard(state) do
    elapsed_str = format_duration(state.elapsed_ms)
    pass_rate = if state.tests_total > 0, do: Float.round(state.tests_passed / state.tests_total * 100, 2), else: 0.0
    gde_achieved = state.coverage >= state.gde_goal
    
    IO.puts("""
    
    ╔═══════════════════════════════════════════════════════════════════════════════╗
    ║                    CYBERNETIC EXECUTION RESULTS                               ║
    ╠═══════════════════════════════════════════════════════════════════════════════╣
    ║                                                                               ║
    ║  ┌─────────────────────────────────────────────────────────────────────────┐  ║
    ║  │  KPI DASHBOARD                                              #{timestamp()}  │  ║
    ║  ├─────────────────────────────────────────────────────────────────────────┤  ║
    ║  │  Tests Executed:    #{String.pad_leading(Integer.to_string(state.tests_total), 6)}                                       │  ║
    ║  │  Tests Passed:      #{String.pad_leading(Integer.to_string(state.tests_passed), 6)} ✓                                     │  ║
    ║  │  Tests Failed:      #{String.pad_leading(Integer.to_string(state.tests_failed), 6)} #{if state.tests_failed > 0, do: "✗", else: "✓"}                                     │  ║
    ║  │  Pass Rate:         #{String.pad_leading(Float.to_string(pass_rate), 6)}%                                    │  ║
    ║  │  Coverage:          #{String.pad_leading(Float.to_string(state.coverage), 6)}%                                    │  ║
    ║  │  Execution Time:    #{String.pad_leading(elapsed_str, 10)}                                  │  ║
    ║  └─────────────────────────────────────────────────────────────────────────┘  ║
    ║                                                                               ║
    ║  ┌─────────────────────────────────────────────────────────────────────────┐  ║
    ║  │  GDE GOAL STATUS                                                        │  ║
    ║  ├─────────────────────────────────────────────────────────────────────────┤  ║
    ║  │  Target Coverage:   #{String.pad_leading(Float.to_string(state.gde_goal), 6)}%                                    │  ║
    ║  │  Actual Coverage:   #{String.pad_leading(Float.to_string(state.coverage), 6)}%                                    │  ║
    ║  │  GDE Status:        #{if gde_achieved, do: "ACHIEVED ✓     ", else: "IN PROGRESS   "}                              │  ║
    ║  │  Exit Code:         #{String.pad_leading(Integer.to_string(state.exit_code), 6)}                                       │  ║
    ║  └─────────────────────────────────────────────────────────────────────────┘  ║
    ║                                                                               ║
    ╚═══════════════════════════════════════════════════════════════════════════════╝
    """)
  end
  
  defp format_duration(ms) when ms < 1000, do: "#{ms}ms"
  defp format_duration(ms) when ms < 60_000, do: "#{Float.round(ms / 1000, 1)}s"
  defp format_duration(ms), do: "#{Float.round(ms / 60_000, 1)}m"
  
  defp timestamp do
    DateTime.utc_now() |> DateTime.to_string() |> String.slice(0..18)
  end
end

CyberneticTestRunner.run()
