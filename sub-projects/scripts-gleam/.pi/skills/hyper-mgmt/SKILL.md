---
name: hyper-mgmt
description: Specialized workflows for managing XCP-ng (XAPI/xe) and Proxmox VE (qm/pct/pvesm/pvesh) hypervisors. Use this skill for VM/Container lifecycle management, storage operations, and cross-hypervisor migrations.
---

# Hypervisor Management Skill

This skill provides expert workflows for managing XCP-ng and Proxmox VE environments via their respective CLI tools.

## 1. XCP-ng (xe CLI) Patterns

XCP-ng uses a structured object model: **PIF** -> **Network** -> **VIF** (Networking) and **SR** -> **PBD** -> **VDI** -> **VBD** (Storage).

### Common Workflows
- **VM Deployment**: `xe vm-install template=<uuid> new-name-label=<name>`
- **Disk Creation**: `xe vdi-create sr-uuid=<sr-uuid> name-label=<name> virtual-size=<bytes> type=user`
- **Networking**: `xe vif-create vm-uuid=<vm-uuid> network-uuid=<net-uuid> device=0`
- **Power State**: `xe vm-start`, `xe vm-shutdown`, `xe vm-reboot`
- **VDI Import**: `xe vdi-import uuid=<vdi-uuid> filename=/dev/stdin format=raw` (Use for streaming migrations).

### Optimization Hints
- Use `--minimal` in scripts to get just the UUID.
- Always check `xe vm-list params=networks` to verify IP assignment (requires guest tools).

## 2. Proxmox VE (qm/pct/pvesm) Patterns

Proxmox uses distinct tools for VMs (`qm`) and Containers (`pct`).

### Common Workflows
- **VM Management**: `qm list`, `qm config <vmid>`, `qm set <vmid> --memory <MB>`
- **Container Management**: `pct enter <vmid>`, `pct exec <vmid> -- <cmd>`
- **Storage Audit**: `pvesm status`, `pvesm list <storage-name>`
- **API Access**: Use `pvesh get /nodes` for cluster-wide status.

## 3. Cross-Hypervisor Migration (Proxmox -> XCP-ng)

### The "Stream" Pattern
To migrate a Proxmox disk to XCP-ng without local storage:
1. Identify Proxmox disk: `zfs list | grep vm-<vmid>`
2. Create placeholder VM and VDI on XCP-ng.
3. Stream: `ssh <proxmox> "zfs send <dataset> | ssh <xcp-ng> 'xe vdi-import uuid=<vdi-uuid> filename=/dev/stdin format=raw'"`

## 4. NixOS for Hypervisors

### Declarative Deployment
Always prefer `nixos-generators` for creating VHD/QCOW2 images.
- **XCP-ng Format**: `nixos-generate -f vhd` (often requires `hyperv` target or raw conversion).
- **Proxmox Format**: `nixos-generate -f proxmox` or `qcow`.

### Essential Config for XCP-ng
```nix
{
  services.xe-guest-utilities.enable = true; # Required for IP reporting in XAPI
  services.tailscale.enable = true; # Secure remote access
}
```

## 5. Troubleshooting
- **XCP-ng Connection Timeout**: Large VDI imports can saturate dom0 networking. Throttling or secondary NIC usage is recommended.
- **VDI Import "File Not Found"**: Ensure `filename=/dev/stdin` is explicitly set when piping data.
- **Proxmox QGA Timeout**: Ensure `agent: 1` is in `qm config` and guest agent is running inside the VM.
