defmodule Mix.Tasks.Git.Incremental do
  @moduledoc """
  Git - Based Incremental Validation Mix Task

  MANDATORY: Use incremental validation for all development workflow validation
  to optimize performance and ensure systematic quality assurance.

  This Mix task provides comprehensive git - based incremental validation with:
  - Smart change detection and analysis
  - Container - aware execution with PHICS integration
  - SOPv5.1 cybernetic coordination and optimization
  - Comprehensive logging and audit trail

  ## Usage

      # Check what validation is needed
      mix git.incremental --check

      # Run incremental validation
      mix git.incremental --validate

      # Run only affected tests
      mix git.incremental --test - only

      # Show git repository status
      mix git.incremental --status

      # Run with container mode disabled
      mix git.incremental --validate --no - container

      # Force full test suite
      mix git.incremental --validate --force - tests

  Agent: Worker - 1 coordinates incremental validation via Mix interface
  SOPv5.1 Compliance: ✅ Cybernetic Mix task integration with systematic optimization
  """

  @shortdoc "Run git - based incremental validation"

  use Mix.Task
  require Logger

  alias Indrajaal.Claude
  alias Indrajaal.Git.IncrementalChecker

  @impl Mix.Task
  @spec run(any()) :: any()
  def run(args) do
    # Start the application to ensure all services are available
    Mix.Task.run("app.start")

    # Start the incremental checker GenServer
    {:ok, _pid} = IncrementalChecker.start_link()

    # Parse arguments
    {opts, [], []} =
      OptionParser.parse(args,
        switches: [
          check: :boolean,
          validate: :boolean,
          test_only: :boolean,
          status: :boolean,
          no_container: :boolean,
          force_tests: :boolean,
          parallel: :boolean,
          timeout: :integer,
          help: :boolean
        ],
        aliases: [
          c: :check,
          v: :validate,
          t: :test_only,
          s: :status,
          h: :help
        ]
      )

    # Log task start
    Claude.git_incremental_check(:mix_task_started, %{
      args: args,
      options: opts,
      container_mode: !opts[:no_container]
    })

    cond do
      opts[:help] -> show_help()
      opts[:check] -> run_check()
      opts[:validate] -> run_validation(opts)
      opts[:test_only] -> run_test_only(opts)
      opts[:status] -> show_status()
      true -> show_help()
    end
  end

  # ============================================================================
  # Command Implementations
  # ============================================================================

  @spec run_check() :: :ok
  defp run_check do
    Mix.shell().info("Checking git changes and validation __requirements...")

    case IncrementalChecker.get_changed_files() do
      {:ok, changed_files} ->
        display_changed_files(changed_files)

        case IncrementalChecker.get_affected_tests(changed_files) do
          {:ok, test_files} ->
            display_affected_tests(test_files)

          {:error, reason} ->
            Mix.shell().error("Failed to determine affected tests: #{reason}")
        end

      {:error, reason} ->
        Mix.shell().error("Failed to get changed files: #{reason}")
    end

    :ok
  end

  @spec run_validation(term()) :: term()
  defp run_validation(opts) do
    Mix.shell().info("[LAUNCH] Running git - based incremental validation...")

    validation_opts = [
      container_mode: !opts[:no_container],
      force_tests: opts[:force_tests] || false,
      parallel: opts[:parallel] != false,
      timeout: opts[:timeout] || 300
    ]

    case IncrementalChecker.run_incremental_validation(validation_opts) do
      {:ok, results} ->
        display_validation_results(results)

        if all_validations_successful?(results) do
          Mix.shell().info("🎉 All incremental validations passed!")
          Claude.git_incremental_check(:mix_validation_success, %{results: results})
        else
          Mix.shell().error("❌ Some validations failed - check results above")
          Claude.git_incremental_check(:mix_validation_failed, %{results: results})
          System.halt(1)
        end

      {:error, reason} ->
        Mix.shell().error("Incremental validation failed: #{reason}")
        Claude.git_incremental_check(:mix_validation_error, %{error: reason})
        System.halt(1)
    end
  end

  @spec run_test_only(term()) :: term()
  defp run_test_only(opts) do
    Mix.shell().info("🧪 Running incremental tests only...")

    with {:ok, changed_files} <- IncrementalChecker.get_changed_files(),
         {:ok, test_files} <- IncrementalChecker.get_affected_tests(changed_files) do
      if Enum.empty?(test_files) do
        Mix.shell().info("No tests affected by current changes")
        :ok
      end

      # Run the affected tests
      container_mode = !opts[:no_container]

      test_command =
        if container_mode do
          ["podman", "exec", "indrajaal-dev", "mix", "test"] ++ test_files
        else
          ["mix", "test"] ++ test_files
        end

      Mix.shell().info("Running #{length(test_files)} affected test files...")

      case System.cmd(List.first(test_command), List.delete_at(test_command, 0),
             into: IO.stream(:stdio, :line)
           ) do
        {_, 0} ->
          Mix.shell().info("🎉 All affected tests passed!")
          Claude.git_incremental_check(:mix_test_success, %{test_files: test_files})

        {_, exit_code} ->
          Mix.shell().error("❌ Some tests failed (exit code: #{exit_code})")

          Claude.git_incremental_check(
            :mix_test_failed,
            %{test_files: test_files, exit_code: exit_code}
          )

          System.halt(exit_code)
      end
    else
      {:error, reason} ->
        Mix.shell().error("Failed to determine test files: #{reason}")
        System.halt(1)
    end
  end

  @spec show_status() :: any()
  defp show_status do
    Mix.shell().info("[STATS] Git repository status and incremental validation state...")

    case IncrementalChecker.get_repo_status() do
      {:ok, repo_status} ->
        display_repo_status(repo_status)

        case IncrementalChecker.validation_needed?() do
          true ->
            Mix.shell().info("🔄 Validation is recommended based on recent changes")

          false ->
            Mix.shell().info("✅ No validation needed - repository is up to date")

          {:error, reason} ->
            Mix.shell().error("Failed to check validation status: #{reason}")
        end

      {:error, reason} ->
        Mix.shell().error("Failed to get repository status: #{reason}")
    end
  end

  @spec show_help() :: any()
  defp show_help do
    Mix.shell().info("""
    Git - Based Incremental Validation Mix Task

    USAGE:
        mix git.incremental [options]

    OPTIONS:
        --check, -c          Check git changes and validation __requirements
        --validate, -v       Run incremental validation based on changes
        --test - only, -t      Run only tests affected by changes
        --status, -s         Show git repository and validation status
        --no - container       Disable container - based execution
        --force - tests        Force running full test suite
        --parallel           Enable parallel execution (default: true)
        --timeout SECONDS    Set timeout for operations (default: 300)
        --help, -h           Show this help message

    EXAMPLES:
        # Check what validation is needed
        mix git.incremental --check

        # Run incremental validation
        mix git.incremental --validate

        # Run only affected tests
        mix git.incremental --test - only

        # Run validation without containers
        mix git.incremental --validate --no - container

        # Force full test suite
        mix git.incremental --validate --force - tests

    FEATURES:
        • Git diff - based change detection
        • Smart test file selection based on changes
        • Container - aware execution with PHICS integration
        • SOPv5.1 cybernetic coordination and optimization
        • Comprehensive logging and audit trail
        • Performance optimization through incremental approach

    Agent: Worker - 1 - Git - based incremental validation coordination
    SOPv5.1 Compliance: ✅ Systematic performance optimization
    """)
  end

  # ============================================================================
  # Display Functions
  # ============================================================================

  @spec display_changed_files(term()) :: term()
  defp display_changed_files(changed_files) do
    Mix.shell().info("📁 Changed files by category:")

    Enum.each(changed_files, fn {category, files} ->
      Mix.shell().info("  📂 #{String.upcase(to_string(category))} (#{length(files)})")

      Enum.each(files, fn file ->
        Mix.shell().info("    📄 #{file}")
      end)
    end)

    total_files = changed_files |> Map.values() |> List.flatten() |> length()
    Mix.shell().info("[STATS] Total changed files: #{total_files}")
  end

  @spec display_affected_tests(term()) :: term()
  defp display_affected_tests(test_files) do
    if length(test_files) > 0 do
      Mix.shell().info("🧪 Affected test files (#{length(test_files)}):")

      Enum.each(test_files, fn test_file ->
        Mix.shell().info("  🧪 #{test_file}")
      end)
    else
      Mix.shell().info("🧪 No test files affected by changes")
    end
  end

  @spec display_validation_results(term()) :: term()
  defp display_validation_results(results) do
    Mix.shell().info("[STATS] Incremental validation results:")

    Enum.each(results, fn {action, result} ->
      case result do
        :skipped ->
          Mix.shell().info("  ⏭️  #{String.upcase(to_string(action))}: SKIPPED")

        {:error, error_info} ->
          Mix.shell().error("  ❌ #{String.upcase(to_string(action))}: FAILED")
          Mix.shell().error("    #{inspect(error_info)}")

        %{status: :success} ->
          Mix.shell().info("  ✅ #{String.upcase(to_string(action))}: SUCCESS")

        %{status: :failed} = failed_info ->
          Mix.shell().error("  ❌ #{String.upcase(to_string(action))}: FAILED")

          if Map.has_key?(failed_info, :output) do
            Mix.shell().error("    #{failed_info.output}")
          end

        _ ->
          Mix.shell().info("  ❓ #{String.upcase(to_string(action))}: UNKNOWN")
      end
    end)
  end

  @spec display_repo_status(term()) :: term()
  defp display_repo_status(repo_status) do
    Mix.shell().info("[STATS] Git Repository Status:")
    Mix.shell().info("  🌿 Branch: #{repo_status.branch}")
    Mix.shell().info("  📋 Commit: #{repo_status.commit_hash}")
    Mix.shell().info("  🔄 Changes: #{if repo_status.has_changes, do: "Yes", else: "No"}")
    Mix.shell().info("  📅 Checked: #{repo_status.timestamp}")

    if length(repo_status.recent_commits) > 0 do
      Mix.shell().info("  📜 Recent commits:")

      recent_commits = Enum.take(repo_status.recent_commits, 3)

      recent_commits
      |> Enum.each(fn commit ->
        Mix.shell().info("    #{commit}")
      end)
    end
  end

  @spec all_validations_successful?(term()) :: term()
  defp all_validations_successful?(results) do
    Enum.all?(results, fn {_action, result} ->
      case result do
        :skipped -> true
        %{status: :success} -> true
        _ -> false
      end
    end)
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cybernetic excellence
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
