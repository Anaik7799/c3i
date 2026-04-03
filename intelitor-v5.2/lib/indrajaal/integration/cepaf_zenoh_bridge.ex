defmodule Indrajaal.Integration.CepafZenohBridge do
  @moduledoc """
  Bridges CEPAF (F# Container Control) events to the Zenoh Nervous System.

  Allows the Cortex to React to container events (OODA "Observe") with zero latency.

  ## STAMP Constraints
  - SC-ZTEST-004: Publishing MUST be async (non-blocking)
  - SC-ZTEST-008: Log fallback written before Zenoh attempt
  - SC-ZENOH-001: Delegates to ZenohSession for actual NIF calls
  """
  use GenServer
  require Logger

  # -----------------------------------------------------------------------------
  # Client API
  # -----------------------------------------------------------------------------

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Publishes a container lifecycle event to Zenoh.
  """
  def publish_event(container_id, event_type, payload) do
    GenServer.cast(__MODULE__, {:publish, container_id, event_type, payload})
  end

  # -----------------------------------------------------------------------------
  # Server Callbacks
  # -----------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    Logger.info("[CepafZenohBridge] CEPAF-Zenoh Bridge Initialized - SC-ZENOH-001")
    {:ok, %{session: nil}}
  end

  @impl true
  def handle_cast({:publish, container_id, event_type, payload}, state) do
    topic = "indrajaal/infra/containers/#{container_id}/#{event_type}"

    # SC-ZTEST-008: Write log fallback first (guaranteed durability)
    Logger.info(
      "[ZTEST-CHECKPOINT] checkpoint=cepaf-event topic=#{topic} type=container_event payload=#{inspect(payload)}"
    )

    # SC-ZTEST-004: Async publish via ZenohSession (non-blocking)
    Task.start(fn ->
      zenoh_session = Indrajaal.Observability.ZenohSession

      if Code.ensure_loaded?(zenoh_session) and
           function_exported?(zenoh_session, :publish, 2) do
        encoded = Jason.encode!(payload)

        case zenoh_session.publish(topic, encoded) do
          :ok ->
            Logger.debug("[CepafZenohBridge] Published #{topic}")

          {:error, reason} ->
            Logger.warning("[CepafZenohBridge] Publish failed for #{topic}: #{inspect(reason)}")
        end
      else
        Logger.debug(
          "[CepafZenohBridge] ZenohSession unavailable - log fallback already written for #{topic}"
        )
      end
    end)

    {:noreply, state}
  end
end
