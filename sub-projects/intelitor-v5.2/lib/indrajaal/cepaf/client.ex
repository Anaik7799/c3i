defmodule Indrajaal.Cepaf.Client do
  @moduledoc """
  High-level Elixir client for Cepaf.Podman container operations.

  ## Overview

  This module provides an ergonomic Elixir API for container management,
  translating between Elixir data structures and the JSON-RPC protocol
  used by the Cepaf.Bridge.

  ## Usage

      # Start containers
      {:ok, id} = Cepaf.Client.create_container(spec)
      :ok = Cepaf.Client.start_container(id)

      # Health checks
      {:ok, :healthy} = Cepaf.Client.health_check(id)

      # Safety validation
      {:ok, :valid} = Cepaf.Client.validate_spec(spec)

  ## Integration with VTO

  This client is designed to replace the direct `System.cmd("podman", ...)`
  calls in VTOOrchestrator with type-safe, validated operations.

  ## Safety Constraints

  All operations enforce STAMP safety constraints:
  - SC-CNT-010: Images must use localhost/ registry
  - SC-POD-001..008: Container specification validation
  - SC-EMR-057: Emergency stop within 5 seconds
  """

  alias Indrajaal.Cepaf.Bridge

  # ============================================================================
  # System Operations
  # ============================================================================

  @doc """
  Ping the bridge to check connectivity.

  Returns `{:ok, :pong}` if connected, `{:error, reason}` otherwise.
  """
  @spec ping() :: {:ok, :pong} | {:error, term()}
  def ping do
    case Bridge.call("system.ping") do
      {:ok, %{"status" => "ok"}} -> {:ok, :pong}
      {:error, type, _details} -> {:error, type}
    end
  end

  @doc """
  Get system information from Podman.
  """
  @spec system_info() :: {:ok, map()} | {:error, term()}
  def system_info do
    case Bridge.call("system.info") do
      {:ok, info} -> {:ok, info}
      {:error, type, _details} -> {:error, type}
    end
  end

  # ============================================================================
  # Container Operations
  # ============================================================================

  @doc """
  List containers.

  ## Options

    * `:all` - Include stopped containers (default: false)

  """
  @spec list_containers(keyword()) :: {:ok, [map()]} | {:error, term()}
  def list_containers(opts \\ []) do
    params = %{all: Keyword.get(opts, :all, false)}

    case Bridge.call("container.list", params) do
      {:ok, containers} when is_list(containers) -> {:ok, containers}
      {:error, type, _details} -> {:error, type}
    end
  end

  @doc """
  Inspect a container by ID or name.
  """
  @spec inspect_container(String.t()) :: {:ok, map()} | {:error, term()}
  def inspect_container(container_id) do
    case Bridge.call("container.inspect", %{containerId: container_id}) do
      {:ok, container} -> {:ok, container}
      {:error, type, _details} -> {:error, type}
    end
  end

  @doc """
  Create a container from specification.

  ## Specification Map

      %{
        name: "indrajaal-db",
        image: "localhost/indrajaal-timescaledb-demo:nixos-devenv",
        ports: [%{host: 5433, container: 5433}],
        env: %{"POSTGRES_USER" => "intelitor"},
        health_check: %{
          test: ["CMD", "pg_isready", "-U", "intelitor"],
          interval: "2s",
          retries: 60
        }
      }

  """
  @spec create_container(map()) :: {:ok, String.t()} | {:error, term()}
  def create_container(spec) do
    params = normalize_container_spec(spec)

    case Bridge.call("container.create", params) do
      {:ok, %{"containerId" => id}} -> {:ok, id}
      {:error, type, _details} -> {:error, type}
    end
  end

  @doc """
  Start a container by ID.
  """
  @spec start_container(String.t()) :: :ok | {:error, term()}
  def start_container(container_id) do
    case Bridge.call("container.start", %{containerId: container_id}) do
      {:ok, _} -> :ok
      {:error, type, _details} -> {:error, type}
    end
  end

  @doc """
  Stop a container by ID.

  ## Options

    * `:timeout` - Seconds to wait before killing (default: 10)

  """
  @spec stop_container(String.t(), keyword()) :: :ok | {:error, term()}
  def stop_container(container_id, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 10)

    case Bridge.call("container.stop", %{containerId: container_id, timeout: timeout}) do
      {:ok, _} -> :ok
      {:error, type, _details} -> {:error, type}
    end
  end

  @doc """
  Remove a container by ID.

  ## Options

    * `:force` - Force removal even if running (default: false)
    * `:volumes` - Remove associated volumes (default: false)

  """
  @spec remove_container(String.t(), keyword()) :: :ok | {:error, term()}
  def remove_container(container_id, opts \\ []) do
    params = %{
      containerId: container_id,
      force: Keyword.get(opts, :force, false),
      volumes: Keyword.get(opts, :volumes, false)
    }

    case Bridge.call("container.remove", params) do
      {:ok, _} -> :ok
      {:error, type, _details} -> {:error, type}
    end
  end

  @doc """
  Get container logs.

  ## Options

    * `:tail` - Number of lines from end (default: 100)

  """
  @spec container_logs(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def container_logs(container_id, opts \\ []) do
    tail = Keyword.get(opts, :tail, 100)

    case Bridge.call("container.logs", %{containerId: container_id, tail: tail}) do
      {:ok, %{"logs" => logs}} -> {:ok, logs}
      {:error, type, _details} -> {:error, type}
    end
  end

  @doc """
  Check if a container exists.
  """
  @spec container_exists?(String.t()) :: boolean()
  def container_exists?(container_id) do
    case Bridge.call("container.exists", %{containerId: container_id}) do
      {:ok, %{"exists" => exists}} -> exists
      _ -> false
    end
  end

  @doc """
  Find a container by name.
  """
  @spec find_container_by_name(String.t()) ::
          {:ok, map()} | {:error, :not_found} | {:error, term()}
  def find_container_by_name(name) do
    case Bridge.call("container.findByName", %{name: name}) do
      {:ok, %{"found" => true, "container" => container}} -> {:ok, container}
      {:ok, %{"found" => false}} -> {:error, :not_found}
      {:error, type, _details} -> {:error, type}
    end
  end

  # ============================================================================
  # Health Operations
  # ============================================================================

  @doc """
  Run health check on a container.

  Returns:
    * `{:ok, :healthy}` - Container is healthy
    * `{:ok, :unhealthy}` - Container is unhealthy
    * `{:ok, :starting}` - Health check still starting
    * `{:ok, :no_healthcheck}` - No health check configured
    * `{:error, reason}` - Error occurred
  """
  @spec health_check(String.t()) :: {:ok, atom()} | {:error, term()}
  def health_check(container_id) do
    case Bridge.call("health.check", %{containerId: container_id}) do
      {:ok, %{"status" => status}} ->
        {:ok, parse_health_status(status)}

      {:error, type, _details} ->
        {:error, type}
    end
  end

  @doc """
  Get health summary for all containers.
  """
  @spec health_summary() :: {:ok, map()} | {:error, term()}
  def health_summary do
    case Bridge.call("health.summary") do
      {:ok, summary} -> {:ok, summary}
      {:error, type, _details} -> {:error, type}
    end
  end

  @doc """
  Check if all containers are healthy.
  """
  @spec all_healthy?() :: boolean()
  def all_healthy? do
    case Bridge.call("health.allHealthy") do
      {:ok, %{"allHealthy" => result}} -> result
      _ -> false
    end
  end

  @doc """
  Get list of unhealthy containers.
  """
  @spec unhealthy_containers() :: {:ok, [map()]} | {:error, term()}
  def unhealthy_containers do
    case Bridge.call("health.unhealthy") do
      {:ok, %{"containers" => containers}} -> {:ok, containers}
      {:error, type, _details} -> {:error, type}
    end
  end

  # ============================================================================
  # Safety Operations
  # ============================================================================

  @doc """
  Validate a container specification against STAMP constraints.

  Returns `{:ok, :valid}` or `{:ok, {:invalid, violations}}`.
  """
  @spec validate_spec(map()) :: {:ok, :valid} | {:ok, {:invalid, [map()]}} | {:error, term()}
  def validate_spec(spec) do
    params = normalize_container_spec(spec)

    case Bridge.call("safety.validateSpec", params) do
      {:ok, %{"valid" => true}} ->
        {:ok, :valid}

      {:ok, %{"valid" => false, "violations" => violations}} ->
        {:ok, {:invalid, violations}}

      {:error, type, _details} ->
        {:error, type}
    end
  end

  @doc """
  Validate an image reference (SC-CNT-010: localhost/ registry only).
  """
  @spec validate_image(String.t()) ::
          {:ok, :valid} | {:ok, {:invalid, [map()]}} | {:error, term()}
  def validate_image(image) do
    case Bridge.call("safety.validateImage", %{image: image}) do
      {:ok, %{"valid" => true}} ->
        {:ok, :valid}

      {:ok, %{"valid" => false, "violations" => violations}} ->
        {:ok, {:invalid, violations}}

      {:error, type, _details} ->
        {:error, type}
    end
  end

  @doc """
  Validate all running containers meet safety requirements.
  """
  @spec validate_all() :: {:ok, :valid} | {:ok, {:invalid, [map()]}} | {:error, term()}
  def validate_all do
    case Bridge.call("safety.validateAll") do
      {:ok, %{"valid" => true}} ->
        {:ok, :valid}

      {:ok, %{"valid" => false, "violations" => violations}} ->
        {:ok, {:invalid, violations}}

      {:error, type, _details} ->
        {:error, type}
    end
  end

  # ============================================================================
  # Emergency Operations
  # ============================================================================

  @doc """
  Emergency stop container (SC-EMR-057: within timeout seconds).
  """
  @spec emergency_stop(String.t(), integer()) :: :ok | {:error, term()}
  def emergency_stop(container_id, timeout \\ 5) do
    case Bridge.call("emergency.stop", %{containerId: container_id, timeout: timeout}) do
      {:ok, _} -> :ok
      {:error, type, _details} -> {:error, type}
    end
  end

  @doc """
  Emergency remove container (SC-EMR-060).
  """
  @spec emergency_remove(String.t()) :: :ok | {:error, term()}
  def emergency_remove(container_id) do
    case Bridge.call("emergency.remove", %{containerId: container_id}) do
      {:ok, _} -> :ok
      {:error, type, _details} -> {:error, type}
    end
  end

  @doc """
  Emergency stop all containers.
  """
  @spec emergency_stop_all() :: {:ok, integer()} | {:error, term()}
  def emergency_stop_all do
    case Bridge.call("emergency.stopAll") do
      {:ok, %{"count" => count}} -> {:ok, count}
      {:error, type, _details} -> {:error, type}
    end
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp normalize_container_spec(spec) do
    %{
      name: Map.get(spec, :name),
      image: Map.get(spec, :image),
      command: Map.get(spec, :command),
      env: Map.get(spec, :env),
      ports: Map.get(spec, :ports),
      volumes: Map.get(spec, :volumes),
      healthCheck: Map.get(spec, :health_check),
      restartPolicy: Map.get(spec, :restart_policy),
      labels: Map.get(spec, :labels)
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp parse_health_status(status) when is_binary(status) do
    case status do
      "healthy" -> :healthy
      "unhealthy" <> _ -> :unhealthy
      "starting" -> :starting
      "none" -> :no_healthcheck
      _ -> :unknown
    end
  end
end
