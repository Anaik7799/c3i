defmodule Mix.Tasks.Compile.Benchmark do
  @moduledoc """
  Benchmarks compilation performance and provides optimization recommendations.

  Tests different compilation strategies and measures their performance
  to help optimize the development workflow.

  ## Usage

      mix compile.benchmark

  ## Options

    * `--strategies` - Comma - separated list of strategies to test
      Available: normal, fast, ultra_fast (default: all)
    * `--iterations` - Number of iterations per strategy (default: 3)
    * `--clean` - Clean build before each test (default: true)

  ## Example

      mix compile.benchmark --strategies = fast,ultra_fast --iterations = 2

  This task helps identify the best compilation strategy for your
  development workflow and hardware configuration.
  """
  use Mix.Task

  @shortdoc "Benchmark compilation performance"

  @switches [
    strategies: :string,
    iterations: :integer,
    clean: :boolean
  ]

  @default_strategies ["normal", "fast", "ultra_fast"]

  @spec run(any()) :: any()
  def run(args) do
    {opts, _} = OptionParser.parse!(args, switches: @switches)

    strategies = parse_strategies(opts[:strategies])
    iterations = opts[:iterations] || 3
    clean = opts[:clean] != false

    Mix.shell().info("""
    ╔══════════════════════════════════════════════════════════════════╗
    ║                   COMPILATION BENCHMARK SUITE                    ║
    ╚══════════════════════════════════════════════════════════════════╝

    Testing #{length(strategies)} strategies with #{iterations} iterations each
    Clean builds: #{if clean, do: "enabled", else: "disabled"}
    """)

    results = run_benchmarks(strategies, iterations, clean)
    display_results(results)
    provide_recommendations(results)
  end

  @spec parse_strategies(term()) :: term()
  defp parse_strategies(nil), do: @default_strategies

  defp parse_strategies(str) do
    str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(&1 in @default_strategies))
  end

  defp run_benchmarks(strategies, iterations, clean) do
    Enum.map(strategies, fn strategy ->
      Mix.shell().info("

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
\n🧪 Testing #{strategy} compilation...")

      times = run_strategy_iterations(strategy, iterations, clean)

      %{
        strategy: strategy,
        times: times,
        avg_time: Enum.sum(times) / length(times),
        min_time: Enum.min(times),
        max_time: Enum.max(times)
      }
    end)
  end

  defp run_strategy_iterations(strategy, iterations, clean) do
    1..iterations
    |> Enum.map(fn i ->
      Mix.shell().info("  Iteration #{i}/#{iterations}...")

      if clean do
        clean_build()
      end

      run_single_benchmark(strategy)
    end)
  end

  @spec run_single_benchmark(term()) :: term()
  defp run_single_benchmark(strategy) do
    start_time = System.monotonic_time(:millisecond)

    case strategy do
      "normal" ->
        Mix.Task.clear()
        Mix.Task.run("compile", ["--force"])

      "fast" ->
        Mix.Task.clear()
        Mix.Task.run("compile.fast", ["--benchmark"])

      "ultra_fast" ->
        Mix.Task.clear()
        Mix.Task.run("compile.ultra_fast")
    end

    System.monotonic_time(:millisecond) - start_time
  end

  @spec clean_build() :: any()
  defp clean_build do
    File.rm_rf!("_build/#{Mix.env()}/lib / indrajaal")
    File.rm_rf!("_build/#{Mix.env()}/consolidated")
  end

  @spec display_results(term()) :: term()
  defp display_results(results) do
    Mix.shell().info("""

    ═══════════════════════════════════════════════════════════════════
    [STATS] BENCHMARK RESULTS
    ═══════════════════════════════════════════════════════════════════
    """)

    # Sort by average time
    sorted_results = Enum.sort_by(results, & &1.avg_time)

    Enum.each(sorted_results, fn result ->
      avg_s = Float.round(result.avg_time / 1000, 2)
      min_s = Float.round(result.min_time / 1000, 2)
      max_s = Float.round(result.max_time / 1000, 2)

      status =
        cond do
          result.avg_time < 30_000 -> "✅ EXCELLENT"
          result.avg_time < 60_000 -> "🟡 ACCEPTABLE"
          result.avg_time < 120_000 -> "🟠 SLOW"
          true -> "❌ TOO SLOW"
        end

      Mix.shell().info("""
      📈 #{String.upcase(result.strategy)} STRATEGY:
         Average: #{avg_s}s
         Range: #{min_s}s - #{max_s}s
         Status: #{status}
      """)
    end)
  end

  @spec provide_recommendations(term()) :: term()
  defp provide_recommendations(results) do
    fastest = Enum.min_by(results, & &1.avg_time)
    slowest = Enum.max_by(results, & &1.avg_time)

    speedup =
      if slowest.avg_time > 0 do
        Float.round(slowest.avg_time / fastest.avg_time, 1)
      else
        1.0
      end

    Mix.shell().info("""
    ═══════════════════════════════════════════════════════════════════
    💡 RECOMMENDATIONS
    ═══════════════════════════════════════════════════════════════════

    🏆 FASTEST STRATEGY: #{fastest.strategy}
       Average time: #{Float.round(fastest.avg_time / 1000, 2)}s
       #{speedup}x faster than slowest strategy

    📋 RECOMMENDED WORKFLOW:

    1. Daily development:
       mix compile.#{fastest.strategy}

    2. Before committing:
       mix quality

    3. Full validation:
       mix quality.full

    4. Add to your .bashrc/.zshrc:
       alias _mf ="mix compile.#{fastest.strategy}"
       alias _mq ="mix quality"

    ⚡ OPTIMIZATION TIPS:

    #{optimization_tips(results)}
    """)
  end

  @spec optimization_tips(term()) :: term()
  defp optimization_tips(results) do
    avg_time =
      results
      |> Enum.map(& &1.avg_time)
      |> Enum.sum()
      |> Kernel./(length(results))

    cond do
      avg_time > 120_000 ->
        """
        - Your system shows slow compilation times (>2min average)
        - Consider upgrading RAM (16GB+ recommended)
        - Use SSD storage for faster I / O
        - Close memory - intensive applications during compilation
        - Consider using mix compile.ultra_fast for development
        """

      avg_time > 60_000 ->
        """
        - Compilation times are moderate (1 - 2min average)
        - mix compile.fast should provide good speedup
        - Consider incremental compilation strategies
        - Monitor memory usage during compilation
        """

      true ->
        """
        - Your system has good compilation performance (<1min average)
        - Current strategies should work well for development
        - Consider using mix compile.fast for routine work
        - mix compile.ultra_fast for maximum speed when needed
        """
    end
  end
end
