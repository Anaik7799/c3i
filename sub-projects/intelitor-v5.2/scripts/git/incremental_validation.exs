#!/usr/bin/env elixir

defmodule GitIncrementalValidation do
  @moduledoc """
  Git-Based Incremental Validation CLI

  MANDATORY: All validation activities MUST use incremental approach based on git changes
  to optimize performance and ensure only necessary validation is performed.

  This script provides comprehensive git-based incremental validation including:-Smart file change detection
  - Incremental compilation and testing
  - Container-aware validation execution
  - SOPv5.1 cybernetic coordination
  - Performance optimization and caching

  Usage:
    elixir scripts/git/incremental_validation.exs --check
    elixir scripts/git/incremental_validation.exs --validate
    elixir scripts/git/incremental_validation.exs --test-only
    elixir scripts/git/incremental_validation.exs --full
    elixir scripts/git/incremental_validation.exs --status

  Agent: Worker-1 coordinates git-based incremental validation
  SOPv5.1 Compliance: ✅ Cybernetic optimization with systematic performance tracking
  """

  @spec main(any()) :: any()
  def main(args \\ []) do
    start_time = DateTime.utc_now()

    # Parse command line arguments
    options = parse_args(args)

    # Display header
    display_header()

    # Execute __requested operations
    case options.action do
      :check -> perform_change_check()
      :validate -> perform_incremental_validation(options)
      :test_only -> perform_test_only_validation(options)
      :full -> perform_full_validation(options)
      :status -> show_git_status()
      :help -> display_help()
      _ -> display_help()
    end

    # Display completion summary
    execution_time = DateTime.diff(DateTime.utc_now(), start_time, :second)
    IO.puts("\n✅ Git incremental validation completed in #{execution_time} second
    IO.puts("🔄 Current system time: #{DateTime.utc_now()}")
  end

  @spec parse_args(term()) :: term()
  defp parse_args(args) do
    base_options = %{
      action: :help,
      container_mode: true,
      phics_enabled: true,
      force_tests: false,
      parallel: true,
      timeout: 300
    }

    case args do
      ["--check"] -> %{base_options | action: :check}
      ["--validate"] -> %{base_options | action: :validate}
      ["--test-only"] -> %{base_options | action: :test_only}
      ["--full"] -> %{base_options | action: :full, force_tests: true}
      ["--status"] -> %{base_options | action: :status}
      ["--help"] -> %{base_options | action: :help}
      [] -> %{base_options | action: :help}
      _ -> %{base_options | action: :help}
    end
  end

  @spec display_header() :: any()
  defp display_header do
    IO.puts("""
    ================================================================
    🔄 MANDATORY: Git-Based Incremental Validation System
    ================================================================

    🎯 CRITICAL: Optimize validation using git change detection
    📅 Current Time: #{DateTime.utc_now()}
    🔄 Approach: Incremental validation based on git diff analysis
    ✅ Benefits: Performance optimization, systematic validation

    Agent: Worker-1-Git-Based Incremental Coordination
    SOPv5.1 Compliance: ✅ Cybernetic performance optimization
    """)
  end

  @spec perform_change_check() :: any()
  defp perform_change_check do
    IO.puts("\n🔍 CHECKING for git changes...")

    # Get current git status
    case get_git_status() do
      {:ok, status} ->
        display_git_status(status)

        # Get changed files
        case get_changed_files() do
          {:ok, changed_files} ->
            display_changed_files(changed_files)

            # Determine validation needs
            case create_validation_plan(changed_files) do
              {:ok, validation_plan} ->
                display_validation_plan(validation_plan)
              {:error, reason} ->
                IO.puts("❌ Failed to create validation plan: #{reason}")
            end

          {:error, reason} ->
            IO.puts("❌ Failed to get changed files: #{reason}")
        end

      {:error, reason} ->
        IO.puts("❌ Failed to get git status: #{reason}")
    end
  end

  @spec perform_incremental_validation(term()) :: term()
  defp perform_incremental_validation(options) do
    IO.puts("\n🚀 PERFORMING incremental validation...")

    with {:ok, changed_files} <- get_changed_files(),
         {:ok, validation_plan} <- create_validation_plan(changed_files),
         {:ok, results} <- execute_validation_plan(validation_plan, options) do

      display_validation_results(results)
      log_validation_activity(changed_files, validation_plan, results)

      if all_validations_passed?(results) do
        IO.puts("\n🎉 ALL INCREMENTAL VALIDATIONS PASSED!")
        System.halt(0)
      else
        IO.puts("\n❌ SOME VALIDATIONS FAILED-Review results above")
        System.halt(1)
      end

    else
      {:error, reason} ->
        IO.puts("❌ Incremental validation failed: #{reason}")
        System.halt(1)
    end
  end

  @spec perform_test_only_validation(term()) :: term()
  defp perform_test_only_validation(options) do
    IO.puts("\n🧪 PERFORMING test-only incremental validation...")

    with {:ok, changed_files} <- get_changed_files(),
         {:ok, test_files} <- get_affected_tests(changed_files),
         {:ok, test_results} <- run_incremental_tests(test_files, options) do

      display_test_results(test_results)
      log_test_activity(changed_files, test_files, test_results)

      if test_results.status == :success do
        IO.puts("\n🎉 ALL INCREMENTAL TESTS PASSED!")
        System.halt(0)
      else
        IO.puts("\n❌ SOME TESTS FAILED-Review results above")
        System.halt(1)
      end

    else
      {:error, reason} ->
        IO.puts("❌ Test-only validation failed: #{reason}")
        System.halt(1)
    end
  end

  @spec perform_full_validation(term()) :: term()
  defp perform_full_validation(options) do
    IO.puts("\n🔄 PERFORMING full validation (non-incremental)...")

    full_validation_commands = [
      {"Compilation", ["mix", "compile", "--warnings-as-errors"]},
      {"Testing", ["mix", "test", "--coverage"]},
      {"Linting", ["mix", "credo", "--strict"]},
      {"Formatting", ["mix", "format", "--check-formatted"]},
      {"Dialyzer", ["mix", "dialyzer"]}
    ]

    _results = Enum.map(full_validation_commands, fn {name, command} ->
      IO.puts("  🔄 Running #{name}...")

      case run_command(command, options) do
        {:ok, result} ->
          IO.puts("  ✅ #{name}: #{result.status}")
          {name, :success, result}

        {:error, reason} ->
          IO.puts("  ❌ #{name}: Failed-#{reason}")
          {name, :failed, reason}
      end
    end)

    display_full_validation_results(results)

    failed_validations = Enum.filter(results, fn {_, status, _} -> status == :failed end)

    if length(failed_validations) == 0 do
      IO.puts("\n🎉 ALL FULL VALIDATIONS PASSED!")
      System.halt(0)
    else
      IO.puts("\n❌ #{length(failed_validations)} VALIDATIONS FAILED")
      System.halt(1)
    end
  end

  @spec show_git_status() :: any()
  defp show_git_status do
    IO.puts("\n📊 GIT REPOSITORY STATUS...")

    case get_git_status() do
      {:ok, status} ->
        display_detailed_git_status(status)

      {:error, reason} ->
        IO.puts("❌ Failed to get git status: #{reason}")
    end
  end

  @spec display_help() :: any()
  defp display_help do
    IO.puts("""

    📖 USAGE INSTRUCTIONS:

    --check         Check git changes and determine validation needs (read-only)
    --validate      Run incremental validation based on changed files
    --test-only     Run only tests affected by changed files
    --full          Run full validation suite (non-incremental)
    --status        Show detailed git repository status
    --help          Show this help message

    🎯 EXAMPLES:

    # Check what validation is needed (safe, read-only)
    elixir scripts/git/incremental_validation.exs --check

    # Run incremental validation
    elixir scripts/git/incremental_validation.exs --validate

    # Run only affected tests
    elixir scripts/git/incremental_validation.exs --test-only

    # Run complete validation suite
    elixir scripts/git/incremental_validation.exs --full

    ⚠️  IMPORTANT NOTES:

    • Incremental validation analyzes git changes to optimize performance
    • Container mode is enabled by default for all validation activities
    • PHICS integration ensures hot-reloading compatibility
    • Current system time: #{DateTime.utc_now()}
    • All validation follows SOPv5.1 cybernetic coordination principles
    """)
  end

  # ============================================================================
  # Core Implementation
  # ============================================================================

  @spec get_git_status() :: any()
  defp get_git_status do
    with {:ok, branch} <- run_git_command(["rev-parse", "--abbrev-ref", "HEAD"]),
         {:ok, commit} <- run_git_command(["rev-parse", "HEAD"]),
         {:ok, status} <- run_git_command(["status", "--porcelain"]),
         {:ok, log} <- run_git_command(["log", "--oneline", "-5"]) do

      {:ok, %{
        branch: String.trim(branch),
        commit_hash: String.trim(commit) |> String.slice(0, 8),
        has_changes: String.trim(status) != "",
        status_output: String.trim(status),
        recent_commits: String.split(log, "\n", trim: true),
        timestamp: DateTime.utc_now()
      }}
    else
      {:error, _} = error -> error
    end
  end

  @spec get_changed_files(String.t()) :: term()
  defp get_changed_files(base \\ "HEAD~1") do
    case run_git_command(["diff", base, "--name-only"]) do
      {:ok, output} ->
        changed_files =
          output
          |> String.split("\n", trim: true)
          |> Enum.filter(&File.exists?/1)
          |> categorize_files()

        {:ok, changed_files}

      {:error, _} = error -> error
    end
  end

  @spec get_affected_tests(term()) :: term()
  defp get_affected_tests(changed_files) do
    # Get direct test files
    direct_tests = Map.get(changed_files, :tests, [])

    # Get tests for changed Elixir files
    elixir_files = Map.get(changed_files, :elixir, [])
    corresponding_tests = Enum.flat_map(elixir_files, &find_corresponding_test_files/1)

    # Get integration tests if config changed
    integration_tests = if Map.has_key?(changed_files, :config) do
      find_integration_tests()
    else
      []
    end

    all_tests = (direct_tests ++ corresponding_tests ++ integration_tests)
    |> Enum.uniq()
    {:ok, all_tests}
  end

  @spec find_corresponding_test_files(term()) :: term()
  defp find_corresponding_test_files(elixir_file) do
    test_file = elixir_file
    |> String.replace(~r/^lib\//, "test/")
    |> String.replace(~r/\.ex$/, "_test.exs")

    if File.exists?(test_file) do
      [test_file]
    else
      []
    end
  end

  @spec find_integration_tests() :: any()
  defp find_integration_tests do
    Path.wildcard("test/**/*integration*_test.exs") ++
      Path.wildcard("test/**/*e2e*_test.exs")
  end

  @spec categorize_files(term()) :: term()
  defp categorize_files(file_list) do
    file_patterns = %{
      elixir: ~r/\.exs?$/,
      tests: ~r/_test\.exs?$/,
      config: ~r/config\/.*\.exs$/,
      mix: ~r/mix\.exs$/,
      documentation: ~r/\.(md|txt)$/,
      container: ~r/(Dockerfile|docker-compose|podman-compose).*\.(yml|yaml)$/,
      scripts: ~r/scripts\/.*\.exs?$/
    }

    Enum.reduce(file_list, %{}, fn file, acc ->
      category = determine_file_category(file, file_patterns)
      Map.update(acc, category, [file], fn existing -> [file | existing] end)
    end)
  end

  @spec determine_file_category(term(), term()) :: term()
  defp determine_file_category(file_path, patterns) do
    cond do
      Regex.match?(patterns.tests, file_path) -> :tests
      Regex.match?(patterns.config, file_path) -> :config
      Regex.match?(patterns.mix, file_path) -> :mix
      Regex.match?(patterns.elixir, file_path) -> :elixir
      Regex.match?(patterns.documentation, file_path) -> :documentation
      Regex.match?(patterns.container, file_path) -> :container
      Regex.match?(patterns.scripts, file_path) -> :scripts
      true -> :other
    end
  end

  @spec create_validation_plan(term()) :: term()
  defp create_validation_plan(changed_files) do
    plan = %{
      compile: should_compile?(changed_files),
      test: should_test?(changed_files),
      lint: should_lint?(changed_files),
      format: should_format?(changed_files),
      docs: should_update_docs?(changed_files),
      container: should_rebuild_containers?(changed_files)
    }

    {:ok, plan}
  end

  @spec should_compile?(term()) :: term()
  defp should_compile?(changed_files) do
    Map.has_key?(changed_files, :elixir) or
    Map.has_key?(changed_files, :mix) or
    Map.has_key?(changed_files, :config)
  end

  @spec should_test?(term()) :: term()
  defp should_test?(changed_files) do
    Map.has_key?(changed_files, :tests) or
    Map.has_key?(changed_files, :elixir) or
    Map.has_key?(changed_files, :config)
  end

  @spec should_lint?(term()) :: term()
  defp should_lint?(changed_files) do
    Map.has_key?(changed_files, :elixir) or Map.has_key?(changed_files, :scripts)
  end

  @spec should_format?(term()) :: term()
  defp should_format?(changed_files) do
    Map.has_key?(changed_files, :elixir) or Map.has_key?(changed_files, :scripts)
  end

  @spec should_update_docs?(term()) :: term()
  defp should_update_docs?(changed_files) do
    Map.has_key?(changed_files, :documentation) or Map.has_key?(changed_files, :elixir)
  end

  @spec should_rebuild_containers?(term()) :: term()
  defp should_rebuild_containers?(changed_files) do
    Map.has_key?(changed_files, :container) or Map.has_key?(changed_files, :config)
  end

  @spec execute_validation_plan(term(), term()) :: term()
  defp execute_validation_plan(plan, options) do
    results = %{}

    results = if plan.compile do
      IO.puts("  🔄 Running incremental compilation...")
      case run_compilation(options) do
        {:ok, result} -> Map.put(results, :compile, result)
        {:error, reason} -> Map.put(results, :compile, {:error, reason})
      end
    else
      Map.put(results, :compile, :skipped)
    end

    results = if plan.test do
      IO.puts("  🔄 Running incremental tests...")
      case run_incremental_tests([], options) do
        {:ok, result} -> Map.put(results, :test, result)
        {:error, reason} -> Map.put(results, :test, {:error, reason})
      end
    else
      Map.put(results, :test, :skipped)
    end

    results = if plan.lint do
      IO.puts("  🔄 Running incremental linting...")
      case run_linting(options) do
        {:ok, result} -> Map.put(results, :lint, result)
        {:error, reason} -> Map.put(results, :lint, {:error, reason})
      end
    else
      Map.put(results, :lint, :skipped)
    end

    results = if plan.format do
      IO.puts("  🔄 Running incremental formatting...")
      case run_formatting(options) do
        {:ok, result} -> Map.put(results, :format, result)
        {:error, reason} -> Map.put(results, :format, {:error, reason})
      end
    else
      Map.put(results, :format, :skipped)
    end

    {:ok, results}
  end

  @spec run_compilation(term()) :: term()
  defp run_compilation(options) do
    command = if options.container_mode do
      ["podman", "exec", "indrajaal-dev", "mix", "compile", "--warnings-as-errors"]
    else
      ["mix", "compile", "--warnings-as-errors"]
    end

    run_command(command, options)
  end

  @spec run_incremental_tests(term(), term()) :: term()
  defp run_incremental_tests(test_files, options) do
    base_command = if options.container_mode do
      ["podman", "exec", "indrajaal-dev", "mix", "test"]
    else
      ["mix", "test"]
    end

    command = if length(test_files) > 0 do
      base_command ++ test_files
    else
      base_command ++ ["--coverage"]
    end

    run_command(command, options)
  end

  @spec run_linting(term()) :: term()
  defp run_linting(options) do
    command = if options.container_mode do
      ["podman", "exec", "indrajaal-dev", "mix", "credo", "--strict"]
    else
      ["mix", "credo", "--strict"]
    end

    run_command(command, options)
  end

  @spec run_formatting(term()) :: term()
  defp run_formatting(options) do
    command = if options.container_mode do
      ["podman", "exec", "indrajaal-dev", "mix", "format", "--check-formatted"]
    else
      ["mix", "format", "--check-formatted"]
    end

    run_command(command, options)
  end

  @spec run_command(term(), term()) :: term()
  defp run_command(command, options) do
    timeout_ms = (options.timeout || 300) * 1000

    case System.cmd(List.first(command), List.delete_at(command, 0),
                   cd: ".", stderr_to_stdout: true, timeout: timeout_ms) do
      {output, 0} ->
        {:ok, %{status: :success, output: String.trim(output), command: Enum.join(command, " ")}}
      {error, exit_code} ->
        {:error,
      %{status: :failed,
      exit_code: exit_code, output: String.trim(error), command: Enum.join(command, " ")}}
    end
  end

  @spec run_git_command(term()) :: term()
  defp run_git_command(args) do
    case System.cmd("git", args, cd: ".", stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {error, _} -> {:error, String.trim(error)}
    end
  end

  # ============================================================================
  # Display Functions
  # ============================================================================

  @spec display_git_status(term()) :: term()
  defp display_git_status(status) do
    IO.puts("📊 Git Repository Status:")
    IO.puts("  🌿 Branch: #{status.branch}")
    IO.puts("  📋 Commit: #{status.commit_hash}")
    IO.puts("  🔄 Changes: #{if status.has_changes, do: "Yes", else: "No"}")

    if status.has_changes do
      IO.puts("  📝 Modified files:")
      String.split(status.status_output, "\n", trim: true)
      |> Enum.each(fn line ->
        IO.puts("    #{line}")
      end)
    end
  end

  @spec display_detailed_git_status(term()) :: term()
  defp display_detailed_git_status(status) do
    display_git_status(status)

    IO.puts("\n📜 Recent Commits:")
    Enum.each(status.recent_commits, fn commit ->
      IO.puts("  #{commit}")
    end)
  end

  @spec display_changed_files(term()) :: term()
  defp display_changed_files(changed_files) do
    IO.puts("\n📁 Changed Files by Category:")

    Enum.each(changed_files, fn {category, files} ->
      IO.puts("  📂 #{String.upcase(to_string(category))} (#{length(files)} files)
      Enum.each(files, fn file ->
        IO.puts("    📄 #{file}")
      end)
    end)

    total_files = changed_files |> Map.values() |> List.flatten() |> length()
    IO.puts("\n📊 Total changed files: #{total_files}")
  end

  @spec display_validation_plan(term()) :: term()
  defp display_validation_plan(plan) do
    IO.puts("\n🎯 Validation Plan:")

    Enum.each(plan, fn {action, needed} ->
      status = if needed, do: "✅ REQUIRED", else: "⏭️  SKIP"
      IO.puts("  #{String.upcase(to_string(action))}: #{status}")
    end)
  end

  @spec display_validation_results(term()) :: term()
  defp display_validation_results(results) do
    IO.puts("\n📊 Validation Results:")

    Enum.each(results, fn {action, result} ->
      case result do
        :skipped ->
          IO.puts("  ⏭️  #{String.upcase(to_string(action))}: SKIPPED")

        {:error, error_info} ->
          IO.puts("  ❌ #{String.upcase(to_string(action))}: FAILED")
          IO.puts("    Error: #{error_info}")

        %{status: :success} = success_info ->
          IO.puts("  ✅ #{String.upcase(to_string(action))}: SUCCESS")
          if Map.has_key?(success_info, :output) and String.length(success_info.output) > 0 do
            output_lines = String.split(success_info.output, "\n") |> Enum.take(3)
            Enum.each(output_lines, fn line ->
              IO.puts("    #{line}")
            end)
          end

        _ ->
          IO.puts("  ❓ #{String.upcase(to_string(action))}: UNKNOWN")
      end
    end)
  end

  @spec display_test_results(term()) :: term()
  defp display_test_results(test_results) do
    IO.puts("\n🧪 Test Results:")

    case test_results.status do
      :success ->
        IO.puts("  ✅ Tests: SUCCESS")
        if Map.has_key?(test_results, :files_tested) do
          IO.puts("  📁 Files tested: #{length(test_results.files_tested)}")
        end

      :failed ->
        IO.puts("  ❌ Tests: FAILED")
        if Map.has_key?(test_results, :output) do
          IO.puts("  📝 Output:")
          String.split(test_results.output, "\n")
    |> Enum.take(10) |> Enum.each(fn line ->
            IO.puts("    #{line}")
          end)
        end
    end
  end

  @spec display_full_validation_results(term()) :: term()
  defp display_full_validation_results(results) do
    IO.puts("\n📊 Full Validation Results:")

    Enum.each(results, fn {name, status, _result} ->
      case status do
        :success -> IO.puts("  ✅ #{name}: SUCCESS")
        :failed -> IO.puts("  ❌ #{name}: FAILED")
      end
    end)

    success_count = Enum.count(results, fn {_, status, _} -> status == :success end)
    total_count = length(results)

    IO.puts("\n📊 Summary: #{success_count}/#{total_count} validations passed")
  end

  @spec all_validations_passed?(term()) :: term()
  defp all_validations_passed?(results) do
    Enum.all?(results, fn {_action, result} ->
      case result do
        :skipped -> true
        %{status: :success} -> true
        _ -> false
      end
    end)
  end

  defp log_validation_activity(changed_files, validation_plan, results) do
    # Log to Claude logging system
    log_entry = %{
      timestamp: DateTime.utc_now(),
      activity: "git_incremental_validation",
      changed_files: changed_files,
      validation_plan: validation_plan,
      results: results,
      sopv51_compliance: true,
      agent: "Worker-1",
      container_mode: true,
      phics_enabled: true
    }

    log_file = "./__data/tmp/claude_git_incremental_validation_#{DateTime.utc_now()
    log_content = inspect(log_entry, pretty: true)

    File.write!(log_file, log_content)
    IO.puts("📄 Validation logged to: #{log_file}")
  end

  defp log_test_activity(changed_files, test_files, test_results) do
    # Log to Claude logging system
    log_entry = %{
      timestamp: DateTime.utc_now(),
      activity: "git_incremental_test_validation",
      changed_files: changed_files,
      test_files: test_files,
      test_results: test_results,
      sopv51_compliance: true,
      agent: "Worker-1"
    }

    log_file = "./__data/tmp/claude_git_incremental_test_#{DateTime.utc_now() |> Da
    log_content = inspect(log_entry, pretty: true)

    File.write!(log_file, log_content)
    IO.puts("📄 Test validation logged to: #{log_file}")
  end
end

# Execute the main function if this script is run directly
if System.argv() |> length() >= 0 do
  GitIncrementalValidation.main(System.argv())
end
end
end
end
end
