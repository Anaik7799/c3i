defmodule Indrajaal.Cluster.StandaloneConfig do
  @moduledoc """
  P1.1: Comprehensive libcluster Configuration for Standalone Distributed Mode.

  WHAT: Complete configuration module for standalone distributed mode with
        Tailscale mesh networking, EPMD management, and node discovery.

  WHY: Provides a single source of truth for all cluster configuration
       required by standalone distributed deployments.

  CONSTRAINTS: Must satisfy SC-CLU-001 to SC-CLU-005 STAMP constraints.

  ## Architecture

  This module provides:
  1. **libcluster Topologies**: Full topology configuration for standalone mode
  2. **Erlang Distribution**: EPMD and distribution port configuration
  3. **Tailscale Integration**: MagicDNS and node naming configuration
  4. **Health Probes**: Cluster health monitoring configuration

  ## STAMP Compliance

  - SC-CLU-001: Name-based Erlang distribution (indrajaal@{ip/hostname})
  - SC-CLU-002: EPMD binding to 0.0.0.0:4369
  - SC-CLU-003: Distribution ports 9100-9105
  - SC-CLU-004: Cookie synchronization across nodes
  - SC-CLU-005: Tailscale MagicDNS integration

  ## Mathematical Invariants

      ∀ node ∈ Cluster: Cookie(node) = Cookie(master)
      ∀ node ∈ Cluster: EPMD(node) = 4369
      ∀ node ∈ Cluster: DistPort(node) ∈ [9100..9105]
      Connected(A, B) ⟺ Cookie(A) = Cookie(B) ∧ Accessible(A, B)
  """

  require Logger
  alias Indrajaal.Cluster.TailscaleDNS

  # ============================================================================
  # CONSTANTS (STAMP Constraints)
  # ============================================================================

  @epmd_port 4369
  @dist_port_min 9100
  @dist_port_max 9105
  @default_polling_interval 5_000
  @health_check_interval 10_000
  @connection_timeout 10_000

  # ============================================================================
  # TYPE SPECIFICATIONS
  # ============================================================================

  @type network_mode :: :tailscale | :local | :hybrid
  @type topology_config :: keyword()
  @type node_spec :: {atom(), String.t()}

  # ============================================================================
  # TOPOLOGY CONFIGURATION
  # ============================================================================

  @doc """
  Generate libcluster topology configuration for standalone mode.

  Options:
  - `:hosts` - List of host names to connect to
  - `:prefer_tailscale` - Whether to prefer Tailscale for discovery (default: true)
  - `:polling_interval` - Node polling interval in ms (default: 5000)
  - `:connection_timeout` - Connection timeout in ms (default: 10_000)

  ## Examples

      iex> StandaloneConfig.topology_config(hosts: ["app-1", "app-2"])
      [standalone: [strategy: Indrajaal.Cluster.Strategies.Standalone, ...]]
  """
  @spec topology_config(keyword()) :: keyword()
  def topology_config(opts \\ []) do
    hosts = Keyword.get(opts, :hosts, [])
    prefer_tailscale = Keyword.get(opts, :prefer_tailscale, true)
    polling_interval = Keyword.get(opts, :polling_interval, @default_polling_interval)
    connection_timeout = Keyword.get(opts, :connection_timeout, @connection_timeout)

    [
      standalone: [
        strategy: Indrajaal.Cluster.Strategies.Standalone,
        config: [
          hosts: hosts,
          prefer_tailscale: prefer_tailscale,
          polling_interval: polling_interval,
          connection_timeout: connection_timeout
        ]
      ]
    ]
  end

  @doc """
  Generate Kubernetes DNS topology for K8s deployments.

  Options:
  - `:service` - Kubernetes service name (default: "indrajaal")
  - `:namespace` - Kubernetes namespace (default: "default")
  - `:application_name` - Erlang application name (default: :indrajaal)
  - `:polling_interval` - Polling interval in ms (default: 5000)
  """
  @spec kubernetes_topology(keyword()) :: keyword()
  def kubernetes_topology(opts \\ []) do
    service = Keyword.get(opts, :service, "indrajaal")
    namespace = Keyword.get(opts, :namespace, "default")
    app_name = Keyword.get(opts, :application_name, :indrajaal)
    polling_interval = Keyword.get(opts, :polling_interval, @default_polling_interval)

    [
      kubernetes: [
        strategy: Cluster.Strategy.Kubernetes.DNS,
        config: [
          service: service,
          application_name: app_name,
          namespace: namespace,
          polling_interval: polling_interval
        ]
      ]
    ]
  end

  # ============================================================================
  # ERLANG DISTRIBUTION CONFIGURATION
  # ============================================================================

  @doc """
  Get Erlang distribution configuration.

  Returns configuration compatible with kernel application settings.

  ## STAMP Compliance
  - SC-CLU-002: EPMD port 4369
  - SC-CLU-003: Distribution ports 9100-9105
  """
  @spec erlang_dist_config() :: keyword()
  def erlang_dist_config do
    [
      inet_dist_listen_min: @dist_port_min,
      inet_dist_listen_max: @dist_port_max
    ]
  end

  @doc """
  Get ERL_AFLAGS for starting Erlang with distribution.
  """
  @spec erl_aflags() :: String.t()
  def erl_aflags do
    "-kernel inet_dist_listen_min #{@dist_port_min} inet_dist_listen_max #{@dist_port_max}"
  end

  @doc """
  Configure Erlang distribution at runtime.

  Must be called before node distribution is started.
  """
  @spec configure_distribution!() :: :ok
  def configure_distribution! do
    Application.put_env(:kernel, :inet_dist_listen_min, @dist_port_min)
    Application.put_env(:kernel, :inet_dist_listen_max, @dist_port_max)

    Logger.info(
      "[StandaloneConfig] Distribution configured: ports #{@dist_port_min}-#{@dist_port_max}"
    )

    :ok
  end

  # ============================================================================
  # NODE NAME GENERATION
  # ============================================================================

  @doc """
  Generate node name based on network mode.

  Options:
  - `:name` - Base node name (default: "indrajaal")
  - `:network_mode` - :tailscale, :local, or :hybrid (default: :hybrid)

  ## STAMP Compliance
  - SC-CLU-001: Name-based distribution
  - SC-CLU-005: Tailscale MagicDNS
  """
  @spec generate_node_name(keyword()) :: atom()
  def generate_node_name(opts \\ []) do
    name = Keyword.get(opts, :name, "indrajaal")
    mode = Keyword.get(opts, :network_mode, detect_network_mode())

    host = get_host_for_mode(mode)
    :"#{name}@#{host}"
  end

  @doc """
  Detect the current network mode.

  Returns:
  - `:tailscale` - Tailscale is available and preferred
  - `:local` - Local network only
  - `:hybrid` - Can use either
  """
  @spec detect_network_mode() :: network_mode()
  def detect_network_mode do
    cond do
      tailscale_available?() and prefer_tailscale?() -> :tailscale
      tailscale_available?() -> :hybrid
      true -> :local
    end
  end

  defp tailscale_available? do
    if Code.ensure_loaded?(TailscaleDNS) do
      case TailscaleDNS.validate_tailscale_connectivity() do
        {:ok, _} -> true
        {:error, _} -> false
      end
    else
      false
    end
  end

  defp prefer_tailscale? do
    Application.get_env(:indrajaal, :prefer_tailscale, true)
  end

  defp get_host_for_mode(:tailscale) do
    case get_tailscale_ip() do
      {:ok, ip} -> ip
      {:error, _} -> get_local_ip()
    end
  end

  defp get_host_for_mode(:local) do
    get_local_ip()
  end

  defp get_host_for_mode(:hybrid) do
    case get_tailscale_ip() do
      {:ok, ip} -> ip
      {:error, _} -> get_local_ip()
    end
  end

  defp get_tailscale_ip do
    if Code.ensure_loaded?(TailscaleDNS) do
      TailscaleDNS.get_tailscale_ip()
    else
      {:error, :tailscale_dns_not_loaded}
    end
  end

  defp get_local_ip do
    case :inet.getif() do
      {:ok, ifs} ->
        ifs
        |> Enum.map(fn {ip, _broadaddr, _mask} -> ip end)
        |> Enum.find(&(&1 != {127, 0, 0, 1}))
        |> case do
          nil ->
            "127.0.0.1"

          ip ->
            ip_charlist = :inet.ntoa(ip)
            to_string(ip_charlist)
        end

      {:error, _} ->
        "127.0.0.1"
    end
  end

  # ============================================================================
  # COOKIE MANAGEMENT
  # ============================================================================

  @doc """
  Get or generate the Erlang cookie for the cluster.

  Cookie sources (in order of precedence):
  1. RELEASE_COOKIE environment variable
  2. ~/.erlang.cookie file
  3. Generated secure cookie (saved to file)

  ## STAMP Compliance
  - SC-CLU-004: Cookie synchronization
  """
  @spec get_cookie() :: String.t()
  def get_cookie do
    case System.get_env("RELEASE_COOKIE") do
      nil ->
        cookie_file = Path.join(System.user_home!(), ".erlang.cookie")

        if File.exists?(cookie_file) do
          cookie_content = File.read!(cookie_file)
          String.trim(cookie_content)
        else
          cookie = generate_secure_cookie()
          File.write!(cookie_file, cookie)
          File.chmod!(cookie_file, 0o400)
          cookie
        end

      cookie ->
        cookie
    end
  end

  @doc """
  Set the cookie for the current node.
  """
  @spec set_cookie!(String.t()) :: :ok
  def set_cookie!(cookie) when is_binary(cookie) do
    Node.set_cookie(String.to_atom(cookie))
    :ok
  end

  defp generate_secure_cookie do
    random_bytes = :crypto.strong_rand_bytes(32)

    random_bytes
    |> Base.encode64()
    |> String.replace(~r/[\/+=]/, "")
    |> String.slice(0, 20)
  end

  # ============================================================================
  # HEALTH MONITORING
  # ============================================================================

  @doc """
  Get cluster health status.

  Returns a map with:
  - `:healthy` - Boolean indicating overall health
  - `:nodes` - List of connected nodes
  - `:node_count` - Number of connected nodes
  - `:network_mode` - Current network mode
  - `:epmd_running` - EPMD status
  """
  @spec health_status() :: map()
  def health_status do
    nodes = Node.list()

    %{
      healthy: length(nodes) > 0 or Node.alive?(),
      nodes: nodes,
      node_count: length(nodes),
      network_mode: detect_network_mode(),
      epmd_running: check_epmd_running(),
      self: Node.self(),
      cookie_set: Node.get_cookie() != :nocookie
    }
  end

  defp check_epmd_running do
    case System.cmd("epmd", ["-names"], stderr_to_stdout: true) do
      {output, 0} -> String.contains?(output, "up and running")
      _ -> false
    end
  rescue
    _ -> false
  end

  # ============================================================================
  # RUNTIME CONFIGURATION
  # ============================================================================

  @doc """
  Apply full standalone configuration at runtime.

  This should be called during application startup to configure
  all cluster settings.

  Options:
  - `:hosts` - List of hosts to connect to
  - `:start_distribution` - Whether to start distribution (default: true)
  """
  @spec apply_config!(keyword()) :: :ok
  def apply_config!(opts \\ []) do
    # Configure distribution ports
    configure_distribution!()

    # Set cookie
    cookie = get_cookie()
    set_cookie!(cookie)

    # Start libcluster if enabled
    if Keyword.get(opts, :start_libcluster, true) do
      start_libcluster(opts)
    end

    Logger.info("[StandaloneConfig] Standalone cluster configuration applied")
    :ok
  end

  defp start_libcluster(opts) do
    hosts = Keyword.get(opts, :hosts, [])
    topologies = topology_config(hosts: hosts)

    case Supervisor.start_child(Indrajaal.Supervisor, {Cluster.Supervisor, [topologies]}) do
      {:ok, _pid} ->
        Logger.info("[StandaloneConfig] libcluster started with #{length(hosts)} hosts")

      {:error, {:already_started, _pid}} ->
        Logger.debug("[StandaloneConfig] libcluster already running")

      {:error, reason} ->
        Logger.error("[StandaloneConfig] Failed to start libcluster: #{inspect(reason)}")
    end
  end

  # ============================================================================
  # PORT ACCESSORS
  # ============================================================================

  @doc "Get EPMD port (SC-CLU-002)"
  @spec epmd_port() :: non_neg_integer()
  def epmd_port, do: @epmd_port

  @doc "Get minimum distribution port (SC-CLU-003)"
  @spec dist_port_min() :: non_neg_integer()
  def dist_port_min, do: @dist_port_min

  @doc "Get maximum distribution port (SC-CLU-003)"
  @spec dist_port_max() :: non_neg_integer()
  def dist_port_max, do: @dist_port_max

  @doc "Get list of all distribution ports"
  @spec dist_ports() :: [non_neg_integer()]
  def dist_ports, do: Enum.to_list(@dist_port_min..@dist_port_max)

  @doc "Get health check interval"
  @spec health_check_interval() :: non_neg_integer()
  def health_check_interval, do: @health_check_interval
end
