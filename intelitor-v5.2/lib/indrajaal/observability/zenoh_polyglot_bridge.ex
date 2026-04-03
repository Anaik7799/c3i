defmodule Indrajaal.Observability.ZenohPolygotBridge do
  @moduledoc """
  Polyglot Bridge for Python/Mojo AI model communication via Zenoh.

  WHAT: Bridges Elixir BEAM with Python/Mojo AI models using subprocess IPC.
  WHY: AI models (Gemini, Claude, Local) run in Python; need zero-copy IPC.
  CONSTRAINTS: Must use subprocess isolation, JSON-RPC protocol, timeouts.

  ## Architecture

  ```
  ┌─────────────────┐     JSON-RPC      ┌─────────────────┐
  │  Elixir BEAM    │◄─────────────────►│  Python Process │
  │  (This module)  │    stdin/stdout   │  (zenoh_bridge) │
  └─────────────────┘                   └─────────────────┘
          │                                      │
          │              Zenoh                   │
          └──────────────────────────────────────┘
  ```

  ## Protocol

  Request (Elixir → Python):
  ```json
  {"jsonrpc": "2.0", "method": "analyze", "params": {...}, "id": 1}
  ```

  Response (Python → Elixir):
  ```json
  {"jsonrpc": "2.0", "result": {...}, "id": 1}
  ```

  ## STAMP Constraints

  - SC-INT-001: Subprocess isolation (no shared memory corruption)
  - SC-INT-002: Request timeout < 30s
  - SC-INT-003: Graceful degradation on Python failure

  ## AOR Rules

  - AOR-CTX-010: Polyglot bridge MUST use subprocess (not NIF)

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-26 |
  | Author | Cybernetic Architect |
  | STAMP | SC-INT-001, SC-INT-002, SC-INT-003 |
  """

  use GenServer
  require Logger

  # ============================================================
  # TYPE DEFINITIONS
  # ============================================================

  @type bridge_config :: %{
          python_path: String.t(),
          script_path: String.t(),
          timeout_ms: pos_integer(),
          max_retries: non_neg_integer()
        }

  @type rpc_request :: %{
          jsonrpc: String.t(),
          method: String.t(),
          params: map(),
          id: pos_integer()
        }

  @type rpc_response :: %{
          jsonrpc: String.t(),
          result: term(),
          id: pos_integer()
        }

  # ============================================================
  # CONSTANTS
  # ============================================================

  @default_timeout_ms 30_000
  @max_retries 3
  @python_script "scripts/ai/zenoh_bridge.py"
  @health_check_interval 30_000

  # ============================================================
  # CLIENT API
  # ============================================================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Call a method on the Python bridge.

  ## Parameters
  - method: Method name (string)
  - params: Parameters map
  - opts: Options
    - :timeout - Request timeout in ms (default: 30_000)

  ## Returns
  - {:ok, result}
  - {:error, reason}
  """
  @spec call(String.t(), map(), keyword()) :: {:ok, term()} | {:error, term()}
  def call(method, params, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout_ms)
    GenServer.call(__MODULE__, {:call, method, params}, timeout + 1000)
  end

  @doc """
  Send a request to Gemini for context analysis.

  ## Parameters
  - files: List of file paths to analyze
  - query: Analysis query

  ## Returns
  - {:ok, analysis_result}
  - {:error, reason}
  """
  @spec analyze_with_gemini([String.t()], String.t()) :: {:ok, map()} | {:error, term()}
  def analyze_with_gemini(files, query) do
    call("gemini_analyze", %{files: files, query: query})
  end

  @doc """
  Send a request to Claude for code generation.

  ## Parameters
  - analysis: Context analysis from Gemini
  - requirements: Code generation requirements

  ## Returns
  - {:ok, generated_code}
  - {:error, reason}
  """
  @spec generate_with_claude(map(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def generate_with_claude(analysis, requirements) do
    call("claude_generate", %{analysis: analysis, requirements: requirements})
  end

  @doc """
  Send a request to Local AI (Ollama) for fast inference.

  ## Parameters
  - prompt: The prompt
  - opts: Model options

  ## Returns
  - {:ok, response}
  - {:error, reason}
  """
  @spec infer_local(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def infer_local(prompt, opts \\ []) do
    model = Keyword.get(opts, :model, "llama3")
    call("local_infer", %{prompt: prompt, model: model})
  end

  @doc """
  Check if the Python bridge is healthy.
  """
  @spec healthy?() :: boolean()
  def healthy? do
    GenServer.call(__MODULE__, :healthy?)
  catch
    :exit, _ -> false
  end

  @doc """
  Get bridge statistics.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  @doc """
  Restart the Python subprocess.
  """
  @spec restart() :: :ok | {:error, term()}
  def restart do
    GenServer.call(__MODULE__, :restart)
  end

  # ============================================================
  # SERVER CALLBACKS
  # ============================================================

  @impl true
  def init(opts) do
    Logger.info("[ZenohPolygotBridge] Initializing Python bridge - SC-INT-001")

    config = %{
      python_path: Keyword.get(opts, :python_path, "python3"),
      script_path: Keyword.get(opts, :script_path, @python_script),
      timeout_ms: Keyword.get(opts, :timeout_ms, @default_timeout_ms),
      max_retries: Keyword.get(opts, :max_retries, @max_retries)
    }

    state = %{
      config: config,
      port: nil,
      request_id: 0,
      pending_requests: %{},
      # Statistics
      total_requests: 0,
      successful_requests: 0,
      failed_requests: 0,
      total_latency_ms: 0,
      last_error: nil,
      healthy: false,
      started_at: DateTime.utc_now()
    }

    # Try to start the Python process
    new_state = start_python_process(state)

    # Schedule health checks
    schedule_health_check()

    {:ok, new_state}
  end

  @impl true
  def handle_call({:call, method, params}, from, state) do
    if state.port == nil do
      {:reply, {:error, :bridge_not_running}, state}
    else
      # Generate request ID
      request_id = state.request_id + 1

      request = %{
        jsonrpc: "2.0",
        method: method,
        params: params,
        id: request_id
      }

      # Send request to Python
      case send_request(state.port, request) do
        :ok ->
          # Track pending request
          pending = %{
            from: from,
            method: method,
            started_at: System.monotonic_time(:millisecond)
          }

          new_pending = Map.put(state.pending_requests, request_id, pending)

          new_state = %{
            state
            | request_id: request_id,
              pending_requests: new_pending,
              total_requests: state.total_requests + 1
          }

          # Set timeout for this request
          Process.send_after(self(), {:timeout, request_id}, state.config.timeout_ms)

          {:noreply, new_state}

        {:error, reason} ->
          {:reply, {:error, reason}, %{state | failed_requests: state.failed_requests + 1}}
      end
    end
  end

  @impl true
  def handle_call(:healthy?, _from, state) do
    {:reply, state.healthy and state.port != nil, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    avg_latency =
      if state.successful_requests > 0,
        do: state.total_latency_ms / state.successful_requests,
        else: 0.0

    stats = %{
      healthy: state.healthy,
      port_alive: state.port != nil,
      total_requests: state.total_requests,
      successful_requests: state.successful_requests,
      failed_requests: state.failed_requests,
      pending_requests: map_size(state.pending_requests),
      avg_latency_ms: Float.round(avg_latency, 2),
      last_error: state.last_error,
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at)
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_call(:restart, _from, state) do
    # Close existing port
    new_state =
      if state.port do
        Port.close(state.port)
        %{state | port: nil, healthy: false}
      else
        state
      end

    # Start new process
    final_state = start_python_process(new_state)
    {:reply, :ok, final_state}
  end

  @impl true
  def handle_info({port, {:data, {:eol, line}}}, %{port: port} = state) do
    # Port with :line option wraps data in {:eol, line} tuple
    handle_line_data(line, state)
  end

  @impl true
  def handle_info({port, {:data, data}}, %{port: port} = state) when is_binary(data) do
    # Handle raw binary data
    handle_line_data(data, state)
  end

  @impl true
  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    Logger.warning("[ZenohPolygotBridge] Python process exited with status #{status}")

    # Reply to all pending requests with error
    Enum.each(state.pending_requests, fn {_id, pending} ->
      GenServer.reply(pending.from, {:error, :bridge_crashed})
    end)

    new_state = %{
      state
      | port: nil,
        healthy: false,
        pending_requests: %{},
        last_error: {:exit, status}
    }

    # Try to restart after delay
    Process.send_after(self(), :restart_python, 5000)

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:timeout, request_id}, state) do
    case Map.pop(state.pending_requests, request_id) do
      {nil, _} ->
        # Already handled
        {:noreply, state}

      {pending, new_pending} ->
        GenServer.reply(pending.from, {:error, :timeout})

        new_state = %{
          state
          | pending_requests: new_pending,
            failed_requests: state.failed_requests + 1,
            last_error: :timeout
        }

        {:noreply, new_state}
    end
  end

  @impl true
  def handle_info(:restart_python, state) do
    if state.port == nil do
      new_state = start_python_process(state)
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:health_check, state) do
    new_state =
      if state.port != nil do
        # Send ping request
        request = %{jsonrpc: "2.0", method: "ping", params: %{}, id: 0}

        case send_request(state.port, request) do
          :ok -> %{state | healthy: true}
          {:error, _} -> %{state | healthy: false}
        end
      else
        %{state | healthy: false}
      end

    schedule_health_check()
    {:noreply, new_state}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # ============================================================
  # PRIVATE FUNCTIONS
  # ============================================================

  defp handle_line_data(data, state) do
    # Parse JSON-RPC response
    case Jason.decode(data) do
      {:ok, %{"jsonrpc" => "2.0", "result" => result, "id" => id}} ->
        handle_response(state, id, {:ok, result})

      {:ok, %{"jsonrpc" => "2.0", "error" => error, "id" => id}} ->
        handle_response(state, id, {:error, error})

      {:error, reason} ->
        Logger.warning("[ZenohPolygotBridge] Failed to parse response: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  defp start_python_process(state) do
    script_path = Path.expand(state.config.script_path, File.cwd!())

    if File.exists?(script_path) do
      try do
        port =
          Port.open({:spawn_executable, System.find_executable(state.config.python_path)}, [
            :binary,
            :exit_status,
            {:args, [script_path]},
            {:line, 1_000_000}
          ])

        Logger.info("[ZenohPolygotBridge] Python bridge started")
        %{state | port: port, healthy: true}
      rescue
        e ->
          Logger.error("[ZenohPolygotBridge] Failed to start Python: #{inspect(e)}")
          %{state | port: nil, healthy: false, last_error: {:start_failed, e}}
      end
    else
      Logger.warning("[ZenohPolygotBridge] Python script not found: #{script_path}")
      %{state | port: nil, healthy: false, last_error: :script_not_found}
    end
  end

  defp send_request(port, request) do
    json = Jason.encode!(request) <> "\n"

    try do
      Port.command(port, json)
      :ok
    rescue
      e -> {:error, e}
    end
  end

  defp handle_response(state, id, result) do
    case Map.pop(state.pending_requests, id) do
      {nil, _} ->
        # Unknown request ID (possibly timed out)
        {:noreply, state}

      {pending, new_pending} ->
        latency = System.monotonic_time(:millisecond) - pending.started_at
        GenServer.reply(pending.from, result)

        {successful, failed} =
          case result do
            {:ok, _} -> {state.successful_requests + 1, state.failed_requests}
            {:error, _} -> {state.successful_requests, state.failed_requests + 1}
          end

        new_state = %{
          state
          | pending_requests: new_pending,
            successful_requests: successful,
            failed_requests: failed,
            total_latency_ms: state.total_latency_ms + latency
        }

        {:noreply, new_state}
    end
  end

  defp schedule_health_check do
    Process.send_after(self(), :health_check, @health_check_interval)
  end
end
