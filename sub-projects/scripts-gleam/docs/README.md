# docs/

Workspace design docs, plans, and hardware inventories. All long-form
prose lives here; code goes in `scripts/` (Gleam automation) or
`nix-configs/` (declarative host/cluster configuration).

## Index

| Doc | Purpose |
|-----|---------|
| [nas1-hardware-analysis.md](nas1-hardware-analysis.md) | Hardware inventory for the `nas-1` XCP-ng hypervisor (CPU, storage, networking, iGPU). Source of truth when allocating VM resources. |
| [nixos-k8s-plan.md](nixos-k8s-plan.md) | Phased plan for a 3-node NixOS + K3s cluster running as VMs on `nas-1`. Tracks architecture, phases, and GKE migration path. |

## Conventions

- One Markdown file per concern. Cross-link liberally.
- Put machine-readable data (inventories, IP allocations) alongside the
  prose that explains it; avoid split sources of truth.
- When a design doc graduates to a build action, capture the build in
  `scripts/` (Gleam) or `nix-configs/` (Nix). Leave a "Status" line in
  the doc pointing to the implementation.
