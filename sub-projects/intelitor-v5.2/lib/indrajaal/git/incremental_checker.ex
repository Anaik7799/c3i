defmodule Indrajaal.Git.IncrementalChecker do
  @moduledoc """

  Git-Based Incremental Validation System

  MANDATORY: All validation and testing MUST use incremental approach based
    on git changes
  to optimize performance and avoid unnecessary work on unchanged code.

  Features:
  - Git diff analysis for changed files identification
  - Incremental compilation checking
  - Smart test selection based on file changes
  - Validation optimization with dependency tracking
  - SOPv5.1 cybernetic feedback integration
  - Container-aware validation execution

  Usage:
  ```elixir
  # Check what files changed since last commit
  {:ok, changed_files} = Indrajaal.Git.IncrementalChecker.get_changed_files()

  # Run incremental validation
  {:ok, results} = Indrajaal.Git.IncrementalChecker.run_incremental_validation()

  # Get affected test files
  {:ok,
    test_files} = Indrajaal.Git.IncrementalChecker.get_affected_tests(changed_files)
  ```

  Agent: Worker-1 coordinates incremental validation activities
  SOPv5.1Compliance: ✅ Systematic incremental validation with cybernetic
    optimization
  """

  use GenServer
  require Logger

  alias Indrajaal.Claude

  @git_commands %{
    status: ["status", "--porcelain"],
    diff_staged: ["diff", "--cached", "--name-only"],
    diff_unstaged: ["diff", "--name-only"],
    diff_commit: ["diff", "HEAD~1", "--name-only"],
    branch: ["rev-parse", "--abbrev-ref", "HEAD"],
    commit_hash: ["rev-parse", "HEAD"],
    log: ["log", "--oneline", "-10"]
  }

  @file_patterns %{
    elixir: ~r/\.exs?$/,
    tests: ~r/test\.exs?$/,
    config: ~r/config\/.*\.exs$/,
    mix: ~r/mix\.exs$/,
    documentation: ~r/\.(md|txt)$/,
    container: ~r/(Dockerfile|docker-compose|podman-compose).*\.(yml|yaml)$/,
    scripts: ~r/scripts\/.*\.exs?$/
  }

  @spec start_link(any()) :: any()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get list of files changed since last commit or between commits.
  """
  @spec get_changed_files(any()) :: any()
  def get_changed_files(base \\ "HEAD~1") do
    GenServer.call(__MODULE__, {:get_changed_files, base})
  end

  @doc """
  Run incremental validation only on changed files and their dependencies.
  """
  @spec run_incremental_validation(any()) :: any()
  def run_incremental_validation(opts \\ []) do
    GenServer.call(__MODULE__, {:run_incremental_validation, opts}, :infinity)
  end

  @doc """
  Get test files that should be run based on changed files.
  """
  @spec get_affected_tests(any()) :: any()
  def get_affected_tests(changed_files) do
    GenServer.call(__MODULE__, {:get_affected_tests, changed_files})
  end

  @doc """
  Check if incremental validation is needed based on git status.
  """
  @spec validation_needed?() :: any()
  def validation_needed? do
    GenServer.call(__MODULE__, :validation_needed?)
  end

  @doc """
  Get git repository status and metadata.
  """
  def get_repo_status do
    GenServer.call(__MODULE__, :get_repo_status)
  end

  # ============================================================================
  # GenServer Implementation
  # ============================================================================

  @impl true
  @spec init(any()) :: any()
  def init(opts) do
    state = %{
      last_validation: nil,
      changed_files_cache: %{},
      validation_results: %{},
      git_status: %{},
      container_mode: Keyword.get(opts, :container_mode, true),
      phics_enabled: Keyword.get(opts, :phics_enabled, true)
    }

    Logger.info("Git Incremental Checker initialized", opts: opts)

    Claude.git_incremental_check(:initialization, %{
      opts: opts,
      container_mode: state.container_mode
    })

    {:ok, state}
  end

  @impl true
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call({:getchanged_files, base}, _from, state) do
    Claude.git_incremental_check(:get_changed_files_started, %{base: base})

    case execute_git_command(@git_commands.diff_commit ++ [base]) do
      {:ok, output} ->
        changed_files =
          output
          |> String.split("\n", trim: true)
          |> Enum.filter(&File.exists?/1)
          |> categorize_files()

        new_state = put_in(state.changed_files_cache[base], changed_files)

        Claude.git_incremental_check(:get_changed_files_completed, %{
          base: base,
          files_count: map_size(changed_files),
          categories: Map.keys(changed_files)
        })

        {:reply, {:ok, changed_files}, new_state}

      {:error, reason} = error ->
        Claude.git_incremental_check(
          :get_changed_files_failed,
          %{base: base, error: reason}
        )

        {:reply, error, state}
    end
  end

  @impl true
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call({:runincrementalvalidation, opts}, _from, state) do
    Claude.git_incremental_check(:incremental_validation_started, %{opts: opts})

    with {:ok, changed_files} <- get_changed_files_internal(state),
         {:ok, validation_plan} <- create_validation_plan(changed_files, opts),
         {:ok, results} <- execute_validation_plan(validation_plan, state) do
      new_state = %{state | last_validation: DateTime.utc_now(), validation_results: results}

      Claude.git_incremental_check(:incremental_validation_completed, %{
        validation_plan: validation_plan,
        results_summary: summarize_results(results),
        container_mode: state.container_mode
      })

      {:reply, {:ok, results}, new_state}
    else
      {:error, reason} = error ->
        Claude.git_incremental_check(
          :incremental_validation_failed,
          %{error: reason}
        )

        {:reply, error, state}
    end
  end

  @impl true
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call({:get_affected_tests, changed_files}, _from, state) do
    affected_tests = determine_affected_tests(changed_files)

    Claude.git_incremental_check(:affected_tests_determined, %{
      changed_files_count: count_files(changed_files),
      affected_tests_count: length(affected_tests)
    })

    {:reply, {:ok, affected_tests}, state}
  end

  @impl true
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call(:validation_needed?, _from, state) do
    case execute_git_command(@git_commands.status) do
      {:ok, output} ->
        has_changes = String.trim(output) != ""

        needs_validation =
          has_changes or
            state.last_validation == nil or
            DateTime.diff(DateTime.utc_now(), state.last_validation, :hour) > 24

        Claude.git_incremental_check(:validation_needed_check, %{
          has_changes: has_changes,
          needs_validation: needs_validation,
          last_validation: state.last_validation
        })

        {:reply, needs_validation, state}

      {:error, reason} = error ->
        Claude.git_incremental_check(
          :validation_needed_check_failed,
          %{error: reason}
        )

        {:reply, error, state}
    end
  end

  @impl true
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call(:get_repo_status, _from, state) do
    repo_status = collect_repo_status()

    new_state = %{state | git_status: repo_status}

    Claude.git_incremental_check(:repo_status_collected, repo_status)

    {:reply, {:ok, repo_status}, new_state}
  end

  # ============================================================================
  # Private Implementation
  # ============================================================================

  @spec execute_git_command(term()) :: term()
  defp execute_git_command(args) do
    case System.cmd("git", args, cd: ".", stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {error, _} -> {:error, String.trim(error)}
    end
  end

  @spec categorize_files(term()) :: term()
  defp categorize_files(file_list) do
    Enum.reduce(file_list, %{}, fn file, acc ->
      category = determine_file_category(file)
      Map.update(acc, category, [file], fn existing -> [file | existing] end)
    end)
  end

  @spec determine_file_category(term()) :: term()
  defp determine_file_category(file_path) do
    cond do
      Regex.match?(@file_patterns.tests, file_path) -> :tests
      Regex.match?(@file_patterns.config, file_path) -> :config
      Regex.match?(@file_patterns.mix, file_path) -> :mix
      Regex.match?(@file_patterns.elixir, file_path) -> :elixir
      Regex.match?(@file_patterns.documentation, file_path) -> :documentation
      Regex.match?(@file_patterns.container, file_path) -> :container
      Regex.match?(@file_patterns.scripts, file_path) -> :scripts
      true -> :other
    end
  end

  @spec get_changed_files_internal(term()) :: term()
  defp get_changed_files_internal(state) do
    # Check cache first
    case Map.get(state.changed_files_cache, "HEAD~1") do
      nil ->
        # Not cached, fetch from git
        case execute_git_command(@git_commands.diff_commit) do
          {:ok, output} ->
            changed_files =
              output
              |> String.split("\n", trim: true)
              |> Enum.filter(&File.exists?/1)
              |> categorize_files()

            {:ok, changed_files}

          {:error, _} = error ->
            error
        end

      cached_files ->
        {:ok, cached_files}
    end
  end

  @spec create_validation_plan(term(), term()) :: term()
  defp create_validation_plan(changed_files, opts) do
    plan = %{
      compile: should_compile?(changed_files),
      test: should_test?(changed_files, opts),
      lint: should_lint?(changed_files),
      format: should_format?(changed_files),
      docs: should_update_docs?(changed_files),
      container: should_rebuild_containers?(changed_files),
      specific_files: changed_files
    }

    {:ok, plan}
  end

  @spec should_compile?(term()) :: term()
  defp should_compile?(changed_files) do
    has_elixir_changes =
      Map.has_key?(changed_files, :elixir) or
        Map.has_key?(changed_files, :mix) or
        Map.has_key?(changed_files, :config)

    has_elixir_changes
  end

  @spec should_test?(term(), term()) :: term()
  defp should_test?(changed_files, opts) do
    force_tests = Keyword.get(opts, :force_tests, false)
    has_test_changes = Map.has_key?(changed_files, :tests)
    has_code_changes = Map.has_key?(changed_files, :elixir)

    force_tests or has_test_changes or has_code_changes
  end

  @spec should_lint?(term()) :: term()
  defp should_lint?(changed_files) do
    Map.has_key?(
      changed_files,
      :elixir
    ) or Map.has_key?(changed_files, :scripts)
  end

  @spec should_format?(term()) :: term()
  defp should_format?(changed_files) do
    Map.has_key?(
      changed_files,
      :elixir
    ) or Map.has_key?(changed_files, :scripts)
  end

  @spec should_update_docs?(term()) :: term()
  defp should_update_docs?(changed_files) do
    Map.has_key?(
      changed_files,
      :documentation
    ) or Map.has_key?(changed_files, :elixir)
  end

  @spec should_rebuild_containers?(term()) :: term()
  defp should_rebuild_containers?(changed_files) do
    Map.has_key?(
      changed_files,
      :container
    ) or Map.has_key?(changed_files, :config)
  end

  @spec execute_validation_plan(term(), term()) :: term()
  defp execute_validation_plan(plan, state) do
    results = %{}

    results =
      if plan.compile do
        Logger.info("Running incremental compilation...")

        case run_compilation(state) do
          {:ok, compile_result} -> Map.put(results, :compile, compile_result)
          {:error, reason} -> Map.put(results, :compile, {:error, reason})
        end
      else
        Map.put(results, :compile, :skipped)
      end

    results =
      if plan.test do
        Logger.info("Running incremental tests...")

        case run_incremental_tests(plan.specific_files, state) do
          {:ok, test_result} -> Map.put(results, :test, test_result)
          {:error, reason} -> Map.put(results, :test, {:error, reason})
        end
      else
        Map.put(results, :test, :skipped)
      end

    results =
      if plan.lint do
        Logger.info("Running incremental linting...")

        case run_incremental_lint(plan.specific_files) do
          {:ok, lint_result} -> Map.put(results, :lint, lint_result)
          {:error, reason} -> Map.put(results, :lint, {:error, reason})
        end
      else
        Map.put(results, :lint, :skipped)
      end

    results =
      if plan.format do
        Logger.info("Running incremental formatting...")

        case run_incremental_format(plan.specific_files) do
          {:ok, format_result} -> Map.put(results, :format, format_result)
          {:error, reason} -> Map.put(results, :format, {:error, reason})
        end
      else
        Map.put(results, :format, :skipped)
      end

    {:ok, results}
  end

  @spec run_compilation(term()) :: term()
  defp run_compilation(state) do
    compile_command =
      if state.container_mode do
        # Agent: Worker-1 executes container-based compilation with PHICS integ
        ["podman", "exec", "indrajaal-dev", "mix", "compile", "--warnings-as-errors"]
      else
        ["mix", "compile", "--warnings-as-errors"]
      end

    case System.cmd(List.first(compile_command), List.delete_at(compile_command, 0),
           cd: ".",
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        {:ok, %{status: :success, output: String.trim(output)}}

      {error, exit_code} ->
        {:error, %{status: :failed, exit_code: exit_code, output: String.trim(error)}}
    end
  end

  @spec run_incremental_tests(term(), term()) :: term()
  defp run_incremental_tests(changed_files, state) do
    test_files = determine_affected_tests(changed_files)

    if Enum.empty?(test_files) do
      {:ok, %{status: :success, message: "No tests affected by changes"}}
    else
      test_command =
        if state.container_mode do
          # Agent: Worker-1 executes container-based testing with PHICS integra
          ["podman", "exec", "indrajaal-dev", "mix", "test"] ++ test_files
        else
          ["mix", "test"] ++ test_files
        end

      case System.cmd(List.first(test_command), List.delete_at(test_command, 0),
             cd: ".",
             stderr_to_stdout: true
           ) do
        {output, 0} ->
          {:ok, %{status: :success, output: String.trim(output), files_tested: test_files}}

        {error, exit_code} ->
          {:error,
           %{
             status: :failed,
             exit_code: exit_code,
             output: String.trim(error),
             files_tested: test_files
           }}
      end
    end
  end

  @spec run_incremental_lint(term()) :: term()
  defp run_incremental_lint(changed_files) do
    elixir_files = get_files_by_category(changed_files, [:elixir, :scripts])

    if Enum.empty?(elixir_files) do
      {:ok, %{status: :success, message: "No Elixir files to lint"}}
    else
      case System.cmd("mix", ["credo", "--strict"] ++ elixir_files,
             cd: ".",
             stderr_to_stdout: true
           ) do
        {output, 0} ->
          {:ok, %{status: :success, output: String.trim(output), files_linted: elixir_files}}

        {error, exit_code} ->
          {:error,
           %{
             status: :failed,
             exit_code: exit_code,
             output: String.trim(error),
             files_linted: elixir_files
           }}
      end
    end
  end

  @spec run_incremental_format(term()) :: term()
  defp run_incremental_format(changed_files) do
    elixir_files = get_files_by_category(changed_files, [:elixir, :scripts])

    if Enum.empty?(elixir_files) do
      {:ok, %{status: :success, message: "No Elixir files to format"}}
    else
      case System.cmd("mix", ["format", "--check-formatted"] ++ elixir_files,
             cd: ".",
             stderr_to_stdout: true
           ) do
        {output, 0} ->
          {:ok, %{status: :success, output: String.trim(output), files_formatted: elixir_files}}

        {error, exit_code} ->
          {:error,
           %{
             status: :failed,
             exit_code: exit_code,
             output: String.trim(error),
             files_formatted: elixir_files
           }}
      end
    end
  end

  @spec determine_affected_tests(term()) :: term()
  defp determine_affected_tests(changed_files) do
    # Get direct test files
    direct_tests = Map.get(changed_files, :tests, [])

    # Get tests for changed Elixir files
    elixir_files = Map.get(changed_files, :elixir, [])

    corresponding_tests =
      Enum.flat_map(
        elixir_files,
        &find_corresponding_test_files/1
      )

    # Get integration tests if config or container files changed
    integration_tests =
      if Map.has_key?(
           changed_files,
           :config
         ) or Map.has_key?(changed_files, :container) do
        find_integration_tests()
      else
        []
      end

    (direct_tests ++ corresponding_tests ++ integration_tests) |> Enum.uniq()
  end

  @spec find_corresponding_test_files(term()) :: term()
  defp find_corresponding_test_files(elixir_file) do
    # Convert lib/myapp/module.ex to test/myapp/module_test.exs
    test_file =
      elixir_file
      |> String.replace(~r/^lib\//, "test/")
      |> String.replace(~r/\.ex$/, "test.exs")

    if File.exists?(test_file) do
      [test_file]
    else
      []
    end
  end

  def find_integration_tests do
    Path.wildcard("test/**/*integration*test.exs") ++
      Path.wildcard("test/**/*e2e*test.exs") ++
      Path.wildcard("test/**/*wallaby*test.exs")
  end

  @spec get_files_by_category(term(), term()) :: term()
  defp get_files_by_category(changed_files, categories) do
    categories
    |> Enum.flat_map(fn category -> Map.get(changed_files, category, []) end)
    |> Enum.uniq()
  end

  def collect_repo_status do
    branch_result = execute_git_command(@git_commands.branch)
    commit_result = execute_git_command(@git_commands.commit_hash)
    status_result = execute_git_command(@git_commands.status)
    log_result = execute_git_command(@git_commands.log)

    %{
      branch:
        case branch_result do
          {:ok, branch} -> String.trim(branch)
          {:error, _} -> "unknown"
        end,
      commit_hash:
        case commit_result do
          {:ok, hash} ->
            trimmed = String.trim(hash)
            trimmed |> String.slice(0, 8)

          {:error, _} ->
            "unknown"
        end,
      has_changes:
        case status_result do
          {:ok, status} -> String.trim(status) != ""
          {:error, _} -> false
        end,
      recent_commits:
        case log_result do
          {:ok, log} -> String.split(log, "\n", trim: true)
          {:error, _} -> []
        end,
      timestamp: DateTime.utc_now()
    }
  end

  @spec count_files(term()) :: term()
  defp count_files(changed_files) do
    changed_files
    |> Map.values()
    |> List.flatten()
    |> length()
  end

  @spec summarize_results(term()) :: term()
  defp summarize_results(results) do
    Enum.reduce(results, %{}, fn {key, value}, acc ->
      case value do
        {:error, reason} -> Map.put(acc, key, %{status: :error, reason: reason})
        %{status: status} = result -> Map.put(acc, key, %{status: status, details: result})
        :skipped -> Map.put(acc, key, %{status: :skipped})
        _ -> Map.put(acc, key, %{status: :completed, result: value})
      end
    end)
  end
end
