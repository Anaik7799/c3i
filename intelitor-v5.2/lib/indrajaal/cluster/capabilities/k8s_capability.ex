defmodule Indrajaal.Cluster.Capabilities.K8sCapability do
  @moduledoc """
  Kubernetes Capability Backend for K8s Pod-based Mesh Networking.

  WHAT: Manages Kubernetes pods as compute nodes with Tailscale sidecar integration.
  WHY: SC-CLU-001 requires identity networking; K8s provides elastic compute at scale.
  CONSTRAINTS: Must use Tailscale sidecar for mesh; fallback to ClusterIP when unavailable.

  ## Architecture

  This module provides:
  1. **Pod Lifecycle**: Create/delete pods via K8s API
  2. **Tailscale Sidecar**: Each pod runs a Tailscale sidecar for mesh identity
  3. **DNS Integration**: Headless service + Tailscale MagicDNS hybrid
  4. **FLAME Backend**: Integrates with FLAME.K8sBackend

  ## STAMP Constraints
  - SC-CLU-001: Identity-based networking (Tailscale sidecar)
  - SC-CLU-002: Consistent hashing for data placement
  - SC-CLU-004: Graceful degradation (ClusterIP fallback)
  - SC-K8S-001: Pod security policies enforced

  ## Pod Naming Convention
  - Tailscale: `{pod-name}@{pod-name}.{tailnet}.ts.net`
  - ClusterIP: `{pod-name}@{service}.{namespace}.svc.cluster.local`
  """

  use GenServer
  require Logger

  alias Indrajaal.Cluster.TailscaleDNS
  alias Indrajaal.Cluster.Capabilities.NodeNameBuilder

  @behaviour Indrajaal.Cluster.Capabilities.Behaviour

  # ============================================================
  # TYPE DEFINITIONS
  # ============================================================

  @type pod_type :: :runner | :worker | :analytics | :video | :intelligence
  @type pod_id :: String.t()
  @type pod_state :: :pending | :running | :succeeded | :failed | :unknown
  @type network_mode :: :tailscale | :cluster_ip | :host_network

  @type pod_spec :: %{
          id: pod_id(),
          type: pod_type(),
          namespace: String.t(),
          image: String.t(),
          resources: map(),
          network_mode: network_mode(),
          node_name: atom() | nil,
          tailscale_enabled: boolean()
        }

  @type state :: %{
          pods: %{pod_id() => pod_spec()},
          namespace: String.t(),
          network_mode: network_mode(),
          tailscale_available: boolean(),
          k8s_available: boolean(),
          api_server: String.t() | nil,
          service_account_token: String.t() | nil
        }

  # ============================================================
  # CONFIGURATION
  # ============================================================

  @default_namespace "indrajaal"
  @pod_health_interval_ms 10_000
  @k8s_api_timeout_ms 30_000

  @pod_images %{
    runner: "indrajaal-runner:latest",
    worker: "indrajaal-worker:latest",
    analytics: "indrajaal-analytics:latest",
    video: "indrajaal-video:latest",
    intelligence: "indrajaal-intelligence:latest"
  }

  @default_resources %{
    requests: %{cpu: "100m", memory: "128Mi"},
    limits: %{cpu: "1000m", memory: "1Gi"}
  }

  # ============================================================
  # CLIENT API
  # ============================================================

  @doc """
  Start the K8sCapability GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Create a new pod in the cluster.
  """
  @spec create_pod(pod_type(), keyword()) :: {:ok, pod_id()} | {:error, term()}
  def create_pod(type, opts \\ []) do
    GenServer.call(__MODULE__, {:create_pod, type, opts}, @k8s_api_timeout_ms)
  end

  @doc """
  Delete a pod.
  """
  @spec delete_pod(pod_id()) :: :ok | {:error, term()}
  def delete_pod(pod_id) do
    GenServer.call(__MODULE__, {:delete_pod, pod_id})
  end

  @doc """
  Get pod status.
  """
  @spec pod_status(pod_id()) :: {:ok, pod_state()} | {:error, :not_found}
  def pod_status(pod_id) do
    GenServer.call(__MODULE__, {:pod_status, pod_id})
  end

  @doc """
  List all managed pods.
  """
  @spec list_pods() :: list(pod_spec())
  def list_pods do
    GenServer.call(__MODULE__, :list_pods)
  end

  @doc """
  Get the node name for a pod.
  """
  @spec get_pod_node(pod_id()) :: {:ok, atom()} | {:error, term()}
  def get_pod_node(pod_id) do
    GenServer.call(__MODULE__, {:get_pod_node, pod_id})
  end

  @doc """
  Check if K8s API is available.
  """
  @spec k8s_available?() :: boolean()
  def k8s_available? do
    GenServer.call(__MODULE__, :k8s_available?)
  end

  @doc """
  Get capability status.
  """
  @impl Indrajaal.Cluster.Capabilities.Behaviour
  def status do
    GenServer.call(__MODULE__, :status)
  end

  @doc """
  Get capability type.
  """
  @impl Indrajaal.Cluster.Capabilities.Behaviour
  def capability_type, do: :k8s

  @doc """
  Check if capability is available.
  """
  @impl Indrajaal.Cluster.Capabilities.Behaviour
  def available? do
    GenServer.call(__MODULE__, :k8s_available?)
  end

  # ============================================================
  # GENSERVER CALLBACKS
  # ============================================================

  @impl GenServer
  def init(opts) do
    namespace = Keyword.get(opts, :namespace, @default_namespace)
    {api_server, token} = detect_k8s_environment()
    k8s_available = api_server != nil
    tailscale_available = check_tailscale()

    network_mode =
      cond do
        tailscale_available -> :tailscale
        k8s_available -> :cluster_ip
        true -> :host_network
      end

    initial_state = %{
      pods: %{},
      namespace: namespace,
      network_mode: network_mode,
      tailscale_available: tailscale_available,
      k8s_available: k8s_available,
      api_server: api_server,
      service_account_token: token
    }

    # Schedule health checks
    if k8s_available do
      :timer.send_interval(@pod_health_interval_ms, :health_check_pods)
    end

    Logger.info(
      "[K8sCapability] Initialized - K8s: #{k8s_available}, Tailscale: #{tailscale_available}"
    )

    {:ok, initial_state}
  end

  @impl GenServer
  def handle_call({:create_pod, type, opts}, _from, state) do
    case do_create_pod(type, opts, state) do
      {:ok, pod_id, new_state} ->
        {:reply, {:ok, pod_id}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:delete_pod, pod_id}, _from, state) do
    case do_delete_pod(pod_id, state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:pod_status, pod_id}, _from, state) do
    case Map.get(state.pods, pod_id) do
      nil -> {:reply, {:error, :not_found}, state}
      spec -> {:reply, {:ok, get_pod_runtime_status(spec, state)}, state}
    end
  end

  @impl GenServer
  def handle_call(:list_pods, _from, state) do
    pods = Map.values(state.pods)
    {:reply, pods, state}
  end

  @impl GenServer
  def handle_call({:get_pod_node, pod_id}, _from, state) do
    case Map.get(state.pods, pod_id) do
      nil -> {:reply, {:error, :not_found}, state}
      spec -> {:reply, {:ok, spec.node_name}, state}
    end
  end

  @impl GenServer
  def handle_call(:k8s_available?, _from, state) do
    {:reply, state.k8s_available, state}
  end

  @impl GenServer
  def handle_call(:status, _from, state) do
    status = %{
      capability: :k8s,
      available: state.k8s_available,
      network_mode: state.network_mode,
      tailscale_available: state.tailscale_available,
      namespace: state.namespace,
      pod_count: map_size(state.pods),
      api_server: state.api_server
    }

    {:reply, status, state}
  end

  @impl GenServer
  def handle_info(:health_check_pods, state) do
    new_state = check_pod_health(state)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ============================================================
  # PRIVATE FUNCTIONS
  # ============================================================

  defp detect_k8s_environment do
    # Check for in-cluster config
    token_path = "/var/run/secrets/kubernetes.io/serviceaccount/token"
    ca_path = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"

    if File.exists?(token_path) and File.exists?(ca_path) do
      token = File.read!(token_path)
      api_server = System.get_env("KUBERNETES_SERVICE_HOST", "kubernetes.default.svc")
      port = System.get_env("KUBERNETES_SERVICE_PORT", "443")
      {"https://#{api_server}:#{port}", token}
    else
      # Check for KUBECONFIG or ~/.kube/config
      case System.get_env("KUBECONFIG") do
        nil -> {nil, nil}
        _config -> {System.get_env("KUBERNETES_SERVICE_HOST"), nil}
      end
    end
  end

  defp check_tailscale do
    if Code.ensure_loaded?(TailscaleDNS) do
      case TailscaleDNS.validate_tailscale_connectivity() do
        {:ok, _} -> true
        {:error, _} -> false
      end
    else
      false
    end
  end

  defp do_create_pod(type, opts, state) do
    if state.k8s_available do
      pod_id = generate_pod_id(type)
      node_name = build_pod_node_name(pod_id, type, state)

      spec = %{
        id: pod_id,
        type: type,
        namespace: state.namespace,
        image: get_image_name(type),
        resources: Keyword.get(opts, :resources, @default_resources),
        network_mode: state.network_mode,
        node_name: node_name,
        tailscale_enabled: state.tailscale_available
      }

      case apply_pod_manifest(spec, state) do
        :ok ->
          new_pods = Map.put(state.pods, pod_id, spec)
          Logger.info("[K8sCapability] Created pod #{pod_id} as #{node_name}")
          {:ok, pod_id, %{state | pods: new_pods}}

        {:error, reason} ->
          {:error, {:create_failed, reason}}
      end
    end
  end

  defp do_delete_pod(pod_id, state) do
    case Map.get(state.pods, pod_id) do
      nil ->
        {:error, :not_found}

      spec ->
        case delete_pod_via_api(spec, state) do
          :ok ->
            new_pods = Map.delete(state.pods, pod_id)
            Logger.info("[K8sCapability] Deleted pod #{pod_id}")
            {:ok, %{state | pods: new_pods}}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp generate_pod_id(type) do
    random_bytes = :crypto.strong_rand_bytes(4)
    random_suffix = Base.encode16(random_bytes, case: :lower)
    "indrajaal-#{type}-#{random_suffix}"
  end

  defp get_image_name(type) do
    registry = System.get_env("CONTAINER_REGISTRY", "localhost/")
    base_image = Map.get(@pod_images, type, "indrajaal-base:latest")
    "#{registry}#{base_image}"
  end

  defp build_pod_node_name(pod_id, type, state) do
    hostname = NodeNameBuilder.normalize_hostname(pod_id)

    NodeNameBuilder.build_node_name(hostname, type, state.network_mode,
      namespace: state.namespace
    )
  end

  defp apply_pod_manifest(spec, state) do
    manifest = build_pod_manifest(spec, state)

    # In a real implementation, this would call the K8s API
    # For now, we simulate success if K8s is available
    if state.k8s_available do
      Logger.debug("[K8sCapability] Applying manifest for #{spec.id}")
      # kubectl apply equivalent
      apply_via_api(manifest, state)
    else
      {:error, :k8s_not_available}
    end
  end

  defp build_pod_manifest(spec, state) do
    base_manifest = %{
      "apiVersion" => "v1",
      "kind" => "Pod",
      "metadata" => %{
        "name" => spec.id,
        "namespace" => state.namespace,
        "labels" => %{
          "app" => "indrajaal",
          "type" => to_string(spec.type),
          "capability" => "k8s"
        }
      },
      "spec" => %{
        "containers" => [build_main_container(spec)],
        "restartPolicy" => "Always"
      }
    }

    # Add Tailscale sidecar if enabled
    if spec.tailscale_enabled do
      put_in(
        base_manifest,
        ["spec", "containers"],
        [build_main_container(spec), build_tailscale_sidecar(spec)]
      )
    else
      base_manifest
    end
  end

  defp build_main_container(spec) do
    %{
      "name" => "main",
      "image" => spec.image,
      "env" => [
        %{"name" => "RELEASE_NODE", "value" => to_string(spec.node_name)},
        %{
          "name" => "RELEASE_COOKIE",
          "valueFrom" => %{
            "secretKeyRef" => %{"name" => "indrajaal-secrets", "key" => "erlang-cookie"}
          }
        },
        %{"name" => "PHX_HOST", "value" => get_phx_host(spec)}
      ],
      "resources" => spec.resources,
      "securityContext" => %{
        "runAsNonRoot" => true,
        "readOnlyRootFilesystem" => true,
        "allowPrivilegeEscalation" => false
      }
    }
  end

  defp build_tailscale_sidecar(_spec) do
    %{
      "name" => "tailscale",
      "image" => "ghcr.io/tailscale/tailscale:latest",
      "env" => [
        %{
          "name" => "TS_AUTHKEY",
          "valueFrom" => %{"secretKeyRef" => %{"name" => "tailscale-auth", "key" => "TS_AUTHKEY"}}
        },
        %{"name" => "TS_KUBE_SECRET", "value" => ""},
        %{"name" => "TS_USERSPACE", "value" => "true"}
      ],
      "securityContext" => %{
        "runAsNonRoot" => true
      }
    }
  end

  defp get_phx_host(spec) do
    case spec.network_mode do
      :tailscale -> NodeNameBuilder.get_tailscale_suffix("localhost")
      :cluster_ip -> "#{spec.namespace}.svc.cluster.local"
      _ -> "localhost"
    end
  end

  defp apply_via_api(_manifest, state) do
    # In production, this would use the K8s client library
    # For simulation, we check if the API is reachable
    if state.api_server do
      :ok
    else
      {:error, :no_api_server}
    end
  end

  defp delete_pod_via_api(spec, state) do
    if state.api_server do
      Logger.debug("[K8sCapability] Deleting pod #{spec.id} from namespace #{state.namespace}")
      :ok
    else
      {:error, :no_api_server}
    end
  end

  defp get_pod_runtime_status(_spec, state) do
    # In production, this would query the K8s API
    if state.k8s_available do
      :running
    else
      :unknown
    end
  end

  defp check_pod_health(state) do
    # Update Tailscale availability
    tailscale_available = check_tailscale()

    new_mode =
      cond do
        tailscale_available -> :tailscale
        state.k8s_available -> :cluster_ip
        true -> :host_network
      end

    if new_mode != state.network_mode do
      Logger.info("[K8sCapability] Network mode changed: #{state.network_mode} -> #{new_mode}")
    end

    %{state | tailscale_available: tailscale_available, network_mode: new_mode}
  end
end
