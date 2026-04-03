defmodule Indrajaal.Distributed.Agents.BaseAgent do
  @moduledoc """
  Base Agent Behaviour for Distributed Mesh Agents.

  WHAT: Provides common functionality for all mesh agents.
  WHY: SC-AGENT-005 requires consistent agent interface and lifecycle.
  CONSTRAINTS: All agents MUST implement callbacks and register FQUN.

  ## Required Callbacks

  - `handle_command/3` - Process control commands
  - `agent_init/1` - Agent-specific initialization
  - `agent_state/1` - Get agent-specific state
  - `agent_metrics/1` - Get agent metrics

  ## Provided Functionality

  - FQUN registration and lifecycle
  - Heartbeat publishing
  - State publishing to Zenoh
  - Command handling framework
  - Telemetry integration
  """

  @callback handle_command(command :: atom(), params :: map(), state :: map()) ::
              {:ok, result :: term(), new_state :: map()}
              | {:error, reason :: term(), state :: map()}

  @callback agent_init(opts :: keyword()) :: {:ok, state :: map()} | {:error, term()}

  @callback agent_state(state :: map()) :: map()

  @callback agent_metrics(state :: map()) :: map()

  @callback handle_agent_info(msg :: term(), state :: map()) ::
              {:ok, new_state :: map()}
              | {:noreply, new_state :: map()}
              | :ignore

  @optional_callbacks handle_agent_info: 2

  defmacro __using__(opts) do
    quote location: :keep do
      use GenServer
      require Logger

      # Suppress warnings for macro-generated functions
      @compile [:nowarn_unused_function]

      alias Indrajaal.Distributed.FQUN

      @behaviour Indrajaal.Distributed.Agents.BaseAgent

      @heartbeat_interval_ms 5_000
      @state_publish_interval_ms 10_000
      @agent_opts unquote(opts)

      unquote(client_api())
      unquote(genserver_callbacks())
      unquote(private_functions())

      # Default implementation for custom message handling
      def handle_agent_info(_msg, _state), do: :ignore

      defoverridable handle_agent_info: 2
    end
  end

  # Split: Client API section
  defp client_api do
    quote do
      # ============================================================
      # CLIENT API
      # ============================================================

      def start_link(opts) do
        merged_opts = Keyword.merge(@agent_opts, opts)
        GenServer.start_link(__MODULE__, merged_opts, name: __MODULE__)
      end

      def get_state do
        GenServer.call(__MODULE__, :get_state)
      end

      def get_metrics do
        GenServer.call(__MODULE__, :get_metrics)
      end

      def get_fqun do
        GenServer.call(__MODULE__, :get_fqun)
      end

      def ping do
        GenServer.call(__MODULE__, :ping, 100)
      end
    end
  end

  # Split: GenServer callbacks section (Part 1 - Init)
  defp genserver_callbacks do
    quote do
      unquote(init_callback())
      unquote(handle_call_callbacks())
      unquote(handle_info_callbacks())
      unquote(terminate_callback())
    end
  end

  # Split: Init callback
  defp init_callback do
    quote do
      # ============================================================
      # GENSERVER CALLBACKS
      # ============================================================

      @impl GenServer
      def init(opts) do
        # Extract FQUN components
        type = Keyword.fetch!(opts, :type)
        namespace = Keyword.fetch!(opts, :namespace)
        name = Keyword.fetch!(opts, :name)

        # Generate FQUN
        {:ok, fqun} = FQUN.generate(:agent, type, namespace, name)

        # Initialize base state
        base_state = %{
          fqun: fqun,
          type: type,
          namespace: namespace,
          name: name,
          started_at: DateTime.utc_now(),
          heartbeat_count: 0,
          command_count: 0,
          last_heartbeat: nil,
          status: :initializing
        }

        # Call agent-specific init with type coercion to satisfy type checker
        # The identity function breaks type inference chain
        raw_result = agent_init(opts)
        init_result = Function.identity(raw_result)

        case init_result do
          {:ok, agent_state} ->
            state = Map.merge(base_state, %{agent_state: agent_state, status: :running})

            # Schedule periodic tasks
            schedule_heartbeat()
            schedule_state_publish()

            Logger.info("[#{__MODULE__}] Agent started - AOR-AGENT-001",
              fqun: fqun,
              type: type,
              namespace: namespace,
              name: name
            )

            {:ok, state}

          {:error, reason} ->
            Logger.error("[#{__MODULE__}] Agent init failed", error: reason)
            {:stop, reason}
        end
      end
    end
  end

  # Split: Handle call callbacks
  defp handle_call_callbacks do
    quote do
      @impl GenServer
      def handle_call(:get_state, _from, state) do
        agent_specific = agent_state(state.agent_state)

        full_state = %{
          fqun: state.fqun,
          type: state.type,
          namespace: state.namespace,
          name: state.name,
          status: state.status,
          started_at: state.started_at,
          heartbeat_count: state.heartbeat_count,
          command_count: state.command_count,
          agent: agent_specific
        }

        {:reply, full_state, state}
      end

      @impl GenServer
      def handle_call(:get_metrics, _from, state) do
        agent_metrics = agent_metrics(state.agent_state)

        metrics = %{
          fqun: state.fqun,
          uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at),
          heartbeat_count: state.heartbeat_count,
          command_count: state.command_count,
          status: state.status,
          agent: agent_metrics
        }

        {:reply, metrics, state}
      end

      @impl GenServer
      def handle_call(:get_fqun, _from, state) do
        {:reply, state.fqun, state}
      end

      @impl GenServer
      def handle_call(:ping, _from, state) do
        {:reply, {:pong, DateTime.utc_now()}, state}
      end

      @impl GenServer
      def handle_call({:command, command, params}, _from, state) do
        Logger.debug("[#{__MODULE__}] Command received",
          command: command,
          params: params
        )

        handle_command_response(handle_command(command, params, state.agent_state), state)
      end

      defp handle_command_response({:ok, result, new_agent_state}, state) do
        new_state = %{
          state
          | agent_state: new_agent_state,
            command_count: state.command_count + 1
        }

        {:reply, {:ok, result}, new_state}
      end

      defp handle_command_response({:error, reason, agent_state}, state) do
        new_state = %{
          state
          | agent_state: agent_state,
            command_count: state.command_count + 1
        }

        {:reply, {:error, reason}, new_state}
      end
    end
  end

  # Split: Handle info callbacks
  defp handle_info_callbacks do
    quote do
      @impl GenServer
      def handle_info(:heartbeat, state) do
        heartbeat_payload = build_heartbeat_payload(state)

        Indrajaal.Observability.ZenohCoordinator.publish_coord(
          "agent/#{state.namespace}/#{state.name}/heartbeat",
          heartbeat_payload
        )

        schedule_heartbeat()

        new_state = %{
          state
          | heartbeat_count: state.heartbeat_count + 1,
            last_heartbeat: DateTime.utc_now()
        }

        {:noreply, new_state}
      end

      defp build_heartbeat_payload(state) do
        %{
          fqun: state.fqun,
          status: state.status,
          timestamp: DateTime.utc_now(),
          uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at)
        }
      end

      @impl GenServer
      def handle_info(:publish_state, state) do
        agent_specific = agent_state(state.agent_state)
        state_payload = build_agent_state_payload(state, agent_specific)

        Indrajaal.Observability.ZenohCoordinator.publish_coord(
          "agent/#{state.namespace}/#{state.name}/state",
          state_payload
        )

        schedule_state_publish()
        {:noreply, state}
      end

      defp build_agent_state_payload(state, agent_specific) do
        %{
          fqun: state.fqun,
          type: state.type,
          namespace: state.namespace,
          name: state.name,
          status: state.status,
          metrics: agent_metrics(state.agent_state),
          agent: agent_specific,
          timestamp: DateTime.utc_now()
        }
      end

      @impl GenServer
      def handle_info(msg, state) do
        # Allow agents to handle custom messages
        # Use Function.identity to break type inference chain (prevents "clause never used" warnings)
        raw_info = handle_agent_info(msg, state.agent_state)
        result = Function.identity(raw_info)
        do_process_agent_info_result(result, state)
      end

      # Use single clause with case to avoid "clause never used" warnings from type checker
      defp do_process_agent_info_result(result, state) do
        case result do
          {:ok, new_agent_state} ->
            {:noreply, %{state | agent_state: new_agent_state}}

          {:noreply, new_agent_state} ->
            {:noreply, %{state | agent_state: new_agent_state}}

          :ignore ->
            {:noreply, state}

          _other ->
            {:noreply, state}
        end
      end
    end
  end

  # Split: Terminate callback
  defp terminate_callback do
    quote do
      @impl GenServer
      def terminate(reason, state) do
        Logger.info("[#{__MODULE__}] Agent terminating - AOR-AGENT-004",
          fqun: state.fqun,
          reason: reason
        )

        # Unregister FQUN
        FQUN.unregister(state.fqun)
        :ok
      end
    end
  end

  # Split: Private functions section
  defp private_functions do
    quote do
      # ============================================================
      # PRIVATE FUNCTIONS
      # ============================================================

      defp schedule_heartbeat do
        Process.send_after(self(), :heartbeat, @heartbeat_interval_ms)
      end

      defp schedule_state_publish do
        Process.send_after(self(), :publish_state, @state_publish_interval_ms)
      end
    end
  end
end
