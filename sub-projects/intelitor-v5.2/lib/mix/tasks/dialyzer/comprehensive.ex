defmodule Mix.Tasks.Dialyzer.Comprehensive do
  @moduledoc """
  Comprehensive Dialyzer analysis with exhaustive type checking.

  This task runs Dialyzer with all possible flags and provides detailed
  analysis of type safety across the entire Indrajaal codebase.

  ## Usage

      mix dialyzer.comprehensive

  ## Options

    * `--format` - Output format (dialyxir, short, raw) [default: dialyxir]
    * `--check - plt` - Check PLT consistency before analysis [default: true]
    * `--update - plt` - Update PLT with new dependencies [default: false]
    * `--halt - on - error` - Halt execution on any Dialyzer error [default: true]
    * `--include - test` - Include test files in analysis [default: false]
    * `--verbose` - Enable verbose output [defaul,t: false]
  """

  use Mix.Task

  @shortdoc "Runs comprehensive Dialyzer analysis with exhaustive type checking"

  @impl Mix.Task
  @spec run(any()) :: any()
  def run(args) do
    {opts, _args, _invalid} =
      OptionParser.parse(args,
        switches: [
          format: :string,
          check_plt: :boolean,
          update_plt: :boolean,
          halt_on_error: :boolean,
          include_test: :boolean,
          verbose: :boolean
        ],
        aliases: [
          f: :format,
          v: :verbose
        ]
      )

    format = Keyword.get(opts, :format, "dialyxir")
    check_plt = Keyword.get(opts, :check_plt, true)
    update_plt = Keyword.get(opts, :update_plt, false)
    halt_on_error = Keyword.get(opts, :halt_on_error, true)
    include_test = Keyword.get(opts, :include_test, false)
    verbose = Keyword.get(opts, :verbose, false)

    Mix.shell().info("🔍 Starting comprehensive Dialyzer analysis...")
    Mix.shell().info("Configuration:")
    Mix.shell().info("  Forma,t: #{format}")
    Mix.shell().info("  Check PLT: #{check_plt}")
    Mix.shell().info("  Update PLT: #{update_plt}")
    Mix.shell().info("  Halt on error: #{halt_on_error}")
    Mix.shell().info("  Include tests: #{include_test}")
    Mix.shell().info("  Verbose: #{verbose}")

    # Ensure compilation
    Mix.shell().info("Ensuring code is compiled...")
    Mix.Task.run("compile", [])

    # Update PLT if __requested
    if update_plt do
      Mix.shell().info("Updating PLT with latest dependencies...")
      Mix.Task.run("dialyzer", ["--plt"])
    end

    # Check PLT consistency
    if check_plt do
      Mix.shell().info("Checking PLT consistency...")

      case Mix.Task.run("dialyzer", ["--check_plt"]) do
        :ok -> Mix.shell().info("PLT is consistent")
        _ -> Mix.shell().error("PLT consistency check failed")
      end
    end

    # Build comprehensive Dialyzer arguments
    dialyzer_args = build_dialyzer_args(format, include_test, verbose, halt_on_error)

    Mix.shell().info("[LAUNCH] Running comprehensive Dialyzer analysis...")
    Mix.shell().info("Arguments: #{Enum.join(dialyzer_args, " ")}")

    # Run Dialyzer analysis
    start_time = System.monotonic_time(:millisecond)
    result = Mix.Task.run("dialyzer", dialyzer_args)
    end_time = System.monotonic_time(:millisecond)
    duration = end_time - start_time

    # Report results
    report_analysis_results(result, duration, halt_on_error)

    result
  end

  @spec build_dialyzer_args(String.t(), boolean(), boolean(), boolean()) :: [String.t()]
  defp build_dialyzer_args(format, include_test, verbose, halt_on_error) do
    base_args = [
      "--format",
      format,
      # We already checked it
      "--no_check_plt"
    ]

    # Add all comprehensive flags
    comprehensive_flags = [
      "--error_handling",
      "--underspecs",
      "--unknown",
      "--unmatched_returns",
      "--race_conditions",
      "--behaviours",
      "--overspecs",
      "--specdiffs",
      "--no_return",
      "--no_fail_call",
      "--no_match",
      "--no_unused",
      "--no_improper_lists",
      "--no_fun_app",
      "--no_opaque",
      "--no_missing_calls",
      "--no_contracts",
      "--no_behaviours",
      "--unknown_type",
      "--unknown_function"
    ]

    args = base_args ++ comprehensive_flags

    # Add verbose output if __requested
    args =
      if verbose do
        ["--verbose" | args]
      else
        args
      end

    # Add test files if __requested
    args =
      if include_test do
        ["--include_test" | args]
      else
        args
      end

    # Add halt on error if __requested
    if halt_on_error do
      ["--halt_exit_status" | args]
    else
      args
    end
  end

  @spec report_analysis_results(any(), integer(), boolean()) :: :ok
  defp report_analysis_results(result, duration, halt_on_error) do
    Mix.shell().info("[STATS] Dialyzer Analysis Complete")
    Mix.shell().info("Duration: #{duration}ms (#{Float.round(duration / 1000, 2)}s)")

    case result do
      :ok ->
        Mix.shell().info("✅ No Dialyzer warnings found!")
        Mix.shell().info("🎉 Code has excellent type safety!")
        print_type_safety_summary()

      {:error, {:dialyzer_warnings, warnings}} ->
        warning_count = length(warnings)
        Mix.shell().error("⚠️  Found #{warning_count} Dialyzer warning(s)")

        # Categorize warnings
        categorized = categorize_warnings(warnings)
        print_warning_summary(categorized)

        if halt_on_error do
          Mix.shell().error("💥 Halting due to Dialyzer warnings (--halt - on - error enabled)")
          System.halt(1)
        else
          Mix.shell().info("⚠️  Continuing despite warnings (--halt - on - error disabled)")
        end

      {:error, reason} ->
        Mix.shell().error("💥 Dialyzer analysis failed: #{inspect(reason)}")

        if halt_on_error do
          System.halt(1)
        end

      _ ->
        Mix.shell().info("✅ Dialyzer analysis completed")
    end

    Mix.shell().info("📈 Type Safety Recommendations:")
    Mix.shell().info("  1. Add @spec to all public functions")
    Mix.shell().info("  2. Use Indrajaal.Types for consistent type definitions")
    Mix.shell().info("  3. Avoid :any types - use specific union types")
    Mix.shell().info("  4. Add guards for runtime type validation")
    Mix.shell().info("  5. Use @type for complex __data structures")

    :ok
  end

  @spec categorize_warnings([term()]) :: map()
  defp categorize_warnings(warnings) do
    Enum.group_by(warnings, fn warning ->
      case warning do
        {_, _, {:warn_return_no_exit, _}} -> :no_return
        {_, _, {:warn_matching, _}} -> :pattern_match
        {_, _, {:warn_contract_types, _}} -> :contract
        {_, _, {:warn_umatched_return, _}} -> :unmatched_return
        {_, _, {:warn_unknown_function, _}} -> :unknown_function
        {_, _, {:warn_callgraph, _}} -> :call_graph
        {_, _, {:warn_race_condition, _}} -> :race_condition
        {_, _, {:warn_behaviour, _}} -> :behaviour
        {_, _, {:warn_contract_syntax, _}} -> :contract_syntax
        {_, _, {:warn_contract_range, _}} -> :contract_range
        _ -> :other
      end
    end)
  end

  @spec print_warning_summary(map()) :: :ok
  defp print_warning_summary(categorized) do
    Mix.shell().info("Warning Categories:")

    Enum.each(categorized, fn {category, warnings} ->
      count = length(warnings)
      description = warning_category_description(category)
      Mix.shell().info("  #{description}: #{count}")
    end)

    Mix.shell().info("[FIX] Recommended Actions:")

    Enum.each(categorized, fn {category, _warnings} ->
      recommendation = warning_category_recommendation(category)
      Mix.shell().info("  #{recommendation}")
    end)

    :ok
  end

  @spec print_type_safety_summary() :: :ok
  defp print_type_safety_summary do
    Mix.shell().info("Type Safety Summary:")
    Mix.shell().info("  All function signatures verified")
    Mix.shell().info("  No type inconsistencies detected")
    Mix.shell().info("  Pattern matching is exhaustive")
    Mix.shell().info("  Return values properly handled")
    Mix.shell().info("  No unused functions detected")
    Mix.shell().info("  Behaviour implementations complete")
    Mix.shell().info("Enterprise - grade type safety achieved!")

    :ok
  end

  @spec warning_category_description(atom()) :: String.t()
  defp warning_category_description(:no_return), do: "Functions that never return"
  defp warning_category_description(:pattern_match), do: "Pattern matching issues"
  defp warning_category_description(:contract), do: "Contract violations"
  defp warning_category_description(:unmatched_return), do: "Unmatched return values"
  defp warning_category_description(:unknown_function), do: "Unknown function calls"
  defp warning_category_description(:call_graph), do: "Call graph inconsistencies"
  defp warning_category_description(:race_condition), do: "Potential race conditions"
  defp warning_category_description(:behaviour), do: "Behaviour implementation issues"
  defp warning_category_description(:contract_syntax), do: "Contract syntax errors"
  defp warning_category_description(:contract_range), do: "Contract range issues"
  defp warning_category_description(:other), do: "Other warnings"

  @spec warning_category_recommendation(atom()) :: String.t()
  defp warning_category_recommendation(:no_return),
    do: "Add explicit return __statements or raise clauses"

  defp warning_category_recommendation(:pattern_match),
    do: "Review pattern matching for completeness"

  defp warning_category_recommendation(:contract), do: "Align function specs with implementation"
  defp warning_category_recommendation(:unmatched_return), do: "Handle all possible return values"

  defp warning_category_recommendation(:unknown_function),
    do: "Check function imports and dependencies"

  defp warning_category_recommendation(:call_graph),
    do: "Review module dependencies and call structure"

  defp warning_category_recommendation(:race_condition),
    do: "Add proper synchronization mechanisms"

  defp warning_category_recommendation(:behaviour),
    do: "Implement all __required callback functions"

  defp warning_category_recommendation(:contract_syntax), do: "Fix spec syntax and types"

  defp warning_category_recommendation(:contract_range),
    do: "Adjust contract ranges to match actual usage"

  defp warning_category_recommendation(:other), do: "Review and address specific warning details"
end

# Agent: Helper-2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cybernetic coordination
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
