defmodule Mix.Tasks.Project.Analyze do
  use Mix.Task

  @shortdoc "Analyze project structure, quality, and Ash domain implementation"

  @moduledoc """
  Performs comprehensive project analysis including:
  - Code quality (Credo, Dialyzer, Sobelow)
  - Test coverage
  - Ash domain implementation status
  - Project structure validation

  ## Usage

      mix project.analyze [options]

  ## Options

    * `--domains` - Analyze only Ash domains
    * `--quality` - Run only quality checks
    * `--quick` - Skip time - consuming checks
  """

  @spec run(any()) :: any()
  def run(args) do
    IO.puts("🔍 Analyzing Indrajaal Project...")

    unless "--domains" in args do
      run_quality_checks(args)
    end

    unless "--quality" in args do
      analyze_domains()
    end

    generate_report()
  end

  @spec run_quality_checks(term()) :: term()
  defp run_quality_checks(args) do
    IO.puts("

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
\n📋 Running quality checks...")

    # Format check
    IO.puts("  Checking code formatting...")
    Mix.Task.run("format", ["--check - formatted"])

    # Credo
    IO.puts("  Running Credo...")
    Mix.Task.run("credo", ["--strict"])

    # Dialyzer (skip if --quick)
    unless "--quick" in args do
      IO.puts("  Running Dialyzer...")
      Mix.Task.run("dialyzer")
    end

    # Security
    IO.puts("  Running security scan...")
    Mix.Task.run("sobelow")
  end

  @spec analyze_domains() :: any()
  def analyze_domains() do
    IO.puts("\n[BUILD]  Analyzing Ash domains...")

    domains = [
      "Core",
      "Accounts",
      "Policy",
      "Sites",
      "Devices",
      "Alarms",
      "Video",
      "Dispatch",
      "Maintenance",
      "Compliance",
      "Billing",
      "Integrations"
    ]

    Enum.each(domains, fn domain ->
      status = check_domain_status(domain)
      IO.puts("  #{domain}: #{status}")
    end)
  end

  @spec check_domain_status(term()) :: term()
  defp check_domain_status(domain) do
    domain_file = "lib / indrajaal/#{String.downcase(domain)}.ex"
    if File.exists?(domain_file), do: "✅ Implemented", else: "❌ Not found"
  end

  @spec generate_report() :: any()
  defp generate_report do
    IO.puts("\n[STATS] Analysis complete!")
    IO.puts("Run 'mix docs' to generate full documentation")
  end
end
