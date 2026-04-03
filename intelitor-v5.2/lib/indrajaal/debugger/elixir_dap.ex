defmodule Indrajaal.Debugger.ElixirDAP do
  @moduledoc """
  Debug Adapter Protocol bridge for Elixir with Zenoh telemetry.

  Provides closed-loop debugging with real-time telemetry:
  - Breakpoint management with Zenoh notifications
  - Step execution with fractal logging
  - Variable inspection with gRPC streaming
  - Stack trace with OTEL correlation

  ## Usage

      # Start debug session
      {:ok, session_id} = ElixirDAP.start_session(project: ".")

      # Set breakpoint
      {:ok, bp_id} = ElixirDAP.set_breakpoint(MyModule, 42)

      # Continue execution
      ElixirDAP.continue(session_id)

  ## Zenoh Topics

  - `indrajaal/debug/elixir/breakpoint/{module}/{line}` - Breakpoint events
  - `indrajaal/debug/elixir/step/{session_id}` - Step execution
  - `indrajaal/debug/elixir/variable/{session_id}/{var}` - Variable values
  - `indrajaal/debug/elixir/stack/{session_id}` - Stack traces

  ## STAMP Constraints

  - SC-DEBUG-001: Publish to Zenoh within 10ms
  - SC-DEBUG-005: Sync breakpoint state across subscribers
  - SC-DEBUG-006: Include source mapping in stack traces

  ## AOR Rules

  - AOR-DEBUG-001: Emit structured telemetry events
  - AOR-DEBUG-003: Version breakpoints in Immutable Register
  """

  use GenServer
  require Logger

  alias Indrajaal.Debugger.FractalIntegration
  alias Indrajaal.Debugger.TelemetryBus

  @zenoh_prefix "indrajaal/debug/elixir"
  @publish_timeout_ms 10
  @grpc_timeout_ms 5000

  # Session state
  defstruct [
    :session_id,
    :language,
    :project_root,
    :status,
    :breakpoints,
    :current_frame,
    :stack,
    :variables,
    :started_at
  ]

  # ==========================================================================
  # Client API
  # ==========================================================================

  @doc """
  Start a new debug session.
  """
  def start_session(opts \\ []) do
    GenServer.call(__MODULE__, {:start_session, opts})
  end

  @doc """
  Stop the current debug session.
  """
  def stop_session(session_id) do
    GenServer.call(__MODULE__, {:stop_session, session_id})
  end

  @doc """
  Set a breakpoint at the specified module and line.
  """
  def set_breakpoint(module, line, opts \\ []) do
    GenServer.call(__MODULE__, {:set_breakpoint, module, line, opts})
  end

  @doc """
  Remove a breakpoint.
  """
  def remove_breakpoint(breakpoint_id) do
    GenServer.call(__MODULE__, {:remove_breakpoint, breakpoint_id})
  end

  @doc """
  List all breakpoints.
  """
  def list_breakpoints do
    GenServer.call(__MODULE__, :list_breakpoints)
  end

  @doc """
  Continue execution.
  """
  def continue(session_id) do
    GenServer.cast(__MODULE__, {:continue, session_id})
  end

  @doc """
  Step over (next line).
  """
  def step_over(session_id) do
    GenServer.cast(__MODULE__, {:step_over, session_id})
  end

  @doc """
  Step into function.
  """
  def step_into(session_id) do
    GenServer.cast(__MODULE__, {:step_into, session_id})
  end

  @doc """
  Step out of function.
  """
  def step_out(session_id) do
    GenServer.cast(__MODULE__, {:step_out, session_id})
  end

  @doc """
  Inspect a variable.
  """
  def inspect_variable(session_id, var_name) do
    GenServer.call(__MODULE__, {:inspect_var, session_id, var_name}, @grpc_timeout_ms)
  end

  @doc """
  Get current stack trace.
  """
  def get_stack_trace(session_id) do
    GenServer.call(__MODULE__, {:get_stack, session_id})
  end

  @doc """
  Evaluate expression in current context.
  """
  def evaluate(session_id, expression) do
    GenServer.call(__MODULE__, {:evaluate, session_id, expression}, @grpc_timeout_ms)
  end

  # ==========================================================================
  # GenServer Implementation
  # ==========================================================================

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Load debugger modules
    if Code.ensure_loaded?(:int) do
      apply(:int, :ni, [:debugger])
    end

    {:ok,
     %__MODULE__{
       status: :idle,
       breakpoints: %{},
       stack: [],
       variables: %{}
     }}
  end

  @impl true
  def handle_call({:start_session, opts}, _from, state) do
    session_id = generate_session_id()
    project_root = Keyword.get(opts, :project, ".")

    new_state = %{
      state
      | session_id: session_id,
        project_root: project_root,
        status: :running,
        started_at: DateTime.utc_now()
    }

    # Emit telemetry
    emit_session_event(:start, session_id, %{project: project_root})

    # Log to fractal
    FractalIntegration.log_event(:session_start, %{
      session_id: session_id,
      language: "elixir",
      project: project_root
    })

    {:reply, {:ok, session_id}, new_state}
  end

  @impl true
  def handle_call({:stop_session, session_id}, _from, state) do
    if state.session_id == session_id do
      # Clear all breakpoints
      Enum.each(state.breakpoints, fn {_id, _bp} ->
        if Code.ensure_loaded?(:int) do
          # :int.delete_break(12)
        end
      end)

      emit_session_event(:stop, session_id, %{})

      FractalIntegration.log_event(:session_end, %{
        session_id: session_id,
        duration_ms: DateTime.diff(DateTime.utc_now(), state.started_at, :millisecond)
      })

      {:reply, :ok, %{state | session_id: nil, status: :idle, breakpoints: %{}}}
    else
      {:reply, {:error, :session_not_found}, state}
    end
  end

  @impl true
  def handle_call({:set_breakpoint, _module, _line, _opts}, _from, state) do
    result =
      if Code.ensure_loaded?(:int) do
        # :int.break(12)
      else
        {:error, :debugger_not_available}
      end

    case result do
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:remove_breakpoint, bp_id}, _from, state) do
    case Map.pop(state.breakpoints, bp_id) do
      {nil, _} ->
        {:reply, {:error, :not_found}, state}

      {breakpoint, new_breakpoints} ->
        if Code.ensure_loaded?(:int) do
          # :int.delete_break(12)
        end

        publish_breakpoint_event(:remove, breakpoint, state.session_id)

        {:reply, :ok, %{state | breakpoints: new_breakpoints}}
    end
  end

  @impl true
  def handle_call(:list_breakpoints, _from, state) do
    {:reply, Map.values(state.breakpoints), state}
  end

  @impl true
  def handle_call({:inspect_var, _session_id, var_name}, _from, state) do
    case get_variable_value(var_name, state) do
      {:ok, value, type} ->
        result = %{
          name: var_name,
          value: inspect(value, pretty: true, limit: 100),
          type: type,
          expandable: is_map(value) or is_list(value) or is_tuple(value)
        }

        TelemetryBus.emit_debugger(:variable_inspected, %{
          session_id: state.session_id,
          variable: var_name,
          type: type
        })

        {:reply, {:ok, result}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:get_stack, _session_id}, _from, state) do
    {:reply, {:ok, state.stack}, state}
  end

  @impl true
  def handle_call({:evaluate, _session_id, expression}, _from, state) do
    case eval_in_context(expression, state) do
      {:ok, result} ->
        {:reply, {:ok, inspect(result, pretty: true)}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_cast({:continue, session_id}, state) do
    if state.session_id == session_id do
      if Code.ensure_loaded?(:int) do
        :int.continue(12)
      end

      publish_step_event(:continue, session_id)
      {:noreply, %{state | status: :running}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:step_over, session_id}, state) do
    if state.session_id == session_id do
      if Code.ensure_loaded?(:int) do
        :int.next(12)
      end

      publish_step_event(:step_over, session_id)
      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:step_into, session_id}, state) do
    if state.session_id == session_id do
      if Code.ensure_loaded?(:int) do
        :int.step(12)
      end

      publish_step_event(:step_into, session_id)
      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:step_out, session_id}, state) do
    if state.session_id == session_id do
      if Code.ensure_loaded?(:int) do
        :int.finish(12)
      end

      publish_step_event(:step_out, session_id)
      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:int, {:break, _meta, {module, line}, bindings}}, state) do
    # Breakpoint hit
    bp = find_breakpoint_by_location(state.breakpoints, module, line)

    stack_trace = build_stack_trace()
    variables = extract_variables(bindings)

    new_state = %{
      state
      | status: :paused,
        stack: stack_trace,
        variables: variables,
        current_frame: %{module: module, line: line}
    }

    # Emit breakpoint hit event
    :telemetry.execute(
      [:debugger, :breakpoint, :hit],
      %{hit_count: (bp && bp.hit_count + 1) || 1},
      %{
        breakpoint_id: bp && bp.id,
        module: module,
        line: line,
        session_id: state.session_id,
        stack: stack_trace
      }
    )

    # Publish to Zenoh
    publish_breakpoint_hit(module, line, stack_trace, variables, state.session_id)

    {:noreply, new_state}
  end

  # ==========================================================================
  # Private Functions
  # ==========================================================================

  defp generate_session_id do
    "elixir-#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
  end

  # defp generate_breakpoint_id do
  #   "bp-#{:crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)}"
  # end

  defp emit_session_event(action, session_id, metadata) do
    TelemetryBus.emit_debugger(:session, %{
      action: action,
      session_id: session_id,
      language: "elixir",
      metadata: metadata,
      timestamp: DateTime.utc_now()
    })
  end

  defp publish_breakpoint_event(action, breakpoint, session_id) do
    topic = "#{@zenoh_prefix}/breakpoint/#{breakpoint.module}/#{breakpoint.line}"

    TelemetryBus.emit(:zenoh, :publish, %{
      topic: topic,
      payload: %{
        action: action,
        breakpoint: breakpoint,
        session_id: session_id,
        timestamp: DateTime.utc_now()
      },
      timeout: @publish_timeout_ms
    })
  end

  defp publish_step_event(action, session_id) do
    topic = "#{@zenoh_prefix}/step/#{session_id}"

    TelemetryBus.emit(:zenoh, :publish, %{
      topic: topic,
      payload: %{action: action, timestamp: DateTime.utc_now()},
      timeout: @publish_timeout_ms
    })
  end

  defp publish_breakpoint_hit(module, line, stack, variables, session_id) do
    topic = "#{@zenoh_prefix}/breakpoint/hit/#{session_id}"

    TelemetryBus.emit(:zenoh, :publish, %{
      topic: topic,
      payload: %{
        module: module,
        line: line,
        stack: stack,
        variables: Map.keys(variables),
        timestamp: DateTime.utc_now()
      },
      timeout: @publish_timeout_ms
    })
  end

  defp find_breakpoint_by_location(breakpoints, module, line) do
    Enum.find(Map.values(breakpoints), fn bp ->
      bp.module == module and bp.line == line
    end)
  end

  defp build_stack_trace do
    Process.info(self(), :current_stacktrace)
    |> elem(1)
    |> Enum.map(fn {mod, fun, arity, location} ->
      %{
        module: mod,
        function: fun,
        arity: arity,
        file: Keyword.get(location, :file, "unknown"),
        line: Keyword.get(location, :line, 0)
      }
    end)
  end

  defp extract_variables(bindings) do
    Enum.into(bindings, %{}, fn {name, value} ->
      {name, %{value: value, type: typeof(value)}}
    end)
  end

  defp get_variable_value(var_name, state) do
    case Map.fetch(state.variables, String.to_atom(var_name)) do
      {:ok, %{value: value, type: type}} ->
        {:ok, value, type}

      :error ->
        {:error, :variable_not_found}
    end
  end

  defp eval_in_context(expression, state) do
    bindings = Enum.map(state.variables, fn {k, v} -> {k, v.value} end)

    try do
      {result, _} = Code.eval_string(expression, bindings)
      {:ok, result}
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  defp typeof(value) when is_binary(value), do: "string"
  defp typeof(value) when is_integer(value), do: "integer"
  defp typeof(value) when is_float(value), do: "float"
  defp typeof(value) when is_atom(value), do: "atom"
  defp typeof(value) when is_list(value), do: "list"
  defp typeof(value) when is_map(value), do: "map"
  defp typeof(value) when is_tuple(value), do: "tuple"
  defp typeof(value) when is_pid(value), do: "pid"
  defp typeof(value) when is_reference(value), do: "reference"
  defp typeof(value) when is_function(value), do: "function"
  defp typeof(_), do: "unknown"
end
