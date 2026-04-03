defmodule Indrajaal.Errors.System do
  @moduledoc """
  System and infrastructure - related errors.
  """
  defmodule DatabaseConnectionError do
    @moduledoc false
    use Splode.Error,
      fields: [:repo, :operation, :error_details, :retry_count],
      class: :system

    @spec message(map()) :: String.t()
    def message(%{repo: repo, operation: operation}) do
      "Database connection error in #{repo} during #{operation}"
    end
  end

  defmodule DatabaseConstraintViolation do
    @moduledoc false
    use Splode.Error,
      fields: [:constraint_name, :table, :operation, :violation_details],
      class: :system

    @spec message(map()) :: String.t()
    def message(%{constraint_name: constraint, table: table}) do
      "Database constraint violation: #{constraint} on table #{table}"
    end
  end

  defmodule CacheConnectionError do
    @moduledoc false
    use Splode.Error,
      fields: [:cache_type, :operation, :error_details, :fallback_available],
      class: :system

    @spec message(map()) :: String.t()
    def message(%{cachetype: type, operation: operation}) do
      "Cache connection error in #{type} during #{operation}"
    end
  end

  defmodule FileSystemError do
    @moduledoc false
    use Splode.Error,
      fields: [:operation, :file_path, :permissions, :disk_space, :error_code],
      class: :system

    @spec message(map()) :: String.t()
    def message(%{operation: operation, filepath: path, errorcode: code}) do
      "Filesystem error during #{operation} on #{path}: #{code}"
    end
  end

  defmodule ConfigurationError do
    @moduledoc false
    use Splode.Error,
      fields: [:config_key, :expected_type, :actual_value, :validation_error],
      class: :system

    @spec message(map()) :: String.t()
    def message(%{configkey: key, expectedtype: expected, actualvalue: actual}) do
      "Configuration error for #{key}: expected #{expected}, got #{inspect(actual)}"
    end
  end

  defmodule ServiceStartupError do
    @moduledoc false
    use Splode.Error,
      fields: [:service_name, :startup_phase, :error_details, :dependencies],
      class: :system

    @spec message(map()) :: String.t()
    def message(%{servicename: service, startupphase: phase}) do
      "Service startup error in #{service} during #{phase}"
    end
  end

  defmodule MemoryExhaustion do
    @moduledoc false
    use Splode.Error,
      fields: [:process_name, :memory_used, :memory_limit, :operation],
      class: :system

    @spec message(map()) :: String.t()
    def message(%{processname: process, memoryused: used, memorylimit: limit}) do
      "Memory exhaustion in #{process}: #{used}/#{limit} bytes used"
    end
  end

  defmodule ProcessCrash do
    @moduledoc false
    use Splode.Error,
      fields: [:process_name, :pid, :exit_reason, :restart_count, :supervisor],
      class: :system

    @spec message(map()) :: String.t()
    def message(%{processname: process, exitreason: reason}) do
      "Process crash in #{process}: #{reason}"
    end
  end

  defmodule NetworkPartition do
    @moduledoc false
    use Splode.Error,
      fields: [:node_name, :target_node, :partition_duration, :cluster_status],
      class: :system

    @spec message(map()) :: String.t()
    def message(%{node_name: node, target_node: target}) do
      "Network partition detected between #{node} and #{target}"
    end
  end

  defmodule ResourceExhaustion do
    @moduledoc false
    use Splode.Error,
      fields: [:resource_type, :current_usage, :limit, :affected_operations],
      class: :system

    @spec message(map()) :: String.t()
    def message(%{resourcetype: type, currentusage: usage, limit: limit}) do
      "Resource exhaustion for #{type}: #{usage}/#{limit}"
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: # OK: General system coordination and management with cybernetic
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
