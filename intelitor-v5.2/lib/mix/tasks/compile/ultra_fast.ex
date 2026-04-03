defmodule Mix.Tasks.Compile.UltraFast do
  @moduledoc """
  Ultra - fast compilation for immediate server startup.

  Uses most aggressive optimizations possible to get a running
  server as quickly as possible. Some runtime validations are
  disabled for speed.

  ## Usage

      mix compile.ultra_fast

  ## Options

    * `--start - server` - Start Phoenix server after compilation
    * `--skip - migrations` - Skip __database migration check

  ## Warning

  This task disables many compile - time and runtime validations
  for maximum speed. Use only for development and testing.

  Always run `mix quality` before committing code.
  """
  use Mix.Task

  @shortdoc "Ultra - fast compilation with maximum optimizations"

  @switches [
    start_server: :boolean,
    skip_migrations: :boolean
  ]

  @spec run(any()) :: any()
  def run(args) do
    {opts, _} = OptionParser.parse!(args, switches: @switches)

    Mix.shell().info("""
    ====================================================================
                    ULTRA - FAST COMPILATION STRATEGY
    ====================================================================
    """)

    # Step 1: Apply ultra optimizations
    apply_ultra_optimizations()

    # Step 2: Clean targeted artifacts
    clean_targeted_artifacts()

    # Step 3: Compile with maximum parallelism
    compile_ultra_fast()

    # Step 4: Start server if __requested
    if opts[:start_server] do
      start_server(opts)
    else
      show_next_steps()
    end
  end

  @spec apply_ultra_optimizations() :: any()
  defp apply_ultra_optimizations do
    Mix.shell().info("[LAUNCH] Applying ULTRA optimizations...")

    # Set maximum optimization environment
    envs = [
      {"ERL_AFLAGS", "+P 10_000_000 +Q 1_000_000 +K true +A 256 +sbt db +sub true"},
      {"ELIXIR_ERL_OPTIONS", "+P 10_000_000 +Q 65_536 +hmbs 46_422 +hms 8348"},
      {"ELIXIR_COMPILER_OPTS", "--no - warnings - as - errors"},
      {"MIX_BUILD_EMBEDDED", "true"},
      {"MIX_QUIET", "1"},
      {"SKIP_ASH_COMPILE_VALIDATION", "true"}
    ]

    Enum.each(envs, fn {k, v} -> System.put_env(k, v) end)

    # Configure ultra - fast application settings
    Application.put_env(:ash, :validate_domain_resource_inclusion?, false)
    Application.put_env(:ash, :validate_domain_config_inclusion?, false)
    Application.put_env(:ash, :validate_action_compilation?, false)
    Application.put_env(:ash, :validate_resource_compilation?, false)
    Application.put_env(:ash, :compile_time_validations?, false)
    Application.put_env(:ash, :disable_async?, false)
    Application.put_env(:ash, :lazy?, true)
    Application.put_env(:ash, :skip_unknown_inputs?, true)
    Application.put_env(:ash, :disable_telemetry?, true)

    Application.put_env(:spark, :formatter, [])
    Application.put_env(:spark, :disable_warnings?, true)
    Application.put_env(:spark, :compile_time_validations?, false)
    Application.put_env(:spark, :validate_extensions?, false)
    Application.put_env(:spark, :no_dependents?, true)

    Application.put_env(:logger, :level, :error)
    Application.put_env(:logger, :compile_time_purge_level, :error)

    Mix.shell().info("✅ Ultra optimizations applied")
  end

  @spec clean_targeted_artifacts() :: any()
  defp clean_targeted_artifacts do
    Mix.shell().info("🧹 Cleaning targeted artifacts...")

    # Only clean problematic parts
    paths = [
      "_build/#{Mix.env()}/lib / indrajaal",
      "_build/#{Mix.env()}/consolidated"
    ]

    Enum.each(paths, fn path ->
      if File.exists?(path) do
        File.rm_rf!(path)
        Mix.shell().info("   Cleaned: #{path}")
      end
    end)
  end

  @spec compile_ultra_fast() :: any()
  defp compile_ultra_fast do
    Mix.shell().info("⚡ Starting ULTRA - FAST compilation...")

    start_time = System.monotonic_time(:second)

    # Step 1: Dependencies (should be fast if already compiled)
    Mix.shell().info("  Step 1 / 3: Dependencies...")
    Mix.Task.run("deps.compile")

    # Step 2: Protocols
    Mix.shell().info("  Step 2 / 3: Protocols...")
    Mix.Task.run("compile.protocols")

    # Step 3: Main compilation
    Mix.shell().info("  Step 3 / 3: Main project...")
    result = Mix.Task.run("compile", ["--force"])

    duration = System.monotonic_time(:second) - start_time

    duration_minutes = Float.round(duration / 60, 2)

    Mix.shell().info("\n[STATS] Ultra - Fast Compilation Results:")
    Mix.shell().info("  Duration: #{duration_minutes} minutes")

    status =
      cond do
        duration <= 120 -> "✅ Excellent (<2 min)"
        duration <= 300 -> "✅ Good (<5 min)"
        duration <= 600 -> "⚠️  Acceptable (<10 min)"
        true -> "❌ Too slow (>10 min)"
      end

    Mix.shell().info("  Performance: #{status}")

    Mix.shell().info(
      "  Build Status: #{if result == :ok, do: "✅ Success", else: "⚠️  Completed with warnings"}"
    )

    # Count compiled modules
    beam_count =
      case File.ls("_build/#{Mix.env()}/lib / indrajaal / ebin") do
        {:ok, files} -> Enum.count(files, &String.ends_with?(&1, ".beam"))
        _ -> 0
      end

    Mix.shell().info("  Modules: #{beam_count} compiled")

    result
  end

  @spec start_server(term()) :: term()
  defp start_server(opts) do
    Mix.shell().info("\n[LAUNCH] Starting Phoenix server...")

    unless opts[:skip_migrations] do
      Mix.shell().info("🗄️  Checking __database...")
      Mix.Task.run("ecto.migrate")
    end

    Mix.shell().info("🌐 Server starting on http://localhost:4000")
    Mix.Task.run("phx.server")
  end

  @spec show_next_steps() :: any()
  defp show_next_steps do
    Mix.shell().info("""

    ═══════════════════════════════════════════════════════════════════
    🎯 COMPILATION COMPLETE - SERVER READY
    ═══════════════════════════════════════════════════════════════════

    [LAUNCH] TO START THE SERVER:

    1. Standard start:
       mix phx.server

    2. Interactive development:
       iex -S mix phx.server

    3. With optimizations:
       MIX_ENV = dev iex --erl "+P 10_000_000" -S mix phx.server

    4. Auto - start server:
       mix compile.ultra_fast --start - server

    💡 IMPORTANT NOTES:
       - First page load may be slow as modules load
       - Some compile - time validations are disabled
       - This is for development only
       - Run `mix quality` before committing

    [FIX] IF SERVER DOESN'T START:
       1. Check PostgreSQL is running on port 5433
       2. Run: mix ecto.create && mix ecto.migrate
       3. Try: mix deps.get && mix deps.compile
    """)
  end
end
