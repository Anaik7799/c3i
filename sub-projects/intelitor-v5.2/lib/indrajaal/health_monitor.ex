defmodule Indrajaal.HealthMonitor do
  @moduledoc """
  Health monitoring facade delegating to container health monitor.

  WHAT: Provides unified health status for all system components.
  WHY: SC-OBS-069 requires comprehensive health monitoring.
  CONSTRAINTS: Non-blocking, <100ms response time.
  """

  alias Indrajaal.Containers.ContainerHealthMonitor

  @doc "Get overall system health status"
  def status do
    containers = ContainerHealthMonitor.discover_containers()

    health_results =
      containers
      |> Enum.map(fn container ->
        case ContainerHealthMonitor.check_container_health(container.name) do
          {:ok, health} -> {container.name, health}
          {:error, _} -> {container.name, %{status: :unknown}}
        end
      end)
      |> Enum.into(%{})

    overall =
      health_results
      |> Map.values()
      |> Enum.all?(fn h -> h.status == :healthy end)
      |> case do
        true -> :healthy
        false -> :degraded
      end

    {:ok, %{overall: overall, containers: health_results}}
  rescue
    _ -> {:error, :health_monitor_unavailable}
  end

  @doc "Check if a specific component is healthy"
  def healthy?(component) when is_atom(component) do
    healthy?(Atom.to_string(component))
  end

  def healthy?(component) when is_binary(component) do
    case ContainerHealthMonitor.check_container_health(component) do
      {:ok, %{status: :healthy}} -> true
      _ -> false
    end
  rescue
    _ -> false
  end

  @doc "Get all component statuses"
  def all_components do
    case status() do
      {:ok, %{containers: containers}} -> {:ok, containers}
      error -> error
    end
  end

  @doc "Health check endpoint data"
  def health_check_data do
    %{
      status: overall_status(),
      timestamp: DateTime.utc_now(),
      components: component_summary()
    }
  end

  # Legacy API for backwards compatibility

  @doc """
  Perform a comprehensive health check of the system.
  Legacy API - delegates to status/0 with enhanced response format.
  """
  def comprehensive_health_check(_options \\ %{}) do
    case status() do
      {:ok, %{overall: overall, containers: containers}} ->
        {:ok,
         %{
           overall_status: overall,
           components: containers,
           timestamp: DateTime.utc_now(),
           framework: "SOPv5.1"
         }}

      error ->
        error
    end
  end

  @doc """
  Check the health of a specific component.
  Legacy API - delegates to ContainerHealthMonitor.
  """
  def check_component_health(component) when is_atom(component) do
    check_component_health(Atom.to_string(component))
  end

  def check_component_health(component) when is_binary(component) do
    ContainerHealthMonitor.check_container_health(component)
  end

  @doc """
  Get the overall system status.
  Legacy API - returns status in legacy format.
  """
  def get_system_status do
    case status() do
      {:ok, data} -> {:ok, data}
      error -> error
    end
  end

  @doc """
  Get health metrics for all components.
  Legacy API - returns component health metrics.
  """
  def get_health_metrics do
    case all_components() do
      {:ok, components} ->
        {:ok, components}

      _ ->
        {:error, :metrics_unavailable}
    end
  end

  defp overall_status do
    case status() do
      {:ok, %{overall: :healthy}} -> :healthy
      {:ok, %{overall: :degraded}} -> :degraded
      _ -> :unhealthy
    end
  end

  defp component_summary do
    case all_components() do
      {:ok, components} ->
        Map.new(components, fn {k, v} -> {k, v[:status] == :healthy} end)

      _ ->
        %{}
    end
  end
end
