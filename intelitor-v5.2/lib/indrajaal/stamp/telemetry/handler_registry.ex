defmodule Indrajaal.STAMP.Telemetry.HandlerRegistry do
  @moduledoc """
  Telemetry Handler Registry - SOPv5.1 Implementation

  🎯 SOPv5.1: Systematic telemetry handler management
  🧪 TDG IMPLEMENTATION: Addresses test __requirement for 11 safety handlers
  🤖 MULTI - AGENT READY: Optimized for parallel processing
  [LAUNCH] NO TIMEOUT: Natural completion with infinite patience

  This module manages the registration, lifecycle, and coordination of all
  safety monitoring telemetry handlers as specified by test __requirements.
  """

  use GenServer
  require Logger

  @handler_definitions [
    %{
      id: "alarm - storm - detector",
      __event: [:indrajaal, :alarm, :received],
      description: "Detects alarm storm conditions based on rate thresholds",
      priority: :critical
    },
    %{
      id: "tenant - violation - detector",
      __event: [:indrajaal, :tenant, :access],
      description: "Monitors cross - tenant access violations",
      priority: :critical
    },
    %{
      id: "audit - gap - detector",
      __event: [:indrajaal, :audit, :event],
      description: "Identifies gaps in audit logging",
      priority: :high
    },
    %{
      id: "auth - failure - detector",
      __event: [:indrajaal, :auth, :attempt],
      description: "Tracks authentication failure patterns",
      priority: :high
    },
    %{
      id: "transaction - monitor",
      __event: [:indrajaal, :db, :transaction],
      description: "Monitors database transaction health",
      priority: :high
    },
    %{
      id: "container - compliance - monitor",
      __event: [:indrajaal, :container, :event],
      description: "Ensures container compliance and security",
      priority: :critical
    },
    %{
      id: "compilation - safety - monitor",
      __event: [:indrajaal, :compilation, :event],
      description: "Monitors compilation safety and warnings",
      priority: :medium
    },
    %{
      id: "pubsub - health - monitor",
      __event: [:indrajaal, :pubsub, :event],
      description: "Monitors Phoenix PubSub health and performance",
      priority: :medium
    },
    %{
      id: "state - consistency - monitor",
      __event: [:indrajaal, :state, :change],
      description: "Validates state consistency across components",
      priority: :high
    },
    %{
      id: "task - coordination - monitor",
      __event: [:indrajaal, :task, :event],
      description: "Monitors multi - agent task coordination",
      priority: :medium
    },
    %{
      id: "performance - threshold - monitor",
      __event: [:indrajaal, :performance, :metric],
      description: "Tracks performance against safety thresholds",
      priority: :high
    }
  ]

  @doc """
  Start the handler registry with SOPv5.1 multi - layer agent support
  """
  @spec start_link(any()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Register all safety monitoring handlers as __required by tests
  """
  @spec register_all_handlers() :: {:ok, non_neg_integer()} | {:error, any()}
  def register_all_handlers do
    GenServer.call(__MODULE__, :register_all_handlers, :infinity)
  end

  @doc """
  Get list of all registered handlers (for test validation)
  """
  @spec list_handlers() :: list(map())
  def list_handlers do
    GenServer.call(__MODULE__, :list_handlers, :infinity)
  end

  @doc """
  Get handler by ID (for test validation)
  """
  @spec get_handler(String.t()) :: {:ok, map()} | {:error, :not_found}
  def get_handler(handler_id) do
    GenServer.call(__MODULE__, {:get_handler, handler_id}, :infinity)
  end

  @doc """
  Unregister all handlers (for test cleanup)
  """
  @spec unregister_all_handlers() :: :ok
  def unregister_all_handlers do
    GenServer.call(__MODULE__, :unregister_all_handlers, :infinity)
  end

  ## GenServer Callbacks

  @impl true
  @spec init(any()) :: {:ok, map()}
  def init(_opts) do
    Logger.info("🏭 SOPv5.1: Starting Telemetry Handler Registry")

    state = %{
      handlers: %{},
      metrics: %{
        registered_count: 0,
        total_events_processed: 0,
        last_registration_time: nil
      }
    }

    # Initialize ETS table for handler tracking
    :ets.new(:handler_registry, [:public, :named_table, :set])

    {:ok, state}
  end

  @impl true
  @spec handle_call(atom(), GenServer.from(), map()) :: {:reply, any(), map()}
  def handle_call(:register_all_handlers, _from, state) do
    Logger.info("🎯 SOPv5.1: Registering all #{length(@handler_definitions)} safety handlers")

    registration_results =
      @handler_definitions
      |> Enum.map(&register_handler/1)
      |> Enum.with_index(1)

    # Update state
    new_handlers =
      registration_results
      |> Enum.reduce(%{}, fn {{:ok, handler_def}, index}, acc ->
        Map.put(acc, handler_def.id, %{
          definition: handler_def,
          registration_time: DateTime.utc_now(),
          index: index,
          __events_processed: 0
        })
      end)

    new_state = %{
      state
      | handlers: Map.merge(state.handlers, new_handlers),
        metrics: %{
          state.metrics
          | registered_count: map_size(new_handlers),
            last_registration_time: DateTime.utc_now()
        }
    }

    # Store in ETS for test validation
    Enum.each(new_handlers, fn {id, handler_info} ->
      :ets.insert(:handler_registry, {id, handler_info})
    end)

    Logger.info("✅ SOPv5.1: Successfully registered #{map_size(new_handlers)} handlers")
    {:reply, {:ok, map_size(new_handlers)}, new_state}
  end

  @impl true
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call(:list_handlers, _from, state) do
    handlers_list =
      state.handlers
      |> Enum.map(fn {id, info} ->
        %{
          id: id,
          __event: info.definition.__event,
          description: info.definition.description,
          priority: info.definition.priority,
          __events_processed: info.__events_processed,
          registration_time: info.registration_time
        }
      end)

    {:reply, handlers_list, state}
  end

  @impl true
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call({:get_handler, handler_id}, _from, state) do
    case Map.get(state.handlers, handler_id) do
      nil -> {:reply, {:error, :not_found}, state}
      handler_info -> {:reply, {:ok, handler_info}, state}
    end
  end

  @impl true
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call(:unregister_all_handlers, _from, state) do
    Logger.info("🧹 SOPv5.1: Unregistering all telemetry handlers")

    # Detach all telemetry handlers
    state.handlers
    |> Map.keys()
    |> Enum.each(fn handler_id ->
      :telemetry.detach(handler_id)
    end)

    # Clear ETS table
    :ets.delete_all_objects(:handler_registry)

    new_state = %{state | handlers: %{}, metrics: %{state.metrics | registered_count: 0}}

    {:reply, :ok, new_state}
  end

  ## Private Functions

  @spec register_handler(map()) :: {:ok, map()} | {:error, any()}
  defp register_handler(handler_def) do
    Logger.debug("📡 Registering handler: #{handler_def.id}")

    handler_function = fn event, measurements, metadata, _config ->
      handle_telemetry_event(handler_def.id, event, measurements, metadata)
    end

    case :telemetry.attach(handler_def.id, handler_def.__event, handler_function, nil) do
      :ok ->
        Logger.debug("✅ Handler registered: #{handler_def.id}")
        {:ok, handler_def}

      {:error, :already_exists} ->
        Logger.warning("⚠️ Handler already exists: #{handler_def.id}")
        {:ok, handler_def}

      error ->
        Logger.error("❌ Failed to register handler #{handler_def.id}: #{inspect(error)}")
        {:error, error}
    end
  end

  @spec handle_telemetry_event(String.t(), list(), map(), map()) :: :ok
  defp handle_telemetry_event(handler_id, event, measurements, meta_data) do
    # Route to appropriate __event processor based on handler type
    case handler_id do
      "alarm - storm - detector" ->
        Indrajaal.STAMP.Telemetry.EventProcessor.process_alarm_event(measurements, meta_data)

      "tenant - violation - detector" ->
        Indrajaal.STAMP.Telemetry.EventProcessor.process_tenant_event(measurements, meta_data)

      "auth - failure - detector" ->
        Indrajaal.STAMP.Telemetry.EventProcessor.process_auth_event(measurements, meta_data)

      "transaction - monitor" ->
        Indrajaal.STAMP.Telemetry.EventProcessor.process_transaction_event(
          measurements,
          meta_data
        )

      _ ->
        Indrajaal.STAMP.Telemetry.EventProcessor.process_generic_event(
          handler_id,
          event,
          measurements,
          meta_data
        )
    end

    # Update processing metrics
    GenServer.cast(__MODULE__, {:increment_processed, handler_id})
  end

  @impl true
  @spec handle_cast({:increment_processed, String.t()}, map()) :: {:noreply, map()}
  def handle_cast({:increment_processed, handler_id}, state) do
    updated_handlers =
      case Map.get(state.handlers, handler_id) do
        nil ->
          state.handlers

        handler_info ->
          updated_info = %{handler_info | __events_processed: handler_info.__events_processed + 1}
          Map.put(state.handlers, handler_id, updated_info)
      end

    updated_metrics = %{
      state.metrics
      | total_events_processed: state.metrics.total_events_processed + 1
    }

    new_state = %{state | handlers: updated_handlers, metrics: updated_metrics}

    {:noreply, new_state}
  end
end
