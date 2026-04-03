defmodule Indrajaal.Cluster.Capabilities.NodeNameBuilder do
  @moduledoc """
  Shared Node Name Builder for Cluster Capability Backends.

  WHAT: Provides unified node name construction for K8s, Container, and Proxmox capabilities.
  WHY: SC-CLU-001 requires consistent identity-based networking across all backends.
  CONSTRAINTS: Must handle Tailscale, ClusterIP, bridge, and local network modes.

  ## Architecture

  This module eliminates duplicate code across capability backends by providing:
  1. **Unified Node Name Construction**: Single function for all backends
  2. **Tailscale Integration**: Consistent suffix handling
  3. **Fallback Handling**: Graceful degradation when Tailscale unavailable

  ## STAMP Constraints
  - SC-CLU-001: Identity-based networking (consistent naming across backends)
  - SC-DRY-001: No duplicate code in capability backends

  ## Node Naming Patterns
  - Tailscale: `{type}@{hostname}.{tailnet}.ts.net`
  - ClusterIP (K8s): `{type}@{hostname}.{namespace}.svc.cluster.local`
  - Local (Container): `{type}@{hostname}.local.indrajaal`
  - Bridge (Proxmox): `{type}@{hostname}.pve.local`
  """

  alias Indrajaal.Cluster.TailscaleDNS

  @type network_mode :: :tailscale | :cluster_ip | :local | :bridge | :host_network | :vlan
  @type build_opts :: [
          namespace: String.t(),
          local_suffix: String.t()
        ]

  # ============================================================
  # PUBLIC API
  # ============================================================

  @doc """
  Build a node name for any capability backend.

  ## Parameters
  - `hostname` - The base hostname (e.g., "indrajaal_worker_abc123" or "vm-1001")
  - `type` - The node type (e.g., :worker, :runner, :compute)
  - `network_mode` - The network mode (:tailscale, :cluster_ip, :local, :bridge, etc.)
  - `opts` - Options for namespace or local suffix

  ## Options
  - `:namespace` - K8s namespace for cluster_ip mode (default: "indrajaal")
  - `:local_suffix` - Suffix for local/bridge modes (default: "local")

  ## Examples

      # K8s with Tailscale
      iex> build_node_name("indrajaal_worker_abc123", :worker, :tailscale)
      :"worker@indrajaal_worker_abc123.tailnet.ts.net"

      # K8s with ClusterIP
      iex> build_node_name("indrajaal_worker_abc123", :worker, :cluster_ip, namespace: "prod")
      :"worker@indrajaal_worker_abc123.prod.svc.cluster.local"

      # Container with local networking
      iex> build_node_name("indrajaal_app_def456", :app, :local, local_suffix: "local.indrajaal")
      :"app@indrajaal_app_def456.local.indrajaal"

      # Proxmox VM with bridge
      iex> build_node_name("vm-1001", :compute, :bridge, local_suffix: "pve.local")
      :"compute@vm-1001.pve.local"
  """
  @spec build_node_name(String.t(), atom(), network_mode(), build_opts()) :: atom()
  def build_node_name(hostname, type, network_mode, opts \\ [])

  def build_node_name(hostname, type, :tailscale, _opts) do
    suffix = get_tailscale_suffix()
    :"#{type}@#{hostname}.#{suffix}"
  end

  def build_node_name(hostname, type, :cluster_ip, opts) do
    namespace = Keyword.get(opts, :namespace, "indrajaal")
    :"#{type}@#{hostname}.#{namespace}.svc.cluster.local"
  end

  def build_node_name(hostname, type, :local, opts) do
    local_suffix = Keyword.get(opts, :local_suffix, "local.indrajaal")
    :"#{type}@#{hostname}.#{local_suffix}"
  end

  def build_node_name(hostname, type, :bridge, opts) do
    local_suffix = Keyword.get(opts, :local_suffix, "pve.local")
    :"#{type}@#{hostname}.#{local_suffix}"
  end

  def build_node_name(hostname, type, :host_network, opts) do
    local_suffix = Keyword.get(opts, :local_suffix, "local")
    :"#{type}@#{hostname}.#{local_suffix}"
  end

  def build_node_name(hostname, type, :vlan, opts) do
    local_suffix = Keyword.get(opts, :local_suffix, "vlan.local")
    :"#{type}@#{hostname}.#{local_suffix}"
  end

  @doc """
  Get the Tailscale network suffix.

  Returns the tailnet suffix if TailscaleDNS is available, otherwise returns
  a fallback suffix.

  ## Parameters
  - `fallback` - Fallback suffix when Tailscale is unavailable (default: "local")

  ## Examples

      iex> get_tailscale_suffix()
      "tailnet.ts.net"

      iex> get_tailscale_suffix("local.indrajaal")
      "local.indrajaal"  # when Tailscale unavailable
  """
  @spec get_tailscale_suffix(String.t()) :: String.t()
  def get_tailscale_suffix(fallback \\ "local") do
    if Code.ensure_loaded?(TailscaleDNS) do
      TailscaleDNS.get_tailnet_suffix()
    else
      fallback
    end
  end

  @doc """
  Normalize a container/pod ID to a valid hostname.

  Replaces hyphens with underscores for Erlang node name compatibility.

  ## Examples

      iex> normalize_hostname("indrajaal-worker-abc123")
      "indrajaal_worker_abc123"
  """
  @spec normalize_hostname(String.t()) :: String.t()
  def normalize_hostname(id) do
    String.replace(id, "-", "_")
  end

  @doc """
  Build a VM hostname from a VMID.

  ## Examples

      iex> build_vm_hostname(1001)
      "vm-1001"
  """
  @spec build_vm_hostname(pos_integer()) :: String.t()
  def build_vm_hostname(vmid) when is_integer(vmid) do
    "vm-#{vmid}"
  end
end
