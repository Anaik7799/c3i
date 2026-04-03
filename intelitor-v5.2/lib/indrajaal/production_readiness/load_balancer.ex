defmodule Indrajaal.ProductionReadiness.LoadBalancer do
  @moduledoc """
  Intelligent load balancer with dynamic rebalancing capabilities.
  Implements TDG _requirements with STAMP safety constraints.

  Framework: AEE+SOPv5.1+GDE+PHICS+TPS+STAMP+Container-Only

  Safety Constraints:
  - SC-011: Load balancer must maintain minimum service availability
  """

  use GenServer
  require Logger

  @rebalance_interval_ms 30_000
  @health_check_interval_ms 5_000
  @min_healthy_backends 1

  # Client API

  def start_link(backends) when is_list(backends) do
    GenServer.start_link(__MODULE__, backends, name: __MODULE__)
  end

  @doc """
  Route a _request to an appropriate backend.
  """
  def route_request(request_meta_data \\ %{}) do
    GenServer.call(__MODULE__, {:route_request, request_meta_data})
  end

  @doc """
  Rebalance traffic weights based on backend performance.
  """
  def rebalance do
    GenServer.call(__MODULE__, :rebalance)
  end

  @doc """
  Mark a backend as unhealthy.
  Satisfies SC-011: Maintains minimum service availability.
  """
  def mark_unhealthy(backend_id) do
    GenServer.call(__MODULE__, {:mark_unhealthy, backend_id})
  end

  @doc """
  Mark a backend as healthy.
  """
  def mark_healthy(backend_id) do
    GenServer.call(__MODULE__, {:mark_healthy, backend_id})
  end

  @doc """
  Get current load balancer status.
  """
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  @doc """
  Add a new backend to the pool.
  """
  def add_backend(backend) do
    GenServer.call(__MODULE__, {:add_backend, backend})
  end

  @doc """
  Remove a backend from the pool.
  """
  def remove_backend(backend_id) do
    GenServer.call(__MODULE__, {:remove_backend, backend_id})
  end

  # Server callbacks

  @impl true
  def init(backends) do
    # Initialize backend states
    backend_states =
      backends
      |> Enum.map(fn backend ->
        {backend.id,
         %{
           id: backend.id,
           weight: backend[:weight] || 1.0,
           health: backend[:health] || :healthy,
           load: backend[:load] || 0.0,
           _request_count: 0,
           error_count: 0,
           response_times: [],
           last_health_check: DateTime.utc_now()
         }}
      end)
      |> Map.new()

    state = %{
      backends: backend_states,
      routing_algorithm: :weighted_least_connections,
      total_requests: 0,
      last_rebalance: DateTime.utc_now()
    }

    # Schedule periodic health checks and rebalancing
    schedule_health_check()
    schedule_rebalance()

    {:ok, state}
  end

  @impl true
  def handle_call({:route_request, meta_data}, _from, state) do
    case select_backend(state, meta_data) do
      {:ok, backend_id} ->
        # Update _request count
        new_backends =
          update_in(
            state.backends,
            [backend_id, :_request_count],
            &(&1 + 1)
          )

        new_state = %{state | backends: new_backends, total_requests: state.total_requests + 1}

        {:reply, {:ok, backend_id}, new_state}

      {:error, :no_healthy_backends} = error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:rebalance, _from, state) do
    Logger.info("[LoadBalancer] Starting rebalancing")

    # Calculate new weights based on performance metrics
    new_weights = calculate_optimal_weights(state.backends)

    # Apply new weights
    new_backends =
      Enum.reduce(new_weights, state.backends, fn {backend_id, weight}, backends ->
        put_in(backends, [backend_id, :weight], weight)
      end)

    new_state = %{state | backends: new_backends, last_rebalance: DateTime.utc_now()}

    {:reply, {:ok, new_weights}, new_state}
  end

  @impl true
  def handle_call({:mark_unhealthy, backend_id}, _from, state) do
    # SC-011: Check if we would lose all backends
    healthy_count = count_healthy_backends(state.backends)

    if healthy_count <= @min_healthy_backends do
      Logger.error("[LoadBalancer] Cannot mark #{backend_id} unhealthy - would lose all backends")
      {:reply, {:error, :would_lose_all_backends}, state}
    else
      new_backends = put_in(state.backends, [backend_id, :health], :unhealthy)

      # AGENT GA FIX: Updated deprecated Logger.warn
      Logger.warning("[LoadBalancer] Backend #{backend_id} marked as unhealthy")

      {:reply, :ok, %{state | backends: new_backends}}
    end
  end

  @impl true
  def handle_call({:mark_healthy, backend_id}, _from, state) do
    new_backends = put_in(state.backends, [backend_id, :health], :healthy)

    Logger.info("[LoadBalancer] Backend #{backend_id} marked as healthy")

    {:reply, :ok, %{state | backends: new_backends}}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    healthy_backends = Enum.filter(state.backends, fn {_, b} -> b.health == :healthy end)
    unhealthy_backends = Enum.filter(state.backends, fn {_, b} -> b.health != :healthy end)

    status = %{
      total_backends: map_size(state.backends),
      healthy_count: length(healthy_backends),
      unhealthy_count: length(unhealthy_backends),
      total_requests_served: state.total_requests,
      routing_algorithm: state.routing_algorithm,
      last_rebalance: state.last_rebalance,
      backend_details: format_backend_details(state.backends)
    }

    {:reply, {:ok, status}, state}
  end

  @impl true
  def handle_call({:addbackend, backend}, _from, state) do
    backend_state = %{
      id: backend.id,
      weight: backend[:weight] || 1.0,
      health: :healthy,
      load: 0.0,
      _request_count: 0,
      error_count: 0,
      response_times: [],
      last_health_check: DateTime.utc_now()
    }

    new_backends = Map.put(state.backends, backend.id, backend_state)

    Logger.info("[LoadBalancer] Added backend #{backend.id}")

    {:reply, :ok, %{state | backends: new_backends}}
  end

  @impl true
  def handle_call({:remove_backend, backend_id}, _from, state) do
    # SC-011: Check minimum availability
    if map_size(state.backends) <= @min_healthy_backends do
      {:reply, {:error, :would_violate_minimum_backends}, state}
    else
      new_backends = Map.delete(state.backends, backend_id)

      Logger.info("[LoadBalancer] Removed backend #{backend_id}")

      {:reply, :ok, %{state | backends: new_backends}}
    end
  end

  @impl true
  def handle_info(:healthcheck, state) do
    # Perform health checks on all backends
    new_backends =
      Enum.reduce(state.backends, %{}, fn {id, backend}, acc ->
        updated_backend = perform_health_check(backend)
        Map.put(acc, id, updated_backend)
      end)

    # Schedule next health check
    schedule_health_check()

    {:noreply, %{state | backends: new_backends}}
  end

  @impl true
  def handle_info(:rebalance, state) do
    # Trigger rebalancing
    {:ok, _} = rebalance()

    # Schedule next rebalance
    schedule_rebalance()

    {:noreply, state}
  end

  # Private functions

  # AGENT GA FIX: meta_data not used in round-robin
  defp select_backend(state, _meta_data) do
    healthy_backends =
      state.backends
      |> Enum.filter(fn {_, backend} -> backend.health == :healthy end)
      # AGENT GA FIX
      |> Enum.map(fn {_id, backend} -> backend end)

    if Enum.empty?(healthy_backends) do
      {:error, :no_healthy_backends}
    else
      # Apply routing algorithm
      backend =
        case state.routing_algorithm do
          :weighted_least_connections ->
            select_weighted_least_connections(healthy_backends, state)

          :weighted_round_robin ->
            select_weighted_round_robin(healthy_backends, state.total_requests, state)

          :least_response_time ->
            select_least_response_time(healthy_backends)

          _ ->
            # Fallback to simple round robin
            Enum.at(healthy_backends, rem(state.total_requests, length(healthy_backends)))
        end

      {:ok, backend.id}
    end
  end

  defp select_weighted_least_connections(backends, _req) do
    # Select backend with lowest connections/weight ratio
    backends
    |> Enum.min_by(fn backend ->
      (backend._request_count + 1) / backend.weight
    end)
  end

  defp select_weighted_round_robin(backends, total_requests, _req) do
    # Calculate cumulative weights
    total_weight = Enum.reduce(backends, 0.0, fn b, acc -> acc + b.weight end)

    # Determine position in weighted sequence
    position = rem(total_requests, round(total_weight * 100)) / 100

    # Find the backend for this position
    {selected, _} =
      Enum.reduce_while(backends, {nil, 0.0}, fn backend, {_, cumulative} ->
        new_cumulative = cumulative + backend.weight

        if position < new_cumulative do
          {:halt, {backend, new_cumulative}}
        else
          {:cont, {nil, new_cumulative}}
        end
      end)

    selected || List.first(backends)
  end

  defp select_least_response_time(backends) do
    # Select backend with lowest average response time
    backends
    |> Enum.min_by(fn backend ->
      if Enum.empty?(backend.response_times) do
        0
      else
        Enum.sum(backend.response_times) / length(backend.response_times)
      end
    end)
  end

  defp calculate_optimal_weights(backends) do
    # Calculate performance scores for each backend
    scores =
      backends
      |> Enum.map(fn {id, backend} ->
        score = calculate_performance_score(backend, nil)
        {id, score}
      end)
      |> Map.new()

    # Normalize scores to weights
    total_score = scores |> Map.values() |> Enum.sum()

    if total_score > 0 do
      scores
      |> Enum.map(fn {id, score} ->
        weight = score / total_score * map_size(backends)
        # Ensure minimum weight for healthy backends
        weight = if backends[id].health == :healthy, do: max(weight, 0.1), else: weight
        {id, Float.round(weight, 2)}
      end)
      |> Map.new()
    else
      # Default equal weights
      backends
      |> Enum.map(fn {id, _} -> {id, 1.0} end)
      |> Map.new()
    end
  end

  defp calculate_performance_score(backend, _req) do
    base_score =
      case backend.health do
        :healthy -> 1.0
        :degraded -> 0.5
        :unhealthy -> 0.0
      end

    # Adjust for error rate
    error_rate =
      if backend._request_count > 0 do
        backend.error_count / backend._request_count
      else
        0.0
      end

    error_penalty = 1.0 - min(error_rate * 10, 0.9)

    # Adjust for response time
    avg_response_time =
      if Enum.empty?(backend.response_times) do
        # Default 50ms
        50.0
      else
        Enum.sum(backend.response_times) / length(backend.response_times)
      end

    response_time_factor = 100.0 / (avg_response_time + 50.0)

    # Adjust for current load
    load_factor = 1.0 - backend.load

    base_score * error_penalty * response_time_factor * load_factor
  end

  defp perform_health_check(backend) do
    # In production, this would actually check backend health
    # For now, simulate with random health updates
    new_health =
      if :rand.uniform() > 0.95 do
        case backend.health do
          :healthy -> :degraded
          :degraded -> :unhealthy
          :unhealthy -> :healthy
        end
      else
        backend.health
      end

    %{backend | health: new_health, last_health_check: DateTime.utc_now()}
  end

  defp count_healthy_backends(backends) do
    backends
    |> Enum.count(fn {_, b} -> b.health == :healthy end)
  end

  defp format_backend_details(backends) do
    backends
    |> Enum.map(fn {id, backend} ->
      %{
        id: id,
        weight: backend.weight,
        health: backend.health,
        _request_count: backend._request_count,
        error_count: backend.error_count,
        average_response_time: calculate_avg_response_time(backend.response_times)
      }
    end)
  end

  defp calculate_avg_response_time([]), do: 0.0

  defp calculate_avg_response_time(times) do
    Float.round(Enum.sum(times) / length(times), 2)
  end

  defp schedule_health_check do
    Process.send_after(self(), :health_check, @health_check_interval_ms)
  end

  defp schedule_rebalance do
    Process.send_after(self(), :rebalance, @rebalance_interval_ms)
  end
end
