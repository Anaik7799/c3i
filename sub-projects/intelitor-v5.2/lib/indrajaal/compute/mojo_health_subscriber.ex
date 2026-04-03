defmodule Indrajaal.Compute.MojoHealthSubscriber do
  @moduledoc """
  Subscribes to `indrajaal/inference/health` via Zenoh and broadcasts
  Mojo container health status to the Phoenix PubSub system.

  This enables the Prajna Cockpit and other LiveView pages to display
  real-time Mojo MAX compute health without direct Zenoh subscriptions.

  ## STAMP Constraints
  - SC-MOJO-006: Health beacon subscription
  - SC-NEURAL-BRIDGE-005: Audit trail for health state changes
  """
  use GenServer

  require Logger

  @health_key "indrajaal/inference/health"
  @pubsub_topic "prajna:mojo_health"
  @stale_threshold_ms 60_000

  defstruct [
    :subscription,
    last_health: nil,
    last_received_at: nil,
    status: :unknown
  ]

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc "Returns the latest known Mojo health status."
  def current_health do
    GenServer.call(__MODULE__, :current_health)
  end

  @impl true
  def init(_opts) do
    # Schedule periodic stale check
    Process.send_after(self(), :check_stale, @stale_threshold_ms)
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_call(:current_health, _from, state) do
    health = %{
      status: state.status,
      last_health: state.last_health,
      last_received_at: state.last_received_at,
      stale: stale?(state)
    }

    {:reply, health, state}
  end

  @impl true
  def handle_info({:zenoh_message, @health_key, payload}, state) do
    case Jason.decode(payload) do
      {:ok, health_data} ->
        new_status =
          case health_data["status"] do
            "healthy" -> :healthy
            "degraded" -> :degraded
            _ -> :unknown
          end

        # Broadcast to PubSub for LiveView consumers
        Phoenix.PubSub.broadcast(
          Indrajaal.PubSub,
          @pubsub_topic,
          {:mojo_health_update, health_data}
        )

        {:noreply,
         %{
           state
           | last_health: health_data,
             last_received_at: System.monotonic_time(:millisecond),
             status: new_status
         }}

      {:error, _} ->
        Logger.warning("[MojoHealthSubscriber] Invalid health payload")
        {:noreply, state}
    end
  end

  def handle_info(:check_stale, state) do
    if stale?(state) and state.status != :stale do
      Logger.warning(
        "[MojoHealthSubscriber] Mojo health beacon STALE (>#{@stale_threshold_ms}ms)"
      )

      Phoenix.PubSub.broadcast(
        Indrajaal.PubSub,
        @pubsub_topic,
        {:mojo_health_update, %{"status" => "stale"}}
      )

      Process.send_after(self(), :check_stale, @stale_threshold_ms)
      {:noreply, %{state | status: :stale}}
    else
      Process.send_after(self(), :check_stale, @stale_threshold_ms)
      {:noreply, state}
    end
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp stale?(state) do
    case state.last_received_at do
      nil -> true
      ts -> System.monotonic_time(:millisecond) - ts > @stale_threshold_ms
    end
  end
end
