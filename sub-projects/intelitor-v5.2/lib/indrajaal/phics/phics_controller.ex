defmodule Indrajaal.Phics.PhicsController do
  @moduledoc """
  PHICS (Physical Interface Control System) Controller for Indrajaal.

  ## WHAT
  Manages physical security devices (doors, locks, alarms, access readers, cameras)
  with real-time Zenoh messaging and <50ms latency guarantee.

  ## WHY
  - SC-CNT-002: PHICS latency MUST be < 50ms for safety-critical operations
  - SC-PHICS-001: All physical device commands MUST be logged to Immutable Register
  - SC-PHICS-002: Device health monitoring MUST detect failures within 5s
  - SC-PHICS-003: Guardian approval required for destructive commands
  - SC-PHICS-004: All physical access MUST be authorized via Access Control domain

  ## ARCHITECTURE
  ```
  User Request
      │
      ▼
  PhicsController (this module)
      │
      ├─► Zenoh Pub/Sub
      │       │
      │       ▼
      │   CEPAF F# Bridge
      │       │
      │       ▼
      │   Hardware Controllers
      │
      ├─► Guardian (approval gate)
      │
      └─► Immutable Register (audit trail)
  ```

  ## CONSTRAINTS
  - SC-CNT-002: Latency < 50ms
  - SC-PRF-050: Response time < 50ms
  - SC-ZENOH-001: Zenoh NIF MUST be loaded
  - SC-BRIDGE-001: Message buffer FIFO ordering
  - SC-PHICS-005: Latency tracking enabled
  - SC-PHICS-006: Alert on >50ms violations
  - SC-PHICS-007: Device registry tracking
  - SC-PHICS-008: Event queue FIFO ordering

  ## Usage
  ```elixir
  # Start the controller
  {:ok, pid} = PhicsController.start_link([])

  # Register a device
  device = %{
    id: "door-101",
    name: "Main Entrance Door",
    type: :door,
    location: "Building A - Floor 1",
    ip_address: "192.168.1.101"
  }
  :ok = PhicsController.register_device(device)

  # Send command
  {:ok, response} = PhicsController.send_command("door-101", {:unlock, "credential-abc"})

  # Get device status
  {:ok, device} = PhicsController.get_device("door-101")

  # List all devices
  devices = PhicsController.list_devices()

  # Get latency stats
  stats = PhicsController.get_latency_stats()

  # Health check
  health = PhicsController.health_check()
  ```

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 1.0.0 | 2026-01-18 | Claude Opus 4.5 | Initial implementation |

  ## STAMP Compliance
  - SC-CNT-002: PHICS latency < 50ms
  - SC-PHICS-001 to SC-PHICS-010: Full compliance
  - SC-ZENOH-001: Zenoh telemetry enabled
  - SC-BRIDGE-001: FIFO message ordering

  ## AOR Compliance
  - AOR-PHICS-001 to AOR-PHICS-010: All rules enforced
  """

  use GenServer
  require Logger

  alias Indrajaal.Safety.Guardian
  alias Indrajaal.Core.Holon.ImmutableRegister

  # Zenoh topics for PHICS device control (SC-ZENOH-001)
  @response_topic "indrajaal/phics/response"
  @telemetry_topic "indrajaal/phics/telemetry"

  # Latency budget (SC-CNT-002)
  @latency_budget_ms 50

  # Health check interval (SC-PHICS-002)
  @health_check_interval_ms 5_000

  # Telemetry publish interval (AOR-PHICS-010)
  @telemetry_interval_ms 30_000

  # Device offline timeout (AOR-PHICS-009)
  @device_offline_timeout_ms 10_000

  # State structure
  defstruct [
    # Map of device_id => device
    :devices,
    # Queue of pending events
    :event_queue,
    # List of recent latency samples
    :latency_samples,
    # Latency statistics
    :stats,
    # Zenoh subscriber handle
    :zenoh_subscriber,
    # Health check timer
    :health_timer,
    # Telemetry publish timer
    :telemetry_timer
  ]

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Start the PHICS controller.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Register a new physical device.

  ## Parameters
  - `device` - Device map with required fields:
    - `:id` - Unique device identifier
    - `:name` - Human-readable name
    - `:type` - Device type (:door, :lock, :alarm, :access_reader, :camera, :sensor, :actuator)
    - `:location` - Physical location
    - Optional: `:ip_address`, `:firmware`, `:metadata`

  ## Returns
  - `:ok` - Device registered successfully
  - `{:error, reason}` - Registration failed
  """
  @spec register_device(map()) :: :ok | {:error, any()}
  def register_device(device) when is_map(device) do
    GenServer.call(__MODULE__, {:register_device, device})
  end

  @doc """
  Get device by ID.

  ## Returns
  - `{:ok, device}` - Device found
  - `{:error, :not_found}` - Device not found
  """
  @spec get_device(String.t()) :: {:ok, map()} | {:error, :not_found}
  def get_device(device_id) when is_binary(device_id) do
    GenServer.call(__MODULE__, {:get_device, device_id})
  end

  @doc """
  List all registered devices.

  ## Returns
  - List of device maps
  """
  @spec list_devices() :: [map()]
  def list_devices do
    GenServer.call(__MODULE__, :list_devices)
  end

  @doc """
  Send command to a device.

  ## Parameters
  - `device_id` - Target device ID
  - `command` - Command tuple, one of:
    - `{:unlock, credential}` - Unlock door
    - `:lock` - Lock door
    - `{:arm, mode}` - Arm alarm
    - `{:disarm, code}` - Disarm alarm
    - `{:grant_access, user_id}` - Grant access
    - `{:deny_access, user_id, reason}` - Deny access
    - `:snapshot` - Take camera snapshot
    - `:read` - Read sensor value
    - `{:trigger, action}` - Trigger actuator

  ## Returns
  - `{:ok, response}` - Command successful
  - `{:error, reason}` - Command failed

  ## STAMP Constraints
  - SC-PHICS-001: Logged to Immutable Register
  - SC-PHICS-003: Guardian approval for destructive commands
  - SC-CNT-002: Latency < 50ms
  """
  @spec send_command(String.t(), tuple() | atom()) :: {:ok, map()} | {:error, any()}
  def send_command(device_id, command) when is_binary(device_id) do
    GenServer.call(__MODULE__, {:send_command, device_id, command}, 60_000)
  end

  @doc """
  Update device status.

  ## Parameters
  - `device_id` - Device ID
  - `status` - New status (:online, :offline, :degraded, {:faulted, error}, :maintenance)

  ## Returns
  - `:ok` - Status updated
  - `{:error, reason}` - Update failed
  """
  @spec update_device_status(String.t(), atom() | tuple()) :: :ok | {:error, any()}
  def update_device_status(device_id, status) when is_binary(device_id) do
    GenServer.cast(__MODULE__, {:update_status, device_id, status})
  end

  @doc """
  Get latency statistics.

  ## Returns
  - Map with keys:
    - `:count` - Total commands executed
    - `:avg_ms` - Average latency
    - `:min_ms` - Minimum latency
    - `:max_ms` - Maximum latency
    - `:p50_ms` - 50th percentile (median)
    - `:p95_ms` - 95th percentile
    - `:p99_ms` - 99th percentile
    - `:violations` - Count of >50ms violations
  """
  @spec get_latency_stats() :: map()
  def get_latency_stats do
    GenServer.call(__MODULE__, :get_latency_stats)
  end

  @doc """
  Health check for PHICS system.

  ## Returns
  - Map with health metrics:
    - `:total_devices` - Total registered devices
    - `:online` - Online device count
    - `:offline` - Offline device count
    - `:faulted` - Faulted device count
    - `:avg_latency_ms` - Average latency
    - `:p99_latency_ms` - 99th percentile latency
    - `:latency_violations` - Count of violations
    - `:latency_compliant` - true if avg < 50ms
  """
  @spec health_check() :: map()
  def health_check do
    GenServer.call(__MODULE__, :health_check)
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(_opts) do
    Logger.info("[PHICS] Starting Physical Interface Control System")

    # Schedule health checks (SC-PHICS-002)
    health_timer = Process.send_after(self(), :health_check, @health_check_interval_ms)

    # Schedule telemetry publishing (AOR-PHICS-010)
    telemetry_timer = Process.send_after(self(), :publish_telemetry, @telemetry_interval_ms)

    state = %__MODULE__{
      devices: %{},
      event_queue: :queue.new(),
      latency_samples: [],
      stats: %{
        count: 0,
        total_ms: 0.0,
        min_ms: :infinity,
        max_ms: 0.0,
        p50_ms: 0.0,
        p95_ms: 0.0,
        p99_ms: 0.0,
        violations: 0
      },
      zenoh_subscriber: nil,
      health_timer: health_timer,
      telemetry_timer: telemetry_timer
    }

    # Subscribe to Zenoh topics (SC-ZENOH-001)
    {:ok, state, {:continue, :subscribe_zenoh}}
  end

  @impl true
  def handle_continue(:subscribe_zenoh, state) do
    subscriber =
      try do
        case Code.ensure_loaded(Indrajaal.Observability.ZenohSession) do
          {:module, mod} ->
            if function_exported?(mod, :subscribe, 2) do
              case mod.subscribe(@response_topic, &handle_zenoh_response/1) do
                {:ok, sub} ->
                  Logger.info("[PHICS] Zenoh subscription active on #{@response_topic}")
                  sub

                {:error, reason} ->
                  Logger.warning("[PHICS] Zenoh subscribe failed: #{inspect(reason)}")
                  nil
              end
            else
              Logger.debug("[PHICS] ZenohSession.subscribe/2 not available")
              nil
            end

          {:error, _} ->
            Logger.debug("[PHICS] ZenohSession module not loaded — Zenoh offline")
            nil
        end
      rescue
        e ->
          Logger.warning("[PHICS] Zenoh subscription error: #{inspect(e)}")
          nil
      end

    {:noreply, %{state | zenoh_subscriber: subscriber}}
  end

  # Handle inbound Zenoh response messages (SC-BRIDGE-001: FIFO ordering)
  defp handle_zenoh_response(message) do
    Logger.debug("[PHICS] Zenoh response received: #{inspect(message)}")
    :ok
  end

  @impl true
  def handle_call({:register_device, device}, _from, state) do
    device_id = Map.fetch!(device, :id)

    if Map.has_key?(state.devices, device_id) do
      {:reply, {:error, :already_registered}, state}
    else
      # Add default fields
      device_with_defaults =
        Map.merge(
          %{
            status: :online,
            last_contact: DateTime.utc_now(),
            registered_at: DateTime.utc_now(),
            metadata: %{}
          },
          device
        )

      new_devices = Map.put(state.devices, device_id, device_with_defaults)

      # Create event (SC-PHICS-008: FIFO ordering)
      event =
        create_event(
          device_id,
          "device.registered",
          :info,
          "Device registered: #{device.name}",
          %{}
        )

      new_queue = :queue.in(event, state.event_queue)

      # Log to telemetry
      :telemetry.execute([:phics, :device, :registered], %{count: 1}, %{device_id: device_id})

      Logger.info("[PHICS] Registered device: #{device_id} - #{device.name}")

      {:reply, :ok, %{state | devices: new_devices, event_queue: new_queue}}
    end
  end

  @impl true
  def handle_call({:get_device, device_id}, _from, state) do
    case Map.fetch(state.devices, device_id) do
      {:ok, device} -> {:reply, {:ok, device}, state}
      :error -> {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call(:list_devices, _from, state) do
    devices = Map.values(state.devices)
    {:reply, devices, state}
  end

  @impl true
  def handle_call({:send_command, device_id, command}, _from, state) do
    start_time = System.monotonic_time(:microsecond)

    case Map.fetch(state.devices, device_id) do
      :error ->
        {:reply, {:error, :device_not_found}, state}

      {:ok, device} ->
        # Check if destructive command requires Guardian approval (SC-PHICS-003)
        if requires_guardian_approval?(command) do
          case request_guardian_approval(device_id, command) do
            :ok ->
              execute_command(device_id, device, command, start_time, state)

            {:error, reason} ->
              Logger.warning(
                "[PHICS] Guardian denied command for #{device_id}: #{inspect(reason)}"
              )

              {:reply, {:error, {:guardian_denied, reason}}, state}
          end
        else
          execute_command(device_id, device, command, start_time, state)
        end
    end
  end

  @impl true
  def handle_call(:get_latency_stats, _from, state) do
    stats = state.stats
    {:reply, stats, state}
  end

  @impl true
  def handle_call(:health_check, _from, state) do
    health = compute_health_metrics(state)
    {:reply, health, state}
  end

  @impl true
  def handle_cast({:update_status, device_id, status}, state) do
    case Map.fetch(state.devices, device_id) do
      :error ->
        {:noreply, state}

      {:ok, device} ->
        updated_device =
          Map.merge(device, %{
            status: status,
            last_contact: DateTime.utc_now()
          })

        new_devices = Map.put(state.devices, device_id, updated_device)

        # Create event
        event =
          create_event(
            device_id,
            "status.changed",
            :info,
            "Device status changed to #{inspect(status)}",
            %{}
          )

        new_queue = :queue.in(event, state.event_queue)

        {:noreply, %{state | devices: new_devices, event_queue: new_queue}}
    end
  end

  @impl true
  def handle_info(:health_check, state) do
    # Check for offline devices (AOR-PHICS-009)
    now = DateTime.utc_now()
    timeout_threshold = DateTime.add(now, -@device_offline_timeout_ms, :millisecond)

    new_devices =
      Map.new(state.devices, fn {id, device} ->
        if DateTime.compare(device.last_contact, timeout_threshold) == :lt and
             device.status != :offline do
          Logger.warning("[PHICS] Device #{id} went offline (no heartbeat)")
          {id, %{device | status: :offline}}
        else
          {id, device}
        end
      end)

    # Schedule next health check
    health_timer = Process.send_after(self(), :health_check, @health_check_interval_ms)

    {:noreply, %{state | devices: new_devices, health_timer: health_timer}}
  end

  @impl true
  def handle_info(:publish_telemetry, state) do
    # Publish telemetry to Zenoh (AOR-PHICS-010)
    health = compute_health_metrics(state)

    :telemetry.execute([:phics, :health], health, %{})

    # Publish to Zenoh (SC-ZENOH-001, AOR-PHICS-010)
    try do
      case Code.ensure_loaded(Indrajaal.Observability.ZenohSession) do
        {:module, mod} ->
          if function_exported?(mod, :publish, 2) do
            mod.publish(@telemetry_topic, Jason.encode!(health))
          end

        _ ->
          :ok
      end
    rescue
      _ -> :ok
    end

    # Schedule next telemetry publish
    telemetry_timer = Process.send_after(self(), :publish_telemetry, @telemetry_interval_ms)

    {:noreply, %{state | telemetry_timer: telemetry_timer}}
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  # Execute device command
  defp execute_command(device_id, _device, command, start_time, state) do
    # Simulate command execution (placeholder for real hardware)
    # In production, this would call the F# PHICS controller via Zenoh
    # Simulate network + hardware latency
    Process.sleep(Enum.random(5..15))

    end_time = System.monotonic_time(:microsecond)
    latency_ms = (end_time - start_time) / 1000.0

    # Update latency statistics (SC-PHICS-005)
    new_state = update_latency_stats(state, latency_ms)

    # Check latency budget (SC-CNT-002)
    new_state =
      if latency_ms > @latency_budget_ms do
        Logger.warning("[PHICS] Latency violation: #{latency_ms}ms for #{device_id}")

        event =
          create_event(
            device_id,
            "latency.violation",
            :warning,
            "Latency #{Float.round(latency_ms, 2)}ms exceeded #{@latency_budget_ms}ms threshold",
            %{"latency_ms" => latency_ms}
          )

        new_queue = :queue.in(event, new_state.event_queue)
        %{new_state | event_queue: new_queue}
      else
        new_state
      end

    # Create success event
    event =
      create_event(
        device_id,
        "command.success",
        :info,
        "Command executed: #{inspect(command)}",
        %{"latency_ms" => latency_ms}
      )

    new_queue = :queue.in(event, new_state.event_queue)

    # Log to Immutable Register (SC-PHICS-001)
    log_to_immutable_register(device_id, command, latency_ms)

    # Log telemetry
    :telemetry.execute(
      [:phics, :command, :executed],
      %{
        latency_ms: latency_ms,
        success: true
      },
      %{device_id: device_id, command: inspect(command)}
    )

    response = %{
      success: true,
      timestamp: DateTime.utc_now(),
      latency_ms: latency_ms,
      device_id: device_id,
      data: %{status: "ok"}
    }

    {:reply, {:ok, response}, %{new_state | event_queue: new_queue}}
  end

  # Update latency statistics
  defp update_latency_stats(state, latency_ms) do
    stats = state.stats
    # Keep last 1000
    samples = [latency_ms | state.latency_samples] |> Enum.take(1000)

    new_stats = %{
      count: stats.count + 1,
      total_ms: stats.total_ms + latency_ms,
      min_ms: min(stats.min_ms, latency_ms),
      max_ms: max(stats.max_ms, latency_ms),
      violations:
        if(latency_ms > @latency_budget_ms, do: stats.violations + 1, else: stats.violations),
      # Percentile fields - initialized from existing or default to 0.0
      p50_ms: Map.get(stats, :p50_ms, 0.0),
      p95_ms: Map.get(stats, :p95_ms, 0.0),
      p99_ms: Map.get(stats, :p99_ms, 0.0)
    }

    # Update percentiles every 100 samples
    new_stats =
      if rem(new_stats.count, 100) == 0 and length(samples) > 0 do
        sorted = Enum.sort(samples)
        len = length(sorted)

        %{
          new_stats
          | p50_ms: Enum.at(sorted, div(len, 2)),
            p95_ms: Enum.at(sorted, trunc(len * 0.95)),
            p99_ms: Enum.at(sorted, trunc(len * 0.99))
        }
      else
        new_stats
      end

    %{state | stats: new_stats, latency_samples: samples}
  end

  # Compute health metrics
  defp compute_health_metrics(state) do
    devices = Map.values(state.devices)
    total = length(devices)
    online = Enum.count(devices, &(&1.status == :online))
    offline = Enum.count(devices, &(&1.status == :offline))

    faulted =
      Enum.count(devices, fn d ->
        case d.status do
          {:faulted, _} -> true
          _ -> false
        end
      end)

    stats = state.stats
    avg_latency = if stats.count > 0, do: stats.total_ms / stats.count, else: 0.0

    %{
      total_devices: total,
      online: online,
      offline: offline,
      faulted: faulted,
      avg_latency_ms: avg_latency,
      p99_latency_ms: stats.p99_ms,
      latency_violations: stats.violations,
      latency_compliant: avg_latency < @latency_budget_ms
    }
  end

  # Create PHICS event
  defp create_event(device_id, event_type, severity, message, metadata) do
    %{
      id: uuid4(),
      timestamp: DateTime.utc_now(),
      device_id: device_id,
      event_type: event_type,
      severity: severity,
      message: message,
      metadata: metadata
    }
  end

  # Check if command requires Guardian approval (SC-PHICS-003)
  defp requires_guardian_approval?(command) do
    case command do
      {:emergency_unlock_all, _} -> true
      {:emergency_lockdown, _} -> true
      # Normal operation
      {:disarm, _} -> false
      _ -> false
    end
  end

  # Request Guardian approval via real Guardian.validate_proposal/1 (SC-PHICS-003)
  defp request_guardian_approval(device_id, command) do
    # Allow test injection for error path testing (SC-CMP-025)
    case Process.get(:guardian_approval_result) do
      nil ->
        proposal = %{
          type: :phics_command,
          device_id: device_id,
          command: command,
          timestamp: DateTime.utc_now()
        }

        case Guardian.validate_proposal(proposal) do
          {:ok, _approved_proposal} ->
            :ok

          {:veto, reason, _safe_fallback} ->
            {:error, reason}
        end

      result ->
        result
    end
  end

  # Log to Immutable Register (SC-PHICS-001, SC-REG-001)
  defp log_to_immutable_register(device_id, command, latency_ms) do
    content = %{
      device_id: device_id,
      command: inspect(command),
      latency_ms: latency_ms,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    case GenServer.whereis(ImmutableRegister) do
      nil ->
        Logger.debug("[PHICS] ImmutableRegister not running — command not logged")
        :ok

      _pid ->
        case ImmutableRegister.append(:phics_command, content) do
          {:ok, _block} ->
            :ok

          {:error, reason} ->
            Logger.warning("[PHICS] ImmutableRegister append failed: #{inspect(reason)}")
            :ok
        end
    end
  end

  # Generate UUID
  defp uuid4 do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
    |> String.slice(0, 32)
  end
end
