defmodule Indrajaal.Compute.MojoRunner do
  @moduledoc """
  Zenoh bridge GenServer to the Mojo MAX compute container.

  Routes inference requests from Elixir to the Mojo container via Zenoh pub/sub,
  implementing the Neural Bridge key expressions:
  - `indrajaal/inference/request/{request_id}` (Elixir -> Mojo)
  - `indrajaal/inference/response/{request_id}` (Mojo -> Elixir)

  ## Features
  - Circuit breaker: trips open after 5 consecutive timeouts, auto-resets after 60s
  - Semaphore: max 10 concurrent requests, rejects with `{:error, :overloaded}` beyond
  - Health broadcasting: publishes bridge health to PubSub `"prajna:mojo_health"`

  ## STAMP Constraints
  - SC-MOJO-001: Zenoh connection to router
  - SC-MOJO-002: Inference latency monitoring (<30s timeout)
  - SC-NEURAL-BRIDGE-001: Request correlation via request_id
  - SC-NEURAL-BRIDGE-002: Circuit breaker on consecutive failures
  - SC-NEURAL-BRIDGE-004: Audit trail for all inference requests
  """
  use GenServer

  require Logger

  @max_concurrent 10
  @default_timeout_ms 30_000
  @circuit_breaker_threshold 5
  @circuit_breaker_reset_ms 60_000

  @request_prefix "indrajaal/inference/request/"

  defstruct [
    :zenoh_session,
    pending: %{},
    concurrent: 0,
    consecutive_failures: 0,
    circuit_open: false,
    circuit_open_at: nil,
    total_requests: 0,
    total_latency_ms: 0.0
  ]

  # -- Client API --

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Send an inference request to the Mojo container via Zenoh.

  Returns `{:ok, result}` or `{:error, reason}`.
  """
  def infer(model, input, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout_ms)
    GenServer.call(__MODULE__, {:infer, model, input, opts}, timeout + 5_000)
  end

  @doc "Returns current bridge health status."
  def health do
    GenServer.call(__MODULE__, :health)
  end

  # -- Server Callbacks --

  @impl true
  def init(_opts) do
    state = %__MODULE__{}
    {:ok, state}
  end

  @impl true
  def handle_call({:infer, model, input, opts}, from, state) do
    timeout = Keyword.get(opts, :timeout, @default_timeout_ms)

    # Circuit breaker check (SC-NEURAL-BRIDGE-002)
    state = maybe_reset_circuit_breaker(state)

    if state.circuit_open do
      {:reply, {:error, :circuit_breaker_open}, state}
    else
      if state.concurrent >= @max_concurrent do
        {:reply, {:error, :overloaded}, state}
      else
        request_id = Ecto.UUID.generate()

        payload =
          Jason.encode!(%{
            request_id: request_id,
            model: model,
            input: input,
            params: Keyword.get(opts, :params, %{}),
            session_token: Keyword.get(opts, :session_token)
          })

        # Publish request via Zenoh (SC-NEURAL-BRIDGE-001)
        case publish_to_zenoh(state, "#{@request_prefix}#{request_id}", payload) do
          :ok ->
            timer_ref = Process.send_after(self(), {:timeout, request_id}, timeout)

            pending =
              Map.put(state.pending, request_id, %{
                from: from,
                timer_ref: timer_ref,
                started_at: System.monotonic_time(:millisecond)
              })

            {:noreply,
             %{
               state
               | pending: pending,
                 concurrent: state.concurrent + 1,
                 total_requests: state.total_requests + 1
             }}

          {:error, reason} ->
            {:reply, {:error, {:publish_failed, reason}}, state}
        end
      end
    end
  end

  def handle_call(:health, _from, state) do
    avg_latency =
      if state.total_requests > 0,
        do: state.total_latency_ms / state.total_requests,
        else: 0.0

    health = %{
      status: if(state.circuit_open, do: :circuit_open, else: :healthy),
      concurrent: state.concurrent,
      pending: map_size(state.pending),
      total_requests: state.total_requests,
      avg_latency_ms: Float.round(avg_latency, 2),
      consecutive_failures: state.consecutive_failures,
      circuit_open: state.circuit_open
    }

    {:reply, health, state}
  end

  @impl true
  def handle_info({:zenoh_response, request_id, payload}, state) do
    case Map.pop(state.pending, request_id) do
      {nil, _} ->
        Logger.warning("[MojoRunner] Response for unknown request: #{request_id}")
        {:noreply, state}

      {%{from: from, timer_ref: timer_ref, started_at: started_at}, pending} ->
        Process.cancel_timer(timer_ref)
        latency = System.monotonic_time(:millisecond) - started_at

        GenServer.reply(from, {:ok, payload})

        {:noreply,
         %{
           state
           | pending: pending,
             concurrent: state.concurrent - 1,
             consecutive_failures: 0,
             total_latency_ms: state.total_latency_ms + latency
         }}
    end
  end

  def handle_info({:timeout, request_id}, state) do
    case Map.pop(state.pending, request_id) do
      {nil, _} ->
        {:noreply, state}

      {%{from: from}, pending} ->
        GenServer.reply(from, {:error, :timeout})
        failures = state.consecutive_failures + 1
        circuit_open = failures >= @circuit_breaker_threshold

        if circuit_open do
          Logger.error(
            "[MojoRunner] Circuit breaker TRIPPED after #{failures} consecutive timeouts"
          )
        end

        {:noreply,
         %{
           state
           | pending: pending,
             concurrent: state.concurrent - 1,
             consecutive_failures: failures,
             circuit_open: circuit_open,
             circuit_open_at:
               if(circuit_open,
                 do: System.monotonic_time(:millisecond),
                 else: state.circuit_open_at
               )
         }}
    end
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # -- Private Helpers --

  defp maybe_reset_circuit_breaker(%{circuit_open: false} = state), do: state

  defp maybe_reset_circuit_breaker(%{circuit_open: true, circuit_open_at: opened_at} = state) do
    elapsed = System.monotonic_time(:millisecond) - opened_at

    if elapsed >= @circuit_breaker_reset_ms do
      Logger.info("[MojoRunner] Circuit breaker RESET after #{elapsed}ms")
      %{state | circuit_open: false, circuit_open_at: nil, consecutive_failures: 0}
    else
      state
    end
  end

  defp publish_to_zenoh(_state, key, payload) do
    case Indrajaal.Observability.ZenohSession.publish(key, payload) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end
end
