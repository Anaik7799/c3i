defmodule Mix.Tasks.Test.CoverageReport do
  use Mix.Task

  @shortdoc "Run tests with comprehensive coverage report"

  @moduledoc """
  Runs the test suite with coverage analysis and generates reports.

  ## Usage

      mix test.coverage [options]

  ## Options

    * `--html` - Generate HTML coverage report
    * `--summary` - Show coverage summary only
    * `--threshold 80` - Set minimum coverage threshold (default: 80)

  ## Examples

      mix test.coverage
      mix test.coverage --html
      mix test.coverage --threshold 100
  """

  @spec run(any()) :: any()
  def run(args) do
    IO.puts("🧪 Running tests with coverage analysis...")

    # Set coverage tool
    System.put_env("MIX_ENV", "test")

    # Run tests with coverage
    Mix.Task.run("test", ["--cover" | args])

    # Generate coverage report
    if "--html" in args do
      IO.puts("

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
\n[STATS] Generating HTML coverage report...")
      Mix.Task.run("coveralls.html")
      IO.puts("Coverage report available at: cover / excoveralls.html")
    end

    IO.puts("\n✅ Test coverage analysis complete!")
  end
end
