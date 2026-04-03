defmodule Indrajaal.Jain.Appropriation do
  @moduledoc """
  Resource Appropriation - Non-Aggressive Acquisition for v20.0.0

  Implements Aparigraha (non-possession) principle in resource acquisition:
  - Request before taking
  - Never exceed limits
  - Release when not needed
  - Graceful degradation

  ## Appropriation Model

  Resource acquisition follows:
  1. Check availability on host
  2. Request permission (if applicable)
  3. Acquire within limits
  4. Monitor usage
  5. Release proactively

  ## Resource Types
  - **CPU**: Computation time
  - **Memory**: RAM allocation
  - **Storage**: Disk space
  - **Network**: Bandwidth
  - **Connections**: Network sockets

  ## STAMP Constraints
  - SC-APR-001: MUST NOT exceed 10% of host capacity
  - SC-APR-002: MUST release on request
  - SC-APR-003: MUST NOT compete aggressively
  - SC-APR-004: MUST track all allocations
  """

  require Logger

  @type resource_type :: :cpu | :memory | :storage | :network | :connections

  @type resource_request :: %{
          type: resource_type(),
          amount: term(),
          priority: :low | :normal | :high,
          duration: non_neg_integer() | :indefinite,
          reason: String.t()
        }

  @type resource_allocation :: %{
          id: String.t(),
          type: resource_type(),
          amount: term(),
          allocated_at: DateTime.t(),
          expires_at: DateTime.t() | nil,
          released: boolean()
        }

  @type state :: %{
          allocations: [resource_allocation()],
          limits: map(),
          stats: map()
        }

  # Maximum resource ratio (SC-APR-001)
  @max_ratio 0.1

  # Release threshold - Reserved for auto-release implementation
  # @release_threshold 0.3

  @doc """
  Requests a resource allocation.
  """
  @spec request(resource_request()) :: {:ok, resource_allocation()} | {:error, term()}
  def request(request) do
    Logger.info("Requesting #{request.type}: #{request.amount}")

    with :ok <- check_limits(request),
         :ok <- check_host_availability(request) do
      allocate(request)
    end
  end

  @doc """
  Releases a resource allocation.
  """
  @spec release(String.t()) :: :ok | {:error, :not_found}
  def release(allocation_id) do
    Logger.info("Releasing allocation: #{allocation_id}")
    # In production, would update allocation state
    :ok
  end

  @doc """
  Releases all resources.
  """
  @spec release_all() :: :ok
  def release_all do
    Logger.info("Releasing all resources")
    :ok
  end

  @doc """
  Checks if a resource request is within limits.
  """
  @spec within_limits?(resource_request()) :: boolean()
  def within_limits?(request) do
    case check_limits(request) do
      :ok -> true
      {:error, _} -> false
    end
  end

  @doc """
  Gets current resource usage.
  """
  @spec current_usage() :: map()
  def current_usage do
    %{
      cpu: 0.0,
      memory: 0,
      storage: 0,
      network: 0,
      connections: 0
    }
  end

  @doc """
  Gets host capacity for a resource type.
  """
  @spec host_capacity(resource_type()) :: term()
  def host_capacity(type) do
    # In production, would query actual system metrics
    case type do
      :cpu -> 1.0
      :memory -> 8 * 1024 * 1024 * 1024
      :storage -> 100 * 1024 * 1024 * 1024
      :network -> 1_000_000_000
      :connections -> 10_000
    end
  end

  @doc """
  Gets the maximum allowed allocation for a resource type.
  """
  @spec max_allowed(resource_type()) :: term()
  def max_allowed(type) do
    capacity = host_capacity(type)

    case type do
      :cpu -> capacity * @max_ratio
      :memory -> trunc(capacity * @max_ratio)
      :storage -> trunc(capacity * @max_ratio)
      :network -> trunc(capacity * @max_ratio)
      :connections -> trunc(capacity * @max_ratio)
    end
  end

  @doc """
  Suggests resources to release based on usage patterns.
  """
  @spec suggest_releases([resource_allocation()]) :: [resource_allocation()]
  def suggest_releases(allocations) do
    # Suggest releasing low-usage or expired allocations
    Enum.filter(allocations, fn alloc ->
      expired?(alloc) or low_usage?(alloc)
    end)
  end

  @doc """
  Calculates appropriation metrics.
  """
  @spec metrics() :: map()
  def metrics do
    %{
      total_requested: 0,
      total_granted: 0,
      total_denied: 0,
      total_released: 0,
      current_allocations: 0,
      efficiency: 1.0
    }
  end

  # Private helpers

  defp check_limits(request) do
    max = max_allowed(request.type)
    current = get_current_allocation(request.type)

    if current + request.amount <= max do
      :ok
    else
      {:error, {:limit_exceeded, %{max: max, current: current, requested: request.amount}}}
    end
  end

  defp check_host_availability(request) do
    capacity = host_capacity(request.type)
    current_host_usage = get_host_usage(request.type)
    available = capacity - current_host_usage

    if request.amount <= available do
      :ok
    else
      {:error, {:insufficient_resources, %{available: available, requested: request.amount}}}
    end
  end

  defp allocate(request) do
    allocation = %{
      id: generate_allocation_id(),
      type: request.type,
      amount: request.amount,
      allocated_at: DateTime.utc_now(),
      expires_at: calculate_expiry(request.duration),
      released: false
    }

    Logger.info("Allocated #{request.type}: #{request.amount} (id: #{allocation.id})")

    {:ok, allocation}
  end

  defp generate_allocation_id do
    rand_bytes = :crypto.strong_rand_bytes(4)
    "alloc_#{Base.encode16(rand_bytes, case: :lower)}"
  end

  defp calculate_expiry(:indefinite), do: nil

  defp calculate_expiry(duration_ms) when is_integer(duration_ms) do
    DateTime.add(DateTime.utc_now(), duration_ms, :millisecond)
  end

  defp get_current_allocation(_type) do
    # In production, would sum current allocations
    0
  end

  defp get_host_usage(_type) do
    # In production, would query actual system metrics
    0
  end

  defp expired?(%{expires_at: nil}), do: false

  defp expired?(%{expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :gt
  end

  defp low_usage?(_allocation) do
    # In production, would check actual usage
    false
  end
end
