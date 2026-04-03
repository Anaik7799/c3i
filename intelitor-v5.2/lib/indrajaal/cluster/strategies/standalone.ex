defmodule Indrajaal.Cluster.Strategies.Standalone do
  @moduledoc """
  libcluster Strategy for Standalone Environments with Tailscale Mesh.

  WHAT: Custom libcluster strategy that uses Tailscale for node discovery with local fallback.
  WHY: SC-CLU-001 requires identity-based networking; SC-CLU-004 requires graceful degradation.
  CONSTRAINTS: Must use Tailscale names when available, fall back to local names otherwise.

  ## Architecture

  This strategy provides:
  1. **Tailscale Node Discovery**: Uses Tailscale DNS for node resolution
  2. **Local Fallback**: Falls back to local naming when Tailscale is unavailable
  3. **Hybrid Mode**: Can operate in mixed Tailscale/local environments
  4. **Health Monitoring**: Periodically checks Tailscale connectivity

  ## STAMP Constraints
  - SC-CLU-001: Identity-based networking (Tailscale MagicDNS)
  - SC-CLU-002: Minimum 3 nodes for HA
  - SC-CLU-004: Graceful degradation (local fallback)
  - SC-CLU-005: Split-brain prevention via consistent naming

  ## Configuration

      config :libcluster,
        topologies: [
          standalone: [
            strategy: Indrajaal.Cluster.Strategies.Standalone,
            config: [
              hosts: ["app-1", "app-2", "app-3"],
              polling_interval: 5_000,
              prefer_tailscale: true,
              connection_timeout: 10_000
            ]
          ]
        ]
  """

  use Cluster.Strategy
  use GenServer
  require Logger

  alias Cluster.Strategy.State
  alias Indrajaal.Cluster.TailscaleDNS

  # ============================================================
  # TYPE DEFINITIONS
  # ============================================================

  @type network_mode :: :tailscale | :local | :hybrid
  @type host_config :: String.t() | {String.t(), network_mode()}

  # ============================================================
  # CONFIGURATION
  # ============================================================

  @default_polling_interval 5_000
  @default_connection_timeout 10_000
  @tailscale_check_interval 30_000

  # ============================================================
  # CALLBACKS
  # ============================================================

  @impl Cluster.Strategy
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl GenServer
  def init([%State{} = state]) do
    {:ok, state, {:continue, :initial_connect}}
  end

  @impl GenServer
  def handle_continue(:initial_connect, state) do
    # Check Tailscale status
    tailscale_available = check_tailscale_available()
    Logger.info("[Standalone] Initializing - Tailscale: #{tailscale_available}")

    # Ensure meta is a map before updating (may be nil initially)
    current_meta = state.meta || %{}

    # Store network mode in state meta
    meta_with_ts = Map.put(current_meta, :tailscale_available, tailscale_available)

    new_meta =
      meta_with_ts
      |> Map.put(:network_mode, if(tailscale_available, do: :tailscale, else: :local))

    new_state = %{state | meta: new_meta}

    # Initial connection attempt
    {:noreply, connect_to_peers(new_state)}
  end

  @impl GenServer
  def handle_info(:poll, state) do
    {:noreply, poll_and_connect(state)}
  end

  @impl GenServer
  def handle_info(:check_tailscale, state) do
    tailscale_available = check_tailscale_available()
    current_available = Map.get(state.meta, :tailscale_available, false)

    new_meta =
      if tailscale_available != current_available do
        Logger.info(
          "[Standalone] Network mode changed: #{if(current_available, do: :tailscale, else: :local)} -> #{if(tailscale_available, do: :tailscale, else: :local)} - SC-CLU-004"
        )

        meta_with_ts = Map.put(state.meta, :tailscale_available, tailscale_available)

        meta_with_ts
        |> Map.put(:network_mode, if(tailscale_available, do: :tailscale, else: :local))
      else
        state.meta
      end

    schedule_tailscale_check()
    {:noreply, %{state | meta: new_meta}}
  end

  @impl GenServer
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(msg, state) do
    Logger.debug("[Standalone] Unhandled message: #{inspect(msg)}")
    {:noreply, state}
  end

  # ============================================================
  # PRIVATE FUNCTIONS
  # ============================================================

  defp connect_to_peers(state) do
    hosts = get_hosts(state)
    network_mode = Map.get(state.meta, :network_mode, :local)

    nodes =
      hosts
      |> Enum.map(&resolve_host(&1, network_mode))
      |> Enum.reject(&(&1 == node()))

    Logger.debug("[Standalone] Attempting to connect to nodes: #{inspect(nodes)}")

    connected =
      nodes
      |> Enum.reduce([], fn target_node, acc ->
        case connect_node(target_node, state) do
          :ok ->
            Logger.info("[Standalone] Connected to #{target_node}")
            [target_node | acc]

          {:error, reason} ->
            Logger.debug("[Standalone] Failed to connect to #{target_node}: #{inspect(reason)}")
            acc
        end
      end)

    # Report topology changes
    if length(connected) > 0 do
      Cluster.Strategy.connect_nodes(state.topology, state.connect, state.list_nodes, connected)
    end

    schedule_poll(state)
    schedule_tailscale_check()

    state
  end

  defp poll_and_connect(state) do
    hosts = get_hosts(state)
    network_mode = Map.get(state.meta, :network_mode, :local)

    current_nodes = MapSet.new(Node.list())

    target_nodes =
      hosts
      |> Enum.map(&resolve_host(&1, network_mode))
      |> Enum.reject(&(&1 == node()))
      |> MapSet.new()

    # Find nodes to connect and disconnect
    to_connect_set = MapSet.difference(target_nodes, current_nodes)
    to_connect = to_connect_set |> MapSet.to_list()
    to_disconnect_set = MapSet.difference(current_nodes, target_nodes)
    to_disconnect = to_disconnect_set |> MapSet.to_list()

    # Connect new nodes
    Enum.each(to_connect, fn target_node ->
      case connect_node(target_node, state) do
        :ok ->
          Logger.info("[Standalone] Connected to #{target_node}")

          Cluster.Strategy.connect_nodes(state.topology, state.connect, state.list_nodes, [
            target_node
          ])

        {:error, reason} ->
          Logger.debug("[Standalone] Failed to connect to #{target_node}: #{inspect(reason)}")
      end
    end)

    # Disconnect removed nodes
    Enum.each(to_disconnect, fn target_node ->
      Logger.info("[Standalone] Disconnecting from #{target_node}")

      Cluster.Strategy.disconnect_nodes(state.topology, state.disconnect, state.list_nodes, [
        target_node
      ])
    end)

    schedule_poll(state)
    state
  end

  defp get_hosts(state) do
    Keyword.get(state.config, :hosts, [])
  end

  defp resolve_host(host, network_mode) when is_binary(host) do
    case network_mode do
      :tailscale ->
        if Code.ensure_loaded?(TailscaleDNS) do
          TailscaleDNS.get_node_name(host)
        else
          build_local_node_name(host)
        end

      :local ->
        build_local_node_name(host)

      :hybrid ->
        # Try Tailscale first, fall back to local
        if Code.ensure_loaded?(TailscaleDNS) and TailscaleDNS.tailscale_available?() do
          TailscaleDNS.get_node_name(host)
        else
          build_local_node_name(host)
        end
    end
  end

  defp resolve_host({host, mode}, _default_mode) when is_binary(host) do
    resolve_host(host, mode)
  end

  defp build_local_node_name(host) do
    sanitized =
      host
      |> String.downcase()
      |> String.replace("_", "-")
      |> String.replace(~r/[^a-z0-9\-.]/, "")

    # SC-NAME-001: Use container hostname directly, no suffix
    # Nodes are started with --name indrajaal@<container-hostname>
    :"indrajaal@#{sanitized}"
  end

  defp connect_node(target_node, state) do
    _timeout = Keyword.get(state.config, :connection_timeout, @default_connection_timeout)

    case Node.connect(target_node) do
      true ->
        :ok

      false ->
        {:error, :connect_failed}

      :ignored ->
        {:error, :node_not_alive}
    end
  rescue
    e -> {:error, {:exception, e}}
  end

  defp check_tailscale_available do
    if Code.ensure_loaded?(TailscaleDNS) do
      case TailscaleDNS.validate_tailscale_connectivity() do
        {:ok, _} -> true
        {:error, _} -> false
      end
    else
      false
    end
  end

  defp schedule_poll(state) do
    interval = Keyword.get(state.config, :polling_interval, @default_polling_interval)
    Process.send_after(self(), :poll, interval)
  end

  defp schedule_tailscale_check do
    Process.send_after(self(), :check_tailscale, @tailscale_check_interval)
  end
end
