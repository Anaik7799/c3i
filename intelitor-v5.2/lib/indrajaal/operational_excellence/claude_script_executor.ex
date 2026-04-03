defmodule Indrajaal.OperationalExcellence.ClaudeScriptExecutor do
  @moduledoc """
  Claude-aware script execution with safety validation and tracking.
  Implements TDG _requirements with STAMP safety constraints.

  Framework: AEE+SOPv5.1+GDE+PHICS+TPS+STAMP+Container-Only

  Safety Constraints:
  - SC-005: Claude sessions must enforce framework compliance
  - SC-006: Claude activity logs must be tamper-proof
  - UCA-004: Pr_event unauthorized script execution
  """

  use GenServer
  require Logger

  alias Indrajaal.OperationalExcellence.{ClaudeSession, ClaudeActivity}

  @script_dirs [
    "scripts/containers",
    "scripts/validation",
    "scripts/performance",
    "scripts/backup",
    "scripts/demo"
  ]

  @allowed_extensions [".exs", ".sh", ".py"]
  # 5 minutes default
  @execution_timeout 300_000

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Execute a script with Claude __context and safety validation.
  Satisfies UCA-004: Pr_event unauthorized script execution.
  """
  def execute(script_path, params \\ %{}, claude_context \\ %{}) do
    GenServer.call(
      __MODULE__,
      {:execute, script_path, params, claude_context},
      @execution_timeout + 10_000
    )
  end

  @doc """
  Validate a script before execution.
  """
  def validate_script(script_path) do
    GenServer.call(__MODULE__, {:validate, script_path})
  end

  @doc """
  List available scripts that Claude can execute.
  """
  def list_available_scripts do
    GenServer.call(__MODULE__, :list_scripts)
  end

  @doc """
  Get execution history for a specific script.
  """
  def get_script_history(script_path) do
    GenServer.call(__MODULE__, {:get_history, script_path})
  end

  @doc """
  Check if a script _requires elevated permissions.
  """
  def _requires_elevation?(script_path) do
    GenServer.call(__MODULE__, {:check_elevation, script_path})
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    state = %{
      script_registry: load_script_registry(),
      execution_history: [],
      active_executions: %{},
      permission_cache: %{},
      safety_rules: load_safety_rules()
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:execute, script_path, params, claude_context}, from, state) do
    # UCA-004: Comprehensive safety validation
    case validate_execution_request(script_path, params, claude_context, state) do
      :ok ->
        # Track execution start
        execution_id = generate_execution_id()

        operation = %{
          type: :script_execution,
          target: script_path,
          __params: params,
          execution_id: execution_id,
          started_at: DateTime.utc_now()
        }

        # Track in Claude activity
        ClaudeActivity.track(operation, claude_context)

        # Update session if exists
        if claude_context[:session_id] do
          ClaudeSession.update_session(claude_context.session_id, operation)
        end

        # Mark as active
        new_active =
          Map.put(state.active_executions, execution_id, %{
            script: script_path,
            started_at: DateTime.utc_now(),
            from: from
          })

        # Execute asynchronously
        self_pid = self()

        Task.start(fn ->
          result = safe_execute_script(script_path, params, claude_context, execution_id)
          send(self_pid, {:execution_complete, execution_id, result})
        end)

        {:noreply, %{state | active_executions: new_active}}

      {:error, reason} = error ->
        # Track validation failure
        ClaudeActivity.track(
          %{
            type: :script_validation_failed,
            target: script_path,
            __params: params,
            reason: reason
          },
          claude_context
        )

        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:validate, script_path}, _from, state) do
    result = validate_script_safety(script_path, state)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:listscripts, _from, state) do
    scripts = discover_available_scripts()
    {:reply, scripts, state}
  end

  @impl true
  def handle_call({:gethistory, script_path}, _from, state) do
    history =
      state.execution_history
      |> Enum.filter(fn entry -> entry.script_path == script_path end)
      |> Enum.take(50)

    {:reply, history, state}
  end

  @impl true
  def handle_call({:checkelevation, script_path}, _from, state) do
    requires_elevation = check_script_elevation(script_path, state)
    {:reply, requires_elevation, state}
  end

  @impl true
  def handle_info({:execution_complete, execution_id, result}, state) do
    case Map.get(state.active_executions, execution_id) do
      nil ->
        {:noreply, state}

      execution ->
        # Remove from active
        new_active = Map.delete(state.active_executions, execution_id)

        # Record in history
        history_entry = %{
          execution_id: execution_id,
          script_path: execution.script,
          started_at: execution.started_at,
          completed_at: DateTime.utc_now(),
          result: result,
          duration_ms: DateTime.diff(DateTime.utc_now(), execution.started_at, :millisecond)
        }

        new_history = [history_entry | state.execution_history] |> Enum.take(1000)

        # Reply to original caller
        GenServer.reply(execution.from, result)

        {:noreply, %{state | active_executions: new_active, execution_history: new_history}}
    end
  end

  # Private functions

  defp load_script_registry do
    # Load meta_data about known scripts
    %{
      "scripts/containers/morning_validation.sh" => %{
        description: "Morning container validation",
        category: :validation,
        risk_level: :low,
        _requires_container: false,
        frameworks: [:tdg, :stamp, :sopv51]
      },
      "scripts/containers/comprehensive_preflight_check.sh" => %{
        description: "Comprehensive preflight validation",
        category: :validation,
        risk_level: :low,
        _requires_container: false,
        frameworks: [:tdg, :stamp, :tps]
      },
      "scripts/containers/setup_nixos_container.exs" => %{
        description: "NixOS container setup",
        category: :infrastructure,
        risk_level: :high,
        _requires_container: false,
        frameworks: [:aee, :sopv51]
      },
      "scripts/performance/comprehensive_performance_test.exs" => %{
        description: "Performance testing suite",
        category: :testing,
        risk_level: :medium,
        _requires_container: true,
        frameworks: [:gde, :phics]
      }
    }
  end

  defp load_safety_rules do
    %{
      forbidden_patterns: [
        # Pr_event root deletion
        ~r/rm\s+-rf\s+\/$/,
        # Pr_event system shutdown
        ~r/:(kill|halt)\(/,
        # Pr_event root deletion via Elixir
        ~r/File\.rm_rf\("\/"/,
        # Pr_event shutdown
        ~r/System\.cmd\("shutdown/,
        # Pr_event elevation without permission
        ~r/sudo\s/
      ],
      _required_frameworks: %{
        validation: [:tdg, :stamp],
        infrastructure: [:aee, :sopv51],
        testing: [:gde, :phics],
        backup: [:stamp, :tps]
      },
      permission_requirements: %{
        high_risk: :admin,
        medium_risk: :developer,
        low_risk: :user
      }
    }
  end

  defp validate_execution_request(script_path, params, claude_context, state) do
    with :ok <- validate_script_exists(script_path),
         :ok <- validate_script_safety(script_path, state),
         :ok <- validate_framework_compliance(script_path, claude_context, state),
         :ok <- validate_permissions(script_path, claude_context, state) do
      validate_parameters(params)
    end
  end

  defp validate_script_exists(script_path) do
    if File.exists?(script_path) do
      :ok
    else
      {:error, :script_not_found}
    end
  end

  defp validate_script_safety(script_path, state) do
    # Check extension
    unless valid_extension?(script_path) do
      return {:error, :invalid_extension}
    end

    # Check content for forbidden patterns
    case File.read(script_path) do
      {:ok, content} ->
        if contains_forbidden_patterns?(content, state.safety_rules.forbidden_patterns) do
          {:error, :unsafe_script_content}
        else
          :ok
        end

      {:error, _} ->
        {:error, :cannot_read_script}
    end
  end

  defp validate_framework_compliance(script_path, claude_context, state) do
    script_info = Map.get(state.script_registry, script_path, %{})
    required_frameworks = script_info[:frameworks] || []

    # SC-005: Verify framework compliance
    session_frameworks = claude_context[:framework_compliance] || %{}

    all_compliant =
      Enum.all?(required_frameworks, fn framework ->
        Map.get(session_frameworks, framework, false)
      end)

    if all_compliant do
      :ok
    else
      {:error, :framework_compliance_violation}
    end
  end

  defp validate_permissions(script_path, claude_context, state) do
    script_info = Map.get(state.script_registry, script_path, %{})
    risk_level = script_info[:risk_level] || :medium
    required_permission = state.safety_rules.permission_requirements[risk_level]

    user_permission = claude_context[:permission_level] || :user

    if permission_sufficient?(user_permission, required_permission) do
      :ok
    else
      {:error, :insufficient_permissions}
    end
  end

  defp validate_parameters(params) do
    # Validate parameter safety
    dangerous_params = [
      "--force",
      "--no-confirm",
      "--bypass-safety",
      "-rf"
    ]

    param_string =
      params
      |> Map.values()
      |> Enum.join(" ")

    if Enum.any?(dangerous_params, &String.contains?(param_string, &1)) do
      {:error, :dangerous_parameters}
    else
      :ok
    end
  end

  defp safe_execute_script(script_path, params, claude_context, execution_id) do
    try do
      # Prepare execution environment
      env = prepare_execution_environment(claude_context, execution_id)

      # Build command based on script type
      {cmd, args} = build_command(script_path, params)

      Logger.info("[ClaudeScriptExecutor] Executing: #{cmd} #{Enum.join(args, " ")}")

      # Execute with timeout
      case System.cmd(cmd, args,
             env: env,
             cd: Path.dirname(script_path),
             stderr_to_stdout: true,
             timeout: @execution_timeout
           ) do
        {output, 0} ->
          # Track success
          ClaudeActivity.track(
            %{
              type: :script_execution_success,
              target: script_path,
              execution_id: execution_id,
              # Would be calculated
              duration_ms: 0
            },
            claude_context
          )

          {:ok,
           %{
             output: output,
             exit_code: 0,
             execution_id: execution_id
           }}

        {output, exit_code} ->
          # Track failure
          ClaudeActivity.track(
            %{
              type: :script_execution_failed,
              target: script_path,
              execution_id: execution_id,
              exit_code: exit_code
            },
            claude_context
          )

          {:error,
           %{
             output: output,
             exit_code: exit_code,
             execution_id: execution_id
           }}
      end
    rescue
      error ->
        Logger.error("[ClaudeScriptExecutor] Execution error: #{inspect(error)}")

        ClaudeActivity.track(
          %{
            type: :script_execution_error,
            target: script_path,
            execution_id: execution_id,
            error: inspect(error)
          },
          claude_context
        )

        {:error, error}
    end
  end

  defp prepare_execution_environment(claude_context, execution_id) do
    [
      {"CLAUDE_EXECUTION_ID", execution_id},
      {"CLAUDE_SESSION_ID", claude_context[:session_id] || "none"},
      {"FRAMEWORK_AEE", "true"},
      {"FRAMEWORK_SOPV51", "true"},
      {"FRAMEWORK_GDE", "true"},
      {"FRAMEWORK_PHICS", "true"},
      {"FRAMEWORK_TPS", "true"},
      {"FRAMEWORK_STAMP", "true"},
      {"CONTAINER_ONLY", "true"}
    ]
  end

  defp build_command(script_path, params) do
    case Path.extname(script_path) do
      ".exs" ->
        args = ["--no-halt", script_path] ++ __params_to_args(params)
        {"elixir", args}

      ".sh" ->
        args = [script_path] ++ __params_to_args(params)
        {"bash", args}

      ".py" ->
        args = [script_path] ++ __params_to_args(params)
        {"python3", args}

      _ ->
        raise "Unsupported script type"
    end
  end

  defp __params_to_args(params) do
    Enum.flat_map(params, fn {key, value} ->
      if value == true do
        ["--#{key}"]
      else
        ["--#{key}", to_string(value)]
      end
    end)
  end

  defp discover_available_scripts do
    @script_dirs
    |> Enum.flat_map(fn dir ->
      if File.dir?(dir) do
        Path.wildcard("#{dir}/**/*{#{Enum.join(@allowed_extensions, ",")}}")
      else
        []
      end
    end)
    |> Enum.map(fn path ->
      %{
        path: path,
        name: Path.basename(path),
        category: categorize_script(path),
        description: get_script_description(path)
      }
    end)
  end

  defp categorize_script(path) do
    cond do
      String.contains?(path, "containers") -> :containers
      String.contains?(path, "validation") -> :validation
      String.contains?(path, "performance") -> :performance
      String.contains?(path, "backup") -> :backup
      String.contains?(path, "demo") -> :demo
      true -> :other
    end
  end

  defp get_script_description(path) do
    # Try to extract description from script
    case File.read(path) do
      {:ok, content} ->
        # Look for description in first few lines
        content
        |> String.split("\n")
        |> Enum.take(10)
        |> Enum.find_value(fn line ->
          cond do
            String.contains?(line, "# Description:") ->
              String.trim_leading(line, "# Description:")

            String.contains?(line, "@moduledoc") ->
              # Extract from next line
              :extract_moduledoc

            true ->
              nil
          end
        end) || "No description available"

      _ ->
        "No description available"
    end
  end

  defp check_script_elevation(script_path, state) do
    script_info = Map.get(state.script_registry, script_path, %{})
    script_info[:risk_level] == :high
  end

  defp valid_extension?(script_path) do
    ext = Path.extname(script_path)
    ext in @allowed_extensions
  end

  defp contains_forbidden_patterns?(content, patterns) do
    Enum.any?(patterns, fn pattern ->
      Regex.match?(pattern, content)
    end)
  end

  defp permission_sufficient?(user_perm, required_perm) do
    perm_levels = %{
      admin: 3,
      developer: 2,
      user: 1
    }

    perm_levels[user_perm] >= perm_levels[required_perm]
  end

  defp generate_execution_id do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601(:basic)
    rand_bytes = :crypto.strong_rand_bytes(4)
    random_suffix = rand_bytes |> Base.encode16()
    "exec_#{timestamp}_#{random_suffix}"
  end

  defp return(value), do: value
end
