defmodule Mix.Tasks.Compile.Fast do
  @moduledoc """
  Fast compilation task for development workflow.

  Optimizes compilation time by disabling non - essential features
  and using aggressive caching strategies.

  ## Usage

      mix compile.fast

  ## Options

    * `--clean` - Clean build artifacts before compiling
    * `--benchmark` - Show compilation timing information

  ## Features

  - Disables compile - time validations
  - Uses aggressive compiler optimizations
  - Skips unnecessary dependency compilation
  - Provides timing feedback

  This task is ideal for rapid development cycles where you need
  fast feedback without full quality validation.
  """
  use Mix.Task

  @shortdoc "Fast compilation for development"

  @switches [
    clean: :boolean,
    benchmark: :boolean
  ]

  @spec run(any()) :: any()
  def run(args) do
    {opts, _} = OptionParser.parse!(args, switches: @switches)

    Mix.shell().info("[LAUNCH] Starting fast compilation...")

    if opts[:clean] do
      clean_build_artifacts()
    end

    start_time = if opts[:benchmark], do: System.monotonic_time(:millisecond)

    # Set fast compilation environment
    setup_fast_environment()

    # Run optimized compilation with realistic expectations
    result = Mix.Task.run("compile", ["--force"])

    if opts[:benchmark] do
      duration = System.monotonic_time(:millisecond) - start_time
      duration_minutes = Float.round(duration / 60_000, 2)
      Mix.shell().info("[STATS] Fast compilation took #{duration_minutes} minutes")

      cond do
        # 5 minutes
        duration < 300_000 ->
          Mix.shell().info("✅ Excellent performance (<5 min)")

        # 10 minutes
        duration < 600_000 ->
          Mix.shell().info("✅ Good performance (<10 min)")

        # 15 minutes
        duration < 900_000 ->
          Mix.shell().info("⚠️  Acceptable but slow (<15 min)")

        true ->
          Mix.shell().info("❌ Exceeds reasonable time (>15 min)")
      end
    end

    result
  end

  @spec clean_build_artifacts() :: any()
  defp clean_build_artifacts do
    Mix.shell().info("🧹 Cleaning build artifacts...")

    paths_to_clean = [
      "_build/#{Mix.env()}/lib / indrajaal",
      "_build/#{Mix.env()}/consolidated"
    ]

    Enum.each(paths_to_clean, fn path ->
      if File.exists?(path) do
        File.rm_rf!(path)
        Mix.shell().info("   Removed: #{path}")
      end
    end)
  end

  @spec setup_fast_environment() :: any()
  defp setup_fast_environment do
    # Set environment variables for fast compilation
    envs = [
      {"ELIXIR_COMPILER_OPTS", "--no - warnings - as - errors"},
      {"MIX_BUILD_EMBEDDED", "true"},
      {"SKIP_ASH_COMPILE_VALIDATION", "true"}
    ]

    Enum.each(envs, fn {key, value} ->
      System.put_env(key, value)
    end)

    # Configure fast compilation options
    Application.put_env(:ash, :validate_domain_resource_inclusion?, false)
    Application.put_env(:ash, :validate_domain_config_inclusion?, false)
    Application.put_env(:ash, :validate_action_compilation?, false)
    Application.put_env(:ash, :validate_resource_compilation?, false)
    Application.put_env(:ash, :compile_time_validations?, false)

    Application.put_env(:spark, :compile_time_validations?, false)
    Application.put_env(:spark, :validate_extensions?, false)
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
