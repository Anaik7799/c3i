defmodule Indrajaal.Integration.CepafPort do
  @moduledoc """
  GenServer managing a Port to the Cepaf.Podman F# CLI for container operations.

  This module provides the low-level interface for executing F# CLI commands
  via Elixir Ports, handling JSON serialization/deserialization, and managing
  the CLI process lifecycle.

  ## Architecture

  The Port-based approach ensures:
  - Process isolation between Elixir and .NET runtime
  - Clean error handling with timeouts
  - JSON-based protocol for structured data exchange

  ## STAMP Safety Constraints

  - SC-CNT-009: NixOS/Podman only (enforced by F# CLI)
  - SC-CNT-010: Localhost registry (validated in responses)
  - SC-CNT-012: Rootless Podman (socket path detection)

  ## Usage

      # Start the GenServer (typically via supervision tree)
      {:ok, _pid} = CepafPort.start_link([])

      # List all containers
      {:ok, containers} = CepafPort.list_containers()

      # Inspect specific container
      {:ok, info} = CepafPort.inspect_container("indrajaal-db")

      # Check system health
      {:ok, health} = CepafPort.check_health()
  """

  use GenServer
  require Logger

  # Default timeout for CLI commands (30 seconds)
  @default_timeout 30_000

  # Path to the Cepaf.Podman CLI executable
  @cli_path "lib/cepaf/artifacts/cepaf-podman-cli"

  # Alternative path using dotnet run
  @dotnet_project_path "lib/cepaf/src/Cepaf.Podman"

  defstruct [
    :cli_mode,
    :cli_path,
    :pending_requests,
    :request_timeout
  ]

  @type cli_mode :: :executable | :dotnet_run
  @type container_status :: :running | :exited | :created | :paused | :dead | :unknown
  @type health_status :: :healthy | :unhealthy | :starting | :no_healthcheck | :unknown

  @type container_summary :: %{
          id: String.t(),
          names: [String.t()],
          image: String.t(),
          status: container_status(),
          state: String.t(),
          created: DateTime.t() | nil,
          ports: [map()],
          labels: %{String.t() => String.t()}
        }

  @type container_inspect :: %{
          id: String.t(),
          name: String.t(),
          image: String.t(),
          state: %{
            status: container_status(),
            running: boolean(),
            paused: boolean(),
            pid: non_neg_integer(),
            exit_code: integer(),
            started_at: DateTime.t() | nil,
            finished_at: DateTime.t() | nil,
            health: health_status() | nil
          },
          config: %{
            env: %{String.t() => String.t()},
            labels: %{String.t() => String.t()},
            cmd: [String.t()]
          },
          mounts: [map()],
          network_settings: map()
        }

  @type health_summary :: %{
          total: non_neg_integer(),
          healthy: non_neg_integer(),
          unhealthy: non_neg_integer(),
          starting: non_neg_integer(),
          no_healthcheck: non_neg_integer(),
          timestamp: DateTime.t()
        }

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Starts the CepafPort GenServer.

  ## Options

  - `:cli_path` - Path to CLI executable (default: uses dotnet run)
  - `:timeout` - Default command timeout in milliseconds (default: 30_000)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Lists all containers (running and stopped).

  ## Options

  - `:running_only` - Only return running containers (default: false)
  - `:labels` - Filter by labels (e.g., ["intelitor=true"])
  - `:timeout` - Command timeout in milliseconds

  ## Examples

      {:ok, containers} = CepafPort.list_containers()
      {:ok, running} = CepafPort.list_containers(running_only: true)
  """
  @spec list_containers(keyword()) :: {:ok, [container_summary()]} | {:error, term()}
  def list_containers(opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    running_only = Keyword.get(opts, :running_only, false)
    labels = Keyword.get(opts, :labels, [])

    args =
      ["containers", "list", "--format", "json"] ++
        if(running_only, do: [], else: ["--all"]) ++
        Enum.flat_map(labels, fn label -> ["--filter", "label=#{label}"] end)

    GenServer.call(__MODULE__, {:execute, args, timeout}, timeout + 1000)
  end

  @doc """
  Inspects a specific container by ID or name.

  ## Examples

      {:ok, info} = CepafPort.inspect_container("indrajaal-db")
      {:ok, info} = CepafPort.inspect_container("abc123def")
  """
  @spec inspect_container(String.t(), keyword()) :: {:ok, container_inspect()} | {:error, term()}
  def inspect_container(id_or_name, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    args = ["containers", "inspect", id_or_name, "--format", "json"]

    GenServer.call(__MODULE__, {:execute, args, timeout}, timeout + 1000)
  end

  @doc """
  Restarts a container.

  ## Examples

      :ok = CepafPort.restart_container("indrajaal-db")
  """
  @spec restart_container(String.t(), keyword()) :: :ok | {:error, term()}
  def restart_container(id_or_name, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    args = ["containers", "restart", id_or_name]

    case GenServer.call(__MODULE__, {:execute_raw, args, timeout}, timeout + 1000) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Checks health of all containers and returns a summary.

  ## Examples

      {:ok, summary} = CepafPort.check_health()
      # => %{total: 5, healthy: 4, unhealthy: 1, ...}
  """
  @spec check_health(keyword()) :: {:ok, health_summary()} | {:error, term()}
  def check_health(opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    args = ["health", "summary", "--format", "json"]

    GenServer.call(__MODULE__, {:execute, args, timeout}, timeout + 1000)
  end

  @doc """
  Checks health of a specific container.

  ## Examples

      {:ok, :healthy} = CepafPort.container_health("indrajaal-db")
      {:ok, :unhealthy} = CepafPort.container_health("failing-container")
  """
  @spec container_health(String.t(), keyword()) :: {:ok, health_status()} | {:error, term()}
  def container_health(id_or_name, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    args = ["health", "check", id_or_name, "--format", "json"]

    GenServer.call(__MODULE__, {:execute, args, timeout}, timeout + 1000)
  end

  @doc """
  Gets Podman system information.

  ## Examples

      {:ok, info} = CepafPort.system_info()
  """
  @spec system_info(keyword()) :: {:ok, map()} | {:error, term()}
  def system_info(opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    args = ["system", "info", "--format", "json"]

    GenServer.call(__MODULE__, {:execute, args, timeout}, timeout + 1000)
  end

  @doc """
  Gets container logs.

  ## Options

  - `:tail` - Number of lines from end (default: all)
  - `:since` - Only logs since timestamp
  - `:timestamps` - Include timestamps (default: false)

  ## Examples

      {:ok, logs} = CepafPort.container_logs("indrajaal-app", tail: 100)
  """
  @spec container_logs(String.t(), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def container_logs(id_or_name, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    tail = Keyword.get(opts, :tail)
    timestamps = Keyword.get(opts, :timestamps, false)

    args =
      ["containers", "logs", id_or_name] ++
        if(tail, do: ["--tail", to_string(tail)], else: []) ++
        if(timestamps, do: ["--timestamps"], else: [])

    GenServer.call(__MODULE__, {:execute_raw, args, timeout}, timeout + 1000)
  end

  @doc """
  Gets container stats (resource usage).

  ## Examples

      {:ok, stats} = CepafPort.container_stats("indrajaal-app")
  """
  @spec container_stats(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def container_stats(id_or_name, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    args = ["containers", "stats", id_or_name, "--no-stream", "--format", "json"]

    GenServer.call(__MODULE__, {:execute, args, timeout}, timeout + 1000)
  end

  @doc """
  Pings the Podman service to verify connectivity.

  ## Examples

      :ok = CepafPort.ping()
      {:error, :connection_refused} = CepafPort.ping()
  """
  @spec ping(keyword()) :: :ok | {:error, term()}
  def ping(opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5_000)
    args = ["system", "ping"]

    case GenServer.call(__MODULE__, {:execute_raw, args, timeout}, timeout + 1000) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(opts) do
    cli_path = Keyword.get(opts, :cli_path)
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    # Determine CLI mode based on available executables
    {mode, path} = detect_cli_mode(cli_path)

    state = %__MODULE__{
      cli_mode: mode,
      cli_path: path,
      pending_requests: %{},
      request_timeout: timeout
    }

    Logger.info("CepafPort initialized",
      mode: mode,
      path: path,
      timeout: timeout
    )

    {:ok, state}
  end

  @impl true
  def handle_call({:execute, args, timeout}, from, state) do
    execute_command(state, args, timeout, from, :json)
  end

  @impl true
  def handle_call({:execute_raw, args, timeout}, from, state) do
    execute_command(state, args, timeout, from, :raw)
  end

  @impl true
  def handle_info({port, {:data, data}}, state) when is_port(port) do
    # Handle port data - this is called when output is available
    handle_port_output(state, port, data)
  end

  @impl true
  def handle_info({port, {:exit_status, status}}, state) when is_port(port) do
    # Handle port exit
    handle_port_exit(state, port, status)
  end

  @impl true
  def handle_info({:timeout, ref}, state) do
    # Handle command timeout
    handle_command_timeout(state, ref)
  end

  @impl true
  def handle_info({:DOWN, _ref, :port, port, reason}, state) do
    Logger.warning("CepafPort: Port terminated", port: inspect(port), reason: reason)
    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("CepafPort: Unexpected message", message: inspect(msg))
    {:noreply, state}
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp detect_cli_mode(custom_path) do
    cond do
      # Check for custom path first
      custom_path && File.exists?(custom_path) ->
        {:executable, custom_path}

      # Check for pre-built executable
      File.exists?(@cli_path) ->
        {:executable, @cli_path}

      # Check for dotnet project
      File.exists?(Path.join(@dotnet_project_path, "Cepaf.Podman.fsproj")) ->
        {:dotnet_run, @dotnet_project_path}

      # Fallback to assuming podman CLI directly
      true ->
        {:podman_direct, "podman"}
    end
  end

  defp execute_command(state, args, timeout, from, output_mode) do
    start_time = System.monotonic_time(:millisecond)

    # Build command based on CLI mode
    {cmd, cmd_args} = build_command(state.cli_mode, state.cli_path, args)

    # Emit telemetry for command start
    :telemetry.execute(
      [:indrajaal, :cepaf_port, :command, :start],
      %{system_time: System.system_time()},
      %{command: hd(args), args: args, mode: state.cli_mode}
    )

    try do
      # Open port to execute command
      port_opts = [
        :binary,
        :exit_status,
        :use_stdio,
        :stderr_to_stdout,
        args: cmd_args
      ]

      port = Port.open({:spawn_executable, cmd}, port_opts)

      # Set up timeout
      timeout_ref = Process.send_after(self(), {:timeout, make_ref()}, timeout)

      # Store pending request
      request = %{
        from: from,
        port: port,
        output_mode: output_mode,
        buffer: "",
        start_time: start_time,
        timeout_ref: timeout_ref,
        command: hd(args)
      }

      new_pending = Map.put(state.pending_requests, port, request)

      {:noreply, %{state | pending_requests: new_pending}}
    rescue
      error ->
        Logger.error("CepafPort: Failed to execute command",
          command: cmd,
          args: cmd_args,
          error: inspect(error)
        )

        {:reply, {:error, {:execution_failed, error}}, state}
    end
  end

  defp build_command(:executable, path, args) do
    {path, args}
  end

  defp build_command(:dotnet_run, project_path, args) do
    dotnet_path = System.find_executable("dotnet") || "dotnet"
    {dotnet_path, ["run", "--project", project_path, "--"] ++ args}
  end

  defp build_command(:podman_direct, _path, args) do
    podman_path = System.find_executable("podman") || "podman"
    {podman_path, translate_to_podman_args(args)}
  end

  # Translate our CLI args to direct podman args
  defp translate_to_podman_args(["containers", "list" | rest]) do
    ["ps"] ++ rest
  end

  defp translate_to_podman_args(["containers", "inspect" | rest]) do
    ["inspect"] ++ rest
  end

  defp translate_to_podman_args(["containers", "logs" | rest]) do
    ["logs"] ++ rest
  end

  defp translate_to_podman_args(["containers", "restart", id | _rest]) do
    ["restart", id]
  end

  defp translate_to_podman_args(["containers", "stats" | rest]) do
    ["stats"] ++ rest
  end

  defp translate_to_podman_args(["health", "summary" | _rest]) do
    # For health summary, we list all and parse health status
    ["ps", "--all", "--format", "json"]
  end

  defp translate_to_podman_args(["health", "check", id | _rest]) do
    ["healthcheck", "run", id]
  end

  defp translate_to_podman_args(["system", "info" | rest]) do
    ["info"] ++ rest
  end

  defp translate_to_podman_args(["system", "ping"]) do
    ["info", "--format", "{{.Host.Hostname}}"]
  end

  defp translate_to_podman_args(args) do
    args
  end

  defp handle_port_output(state, port, data) do
    case Map.get(state.pending_requests, port) do
      nil ->
        {:noreply, state}

      request ->
        # Append data to buffer
        updated_request = %{request | buffer: request.buffer <> data}
        new_pending = Map.put(state.pending_requests, port, updated_request)
        {:noreply, %{state | pending_requests: new_pending}}
    end
  end

  defp handle_port_exit(state, port, exit_status) do
    case Map.pop(state.pending_requests, port) do
      {nil, _} ->
        {:noreply, state}

      {request, new_pending} ->
        # Cancel timeout
        Process.cancel_timer(request.timeout_ref)

        # Calculate duration
        duration = System.monotonic_time(:millisecond) - request.start_time

        # Process result
        result = process_command_result(request, exit_status, duration)

        # Reply to caller
        GenServer.reply(request.from, result)

        {:noreply, %{state | pending_requests: new_pending}}
    end
  end

  defp handle_command_timeout(state, _ref) do
    # Find timed out requests and terminate them
    {timed_out, remaining} =
      Enum.split_with(state.pending_requests, fn {_port, request} ->
        elapsed = System.monotonic_time(:millisecond) - request.start_time
        elapsed >= state.request_timeout
      end)

    # Reply with timeout error and close ports
    Enum.each(timed_out, fn {port, request} ->
      Port.close(port)
      GenServer.reply(request.from, {:error, :timeout})

      :telemetry.execute(
        [:indrajaal, :cepaf_port, :command, :timeout],
        %{duration_ms: System.monotonic_time(:millisecond) - request.start_time},
        %{command: request.command}
      )
    end)

    {:noreply, %{state | pending_requests: Map.new(remaining)}}
  end

  defp process_command_result(request, exit_status, duration) do
    # Emit telemetry
    :telemetry.execute(
      [:indrajaal, :cepaf_port, :command, :stop],
      %{duration_ms: duration},
      %{command: request.command, exit_status: exit_status, success: exit_status == 0}
    )

    if exit_status == 0 do
      case request.output_mode do
        :json ->
          parse_json_output(request.buffer)

        :raw ->
          {:ok, String.trim(request.buffer)}
      end
    else
      Logger.warning("CepafPort: Command failed",
        command: request.command,
        exit_status: exit_status,
        output: String.slice(request.buffer, 0, 500)
      )

      {:error, {:command_failed, exit_status, request.buffer}}
    end
  end

  defp parse_json_output(output) do
    trimmed = String.trim(output)

    if trimmed == "" do
      {:ok, []}
    else
      case Jason.decode(trimmed) do
        {:ok, data} ->
          {:ok, normalize_response(data)}

        {:error, error} ->
          Logger.warning("CepafPort: Failed to parse JSON output",
            error: inspect(error),
            output: String.slice(trimmed, 0, 200)
          )

          {:error, {:json_parse_error, error}}
      end
    end
  end

  # Normalize response keys to atoms and transform data
  defp normalize_response(data) when is_list(data) do
    Enum.map(data, &normalize_response/1)
  end

  defp normalize_response(data) when is_map(data) do
    data
    |> Enum.map(fn {k, v} ->
      key =
        k
        |> to_string()
        |> Macro.underscore()
        |> String.to_atom()

      {key, normalize_value(key, v)}
    end)
    |> Map.new()
  end

  defp normalize_response(data), do: data

  # Normalize specific values
  defp normalize_value(:status, status) when is_binary(status) do
    case String.downcase(status) do
      "running" -> :running
      "exited" -> :exited
      "created" -> :created
      "paused" -> :paused
      "dead" -> :dead
      _ -> :unknown
    end
  end

  defp normalize_value(:state, state) when is_map(state) do
    normalize_response(state)
  end

  defp normalize_value(:health, health) when is_binary(health) do
    case String.downcase(health) do
      "healthy" -> :healthy
      "unhealthy" -> :unhealthy
      "starting" -> :starting
      "none" -> :no_healthcheck
      _ -> :unknown
    end
  end

  defp normalize_value(:created, timestamp) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end

  defp normalize_value(:started_at, timestamp), do: normalize_value(:created, timestamp)
  defp normalize_value(:finished_at, timestamp), do: normalize_value(:created, timestamp)

  defp normalize_value(_key, value) when is_map(value), do: normalize_response(value)

  defp normalize_value(_key, value) when is_list(value),
    do: Enum.map(value, &normalize_response/1)

  defp normalize_value(_key, value), do: value
end
