defmodule Mix.Tasks.Holon.Verify do
  @moduledoc """
  Verifies Holon compliance across the codebase.

  Scans all modules to ensure agents and key components implement
  the Holon behaviour with all 5 VSM systems.

  ## Usage

      mix holon.verify              # Standard check
      mix holon.verify --strict     # Fail on any non-compliance
      mix holon.verify --json       # Output as JSON
      mix holon.verify --agents     # Only check agent modules

  ## STAMP Constraints

  - SC-HOL-001: All holons MUST implement all 5 systems
  - SC-HOL-002: Holons MUST verify constitution on startup

  ## Exit Codes

  - 0: All checks passed
  - 1: Non-compliance detected (strict mode)
  """

  use Mix.Task

  require Logger

  @shortdoc "Verifies Holon compliance across the codebase"

  @vsm_callbacks [
    :system1_operations,
    :system2_coordination,
    :system3_control,
    :system4_intelligence,
    :system5_policy
  ]

  # Reserved for future use - structural callback validation
  # @structural_callbacks [:holon_id, :layer, :parent, :children, :health]

  @impl Mix.Task
  def run(args) do
    # Start required applications
    Mix.Task.run("compile", [])

    {opts, _, _} =
      OptionParser.parse(args,
        switches: [strict: :boolean, json: :boolean, agents: :boolean],
        aliases: [s: :strict, j: :json, a: :agents]
      )

    strict_mode = Keyword.get(opts, :strict, false)
    json_output = Keyword.get(opts, :json, false)
    agents_only = Keyword.get(opts, :agents, false)

    unless json_output do
      IO.puts("\n🔍 Holon Compliance Verification")
      IO.puts("================================")

      if strict_mode do
        IO.puts("Running in strict mode - will fail on any non-compliance\n")
      end
    end

    # Scan and check modules
    modules =
      scan_modules()
      |> maybe_filter_agents(agents_only)

    results = Enum.map(modules, &check_holon_compliance/1)

    # Generate report
    report = generate_report(results)

    # Output
    if json_output do
      output_json(report, results)
    else
      output_text(report, results, strict_mode)
    end

    # Exit code for CI
    if strict_mode and report.non_compliant > 0 do
      System.halt(1)
    end
  end

  @doc """
  Returns the list of required VSM callbacks.
  """
  @spec vsm_callbacks() :: [atom()]
  def vsm_callbacks, do: @vsm_callbacks

  @doc """
  Scans the codebase for modules that should implement Holon.
  """
  @spec scan_modules() :: [module()]
  def scan_modules do
    # Get all compiled modules from the application
    {:ok, modules} = :application.get_key(:indrajaal, :modules)

    modules
    |> Enum.filter(&should_check?/1)
    |> Enum.sort()
  end

  @doc """
  Checks if a module is an agent module.
  """
  @spec is_agent_module?(module()) :: boolean()
  def is_agent_module?(module) do
    module_name = to_string(module)

    String.contains?(module_name, "Agent") or
      String.contains?(module_name, "Agents.") or
      String.ends_with?(module_name, "Agent")
  end

  @doc """
  Checks if a module is a holon (implements the behaviour).
  """
  @spec is_holon?(module()) :: boolean()
  def is_holon?(module) do
    behaviours = get_behaviours(module)
    Indrajaal.Core.Holon in behaviours
  end

  @doc """
  Checks Holon compliance for a module.
  """
  @spec check_holon_compliance(module()) :: map()
  def check_holon_compliance(module) do
    if is_holon?(module) do
      # Check which callbacks are implemented
      implemented = check_callbacks(module)
      missing = @vsm_callbacks -- implemented

      if missing == [] do
        %{
          module: module,
          status: :compliant,
          reason: nil,
          callbacks_implemented: length(implemented),
          missing_callbacks: []
        }
      else
        %{
          module: module,
          status: :partial,
          reason: :missing_callbacks,
          callbacks_implemented: length(implemented),
          missing_callbacks: missing
        }
      end
    else
      %{
        module: module,
        status: :non_compliant,
        reason: :not_a_holon,
        callbacks_implemented: 0,
        missing_callbacks: @vsm_callbacks
      }
    end
  end

  @doc """
  Generates a compliance report from results.
  """
  @spec generate_report([map()]) :: map()
  def generate_report(results) do
    total = length(results)
    compliant = Enum.count(results, &(&1.status == :compliant))
    partial = Enum.count(results, &(&1.status == :partial))
    non_compliant = Enum.count(results, &(&1.status == :non_compliant))

    rate =
      if total > 0 do
        Float.round(compliant / total * 100, 1)
      else
        100.0
      end

    %{
      total_checked: total,
      compliant: compliant,
      partial: partial,
      non_compliant: non_compliant,
      compliance_rate: rate,
      timestamp: DateTime.utc_now(),
      stamp_constraints: ["SC-HOL-001", "SC-HOL-002"]
    }
  end

  # Private functions

  defp should_check?(module) do
    module_name = to_string(module)

    # Check modules that are likely to be holons
    cond do
      # Always check agents
      is_agent_module?(module) -> true
      # Check controllers and processors
      String.contains?(module_name, "Controller") -> true
      String.contains?(module_name, "Processor") -> true
      # Check core infrastructure
      String.contains?(module_name, "Core.") -> true
      String.contains?(module_name, "Cortex.") -> true
      # Skip test modules
      String.contains?(module_name, "Test") -> false
      # Skip Phoenix/Web modules (not holons)
      String.contains?(module_name, "Web.") -> false
      String.contains?(module_name, "Live.") -> false
      # Default: check if it implements Holon
      is_holon?(module) -> true
      # Otherwise skip
      true -> false
    end
  end

  defp maybe_filter_agents(modules, true), do: Enum.filter(modules, &is_agent_module?/1)
  defp maybe_filter_agents(modules, false), do: modules

  defp get_behaviours(module) do
    if function_exported?(module, :__info__, 1) do
      attributes = module.__info__(:attributes)
      behaviours = attributes |> Keyword.get_values(:behaviour)
      behaviours |> List.flatten()
    else
      []
    end
  rescue
    _ -> []
  end

  defp check_callbacks(module) do
    Enum.filter(@vsm_callbacks, fn callback ->
      # Check if callback is exported
      # VSM callbacks have specific arities
      arity = callback_arity(callback)
      function_exported?(module, callback, arity)
    end)
  end

  defp callback_arity(:system1_operations), do: 1
  defp callback_arity(:system2_coordination), do: 1
  defp callback_arity(:system3_control), do: 1
  defp callback_arity(:system4_intelligence), do: 1
  defp callback_arity(:system5_policy), do: 0

  defp output_json(report, results) do
    output = %{
      report: report,
      results:
        Enum.map(results, fn r ->
          %{
            module: to_string(r.module),
            status: r.status,
            reason: r.reason,
            callbacks_implemented: r.callbacks_implemented,
            missing_callbacks: Enum.map(r.missing_callbacks, &to_string/1)
          }
        end)
    }

    IO.puts(Jason.encode!(output, pretty: true))
  end

  defp output_text(report, results, strict_mode) do
    # Summary
    IO.puts("📊 Summary")
    IO.puts("----------")
    IO.puts("Total modules checked: #{report.total_checked}")
    IO.puts("✅ Compliant:          #{report.compliant}")
    IO.puts("⚠️  Partial:            #{report.partial}")
    IO.puts("❌ Non-compliant:      #{report.non_compliant}")
    IO.puts("📈 Compliance rate:    #{report.compliance_rate}%\n")

    # Show compliant modules
    compliant = Enum.filter(results, &(&1.status == :compliant))

    if length(compliant) > 0 do
      IO.puts("✅ Compliant Modules (#{length(compliant)})")
      IO.puts(String.duplicate("-", 40))

      Enum.each(compliant, fn r ->
        IO.puts("  • #{inspect(r.module)} (#{r.callbacks_implemented}/5 VSM)")
      end)

      IO.puts("")
    end

    # Show partial implementations
    partial = Enum.filter(results, &(&1.status == :partial))

    if length(partial) > 0 do
      IO.puts("⚠️  Partial Implementations (#{length(partial)})")
      IO.puts(String.duplicate("-", 40))

      Enum.each(partial, fn r ->
        IO.puts("  • #{inspect(r.module)}")
        IO.puts("    Missing: #{Enum.join(r.missing_callbacks, ", ")}")
      end)

      IO.puts("")
    end

    # Show non-compliant modules (only first 20 in non-strict mode)
    non_compliant = Enum.filter(results, &(&1.status == :non_compliant))

    if length(non_compliant) > 0 do
      show_count = if strict_mode, do: length(non_compliant), else: min(20, length(non_compliant))

      IO.puts("❌ Non-Compliant Modules (showing #{show_count}/#{length(non_compliant)})")
      IO.puts(String.duplicate("-", 40))

      non_compliant
      |> Enum.take(show_count)
      |> Enum.each(fn r ->
        IO.puts("  • #{inspect(r.module)}")
        IO.puts("    Reason: #{r.reason}")
      end)

      if not strict_mode and length(non_compliant) > 20 do
        IO.puts("  ... and #{length(non_compliant) - 20} more")
      end

      IO.puts("")
    end

    # STAMP compliance note
    IO.puts("📋 STAMP Constraints: #{Enum.join(report.stamp_constraints, ", ")}")

    if report.compliance_rate >= 100.0 do
      IO.puts("\n🎉 All checked modules are Holon-compliant!")
    else
      IO.puts("\n⚠️  Some modules need Holon compliance updates")

      if strict_mode do
        IO.puts("   Exiting with error code 1 (strict mode)")
      end
    end
  end
end
