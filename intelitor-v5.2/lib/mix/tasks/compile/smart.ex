defmodule Mix.Tasks.Compile.Smart do
  @moduledoc """
  Intelligent compilation strategy that adapts based on project changes.

  Analyzes recent changes and automatically selects the optimal compilation
  strategy for maximum developer productivity.

  ## Usage

      mix compile.smart

  ## Options

    * `--force - strategy` - Override automatic detection with specific strategy
      Available: ultra_fast, fast, standard (default: auto - detect)
    * `--benchmark` - Show compilation timing and strategy selection reasoning

  ## Strategy Selection Logic

  1. **Ultra - Fast**: Minor changes, config only, or server startup needed
  2. **Fast**: Moderate changes, development iteration, or dependency updates
  3. **Standard**: Extensive changes, new files, or pre - commit validation

  This task optimizes the development workflow by providing the fastest
  safe compilation strategy based on actual project state.
  """
  use Mix.Task

  @shortdoc "Intelligent compilation with automatic strategy selection"

  @switches [
    force_strategy: :string,
    benchmark: :boolean
  ]

  @strategies [:ultra_fast, :fast, :standard]

  @spec run(any()) :: any()
  def run(args) do
    {opts, _} = OptionParser.parse!(args, switches: @switches)

    strategy =
      case opts[:force_strategy] do
        nil ->
          analyze_and_select_strategy()

        forced_strategy ->
          strategy_atom = String.to_existing_atom(forced_strategy)

          if strategy_atom in @strategies do
            strategy_atom
          else
            Mix.shell().error(
              "Invalid strategy: #{forced_strategy}. Available: #{Enum.join(@strategies, ", ")}"
            )

            exit(1)
          end
      end

    if opts[:benchmark] do
      show_strategy_reasoning(strategy)
    end

    execute_strategy(strategy, opts)
  end

  @spec analyze_and_select_strategy() :: any()
  defp analyze_and_select_strategy do
    changes = analyze_git_changes()
    file_changes = analyze_file_changes()
    dependency_changes = analyze_dependency_changes()

    cond do
      # Ultra - fast conditions
      changes.total_files <= 2 and changes.config_only? ->
        :ultra_fast

      file_changes.only_test_files? ->
        :ultra_fast

      dependency_changes.deps_unchanged? and changes.total_files <= 5 ->
        :ultra_fast

      # Fast conditions
      changes.total_files <= 15 and not changes.new_files? ->
        :fast

      file_changes.mostly_existing_files? ->
        :fast

      # Standard conditions (safety first)
      true ->
        :standard
    end
  end

  @spec analyze_git_changes() :: any()
  defp analyze_git_changes do
    {output, 0} = System.cmd("git", ["diff", "--name-status", "HEAD~1"], stderr_to_stdout: true)

    lines = String.split(output, "

# Agent: Helper-2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cybernetic coordination
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement

", trim: true)

    files =
      Enum.map(lines, fn line ->
        [status | file_parts] = String.split(line, "\t")
        file = Enum.join(file_parts, "\t")
        {status, file}
      end)

    %{
      total_files: length(files),
      new_files?: Enum.any?(files, fn {status, _} -> status == "A" end),
      deleted_files?: Enum.any?(files, fn {status, _} -> status == "D" end),
      config_only?:
        Enum.all?(files, fn {_, file} ->
          String.starts_with?(file, "config/") or String.ends_with?(file, ".md")
        end),
      lib_changes: Enum.count(files, fn {_, file} -> String.starts_with?(file, "lib/") end),
      test_changes: Enum.count(files, fn {_, file} -> String.starts_with?(file, "test/") end)
    }
  rescue
    _ ->
      # Fallback if git analysis fails
      %{
        total_files: 10,
        new_files?: false,
        deleted_files?: false,
        config_only?: false,
        lib_changes: 5,
        test_changes: 2
      }
  end

  @spec analyze_file_changes() :: any()
  defp analyze_file_changes do
    lib_files = Path.wildcard("lib/**/*.ex")
    test_files = Path.wildcard("test/**/*.exs")

    recent_lib_changes = Enum.count(lib_files, &recently_modified?/1)
    recent_test_changes = Enum.count(test_files, &recently_modified?/1)

    %{
      only_test_files?: recent_lib_changes == 0 and recent_test_changes > 0,
      mostly_existing_files?: recent_lib_changes < 10,
      heavy_lib_changes?: recent_lib_changes > 20
    }
  end

  @spec analyze_dependency_changes() :: any()
  defp analyze_dependency_changes do
    mix_lock_time = get_file_mtime("mix.lock")
    mix_exs_time = get_file_mtime("mix.exs")
    one_hour_ago = DateTime.add(DateTime.utc_now(), -3600)

    # Convert file times to DateTime if they're not already
    mix_lock_dt = ensure_datetime(mix_lock_time)
    mix_exs_dt = ensure_datetime(mix_exs_time)

    %{
      deps_unchanged?:
        DateTime.compare(mix_lock_dt, one_hour_ago) == :lt and
          DateTime.compare(mix_exs_dt, one_hour_ago) == :lt,
      recent_dep_changes?:
        DateTime.compare(mix_lock_dt, one_hour_ago) == :gt or
          DateTime.compare(mix_exs_dt, one_hour_ago) == :gt
    }
  end

  @spec ensure_datetime(term()) :: term()
  defp ensure_datetime(%DateTime{} = dt), do: dt

  defp ensure_datetime(timestamp) when is_integer(timestamp) do
    DateTime.from_unix!(timestamp)
  end

  defp ensure_datetime(_), do: DateTime.utc_now()

  defp recently_modified?(file_path) do
    case File.stat(file_path) do
      {:ok, %{mtime: mtime}} ->
        file_time = NaiveDateTime.from_erl!(mtime)
        one_hour_ago = NaiveDateTime.add(NaiveDateTime.utc_now(), -3600)
        NaiveDateTime.compare(file_time, one_hour_ago) == :gt

      _ ->
        false
    end
  end

  @spec get_file_mtime(term()) :: term()
  defp get_file_mtime(filepath) do
    case File.stat(filepath) do
      {:ok, %{mtime: mtime}} -> NaiveDateTime.from_erl!(mtime)
      _ -> ~N[1970-01-01 00:00:00]
    end
  end

  @spec show_strategy_reasoning(term()) :: term()
  defp show_strategy_reasoning(strategy) do
    reason =
      case strategy do
        :ultra_fast -> "Minimal changes detected - using maximum speed optimization"
        :fast -> "Moderate changes detected - using fast development compilation"
        :standard -> "Extensive changes detected - using full validation compilation"
      end

    Mix.shell().info("""

    SMART COMPILATION ANALYSIS
    ═══════════════════════════════════════════════════════════════════

    Selected Strategy: #{String.upcase(to_string(strategy))}
    Reasoning: #{reason}

    """)
  end

  @spec execute_strategy(term(), term()) :: term()
  defp execute_strategy(strategy, opts) do
    start_time = System.monotonic_time(:millisecond)

    Mix.shell().info("[LAUNCH] Executing #{strategy} compilation strategy...")

    result =
      case strategy do
        :ultra_fast ->
          Mix.Task.run("compile.ultra_fast")

        :fast ->
          Mix.Task.run("compile.fast", if(opts[:benchmark], do: ["--benchmark"], else: []))

        :standard ->
          Mix.Task.run("compile", ["--warnings-as-errors", "--force"])
      end

    if opts[:benchmark] do
      duration = System.monotonic_time(:millisecond) - start_time

      Mix.shell().info("[STATS] Smart compilation completed in #{duration}ms")
    end

    result
  end
end
