defmodule Indrajaal.Errors.ServiceUnavailable do
  @moduledoc """
  Service unavailability errors.
  """
  defmodule MaintenanceMode do
    @moduledoc false
    use Splode.Error,
      fields: [:service_name, :maintenance_start, :maintenance_end, :reason],
      class: :service_unavailable

    @spec message(map()) :: String.t()
    def message(%{servicename: service, maintenanceend: endtime}) do
      "Service #{service} in maintenance mode until #{endtime}"
    end
  end

  defmodule CircuitBreakerOpen do
    @moduledoc false
    use Splode.Error,
      fields: [:service_name, :failure_count, :failure_threshold, :retry_after],
      class: :service_unavailable

    @spec message(map()) :: String.t()
    def message(%{servicename: service, failurecount: failures, failurethreshold: threshold}) do
      "Circuit breaker open for #{service}: #{failures}/#{threshold} failures"
    end
  end

  defmodule RateLimitExceeded do
    @moduledoc false
    use Splode.Error,
      fields: [:service_name, :rate_limit, :current_rate, :window_size, :retry_after],
      class: :service_unavailable

    @spec message(map()) :: String.t()
    def message(%{servicename: service, currentrate: rate, ratelimit: limit}) do
      "Rate limit exceeded for #{service}: #{rate}/#{limit} _requests"
    end
  end

  defmodule CapacityExceeded do
    @moduledoc false
    use Splode.Error,
      fields: [:service_name, :current_load, :max_capacity, :queue_size],
      class: :service_unavailable

    @spec message(map()) :: String.t()
    def message(%{servicename: service, currentload: load, maxcapacity: capacity}) do
      "Capacity exceeded for #{service}: #{load}/#{capacity}"
    end
  end

  defmodule DatabaseUnavailable do
    @moduledoc false
    use Splode.Error,
      fields: [
        :__database_name,
        :connection_pool_exhausted,
        :active_connections,
        :max_connections
      ],
      class: :service_unavailable

    @spec message(map()) :: String.t()
    def message(%{__databasename: db, activeconnections: active, max_connections: max}) do
      "Database #{db} unavailable: #{active}/#{max} connections active"
    end
  end

  defmodule ExternalServiceDown do
    @moduledoc false
    use Splode.Error,
      fields: [:service_name, :endpoint, :last_successful_check, :health_check_failures],
      class: :service_unavailable

    @spec message(map()) :: String.t()
    def message(%{servicename: service, endpoint: endpoint, health_check_failures: failures}) do
      "External service #{service} at #{endpoint} down (#{failures} consecutive failures)"
    end
  end

  defmodule FeatureDisabled do
    @moduledoc false
    use Splode.Error,
      fields: [:feature_name, :disabled_reason, :disabled_by, :disabled_at],
      class: :service_unavailable

    @spec message(map()) :: String.t()
    def message(%{featurename: feature, disabledreason: reason}) do
      "Feature #{feature} disabled: #{reason}"
    end
  end

  defmodule RegionUnavailable do
    @moduledoc false
    use Splode.Error,
      fields: [:region, :service_name, :failover_region, :estimated_recovery],
      class: :service_unavailable

    @spec message(map()) :: String.t()
    def message(%{region: region, service_name: service, failover_region: failover}) do
      "Service #{service} unavailable in region #{region}. Failover: #{failover}"
    end
  end

  defmodule StorageUnavailable do
    @moduledoc false
    use Splode.Error,
      fields: [:storage_type, :storage_location, :reason, :available_alternatives],
      class: :service_unavailable

    @spec message(map()) :: String.t()
    def message(%{storagetype: type, storagelocation: location, reason: reason}) do
      "Storage unavailable: #{type} at #{location} - #{reason}"
    end
  end

  defmodule NodeDown do
    @moduledoc false
    use Splode.Error,
      fields: [:node_name, :node_type, :cluster_status, :services_affected],
      class: :service_unavailable

    @spec message(map()) :: String.t()
    def message(%{node_name: node, node_type: type, services_affected: services}) do
      "Node #{node} (#{type}) down. Affected services: #{Enum.join(services, ", ")}"
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: # OK: General system coordination and management with cyberneti
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
