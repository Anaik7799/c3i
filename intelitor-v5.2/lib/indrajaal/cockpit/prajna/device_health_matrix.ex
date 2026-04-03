defmodule Indrajaal.Cockpit.Prajna.DeviceHealthMatrix do
  @moduledoc """
  Prajna Device Health Matrix — Real-time device health with color coding.

  WHAT: Maintains a health matrix for all connected devices with traffic-light
        color coding (green/yellow/red) based on health scores. Stores device
        data in ETS for fast reads and publishes updates to Zenoh.
  WHY: Operators need at-a-glance device health in the C3I cockpit (SC-DEV-001).
  CONSTRAINTS: SC-DEV-001, SC-HMI-001, SC-MON-003, SC-PRF-050

  ## Color Coding
  - green:  health_score > 0.8  (healthy)
  - yellow: health_score > 0.5  (degraded)
  - red:    health_score <= 0.5 (critical)

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 1.0.0 | 2026-03-23 | Claude Sonnet 4.6 | Initial implementation |
  """

  use GenServer
  require Logger

  @table :prajna_device_health
  @refresh_interval_ms 30_000
  @zenoh_topic "indrajaal/prajna/devices/health"

  # ============================================================
  # CLIENT API
  # ============================================================

  @doc "Starts the DeviceHealthMatrix GenServer."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Returns all devices with their health scores, sorted by health_score ascending
  (most critical first).
  """
  @spec get_matrix() :: [map()]
  def get_matrix do
    :ets.tab2list(@table)
    |> Enum.map(fn {id, data} -> Map.put(data, :device_id, id) end)
    |> Enum.sort_by(& &1.health_score)
  end

  @doc "Returns a single device's health data by device_id."
  @spec get_device(String.t()) :: {:ok, map()} | {:error, :not_found}
  def get_device(device_id) do
    case :ets.lookup(@table, device_id) do
      [{^device_id, data}] -> {:ok, Map.put(data, :device_id, device_id)}
      [] -> {:error, :not_found}
    end
  end

  @doc "Updates a device's health data asynchronously."
  @spec update_device(String.t(), map()) :: :ok
  def update_device(device_id, attrs) do
    GenServer.cast(__MODULE__, {:update, device_id, attrs})
  end

  @doc "Returns the total count of tracked devices."
  @spec device_count() :: non_neg_integer()
  def device_count, do: :ets.info(@table, :size)

  @doc "Returns summary statistics for the health matrix."
  @spec summary() :: map()
  def summary do
    devices = get_matrix()
    total = length(devices)

    %{
      total: total,
      green: Enum.count(devices, &(&1.color == :green)),
      yellow: Enum.count(devices, &(&1.color == :yellow)),
      red: Enum.count(devices, &(&1.color == :red)),
      avg_health: average_health(devices),
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  # ============================================================
  # GENSERVER CALLBACKS
  # ============================================================

  @impl true
  def init(_opts) do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    end

    Logger.info("[DeviceHealthMatrix] Starting with ETS table #{@table}")

    seed_demo_devices()
    schedule_refresh()

    {:ok, %{last_refresh: DateTime.utc_now()}}
  end

  @impl true
  def handle_cast({:update, device_id, attrs}, state) do
    health_score = Map.get(attrs, :health_score, 1.0)

    data = %{
      health_score: health_score,
      color: color_for(health_score),
      device_type: Map.get(attrs, :device_type, "unknown"),
      last_seen: DateTime.utc_now(),
      status: Map.get(attrs, :status, :online),
      metadata: Map.get(attrs, :metadata, %{})
    }

    :ets.insert(@table, {device_id, data})

    :telemetry.execute(
      [:prajna, :device_health, :updated],
      %{health_score: health_score, timestamp: System.monotonic_time(:millisecond)},
      %{device_id: device_id, color: data.color}
    )

    {:noreply, state}
  end

  @impl true
  def handle_info(:refresh, state) do
    device_count = :ets.info(@table, :size)

    :telemetry.execute(
      [:prajna, :device_health, :refresh],
      %{
        device_count: device_count,
        timestamp: System.monotonic_time(:millisecond)
      },
      %{}
    )

    publish_to_zenoh()

    schedule_refresh()
    {:noreply, %{state | last_refresh: DateTime.utc_now()}}
  end

  # ============================================================
  # PRIVATE HELPERS
  # ============================================================

  @spec color_for(float()) :: :green | :yellow | :red
  defp color_for(score) when score > 0.8, do: :green
  defp color_for(score) when score > 0.5, do: :yellow
  defp color_for(_score), do: :red

  @spec schedule_refresh() :: reference()
  defp schedule_refresh, do: Process.send_after(self(), :refresh, @refresh_interval_ms)

  @spec average_health([map()]) :: float()
  defp average_health([]), do: 0.0

  defp average_health(devices) do
    devices
    |> Enum.map(& &1.health_score)
    |> Enum.sum()
    |> Kernel./(length(devices))
    |> Float.round(3)
  end

  @spec publish_to_zenoh() :: :ok
  defp publish_to_zenoh do
    if Code.ensure_loaded?(Indrajaal.Observability.ZenohEvolutionPublisher) do
      payload = %{
        topic: @zenoh_topic,
        summary: summary(),
        timestamp: DateTime.utc_now()
      }

      if function_exported?(
           Indrajaal.Observability.ZenohEvolutionPublisher,
           :publish_training_episode,
           1
         ) do
        Indrajaal.Observability.ZenohEvolutionPublisher.publish_training_episode(payload)
      end
    end

    :ok
  rescue
    _ -> :ok
  end

  @spec seed_demo_devices() :: :ok
  defp seed_demo_devices do
    demo_devices = [
      {"cam-001", %{health_score: 0.95, device_type: "camera", status: :online}},
      {"cam-002", %{health_score: 0.72, device_type: "camera", status: :online}},
      {"reader-001", %{health_score: 0.98, device_type: "card_reader", status: :online}},
      {"panel-001", %{health_score: 0.45, device_type: "alarm_panel", status: :degraded}},
      {"sensor-001", %{health_score: 0.88, device_type: "motion_sensor", status: :online}}
    ]

    Enum.each(demo_devices, fn {id, attrs} -> update_device(id, attrs) end)
  end
end
