defmodule Indrajaal.Cluster.Capabilities.Behaviour do
  @moduledoc """
  Behaviour definition for Cluster Capability Backends.

  WHAT: Defines the contract for all capability backends (Process, Container, K8s, Proxmox).
  WHY: SC-CLU-001 requires unified identity-based networking across all backend types.
  CONSTRAINTS: All backends must support Tailscale naming with local fallback.

  ## Capability Types
  - `:process` - OS process-based compute (ProcessCapability)
  - `:container` - Podman container-based compute (ContainerCapability)
  - `:k8s` - Kubernetes pod-based compute (K8sCapability)
  - `:proxmox` - Proxmox VM-based compute (ProxmoxCapability)

  ## STAMP Constraints
  - SC-CLU-001: Identity-based networking
  - SC-CLU-004: Graceful degradation
  - SC-FLAME-002: Secure RPC
  """

  @type capability_type :: :process | :container | :k8s | :proxmox
  @type network_mode :: :tailscale | :local | :hybrid

  @type status :: %{
          required(:capability) => capability_type(),
          required(:available) => boolean(),
          required(:network_mode) => network_mode(),
          required(:tailscale_available) => boolean(),
          optional(atom()) => any()
        }

  @doc """
  Get the capability type.
  """
  @callback capability_type() :: capability_type()

  @doc """
  Check if the capability is available.
  """
  @callback available?() :: boolean()

  @doc """
  Get the current status of the capability.
  """
  @callback status() :: status()
end
