defmodule Indrajaal.Cybernetic.ZenohPulse do
  @moduledoc """
  Metabolic Heartbeat for the Indrajaal Biomorphic Mesh.
  Classification: L5-METABOLIC
  Protocol: Zenoh
  Topic: indrajaal/control/heartbeat
  Interval: 100ms
  """
  use GenServer
  require Logger
  alias Indrajaal.Native.Zenoh

  @topic "indrajaal/control/heartbeat"

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    # Only start if Zenoh NIF is loaded (Graceful degradation)
    if Code.ensure_loaded?(Indrajaal.Native.Zenoh) and
         function_exported?(Indrajaal.Native.Zenoh, :open_session, 1) do
      Logger.info("💓 Zenoh Pulse: INITIALIZING on #{@topic}")

      try do
        # Use default config or customize as needed
        config = %{mode: "client", connect: ["tcp/localhost:7447"]}
        {:ok, session} = Zenoh.open_session(config)
        schedule_pulse()

        # Initialize with empty last_state for delta tracking. Publisher is not needed for Native wrapper.
        {:ok, %{session: session, sequence: 0, last_state: nil}}
      rescue
        e ->
          Logger.warning(
            "⚠️  Zenoh Pulse: Initialization failed (NIF error). Pulse DISABLED. Error: #{inspect(e)}"
          )

          {:ok, %{session: nil, sequence: 0, last_state: nil}}
      end
    else
      Logger.warning("⚠️  Zenoh Pulse: Zenoh NIF not loaded. Pulse DISABLED.")
      {:ok, %{session: nil, sequence: 0, last_state: nil}}
    end
  end

  # L5 Smart Fix: Adaptive Clock
  @min_interval 50
  @max_interval 1000
  @default_interval 100

  defp schedule_pulse(interval \\ @default_interval) do
    Process.send_after(self(), :pulse, interval)
  end

  @impl true
  def handle_info(:pulse, state) do
    if state.session do
      current_state = %{
        memory_mb: Float.round(:erlang.memory(:total) / 1024 / 1024, 2),
        process_count: :erlang.system_info(:process_count),
        cluster_size: length(Node.list()) + 1,
        status: :homeostasis
      }

      # L2 Smart Fix: Trend Analysis
      mem_delta =
        if state.last_state,
          do: abs(current_state.memory_mb - state.last_state.memory_mb),
          else: 0.0

      # Sensitive trigger (5MB delta)
      should_publish_full =
        is_nil(state.last_state) or
          rem(state.sequence, 100) == 0 or
          mem_delta > 5.0 or
          current_state.cluster_size != state.last_state.cluster_size or
          current_state.status != state.last_state.status

      payload =
        if should_publish_full do
          Jason.encode!(
            Map.merge(current_state, %{
              type: "full",
              node: Node.self(),
              version: "21.2.0-SIL6",
              ts: System.system_time(:millisecond),
              seq: state.sequence,
              entropy: if(mem_delta > 5.0, do: "high", else: "low")
            })
          )
        else
          Jason.encode!(%{
            type: "heartbeat",
            node: Node.self(),
            seq: state.sequence
          })
        end

      # Use Native.Zenoh.publish directly
      Zenoh.publish(state.session, @topic, payload)

      # L5 Adaptive Clock Logic
      next_interval =
        if should_publish_full do
          Logger.info(
            "💓 Zenoh Pulse: Full State ##{state.sequence} (Entropy High). Accelerating clock."
          )

          # Speed up to capture event resolution
          @min_interval
        else
          # Slow down if stable, but cap at max
          min(@max_interval, @default_interval + rem(state.sequence, 10) * 10)
        end

      schedule_pulse(next_interval)
      {:noreply, %{state | sequence: state.sequence + 1, last_state: current_state}}
    else
      # Slowest possible if disabled
      schedule_pulse(@max_interval)
      {:noreply, %{state | sequence: state.sequence + 1}}
    end
  end
end
