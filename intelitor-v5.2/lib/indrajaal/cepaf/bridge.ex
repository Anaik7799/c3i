defmodule Indrajaal.Cepaf.Bridge do
  @moduledoc """
  GenServer managing the Erlang Port to the Cepaf.Bridge F# process.

  ## Overview

  This module provides a persistent connection to the F# Cepaf.Bridge server,
  enabling type-safe container management with STAMP safety constraints.

  ## Architecture

  ```
  Elixir Application
        |
        v
  +-------------------+
  | Cepaf.Bridge      | <-- This GenServer
  | (Port Manager)    |
  +-------------------+
        |
        | Erlang Port (stdio)
        v
  +-------------------+
  | cepaf-bridge      | <-- F# process
  | (JSON-RPC server) |
  +-------------------+
        |
        | Unix Socket
        v
  +-------------------+
  | Podman 5.4.1+     |
  +-------------------+
  ```

  ## Usage

      {:ok, pid} = Indrajaal.Cepaf.Bridge.start_link()
      {:ok, response} = Indrajaal.Cepaf.Bridge.call(pid, "system.ping")

  ## Safety Constraints

  - SC-PRF-050: Response latency < 50ms (target)
  - SC-EMR-057: Emergency stop < 5s
  """

  use GenServer
  require Logger

  @default_timeout 30_000
  @bridge_executable "cepaf-bridge"
  @heartbeat_interval 10_000
  @max_reconnect_backoff 60_000
  @initial_reconnect_delay 1_000

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Start the Bridge GenServer.

  ## Options

    * `:executable` - Path to cepaf-bridge executable (default: searches PATH)
    * `:timeout` - Default call timeout in ms (default: 30_000)

  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Make a JSON-RPC call to the bridge.

  ## Parameters

    * `method` - The RPC method name (e.g., "system.ping")
    * `params` - Optional parameters map (default: %{})
    * `timeout` - Call timeout in ms (default: 30_000)

  ## Returns

    * `{:ok, result}` - Success with result map
    * `{:error, type, details}` - Error with type atom and details

  ## Examples

      {:ok, %{"status" => "ok"}} = Bridge.call("system.ping")

      {:ok, result} = Bridge.call("container.list", %{all: true})

  """
  def call(method, params \\ %{}, timeout \\ @default_timeout) do
    GenServer.call(__MODULE__, {:call, method, params}, timeout)
  end

  @doc """
  Cast a JSON-RPC notification (no response expected).
  """
  def cast(method, params \\ %{}) do
    GenServer.cast(__MODULE__, {:cast, method, params})
  end

  @doc """
  Check if the bridge is alive and connected.
  """
  def alive?() do
    case call("system.ping", %{}, 5_000) do
      {:ok, %{"status" => "ok"}} -> true
      _ -> false
    end
  catch
    :exit, _ -> false
  end

  @doc """
  Stop the bridge gracefully.
  """
  def stop() do
    GenServer.stop(__MODULE__, :normal)
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  defmodule State do
    @moduledoc false
    defstruct [
      :port,
      :executable,
      :timeout,
      :request_id,
      :pending_requests,
      :buffer,
      :heartbeat_ref,
      :reconnect_attempts,
      :last_heartbeat_at,
      :connected
    ]
  end

  @impl true
  def init(opts) do
    executable = Keyword.get(opts, :executable, find_executable())
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    case start_port(executable) do
      {:ok, port} ->
        heartbeat_ref = schedule_heartbeat()

        state = %State{
          port: port,
          executable: executable,
          timeout: timeout,
          request_id: 0,
          pending_requests: %{},
          buffer: "",
          heartbeat_ref: heartbeat_ref,
          reconnect_attempts: 0,
          last_heartbeat_at: nil,
          connected: true
        }

        emit_telemetry(:connected, %{executable: executable})
        Logger.info("Cepaf.Bridge started with executable: #{executable}")
        {:ok, state}

      {:error, reason} ->
        Logger.error("Failed to start Cepaf.Bridge: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:call, _method, _params}, _from, %{connected: false} = state) do
    {:reply, {:error, :disconnected, %{message: "Bridge not connected"}}, state}
  end

  def handle_call({:call, method, params}, from, state) do
    {id, state} = next_request_id(state)
    request = encode_request(id, method, params)

    case send_to_port(state.port, request) do
      :ok ->
        # Store pending request
        pending = Map.put(state.pending_requests, id, {from, System.monotonic_time(:millisecond)})
        {:noreply, %{state | pending_requests: pending}}

      {:error, reason} ->
        {:reply, {:error, :port_error, reason}, state}
    end
  end

  @impl true
  def handle_cast({:cast, method, params}, state) do
    # Notifications have no id
    request = encode_notification(method, params)
    send_to_port(state.port, request)
    {:noreply, state}
  end

  @impl true
  def handle_info({port, {:data, data}}, %{port: port} = state) do
    # Handle data from port (may be partial lines)
    buffer = state.buffer <> to_string(data)
    {responses, remaining_buffer} = extract_lines(buffer)

    state = %{state | buffer: remaining_buffer}

    state =
      Enum.reduce(responses, state, fn line, acc ->
        process_response(line, acc)
      end)

    {:noreply, state}
  end

  @impl true
  def handle_info(:heartbeat, state) do
    state =
      if state.connected do
        case send_to_port(state.port, encode_request("hb", "system.ping", %{})) do
          :ok ->
            %{state | last_heartbeat_at: System.monotonic_time(:millisecond)}

          {:error, _reason} ->
            Logger.warning("Cepaf.Bridge heartbeat failed, marking disconnected")
            emit_telemetry(:heartbeat_failed, %{})
            %{state | connected: false}
        end
      else
        state
      end

    heartbeat_ref = schedule_heartbeat()
    {:noreply, %{state | heartbeat_ref: heartbeat_ref}}
  end

  @impl true
  def handle_info(:reconnect, state) do
    Logger.info("Cepaf.Bridge attempting reconnect (attempt #{state.reconnect_attempts + 1})")
    emit_telemetry(:reconnecting, %{attempt: state.reconnect_attempts + 1})

    case start_port(state.executable) do
      {:ok, new_port} ->
        Logger.info("Cepaf.Bridge reconnected successfully")
        emit_telemetry(:reconnected, %{attempts: state.reconnect_attempts + 1})

        {:noreply,
         %{
           state
           | port: new_port,
             pending_requests: %{},
             buffer: "",
             reconnect_attempts: 0,
             connected: true
         }}

      {:error, reason} ->
        attempts = state.reconnect_attempts + 1
        delay = min(@initial_reconnect_delay * Integer.pow(2, attempts), @max_reconnect_backoff)

        Logger.warning(
          "Cepaf.Bridge reconnect failed: #{inspect(reason)}, retrying in #{delay}ms"
        )

        Process.send_after(self(), :reconnect, delay)
        {:noreply, %{state | reconnect_attempts: attempts, connected: false}}
    end
  end

  @impl true
  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    Logger.error("Cepaf.Bridge exited with status: #{status}")
    emit_telemetry(:crashed, %{exit_status: status})

    # Fail all pending requests
    for {_id, {from, _start}} <- state.pending_requests do
      GenServer.reply(from, {:error, :bridge_crashed, status})
    end

    # Schedule reconnect with exponential backoff
    delay =
      min(
        @initial_reconnect_delay * Integer.pow(2, state.reconnect_attempts),
        @max_reconnect_backoff
      )

    Process.send_after(self(), :reconnect, delay)

    {:noreply, %{state | port: nil, pending_requests: %{}, buffer: "", connected: false}}
  end

  @impl true
  def handle_info({:DOWN, _ref, :port, port, reason}, %{port: port} = state) do
    Logger.error("Cepaf.Bridge port down: #{inspect(reason)}")
    {:stop, {:port_down, reason}, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.warning("Cepaf.Bridge received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("Cepaf.Bridge terminating: #{inspect(reason)}")

    if state.heartbeat_ref, do: Process.cancel_timer(state.heartbeat_ref)

    if state.port do
      try do
        Port.close(state.port)
      rescue
        _ -> :ok
      end
    end

    :ok
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp find_executable do
    # Look in common locations
    paths = [
      # Local build output
      Path.join([
        File.cwd!(),
        "lib",
        "cepaf",
        "src",
        "Cepaf.Bridge",
        "bin",
        "Release",
        "net8.0",
        @bridge_executable
      ]),
      Path.join([
        File.cwd!(),
        "lib",
        "cepaf",
        "src",
        "Cepaf.Bridge",
        "bin",
        "Debug",
        "net8.0",
        @bridge_executable
      ]),
      # System PATH
      System.find_executable(@bridge_executable)
    ]

    Enum.find(paths, &(&1 && File.exists?(&1))) || @bridge_executable
  end

  defp start_port(executable) do
    try do
      port =
        Port.open(
          {:spawn_executable, executable},
          [
            :binary,
            :exit_status,
            :use_stdio,
            :hide,
            # 1MB line buffer
            {:line, 1024 * 1024}
          ]
        )

      {:ok, port}
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  defp send_to_port(port, message) do
    try do
      Port.command(port, message <> "\n")
      :ok
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  defp next_request_id(state) do
    id = state.request_id + 1
    {Integer.to_string(id), %{state | request_id: id}}
  end

  defp encode_request(id, method, params) do
    %{
      jsonrpc: "2.0",
      id: id,
      method: method,
      params: params
    }
    |> Jason.encode!()
  end

  defp encode_notification(method, params) do
    %{
      jsonrpc: "2.0",
      method: method,
      params: params
    }
    |> Jason.encode!()
  end

  defp extract_lines(buffer) do
    lines = String.split(buffer, "\n")

    case List.last(lines) do
      "" ->
        # Buffer ended with newline, all lines complete
        {Enum.drop(lines, -1), ""}

      partial ->
        # Last line is partial
        {Enum.drop(lines, -1), partial}
    end
  end

  defp process_response("", state), do: state

  defp process_response(line, state) do
    case Jason.decode(line) do
      {:ok, %{"id" => id} = response} when not is_nil(id) ->
        case Map.pop(state.pending_requests, id) do
          {nil, _} ->
            Logger.warning("Received response for unknown request ID: #{id}")
            state

          {{from, start_time}, pending} ->
            duration = System.monotonic_time(:millisecond) - start_time
            Logger.debug("Cepaf.Bridge response for #{id} in #{duration}ms")

            reply = parse_response(response)
            GenServer.reply(from, reply)

            %{state | pending_requests: pending}
        end

      {:ok, %{"error" => _} = response} ->
        # Error without ID - log it
        Logger.error("Cepaf.Bridge error: #{inspect(response)}")
        state

      {:error, reason} ->
        Logger.error("Failed to parse Cepaf.Bridge response: #{inspect(reason)}, line: #{line}")
        state
    end
  end

  defp parse_response(%{"result" => result}) do
    {:ok, result}
  end

  defp parse_response(%{"error" => %{"code" => code, "message" => message} = error}) do
    type = error_code_to_atom(code)
    data = Map.get(error, "data", %{})
    {:error, type, %{message: message, code: code, data: data}}
  end

  defp schedule_heartbeat do
    Process.send_after(self(), :heartbeat, @heartbeat_interval)
  end

  defp emit_telemetry(event, metadata) do
    :telemetry.execute(
      [:indrajaal, :cepaf, :bridge, event],
      %{system_time: System.system_time(:millisecond)},
      metadata
    )
  end

  defp error_code_to_atom(code) do
    case code do
      -32700 -> :parse_error
      -32600 -> :invalid_request
      -32601 -> :method_not_found
      -32602 -> :invalid_params
      -32603 -> :internal_error
      -32001 -> :socket_not_found
      -32002 -> :connection_refused
      -32003 -> :connection_timeout
      -32004 -> :container_not_found
      -32005 -> :container_exists
      -32006 -> :image_not_found
      -32007 -> :health_check_failed
      -32008 -> :safety_violation
      -32009 -> :network_not_found
      -32010 -> :volume_not_found
      _ -> :unknown_error
    end
  end
end
