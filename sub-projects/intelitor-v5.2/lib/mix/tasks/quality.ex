defmodule Mix.Tasks.Quality do
  @moduledoc """
  Comprehensive quality assurance task for enterprise - grade validation.

  This Mix task provides a unified interface for all quality gates:
  - Zero - warning compilation validation
  - Credo quality analysis (strict mode)
  - @spec coverage validation
  - Test - Driven Generation (TDG) methodology compliance
  - STAMP safety constraint validation
  - Security analysis with Sobelow
  - Performance benchmarking
  - Documentation and timestamp validation

  ## SOPv5.1 Cybernetic Integration

  This task implements cybernetic feedback loops with:
  - Real - time quality monitoring and reporting
  - Automated quality gate enforcement
  - Systematic quality improvement recommendations
  - Enterprise - grade compliance validation

  ## Usage Examples

      # Run comprehensive quality analysis
      mix quality

      # Run specific quality gate
      mix quality --gate compilation
      mix quality --gate credo
      mix quality --gate specs
      mix quality --gate security

      # Generate quality report
      mix quality --report

      # Continuous quality monitoring
      mix quality --monitor

  """

  use Mix.Task

  @shortdoc "Comprehensive enterprise quality assurance validation"

  @quality_gates %{
    compilation: %{
      name: "🏭 Zero - Warning Compilation",
      description: "Enterprise - standard zero - tolerance compilation",
      command: "ELIXIR_ERL_OPTIONS=\"+S 16\" mix compile --warnings - as - errors"
    },
    format: %{
      name: "📐 Code Formatting",
      description: "Elixir code formatting validation",
      command: "mix format --check - formatted"
    },
    credo: %{
      name: "🎯 Credo Quality Analysis",
      description: "Strict code quality analysis",
      command: "mix credo --strict"
    },
    dialyzer: %{
      name: "🔬 Dialyzer Type Analysis",
      description: "Static type analysis and validation",
      command: "mix dialyzer"
    },
    specs: %{
      name: "📋 @spec Coverage Validation",
      description: "Type specification coverage analysis",
      function: :validate_spec_coverage
    },
    security: %{
      name: "🔐 Security Analysis",
      description: "Sobelow security vulnerability analysis",
      command: "mix sobelow --exit"
    },
    deps_audit: %{
      name: "🔍 Dependency Security Audit",
      description: "Dependency vulnerability analysis",
      command: "mix deps.audit"
    },
    tests: %{
      name: "🧪 Comprehensive Testing",
      description: "Full test suite execution",
      command: "ELIXIR_ERL_OPTIONS=\"+S 16\" mix test"
    },
    coverage: %{
      name: "📊 Test Coverage Analysis",
      description: "Test coverage validation",
      command: "mix test --cover"
    },
    tdg: %{
      name: "🧬 TDG Methodology Validation",
      description: "Test - Driven Generation compliance",
      function: :validate_tdg_compliance
    },
    stamp: %{
      name: "🛡️ STAMP Safety Validation",
      description: "STAMP safety constraint analysis",
      function: :validate_stamp_safety
    },
    performance: %{
      name: "⚡ Performance Benchmarking",
      description: "Compilation and runtime performance",
      function: :benchmark_performance
    },
    timestamps: %{
      name: "🕒 Timestamp Validation",
      description: "Documentation timestamp accuracy",
      function: :validate_timestamps
    }
  }

  @spec run(list(String.t())) :: :ok
  def run(args) do
    {opts, _args, _} =
      OptionParser.parse(args,
        switches: [
          gate: :string,
          report: :boolean,
          monitor: :boolean,
          help: :boolean,
          parallel: :boolean,
          timeout: :integer
        ],
        aliases: [
          g: :gate,
          r: :report,
          m: :monitor,
          h: :help,
          p: :parallel,
          t: :timeout
        ]
      )

    cond do
      opts[:help] -> show_help()
      opts[:report] -> generate_quality_report()
      opts[:monitor] -> start_continuous_monitoring()
      opts[:gate] -> run_specific_gate(opts[:gate])
      opts[:parallel] -> run_parallel_quality_gates(opts)
      true -> run_comprehensive_quality_analysis(opts)
    end
  end

  @spec run_comprehensive_quality_analysis(keyword()) :: :ok
  defp run_comprehensive_quality_analysis(opts) do
    # 5 minutes default
    timeout = Keyword.get(opts, :timeout, 300_000)

    Mix.shell().info([
      IO.ANSI.bright(),
      IO.ANSI.blue(),
      "🏭 ENTERPRISE QUALITY ASSURANCE SYSTEM",
      IO.ANSI.reset()
    ])

    Mix.shell().info("=" <> String.duplicate("=", 49))
    Mix.shell().info("Timestamp: #{DateTime.utc_now()}")
    Mix.shell().info("Framework: SOPv5.1 Cybernetic Quality Gates")
    Mix.shell().info("Parallelization: ELIXIR_ERL_OPTIONS=\"+S 16\" (Maximum)")
    Mix.shell().info("")

    results = %{
      started_at: DateTime.utc_now(),
      gates: [],
      summary: %{passed: 0, failed: 0, warnings: 0}
    }

    # Run all quality gates in sequence
    final_results =
      Enum.reduce(@quality_gates, results, fn {gate_id, gate_config}, acc ->
        gate_result = execute_quality_gate(gate_id, gate_config, timeout)

        updated_summary =
          case gate_result.status do
            :passed -> %{acc.summary | passed: acc.summary.passed + 1}
            :failed -> %{acc.summary | failed: acc.summary.failed + 1}
            :warning -> %{acc.summary | warnings: acc.summary.warnings + 1}
          end

        %{acc | gates: acc.gates ++ [gate_result], summary: updated_summary}
      end)

    # Display comprehensive results
    display_quality_results(final_results)

    # Determine overall success
    if final_results.summary.failed > 0 do
      Mix.shell().error([
        IO.ANSI.red(),
        IO.ANSI.bright(),
        "❌ QUALITY GATES FAILED: #{final_results.summary.failed} gate(s) failed",
        IO.ANSI.reset()
      ])

      System.at_exit(fn _ -> exit({:shutdown, 1}) end)
    else
      Mix.shell().info([
        IO.ANSI.green(),
        IO.ANSI.bright(),
        "✅ ALL QUALITY GATES PASSED SUCCESSFULLY",
        IO.ANSI.reset()
      ])
    end

    :ok
  end

  @spec run_parallel_quality_gates(keyword()) :: :ok
  defp run_parallel_quality_gates(opts) do
    # 10 minutes for parallel execution
    timeout = Keyword.get(opts, :timeout, 600_000)

    Mix.shell().info([
      IO.ANSI.bright(),
      IO.ANSI.cyan(),
      "⚡ PARALLEL QUALITY GATE EXECUTION",
      IO.ANSI.reset()
    ])

    # Group gates by execution type
    {command_gates, function_gates} =
      Enum.split_with(@quality_gates, fn {_id, config} ->
        Map.has_key?(config, :command)
      end)

    # Execute command - based gates in parallel
    command_tasks =
      Enum.map(command_gates, fn {gate_id, gate_config} ->
        Task.async(fn -> execute_quality_gate(gate_id, gate_config, timeout) end)
      end)

    # Execute function - based gates in parallel
    function_tasks =
      Enum.map(function_gates, fn {gate_id, gate_config} ->
        Task.async(fn -> execute_quality_gate(gate_id, gate_config, timeout) end)
      end)

    # Collect all results
    all_tasks = command_tasks ++ function_tasks
    results = Task.await_many(all_tasks, timeout)

    # Process and display results
    summary =
      Enum.reduce(results, %{passed: 0, failed: 0, warnings: 0}, fn result, acc ->
        case result.status do
          :passed -> %{acc | passed: acc.passed + 1}
          :failed -> %{acc | failed: acc.failed + 1}
          :warning -> %{acc | warnings: acc.warnings + 1}
        end
      end)

    final_results = %{
      started_at: DateTime.utc_now(),
      gates: results,
      summary: summary,
      execution_mode: :parallel
    }

    display_quality_results(final_results)

    if summary.failed > 0 do
      Mix.shell().error([
        IO.ANSI.red(),
        IO.ANSI.bright(),
        "❌ PARALLEL QUALITY GATES FAILED: #{summary.failed} gate(s) failed",
        IO.ANSI.reset()
      ])

      System.at_exit(fn _ -> exit({:shutdown, 1}) end)
    else
      Mix.shell().info([
        IO.ANSI.green(),
        IO.ANSI.bright(),
        "✅ ALL PARALLEL QUALITY GATES PASSED SUCCESSFULLY",
        IO.ANSI.reset()
      ])
    end

    :ok
  end

  @spec execute_quality_gate(atom(), map(), integer()) :: map()
  defp execute_quality_gate(gate_id, gate_config, timeout) do
    Mix.shell().info([
      IO.ANSI.yellow(),
      "▶ Running: ",
      IO.ANSI.bright(),
      gate_config.name,
      IO.ANSI.reset()
    ])

    start_time = System.monotonic_time(:millisecond)

    result =
      cond do
        Map.has_key?(gate_config, :command) ->
          execute_command_gate(gate_config.command, timeout)

        Map.has_key?(gate_config, :function) ->
          execute_function_gate(gate_config.function, gate_id)

        true ->
          %{status: :failed, output: "Invalid gate configuration", exit_code: 1}
      end

    end_time = System.monotonic_time(:millisecond)
    duration = end_time - start_time

    gate_result = %{
      gate_id: gate_id,
      name: gate_config.name,
      description: gate_config.description,
      status: result.status,
      output: result.output,
      exit_code: Map.get(result, :exit_code, 0),
      duration_ms: duration,
      timestamp: DateTime.utc_now()
    }

    # Display immediate result
    status_indicator =
      case result.status do
        :passed -> [IO.ANSI.green(), "✅ PASSED", IO.ANSI.reset()]
        :failed -> [IO.ANSI.red(), "❌ FAILED", IO.ANSI.reset()]
        :warning -> [IO.ANSI.yellow(), "⚠️ WARNING", IO.ANSI.reset()]
      end

    Mix.shell().info([
      "  ",
      status_indicator,
      " (#{duration}ms) - ",
      gate_config.description
    ])

    if result.status == :failed and String.length(result.output) > 0 do
      Mix.shell().info("  Output: #{String.slice(result.output, 0, 200)}...")
    end

    gate_result
  end

  @spec execute_command_gate(String.t(), integer()) :: map()
  defp execute_command_gate(command, timeout) do
    try do
      case System.cmd("sh", ["-c", command], stderr_to_stdout: true, timeout: timeout) do
        {output, 0} -> %{status: :passed, output: output}
        {output, exit_code} -> %{status: :failed, output: output, exit_code: exit_code}
      end
    rescue
      e -> %{status: :failed, output: "Exception: #{inspect(e)}", exit_code: 1}
    end
  end

  @spec execute_function_gate(atom(), atom()) :: map()
  defp execute_function_gate(function_name, _gate_id) when is_atom(function_name) do
    try do
      case function_name do
        :validate_spec_coverage -> validate_spec_coverage()
        :validate_tdg_compliance -> validate_tdg_compliance()
        :validate_stamp_safety -> validate_stamp_safety()
        :benchmark_performance -> benchmark_performance()
        :validate_timestamps -> validate_timestamps()
        _ -> %{status: :failed, output: "Unknown function: #{function_name}"}
      end
    rescue
      e -> %{status: :failed, output: "Exception: #{inspect(e)}"}
    end
  end

  # Quality gate implementation functions

  @spec validate_spec_coverage() :: map()
  defp validate_spec_coverage do
    try do
      # Get all Elixir files in lib/
      elixir_files = Path.wildcard("lib/**/*.ex")

      # Count functions and @spec declarations
      {total_functions, spec_functions} =
        Enum.reduce(elixir_files, {0, 0}, fn file, {total, specs} ->
          content = File.read!(file)

          # Count public functions (def but not defp)
          function_matches = Regex.scan(~r/^\s * def\s+\w+/, content)
          function_count = length(function_matches)

          # Count @spec declarations
          spec_matches = Regex.scan(~r/^\s*@spec\s/, content)
          spec_count = length(spec_matches)

          {total + function_count, specs + spec_count}
        end)

      coverage_percentage =
        if total_functions > 0 do
          spec_functions / total_functions * 100
        else
          100.0
        end

      output = """
      @spec Coverage Analysis:
      - Total public functions: #{total_functions}
      - Functions with @spec: #{spec_functions}
      - Coverage percentage: #{Float.round(coverage_percentage, 1)}%
      """

      if coverage_percentage >= 80.0 do
        %{status: :passed, output: output}
      else
        %{status: :warning, output: output}
      end
    rescue
      e -> %{status: :failed, output: "Error analyzing @spec coverage: #{inspect(e)}"}
    end
  end

  @spec validate_tdg_compliance() :: any()
  def validate_tdg_compliance() do
    try do
      # Check if TDG validator exists
      if File.exists?("scripts/testing/tdg_validator.exs") do
        case System.cmd(
               "elixir",
               ["scripts/testing/tdg_validator.exs", "--comprehensive-audit"],
               stderr_to_stdout: true
             ) do
          {output, 0} -> %{status: :passed, output: output}
          {output, _} -> %{status: :warning, output: output}
        end
      else
        # Basic TDG validation
        lib_files = length(Path.wildcard("lib/**/*.ex"))
        test_files = length(Path.wildcard("test/**/*.exs"))

        test_to_lib_ratio = if lib_files > 0, do: test_files / lib_files, else: 0

        output = """
        TDG Basic Analysis:
        - Library modules: #{lib_files}
        - Test modules: #{test_files}
        - Test - to - lib ratio: #{Float.round(test_to_lib_ratio, 2)}
        """

        if test_to_lib_ratio >= 0.8 do
          %{status: :passed, output: output}
        else
          %{status: :warning, output: output}
        end
      end
    rescue
      e -> %{status: :failed, output: "Error validating TDG compliance: #{inspect(e)}"}
    end
  end

  @spec validate_stamp_safety() :: any()
  def validate_stamp_safety() do
    try do
      if File.exists?("scripts/stamp/integrated_stamp_safety_implementation.exs") do
        case System.cmd(
               "elixir",
               [
                 "scripts/stamp/integrated_stamp_safety_implementation.exs",
                 "--validate-all"
               ],
               stderr_to_stdout: true
             ) do
          {output, 0} -> %{status: :passed, output: output}
          {output, _} -> %{status: :warning, output: output}
        end
      else
        # Basic safety validation
        elixir_files = Path.wildcard("lib/**/*.ex")
        unsafe_patterns = ["System.cmd", "File.rm", "Process.spawn", ":os.cmd"]

        unsafe_count =
          Enum.reduce(elixir_files, 0, fn file, acc ->
            content = File.read!(file)

            pattern_count =
              Enum.reduce(unsafe_patterns, 0, fn pattern, count ->
                split_result = String.split(content, pattern)
                length_result = length(split_result)
                matches = length_result |> Kernel.-(1)
                count + matches
              end)

            acc + pattern_count
          end)

        output = """
        STAMP Basic Safety Analysis:
        - Potentially unsafe operations: #{unsafe_count}
        - Safety threshold: 10 operations
        """

        if unsafe_count <= 10 do
          %{status: :passed, output: output}
        else
          %{status: :warning, output: output}
        end
      end
    rescue
      e -> %{status: :failed, output: "Error validating STAMP safety: #{inspect(e)}"}
    end
  end

  @spec benchmark_performance() :: map()
  defp benchmark_performance do
    try do
      Mix.shell().info("  Benchmarking compilation performance...")

      start_time = System.monotonic_time(:millisecond)

      case System.cmd("sh", ["-c", "ELIXIR_ERL_OPTIONS=\"+S 16\" mix compile"],
             stderr_to_stdout: true
           ) do
        {_output, 0} ->
          end_time = System.monotonic_time(:millisecond)
          duration = end_time - start_time

          output = """
          Performance Benchmark Results:
          - Compilation time: #{duration}ms
          - Performance target: <180,000ms (3 minutes)
          """

          if duration < 180_000 do
            %{status: :passed, output: output}
          else
            %{status: :warning, output: output}
          end

        {output, _exit_code} ->
          %{status: :failed, output: "Compilation failed during performance benchmark: #{output}"}
      end
    rescue
      e -> %{status: :failed, output: "Error benchmarking performance: #{inspect(e)}"}
    end
  end

  @spec validate_timestamps() :: any()
  def validate_timestamps() do
    try do
      if File.exists?("scripts/maintenance/simple_timestamp_validator.exs") do
        case System.cmd(
               "elixir",
               ["scripts/maintenance/simple_timestamp_validator.exs", "--audit"],
               stderr_to_stdout: true
             ) do
          {output, 0} -> %{status: :passed, output: output}
          {output, _} -> %{status: :warning, output: output}
        end
      else
        # Basic timestamp validation
        current_year = Date.utc_today().year
        md_files = Path.wildcard("**/*.md")

        outdated_count =
          Enum.reduce(md_files, 0, fn file, acc ->
            content = File.read!(file)
            # Look for dates from previous years
            old_patterns = ["2024-", "2023-", "2022-"]

            pattern_count =
              Enum.reduce(old_patterns, 0, fn pattern, count ->
                split_result = String.split(content, pattern)
                length_result = length(split_result)
                matches = length_result |> Kernel.-(1)
                count + matches
              end)

            acc + pattern_count
          end)

        output = """
        Timestamp Validation:
        - Current year: #{current_year}
        - Outdated timestamps found: #{outdated_count}
        """

        if outdated_count <= 5 do
          %{status: :passed, output: output}
        else
          %{status: :warning, output: output}
        end
      end
    rescue
      e -> %{status: :failed, output: "Error validating timestamps: #{inspect(e)}"}
    end
  end

  # Helper functions for display and reporting

  @spec display_quality_results(map()) :: :ok
  defp display_quality_results(results) do
    Mix.shell().info("")

    Mix.shell().info([
      IO.ANSI.bright(),
      IO.ANSI.blue(),
      "📊 QUALITY GATE RESULTS SUMMARY",
      IO.ANSI.reset()
    ])

    Mix.shell().info("=" <> String.duplicate("=", 33))

    Mix.shell().info(
      "Execution time: #{DateTime.diff(DateTime.utc_now(), results.started_at)} seconds"
    )

    if Map.has_key?(results, :execution_mode) do
      Mix.shell().info("Execution mode: #{results.execution_mode}")
    end

    Mix.shell().info("")

    Mix.shell().info([
      IO.ANSI.green(),
      "✅ Passed: #{results.summary.passed}",
      IO.ANSI.reset(),
      "  ",
      IO.ANSI.red(),
      "❌ Failed: #{results.summary.failed}",
      IO.ANSI.reset(),
      "  ",
      IO.ANSI.yellow(),
      "⚠️ Warnings: #{results.summary.warnings}",
      IO.ANSI.reset()
    ])

    Mix.shell().info("")

    # Show detailed results for failed gates
    failed_gates = Enum.filter(results.gates, fn gate -> gate.status == :failed end)

    if length(failed_gates) > 0 do
      Mix.shell().info([
        IO.ANSI.red(),
        IO.ANSI.bright(),
        "❌ FAILED QUALITY GATES:",
        IO.ANSI.reset()
      ])

      Enum.each(failed_gates, fn gate ->
        Mix.shell().info("  • #{gate.name}")

        if String.length(gate.output) > 0 do
          Mix.shell().info("    #{String.slice(gate.output, 0, 100)}...")
        end
      end)

      Mix.shell().info("")
    end

    :ok
  end

  @spec run_specific_gate(String.t()) :: :ok
  defp run_specific_gate(gate_name) do
    gate_atom = String.to_existing_atom(gate_name)

    case Map.get(@quality_gates, gate_atom) do
      nil ->
        Mix.shell().error("Unknown quality gate: #{gate_name}")
        show_available_gates()

      gate_config ->
        Mix.shell().info([
          IO.ANSI.bright(),
          IO.ANSI.blue(),
          "🎯 Running Specific Quality Gate: #{gate_config.name}",
          IO.ANSI.reset()
        ])

        result = execute_quality_gate(gate_atom, gate_config, 300_000)

        if result.status == :failed do
          Mix.shell().error(result.output)
          System.at_exit(fn _ -> exit({:shutdown, 1}) end)
        end
    end

    :ok
  end

  @spec generate_quality_report() :: :ok
  defp generate_quality_report do
    Mix.shell().info("📋 Generating comprehensive quality report...")

    # This would generate a detailed report
    # For now, just run the comprehensive analysis
    run_comprehensive_quality_analysis([])

    :ok
  end

  @spec start_continuous_monitoring() :: :ok
  defp start_continuous_monitoring do
    Mix.shell().info("🔍 Starting continuous quality monitoring...")
    Mix.shell().info("Press Ctrl + C to stop monitoring")

    # Every 30 seconds
    interval_stream = Stream.interval(30_000)

    interval_stream
    |> Enum.each(fn _i ->
      Mix.shell().info("\n--- Quality Check: #{DateTime.utc_now()} ---")
      run_comprehensive_quality_analysis([])
    end)

    :ok
  end

  @spec show_help() :: :ok
  defp show_help do
    Mix.shell().info("""
    #{IO.ANSI.bright()}mix quality#{IO.ANSI.reset()} - Comprehensive Enterprise Quality Assurance

    #{IO.ANSI.bright()}USAGE:#{IO.ANSI.reset()}
        mix quality [options]

    #{IO.ANSI.bright()}OPTIONS:#{IO.ANSI.reset()}
        --gate, -g GATE     Run specific quality gate
        --report, -r        Generate quality report
        --monitor, -m       Start continuous monitoring
        --parallel, -p      Run quality gates in parallel
        --timeout, -t MS    Set timeout in milliseconds
        --help, -h          Show this help

    #{IO.ANSI.bright()}AVAILABLE QUALITY GATES:#{IO.ANSI.reset()}
    """)

    show_available_gates()

    Mix.shell().info("""

    #{IO.ANSI.bright()}EXAMPLES:#{IO.ANSI.reset()}
        mix quality                    # Run all quality gates
        mix quality --gate compilation # Run only compilation gate
        mix quality --parallel         # Run gates in parallel
        mix quality --report           # Generate quality report
        mix quality --monitor          # Continuous monitoring
    """)
  end

  @spec show_available_gates() :: :ok
  defp show_available_gates do
    Enum.each(@quality_gates, fn {gate_id, gate_config} ->
      Mix.shell().info("        #{gate_id} - #{gate_config.name}")
      Mix.shell().info("            #{gate_config.description}")
    end)
  end
end
