# Plan — `sys` workspace, five-level WBS

> Task-ID scheme: `P{phase}.W{workstream}.T{task}.S{subtask}`.
> Cross-referenced by [`design.md`](design.md),
> [`implementation.md`](implementation.md), [`tests.md`](tests.md).

---

## Level 1 — Mission

Stand up a **reproducible, declarative K3s Kubernetes cluster on
`nas-1`**, backed by NixOS VMs with encrypted secrets, a Tailscale
mesh for admin access, and deployment fully orchestrated from the
`sys` repo via one command — `gleam run -m sys_scripts -- deploy
apply nixos <host> --execute`. Keep the workload YAMLs portable so
migration to GKE is a day's work, not a project.

---

## Level 2 — Phases (chronological, each unblocks the next)

| Phase | Outcome |
|-------|---------|
| **P1** | 3 NixOS VMs installed, reachable over SSH (key-only), with real `hardware-configuration.nix` files committed back to the repo. |
| **P2** | Tailscale mesh joined; `inventory.nix` has real addresses; `deploy plan nixos <host>` reads real targetHost from the config. |
| **P3** | sops-nix active; k3s token + tailscale authkey encrypted in `secrets/`; no plaintext secrets anywhere. |
| **P4** | K3s control-plane + 2 workers form a cluster; `kubectl get nodes` shows 3 Ready. |
| **P5** | Longhorn storage, an ingress, and a first workload. GKE parity verified with a `kubectl apply -f` test case. |

---

## Level 3 — Workstreams inside each phase

### P1 — NixOS on VMs

| ID | Workstream |
|----|------------|
| P1.W1 | Boot + base install on `nix-k8s-master` |
| P1.W2 | Boot + base install on `nix-k8s-worker-1` |
| P1.W3 | Boot + base install on `nix-k8s-worker-2` |
| P1.W4 | Commit generated `hardware-configuration.nix` back to the repo |

### P2 — Mesh & inventory

| ID | Workstream |
|----|------------|
| P2.W1 | Tailscale module (`modules/tailscale.nix`) |
| P2.W2 | Inventory module (`nix-configs/inventory.nix`) |
| P2.W3 | Wire `sys.deploy.targetHost` defaults to inventory |
| P2.W4 | `sys inventory` Gleam subcommand (read-only listing) |

### P3 — Secrets

| ID | Workstream |
|----|------------|
| P3.W1 | Age-key extraction from each VM's ssh host key |
| P3.W2 | `.sops.yaml` policy + repo's first `secrets/nas1.yaml` |
| P3.W3 | Wire `sops.secrets.k3s-token` and `sops.secrets.tailscale-authkey` |
| P3.W4 | `sys secrets` Gleam subcommand (list/validate/edit) |

### P4 — K3s cluster

| ID | Workstream |
|----|------------|
| P4.W1 | First-rebuild of `nix-k8s-master` with `services.k3s` enabled |
| P4.W2 | Verify API reachable; extract join token; rebuild `worker-1` |
| P4.W3 | Rebuild `worker-2` |
| P4.W4 | `kubectl` config piped into `secrets/kubeconfig.yaml` for workstation use |

### P5 — Storage, ingress, GKE readiness

| ID | Workstream |
|----|------------|
| P5.W1 | Longhorn installed (NixOS module or Helm; decide in design.md) |
| P5.W2 | Traefik/NGINX ingress decision + manifest |
| P5.W3 | First real workload deployed (pick a stateful one to exercise Longhorn) |
| P5.W4 | GKE-parity smoke: same manifest applies cleanly against a kind cluster |

---

## Level 4 — Tasks inside each workstream

### P1 — NixOS on VMs

**P1.W1** (master — template for W2/W3):

| ID | Task |
|----|------|
| P1.W1.T1 | Boot the VM from NixOS Minimal 24.05 ISO via XCP-ng console |
| P1.W1.T2 | Partition + format the 40 GB root disk (UEFI: 512 MB ESP + remainder ext4) |
| P1.W1.T3 | Mount, generate hardware-configuration.nix, replace configuration.nix with a minimal placeholder that sources the flake |
| P1.W1.T4 | `nixos-install` then reboot |
| P1.W1.T5 | Verify SSH reachable from the workstation; add the VM's public ssh host key to `known_hosts`; set `~/.ssh/config` alias |

**P1.W4**:

| ID | Task |
|----|------|
| P1.W4.T1 | `scp root@<vm>:/etc/nixos/hardware-configuration.nix nix-configs/hosts/nas1/<vm>/` |
| P1.W4.T2 | Uncomment the `./hardware-configuration.nix` import in each host's `configuration.nix` |
| P1.W4.T3 | `sys check` passes full (nix eval hits no missing options) |
| P1.W4.T4 | `sys deploy plan nixos <host>` against every host; JSON summaries sane |

### P2 — Mesh & inventory

**P2.W1** (tailscale module):

| ID | Task |
|----|------|
| P2.W1.T1 | Write `nix-configs/modules/tailscale.nix` with options `sys.tailscale.{enable, authKeyFile, tags, advertiseRoutes}` |
| P2.W1.T2 | Import from all three host configs behind `sys.tailscale.enable = true` |
| P2.W1.T3 | `sys check` passes |

**P2.W2** (inventory):

| ID | Task |
|----|------|
| P2.W2.T1 | `nix-configs/inventory.nix` attrset: `hosts.<name>.{lanAddr, tailscaleAddr, role, sshUser}` |
| P2.W2.T2 | Flake `specialArgs` passes inventory to every `nixosConfiguration` |
| P2.W2.T3 | `modules/deploy.nix`: `sys.deploy.targetHost` defaults to `inventory.hosts.<this>.tailscaleAddr` when `sys.deploy.useInventory = true` |

**P2.W3** (wire defaults):

| ID | Task |
|----|------|
| P2.W3.T1 | Flip each host to `sys.deploy.useInventory = true` |
| P2.W3.T2 | `sys deploy plan nixos <host>` — no longer requires explicit targetHost |

**P2.W4** (`sys inventory`):

| ID | Task |
|----|------|
| P2.W4.T1 | New `scripts/src/sys_scripts/commands/inventory.gleam` |
| P2.W4.T2 | Subcommands: `list`, `show <name>`, `ping` (shells to `tailscale ping` per host) |
| P2.W4.T3 | Wire into dispatcher; dispatcher test updated |

### P3 — Secrets

**P3.W1**:

| ID | Task |
|----|------|
| P3.W1.T1 | `ssh root@<vm> cat /etc/ssh/ssh_host_ed25519_key.pub \| ssh-to-age` per VM, save pubkeys to `secrets/.sops.yaml` |
| P3.W1.T2 | Add an admin age key (workstation) to `secrets/.sops.yaml` so humans can edit |

**P3.W2**:

| ID | Task |
|----|------|
| P3.W2.T1 | Write `secrets/.sops.yaml` creation_rules covering `nas1.yaml` |
| P3.W2.T2 | `sops secrets/nas1.yaml` — fill in `k3s-token`, `tailscale-authkey` |

**P3.W3** (wire):

| ID | Task |
|----|------|
| P3.W3.T1 | `sys.secrets.enable = true` on all three hosts |
| P3.W3.T2 | `sops.secrets.k3s-token.sopsFile = ../../../secrets/nas1.yaml` on each |
| P3.W3.T3 | `sys.k3s.server.tokenFile = config.sops.secrets.k3s-token.path` |
| P3.W3.T4 | `sys.k3s.agent.tokenFile = config.sops.secrets.k3s-token.path` |
| P3.W3.T5 | `sys.tailscale.authKeyFile = config.sops.secrets.tailscale-authkey.path` |

**P3.W4** (`sys secrets`):

| ID | Task |
|----|------|
| P3.W4.T1 | New command: `sys secrets list`, `sys secrets validate`, `sys secrets edit <file>` |
| P3.W4.T2 | Wire into dispatcher + tests |

### P4 — K3s cluster

**P4.W1** (master first-rebuild):

| ID | Task |
|----|------|
| P4.W1.T1 | `sys deploy apply nixos nix-k8s-master --execute` |
| P4.W1.T2 | `journalctl -u k3s` clean; `curl -k https://<master>:6443` returns 401 (API up) |
| P4.W1.T3 | `kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml get nodes` shows master Ready |

**P4.W2, P4.W3** — same shape for workers.

**P4.W4** (kubeconfig):

| ID | Task |
|----|------|
| P4.W4.T1 | Extract `/etc/rancher/k3s/k3s.yaml`, rewrite server URL to tailscale addr |
| P4.W4.T2 | Drop into workstation `~/.kube/config` behind a context named `nas1` |
| P4.W4.T3 | `kubectl config use-context nas1 && kubectl get nodes` → 3 Ready |

### P5 — Storage, ingress, GKE readiness

**P5.W1** (Longhorn):

| ID | Task |
|----|------|
| P5.W1.T1 | Decide: NixOS `services.longhorn` vs Helm install (design.md decision) |
| P5.W1.T2 | Provision iSCSI/open-iscsi deps on each node |
| P5.W1.T3 | Deploy; wait for `longhorn-system` namespace all-Ready |
| P5.W1.T4 | PVC smoke test: a 1 GiB claim binds and is writable from a pod |

**P5.W2** (ingress):

| ID | Task |
|----|------|
| P5.W2.T1 | Traefik chosen? NGINX? (design.md) |
| P5.W2.T2 | Install via Helm chart committed under `nix-configs/k3s/manifests/` |
| P5.W2.T3 | External access tested via Tailscale funnel or LAN IP |

**P5.W3** (first workload):

| ID | Task |
|----|------|
| P5.W3.T1 | Pick a stateful app that exercises PVC + Ingress (the design doc proposes Gitea) |
| P5.W3.T2 | Apply manifest; verify persistence across pod restarts |

**P5.W4** (GKE readiness):

| ID | Task |
|----|------|
| P5.W4.T1 | `kind create cluster` locally; apply the same manifests |
| P5.W4.T2 | Note any CRDs / storage-class differences in `docs/gke-parity.md` |

---

## Level 5 — Subtasks (most granular — only filled where non-obvious)

### P1.W1.T2 — Partition the 40 GB disk

| ID | Subtask |
|----|---------|
| P1.W1.T2.S1 | `parted /dev/sda mklabel gpt` |
| P1.W1.T2.S2 | `parted /dev/sda mkpart ESP fat32 1MiB 513MiB && parted /dev/sda set 1 esp on` |
| P1.W1.T2.S3 | `parted /dev/sda mkpart primary ext4 513MiB 100%` |
| P1.W1.T2.S4 | `mkfs.fat -F 32 -n BOOT /dev/sda1` |
| P1.W1.T2.S5 | `mkfs.ext4 -L nixos /dev/sda2` |
| P1.W1.T2.S6 | `mount /dev/disk/by-label/nixos /mnt && mkdir -p /mnt/boot && mount /dev/disk/by-label/BOOT /mnt/boot` |

### P2.W1.T1 — Tailscale module options

| ID | Subtask |
|----|---------|
| P2.W1.T1.S1 | `sys.tailscale.enable` — boolean, default false |
| P2.W1.T1.S2 | `sys.tailscale.authKeyFile` — path (null until P3) |
| P2.W1.T1.S3 | `sys.tailscale.tags` — listOf str (e.g. `["tag:k3s"]`) |
| P2.W1.T1.S4 | `sys.tailscale.advertiseRoutes` — listOf str (subnets to advertise; empty by default) |
| P2.W1.T1.S5 | `sys.tailscale.ssh` — boolean, default true (lets `tailscale ssh` work) |

### P2.W2.T1 — Inventory shape

| ID | Subtask |
|----|---------|
| P2.W2.T1.S1 | `inventory.hosts.nix-k8s-master = { lanAddr = "192.168.1.10"; tailscaleAddr = null; role = "k3s-server"; sshUser = "root"; }` |
| P2.W2.T1.S2 | Same for `worker-1`/`worker-2` |
| P2.W2.T1.S3 | `inventory.hypervisors.nas-1 = { lanAddr = "192.168.1.219"; kind = "xcp-ng"; }` |
| P2.W2.T1.S4 | `inventory.hypervisors.nuc-1 = { lanAddr = ?; kind = "proxmox"; }` |

### P3.W2.T2 — secrets/nas1.yaml contents

| ID | Subtask |
|----|---------|
| P3.W2.T2.S1 | `k3s-token` — 64 random hex chars |
| P3.W2.T2.S2 | `tailscale-authkey` — pasted from Tailscale admin console (reusable, ephemeral, preauthorized, tagged `tag:k3s`) |

### P4.W2.T1 — Extract join token safely

| ID | Subtask |
|----|---------|
| P4.W2.T1.S1 | `ssh nix-k8s-master sudo cat /var/lib/rancher/k3s/server/node-token` |
| P4.W2.T1.S2 | Confirm it matches `config.sops.secrets.k3s-token` (it's the same token used by the server bootstrap) |

### P5.W3.T1 — Gitea workload choice criteria

| ID | Subtask |
|----|---------|
| P5.W3.T1.S1 | Uses 1 PVC (exercises Longhorn) |
| P5.W3.T1.S2 | HTTP + SSH endpoints (exercises ingress + service of type LoadBalancer) |
| P5.W3.T1.S3 | Has a healthcheck endpoint (exercises probes + monitoring later) |
| P5.W3.T1.S4 | Meaningful to have around (mirrors `/root/git/sys.git` into a web UI) |

---

## Risk register

| Risk | Phase | Mitigation |
|------|-------|------------|
| VM console access during install breaks, requiring out-of-band intervention | P1 | Document the XCP-ng `xl console` fallback in `docs/nas1-hardware-analysis.md`. |
| sops age key not yet present when `nixos-install` activates secrets | P3/P4 | First rebuild runs with `sys.secrets.enable = false`; flip to true on second rebuild after ssh-host-key-to-age conversion. |
| Tailscale ephemeral authkey expires mid-install | P2 | Use a reusable authkey; expiry ≥ 90 days. |
| K3s master unhappy with CIDR clash on 10.0.0.0/8 if LAN uses it | P4 | `cluster-cidr = 10.42.0.0/16` (already set); `service-cidr = 10.43.0.0/16`. |
| Longhorn requires multi-attach RWX for some workloads | P5 | If needed, swap to NFS PVC backed by the 4×3.7 TB SATA array. |
| GKE's default StorageClass isn't Longhorn | P5.W4 | Parameterise manifests via `kustomize` overlays (local / gke). |

---

## Exit criteria

**"Done with P5"** is a single line: `kubectl --context nas1 get pods -A`
shows **all pods Running**, a Gitea pod serves HTTP via the ingress,
and re-applying the same manifests to a local `kind` cluster
succeeds with one documented diff (the StorageClass overlay).
