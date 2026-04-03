# Elixir gRPC Client Example for Cepaf.Podman.Grpc
#
# This is a sample showing how to connect to the F# gRPC service from Elixir.
# To use this, you'll need to:
#
# 1. Add the grpc and protobuf dependencies to mix.exs:
#    {:grpc, github: "elixir-grpc/grpc"}
#    {:protobuf, "~> 0.12"}
#
# 2. Generate Elixir code from the proto file:
#    protoc --elixir_out=plugins=grpc:./lib \
#           --proto_path=lib/cepaf/services/Cepaf.Podman.Grpc/Protos \
#           podman.proto
#
# 3. Configure the gRPC channel:

defmodule Intelitor.Cepaf.PodmanClient do
  @moduledoc """
  Elixir client for Cepaf.Podman.Grpc service.

  Provides container, image, and health management via gRPC
  to the F# Podman interop layer.

  ## Configuration

  Configure the gRPC endpoint in config/runtime.exs:

      config :intelitor,
        cepaf_grpc_endpoint: "localhost:50_051"

  ## Usage

      # List all containers
      {:ok, containers} = Intelitor.Cepaf.PodmanClient.list_containers(all: true)

      # Check health
      {:ok, summary} = Intelitor.Cepaf.PodmanClient.get_health_summary()

      # Create container
      {:ok, id} = Intelitor.Cepaf.PodmanClient.create_container(
        name: "my-container",
        image: "localhost/my-image:latest"
      )
  """

  require Logger

  @default_endpoint "localhost:50_051"

  # ============================================================================
  # Connection Management
  # ============================================================================

  @doc """
  Gets the configured gRPC endpoint.
  """
  def endpoint do
    Application.get_env(:intelitor, :cepaf_grpc_endpoint, @default_endpoint)
  end

  @doc """
  Opens a gRPC channel to the Cepaf.Podman service.
  """
  def connect do
    GRPC.Stub.connect(endpoint())
  end

  @doc """
  Disconnects from the gRPC service.
  """
  def disconnect(channel) do
    GRPC.Stub.disconnect(channel)
  end

  # ============================================================================
  # Container Operations
  # ============================================================================

  @doc """
  Lists containers.

  ## Options

    * `:all` - Include stopped containers (default: false)
    * `:limit` - Maximum number of containers to return
    * `:label_filter` - Filter by labels
    * `:name_filter` - Filter by name

  ## Examples

      {:ok, containers} = list_containers(all: true)
      {:ok, containers} = list_containers(name_filter: ["intelitor-"])
  """
  def list_containers(opts \\ []) do
    with {:ok, channel} <- connect() do
      request = build_list_request(opts)
      result = Cepaf.Podman.V1.ContainerService.Stub.list(channel, request)
      disconnect(channel)
      handle_response(result)
    end
  end

  @doc """
  Inspects a container by ID or name.
  """
  def inspect_container(id) when is_binary(id) do
    with {:ok, channel} <- connect() do
      request = %Cepaf.Podman.V1.InspectContainerRequest{id: id}
      result = Cepaf.Podman.V1.ContainerService.Stub.inspect(channel, request)
      disconnect(channel)
      handle_response(result)
    end
  end

  @doc """
  Creates a new container.

  ## Options

    * `:name` - Container name
    * `:image` - Image reference (required, must start with localhost/)
    * `:command` - Command to run
    * `:env` - Environment variables as keyword list or map
    * `:ports` - Port mappings
    * `:mounts` - Volume mounts
  """
  def create_container(opts) do
    with {:ok, channel} <- connect() do
      request = build_create_request(opts)
      result = Cepaf.Podman.V1.ContainerService.Stub.create(channel, request)
      disconnect(channel)
      handle_response(result)
    end
  end

  @doc """
  Starts a container.
  """
  def start_container(id) when is_binary(id) do
    with {:ok, channel} <- connect() do
      request = %Cepaf.Podman.V1.StartContainerRequest{id: id}
      result = Cepaf.Podman.V1.ContainerService.Stub.start(channel, request)
      disconnect(channel)
      handle_response(result)
    end
  end

  @doc """
  Stops a container.

  ## Options

    * `:timeout` - Timeout in seconds before force kill (default: 10)
  """
  def stop_container(id, opts \\ []) when is_binary(id) do
    timeout = Keyword.get(opts, :timeout, 10)

    with {:ok, channel} <- connect() do
      request = %Cepaf.Podman.V1.StopContainerRequest{id: id, timeout: timeout}
      result = Cepaf.Podman.V1.ContainerService.Stub.stop(channel, request)
      disconnect(channel)
      handle_response(result)
    end
  end

  @doc """
  Removes a container.

  ## Options

    * `:force` - Force removal of running container
    * `:volumes` - Remove associated volumes
  """
  def remove_container(id, opts \\ []) when is_binary(id) do
    force = Keyword.get(opts, :force, false)
    volumes = Keyword.get(opts, :volumes, false)

    with {:ok, channel} <- connect() do
      request = %Cepaf.Podman.V1.RemoveContainerRequest{
        id: id,
        force: force,
        volumes: volumes
      }
      result = Cepaf.Podman.V1.ContainerService.Stub.remove(channel, request)
      disconnect(channel)
      handle_response(result)
    end
  end

  # ============================================================================
  # Image Operations
  # ============================================================================

  @doc """
  Lists images.

  ## Options

    * `:all` - Include intermediate images
  """
  def list_images(opts \\ []) do
    all = Keyword.get(opts, :all, false)

    with {:ok, channel} <- connect() do
      request = %Cepaf.Podman.V1.ListImagesRequest{all: all}
      result = Cepaf.Podman.V1.ImageService.Stub.list(channel, request)
      disconnect(channel)
      handle_response(result)
    end
  end

  @doc """
  Pulls an image from registry.

  Note: Only localhost/ registry is allowed per STAMP safety constraints.
  """
  def pull_image(reference) when is_binary(reference) do
    with {:ok, channel} <- connect() do
      request = %Cepaf.Podman.V1.PullImageRequest{reference: reference}
      result = Cepaf.Podman.V1.ImageService.Stub.pull(channel, request)
      disconnect(channel)
      handle_response(result)
    end
  end

  @doc """
  Inspects an image.
  """
  def inspect_image(reference) when is_binary(reference) do
    with {:ok, channel} <- connect() do
      request = %Cepaf.Podman.V1.InspectImageRequest{reference: reference}
      result = Cepaf.Podman.V1.ImageService.Stub.inspect(channel, request)
      disconnect(channel)
      handle_response(result)
    end
  end

  # ============================================================================
  # Health Operations
  # ============================================================================

  @doc """
  Checks health of all running containers.
  """
  def check_all_health do
    with {:ok, channel} <- connect() do
      request = Google.Protobuf.Empty.new()
      result = Cepaf.Podman.V1.HealthService.Stub.check_all(channel, request)
      disconnect(channel)
      handle_response(result)
    end
  end

  @doc """
  Gets health summary for all containers.
  """
  def get_health_summary do
    with {:ok, channel} <- connect() do
      request = Google.Protobuf.Empty.new()
      result = Cepaf.Podman.V1.HealthService.Stub.get_summary(channel, request)
      disconnect(channel)
      handle_response(result)
    end
  end

  @doc """
  Checks health of a specific container.
  """
  def check_container_health(container_id) when is_binary(container_id) do
    with {:ok, channel} <- connect() do
      request = %Cepaf.Podman.V1.CheckContainerRequest{container_id: container_id}
      result = Cepaf.Podman.V1.HealthService.Stub.check_container(channel, request)
      disconnect(channel)
      handle_response(result)
    end
  end

  @doc """
  Liveness probe for a container.
  Returns true if container is running.
  """
  def liveness_probe(container_id) when is_binary(container_id) do
    with {:ok, channel} <- connect() do
      request = %Cepaf.Podman.V1.LivenessProbeRequest{container_id: container_id}
      result = Cepaf.Podman.V1.HealthService.Stub.liveness_probe(channel, request)
      disconnect(channel)

      case handle_response(result) do
        {:ok, %{alive: alive}} -> {:ok, alive}
        error -> error
      end
    end
  end

  @doc """
  Readiness probe for a container.
  Returns true if container is ready to receive traffic.
  """
  def readiness_probe(container_id) when is_binary(container_id) do
    with {:ok, channel} <- connect() do
      request = %Cepaf.Podman.V1.ReadinessProbeRequest{container_id: container_id}
      result = Cepaf.Podman.V1.HealthService.Stub.readiness_probe(channel, request)
      disconnect(channel)

      case handle_response(result) do
        {:ok, %{alive: ready}} -> {:ok, ready}
        error -> error
      end
    end
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp build_list_request(opts) do
    %Cepaf.Podman.V1.ListContainersRequest{
      all: Keyword.get(opts, :all, false),
      limit: Keyword.get(opts, :limit, 0),
      label_filter: Keyword.get(opts, :label_filter, []),
      name_filter: Keyword.get(opts, :name_filter, []),
      status_filter: Keyword.get(opts, :status_filter, [])
    }
  end

  defp build_create_request(opts) do
    env_list = opts
    |> Keyword.get(:env, %{})
    |> Enum.map(fn {k, v} -> %Cepaf.Podman.V1.KeyValue{key: to_string(k), value: to_string(v)} end)

    %Cepaf.Podman.V1.CreateContainerRequest{
      name: Keyword.get(opts, :name, ""),
      image: Keyword.fetch!(opts, :image),
      command: Keyword.get(opts, :command, []),
      env: env_list,
      tty: Keyword.get(opts, :tty, false),
      stdin_open: Keyword.get(opts, :stdin_open, false)
    }
  end

  defp handle_response({:ok, response}), do: {:ok, response}
  defp handle_response({:error, %GRPC.RPCError{status: status, message: message}}) do
    Logger.error("gRPC error: status=#{status}, message=#{message}")
    {:error, %{status: status, message: message}}
  end
  defp handle_response({:error, reason}) do
    Logger.error("gRPC connection error: #{inspect(reason)}")
    {:error, reason}
  end
end
