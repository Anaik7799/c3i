defmodule Indrajaal.Cluster.Capabilities.ProxmoxCapability do
  @moduledoc """
  Proxmox VE Capability Backend for VM-based Mesh Networking.

  WHAT: Manages Proxmox VMs as compute nodes with Tailscale mesh integration.
  WHY: SC-CLU-001 requires identity networking; VMs provide strongest isolation.
  CONSTRAINTS: Must use Tailscale for inter-VM mesh; fallback to bridge when unavailable.

  ## Architecture

  This module provides:
  1. **VM Lifecycle**: Create/start/stop/delete VMs via Proxmox API
  2. **Tailscale Integration**: VMs auto-join Tailscale mesh on boot
  3. **Cloud-Init**: VM configuration via cloud-init for node naming
  4. **FLAME Backend**: Heavy compute tasks (video processing, ML inference)

  ## STAMP Constraints
  - SC-CLU-001: Identity-based networking (Tailscale in VM)
  - SC-CLU-003: VM-level isolation for security-critical workloads
  - SC-CLU-004: Graceful degradation (bridge networking fallback)
  - SC-PVE-001: API token authentication only

  ## VM Naming Convention
  - Tailscale: `{type}@vm-{vmid}.{tailnet}.ts.net`
  - Bridge: `{type}@vm-{vmid}.pve.local`
  """

  use GenServer
  require Logger

  alias Indrajaal.Cluster.TailscaleDNS
  alias Indrajaal.Cluster.Capabilities.NodeNameBuilder

  @behaviour Indrajaal.Cluster.Capabilities.Behaviour

  # ============================================================
  # TYPE DEFINITIONS
  # ============================================================

  @type vm_type :: :compute | :inference | :video | :analytics | :storage
  @type vmid :: pos_integer()
  @type vm_state :: :stopped | :running | :paused | :unknown
  @type network_mode :: :tailscale | :bridge | :vlan

  @type vm_spec :: %{
          vmid: vmid(),
          type: vm_type(),
          name: String.t(),
          node: String.t(),
          cores: pos_integer(),
          memory: pos_integer(),
          disk: pos_integer(),
          network_mode: network_mode(),
          node_name: atom() | nil,
          tailscale_enabled: boolean(),
          cloud_init: map()
        }

  @type state :: %{
          vms: %{vmid() => vm_spec()},
          network_mode: network_mode(),
          tailscale_available: boolean(),
          pve_available: boolean(),
          api_url: String.t() | nil,
          api_token: String.t() | nil,
          default_node: String.t(),
          vmid_range: {pos_integer(), pos_integer()}
        }

  # ============================================================
  # CONFIGURATION
  # ============================================================

  @default_pve_node "pve"
  @vmid_range_start 1000
  @vmid_range_end 1999
  @vm_health_interval_ms 30_000
  @pve_api_timeout_ms 60_000

  @vm_templates %{
    compute: %{cores: 4, memory: 8192, disk: 50},
    inference: %{cores: 8, memory: 32_768, disk: 100},
    video: %{cores: 4, memory: 16_384, disk: 200},
    analytics: %{cores: 2, memory: 4096, disk: 50},
    storage: %{cores: 2, memory: 4096, disk: 500}
  }

  @base_image "local:vztmpl/indrajaal-base.tar.zst"

  # ============================================================
  # CLIENT API
  # ============================================================

  @doc """
  Start the ProxmoxCapability GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Create a new VM in Proxmox.
  """
  @spec create_vm(vm_type(), keyword()) :: {:ok, vmid()} | {:error, term()}
  def create_vm(type, opts \\ []) do
    GenServer.call(__MODULE__, {:create_vm, type, opts}, @pve_api_timeout_ms)
  end

  @doc """
  Start a VM.
  """
  @spec start_vm(vmid()) :: :ok | {:error, term()}
  def start_vm(vmid) do
    GenServer.call(__MODULE__, {:start_vm, vmid})
  end

  @doc """
  Stop a VM.
  """
  @spec stop_vm(vmid()) :: :ok | {:error, term()}
  def stop_vm(vmid) do
    GenServer.call(__MODULE__, {:stop_vm, vmid})
  end

  @doc """
  Delete a VM.
  """
  @spec delete_vm(vmid()) :: :ok | {:error, term()}
  def delete_vm(vmid) do
    GenServer.call(__MODULE__, {:delete_vm, vmid})
  end

  @doc """
  Get VM status.
  """
  @spec vm_status(vmid()) :: {:ok, vm_state()} | {:error, :not_found}
  def vm_status(vmid) do
    GenServer.call(__MODULE__, {:vm_status, vmid})
  end

  @doc """
  List all managed VMs.
  """
  @spec list_vms() :: list(vm_spec())
  def list_vms do
    GenServer.call(__MODULE__, :list_vms)
  end

  @doc """
  Get the node name for a VM.
  """
  @spec get_vm_node(vmid()) :: {:ok, atom()} | {:error, term()}
  def get_vm_node(vmid) do
    GenServer.call(__MODULE__, {:get_vm_node, vmid})
  end

  @doc """
  Check if Proxmox API is available.
  """
  @spec pve_available?() :: boolean()
  def pve_available? do
    GenServer.call(__MODULE__, :pve_available?)
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
  def capability_type, do: :proxmox

  @doc """
  Check if capability is available.
  """
  @impl Indrajaal.Cluster.Capabilities.Behaviour
  def available? do
    GenServer.call(__MODULE__, :pve_available?)
  end

  # ============================================================
  # GENSERVER CALLBACKS
  # ============================================================

  @impl GenServer
  def init(opts) do
    api_url = Keyword.get(opts, :api_url, System.get_env("PVE_API_URL"))
    api_token = Keyword.get(opts, :api_token, System.get_env("PVE_API_TOKEN"))
    default_node = Keyword.get(opts, :node, @default_pve_node)

    pve_available = api_url != nil and api_token != nil
    tailscale_available = check_tailscale()

    network_mode =
      cond do
        tailscale_available -> :tailscale
        pve_available -> :bridge
        true -> :bridge
      end

    initial_state = %{
      vms: %{},
      network_mode: network_mode,
      tailscale_available: tailscale_available,
      pve_available: pve_available,
      api_url: api_url,
      api_token: api_token,
      default_node: default_node,
      vmid_range: {@vmid_range_start, @vmid_range_end}
    }

    # Schedule health checks if PVE is available
    if pve_available do
      :timer.send_interval(@vm_health_interval_ms, :health_check_vms)
    end

    Logger.info(
      "[ProxmoxCapability] Initialized - PVE: #{pve_available}, Tailscale: #{tailscale_available}"
    )

    {:ok, initial_state}
  end

  @impl GenServer
  def handle_call({:create_vm, type, opts}, _from, state) do
    case do_create_vm(type, opts, state) do
      {:ok, vmid, new_state} ->
        {:reply, {:ok, vmid}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:start_vm, vmid}, _from, state) do
    case do_start_vm(vmid, state) do
      :ok -> {:reply, :ok, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:stop_vm, vmid}, _from, state) do
    case do_stop_vm(vmid, state) do
      :ok -> {:reply, :ok, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:delete_vm, vmid}, _from, state) do
    case do_delete_vm(vmid, state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:vm_status, vmid}, _from, state) do
    case Map.get(state.vms, vmid) do
      nil -> {:reply, {:error, :not_found}, state}
      spec -> {:reply, {:ok, get_vm_runtime_status(spec, state)}, state}
    end
  end

  @impl GenServer
  def handle_call(:list_vms, _from, state) do
    vms = Map.values(state.vms)
    {:reply, vms, state}
  end

  @impl GenServer
  def handle_call({:get_vm_node, vmid}, _from, state) do
    case Map.get(state.vms, vmid) do
      nil -> {:reply, {:error, :not_found}, state}
      spec -> {:reply, {:ok, spec.node_name}, state}
    end
  end

  @impl GenServer
  def handle_call(:pve_available?, _from, state) do
    {:reply, state.pve_available, state}
  end

  @impl GenServer
  def handle_call(:status, _from, state) do
    status = %{
      capability: :proxmox,
      available: state.pve_available,
      network_mode: state.network_mode,
      tailscale_available: state.tailscale_available,
      vm_count: map_size(state.vms),
      api_url: state.api_url,
      default_node: state.default_node
    }

    {:reply, status, state}
  end

  @impl GenServer
  def handle_info(:health_check_vms, state) do
    new_state = check_vm_health(state)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ============================================================
  # PRIVATE FUNCTIONS
  # ============================================================

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

  defp do_create_vm(type, opts, state) do
    if state.pve_available do
      vmid = allocate_vmid(state)
      name = "indrajaal-#{type}-#{vmid}"
      node_name = build_vm_node_name(vmid, type, state)
      template = Map.get(@vm_templates, type, @vm_templates.compute)

      spec = %{
        vmid: vmid,
        type: type,
        name: name,
        node: state.default_node,
        cores: Keyword.get(opts, :cores, template.cores),
        memory: Keyword.get(opts, :memory, template.memory),
        disk: Keyword.get(opts, :disk, template.disk),
        network_mode: state.network_mode,
        node_name: node_name,
        tailscale_enabled: state.tailscale_available,
        cloud_init: build_cloud_init(node_name, opts, state)
      }

      case create_vm_via_api(spec, state) do
        :ok ->
          new_vms = Map.put(state.vms, vmid, spec)
          Logger.info("[ProxmoxCapability] Created VM #{vmid} (#{name}) as #{node_name}")
          {:ok, vmid, %{state | vms: new_vms}}

        {:error, reason} ->
          {:error, {:create_failed, reason}}
      end
    end
  end

  defp do_start_vm(vmid, state) do
    case Map.get(state.vms, vmid) do
      nil ->
        {:error, :not_found}

      spec ->
        start_vm_via_api(spec, state)
    end
  end

  defp do_stop_vm(vmid, state) do
    case Map.get(state.vms, vmid) do
      nil ->
        {:error, :not_found}

      spec ->
        stop_vm_via_api(spec, state)
    end
  end

  defp do_delete_vm(vmid, state) do
    case Map.get(state.vms, vmid) do
      nil ->
        {:error, :not_found}

      spec ->
        # Stop first, then delete
        _ = stop_vm_via_api(spec, state)

        case delete_vm_via_api(spec, state) do
          :ok ->
            new_vms = Map.delete(state.vms, vmid)
            Logger.info("[ProxmoxCapability] Deleted VM #{vmid}")
            {:ok, %{state | vms: new_vms}}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp allocate_vmid(state) do
    {start_id, end_id} = state.vmid_range
    vm_keys = Map.keys(state.vms)
    existing_ids = MapSet.new(vm_keys)

    Enum.find(start_id..end_id, fn id ->
      not MapSet.member?(existing_ids, id)
    end)
  end

  defp build_vm_node_name(vmid, type, state) do
    hostname = NodeNameBuilder.build_vm_hostname(vmid)
    NodeNameBuilder.build_node_name(hostname, type, state.network_mode, local_suffix: "pve.local")
  end

  defp build_cloud_init(node_name, opts, state) do
    tailscale_authkey = Keyword.get(opts, :tailscale_authkey, System.get_env("TS_AUTHKEY"))

    node_string = to_string(node_name)
    hostname = node_string |> String.split("@") |> List.last() |> String.split(".") |> hd()

    base_config = %{
      "hostname" => hostname,
      "manage_etc_hosts" => true,
      "packages" => ["tailscale", "erlang", "elixir"],
      "runcmd" => build_runcmd(node_name, tailscale_authkey, state)
    }

    # Add user data
    user_data = Keyword.get(opts, :user_data, %{})
    Map.merge(base_config, user_data)
  end

  defp build_runcmd(node_name, tailscale_authkey, state) do
    base_cmds = [
      "systemctl enable tailscaled",
      "systemctl start tailscaled"
    ]

    tailscale_cmds =
      if state.tailscale_available and tailscale_authkey do
        [
          "tailscale up --authkey=#{tailscale_authkey} --hostname=#{extract_hostname(node_name)}"
        ]
      else
        []
      end

    app_cmds = [
      "export RELEASE_NODE=#{node_name}",
      "export RELEASE_COOKIE=$(cat /etc/indrajaal/cookie)",
      "/opt/indrajaal/bin/indrajaal start"
    ]

    base_cmds ++ tailscale_cmds ++ app_cmds
  end

  defp extract_hostname(node_name) do
    node_name
    |> to_string()
    |> String.split("@")
    |> List.last()
    |> String.split(".")
    |> hd()
  end

  defp create_vm_via_api(spec, state) do
    # Build Proxmox API request
    params = %{
      vmid: spec.vmid,
      name: spec.name,
      cores: spec.cores,
      memory: spec.memory,
      ostemplate: @base_image,
      storage: "local-lvm",
      rootfs: "local-lvm:#{spec.disk}",
      net0: build_network_config(spec, state),
      start: 0
    }

    case call_pve_api(:post, "/nodes/#{spec.node}/lxc", params, state) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp start_vm_via_api(spec, state) do
    case call_pve_api(:post, "/nodes/#{spec.node}/lxc/#{spec.vmid}/status/start", %{}, state) do
      {:ok, _} ->
        Logger.info("[ProxmoxCapability] Started VM #{spec.vmid}")
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp stop_vm_via_api(spec, state) do
    case call_pve_api(:post, "/nodes/#{spec.node}/lxc/#{spec.vmid}/status/stop", %{}, state) do
      {:ok, _} ->
        Logger.info("[ProxmoxCapability] Stopped VM #{spec.vmid}")
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp delete_vm_via_api(spec, state) do
    case call_pve_api(:delete, "/nodes/#{spec.node}/lxc/#{spec.vmid}", %{}, state) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_network_config(spec, _state) do
    case spec.network_mode do
      :tailscale -> "name=eth0,bridge=vmbr0,ip=dhcp"
      :vlan -> "name=eth0,bridge=vmbr1,tag=100,ip=dhcp"
      _ -> "name=eth0,bridge=vmbr0,ip=dhcp"
    end
  end

  defp call_pve_api(method, path, params, state) do
    if state.pve_available do
      url = "#{state.api_url}/api2/json#{path}"
      _headers = [{"Authorization", "PVEAPIToken=#{state.api_token}"}]

      # In production, this would use HTTPoison or Req
      # For now, simulate based on availability
      Logger.debug("[ProxmoxCapability] API #{method} #{url} #{inspect(params)}")

      if state.api_url do
        {:ok, %{}}
      else
        {:error, :no_api_url}
      end
    else
      {:error, :pve_not_available}
    end
  end

  defp get_vm_runtime_status(_spec, state) do
    if state.pve_available do
      :running
    else
      :unknown
    end
  end

  defp check_vm_health(state) do
    tailscale_available = check_tailscale()

    new_mode =
      cond do
        tailscale_available -> :tailscale
        state.pve_available -> :bridge
        true -> :bridge
      end

    if new_mode != state.network_mode do
      Logger.info(
        "[ProxmoxCapability] Network mode changed: #{state.network_mode} -> #{new_mode}"
      )
    end

    %{state | tailscale_available: tailscale_available, network_mode: new_mode}
  end
end
