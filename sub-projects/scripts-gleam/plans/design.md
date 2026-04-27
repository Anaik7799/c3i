# Design

Architecture, rationale, trade-offs, and rejected alternatives.
Cross-references [`plan.md`](plan.md); task IDs are of the form
`P{phase}.W{workstream}.T{task}.S{subtask}`.

This document answers *why*. If a decision isn't documented here, it
isn't a decision — it's an accident, and you should open a PR that
either deletes the behaviour or adds the rationale.

---

## Guiding principles

1. **Declarative everything.** If a config knob lives on a host's
   filesystem and not in git, it doesn't exist. Recovery is
   `nixos-rebuild switch --flake github:user/sys#<host>` from a
   freshly-installed NixOS minimal.
2. **Pure core, effectful shell.** Inspection commands (`sys check`,
   `sys deploy plan`) never mutate remote state. Mutating commands
   (`sys deploy apply --execute`) are the only ones that ssh and
   they fail closed if preconditions don't hold.
3. **One language per concern.** Gleam orchestrates, Rust does
   perf/CLI leaf work, Nix describes system state. No bash scripts
   beyond the one-shot `.pi/bootstrap/*.sh` that pre-dated Gleam.
4. **Secrets never leave the target's memory in plaintext.** sops-nix
   decrypts at activation time using the host's ssh ed25519 key as
   the age identity. No operator's laptop needs the decryption key.
5. **Tailscale is the admin plane.** LAN is for performance traffic
   only (k3s VXLAN, iSCSI, whatever). Admin SSH + kubectl goes over
   Tailscale — portable across networks, survives LAN rearrangement.
6. **GKE parity from day 0.** Manifests are kustomize overlays
   (`base/`, `overlays/nas1/`, `overlays/gke/`). No manifest
   authored for K3s should require rework to apply against GKE.

---

## Architecture overview

```
           workstation (pi, this repo)
                  │
                  │ ssh + kubectl over Tailscale
                  ▼
        ┌──────────────────────┐
        │ Tailnet tag:k3s      │
        └─┬──────┬──────┬──────┘
          │      │      │
       master  w-1    w-2       ← NixOS VMs on XCP-ng nas-1
          │      │      │
          └──────┴──────┘  k3s control plane + agents
                 │
                 │ Flannel VXLAN (LAN MTU 1500, 8472/udp)
                 │ Longhorn iSCSI (3260/tcp between nodes)
                 ▼
              Pod network 10.42.0.0/16
              Service network 10.43.0.0/16

        nas-1 (dom0 XCP-ng, 192.168.1.219)
        ├── Aquantia 10 GbE  ←── LAN switch
        ├── 2× NVMe 1.8 TB   ←── VM OS disks
        └── 4× SATA 3.7 TB   ←── Longhorn storage pool (reserved)

        nuc-1 (Proxmox, elsewhere)
        └── historical; source of the vm-1 migration
```

### What lives where in the repo

```
flake.nix                    # inputs: nixpkgs, rust-overlay, sops-nix
rust-toolchain.toml          # pinned stable + clippy/rustfmt/rust-analyzer
Cargo.toml / crates/         # Rust workspace (sysctl CLI)
scripts/                     # Gleam orchestrator: doctor/fmt/test/deploy/check
nix-configs/
  inventory.nix              # ← P2: IPs + roles; single source of truth
  modules/
    base.nix                 # sshd, nftables, chrony, ops user
    deploy.nix               # sys.deploy.targetHost option
    secrets.nix              # sops-nix wrapper, age-from-ssh
    tailscale.nix            # ← P2: sys.tailscale.* options
  k3s/
    server.nix               # control-plane role
    agent.nix                # worker role
  hosts/nas1/<vm>/
    configuration.nix        # thin: imports + host-specific options
    hardware-configuration.nix   # ← P1.W4: committed AFTER first install
secrets/                     # ← P3: sops-encrypted yaml (gitignored until P3)
  .sops.yaml                 # creation rules
  nas1.yaml                  # k3s-token, tailscale-authkey, …
plans/                       # this directory
docs/                        # long-form notes, hardware audits
journal/                     # dated session summaries
.pi/                         # pi-agent config + bootstrap scripts
.github/workflows/           # CI; dormant until origin is a real remote
.githooks/pre-commit         # sys check --fast
```

---

## Decisions per phase

### P1 — NixOS install strategy

**Decision**: Boot from the official **NixOS 24.05 Minimal ISO** via
XCP-ng's VNC console, run `nixos-install` against a minimal stub
`configuration.nix` that just imports `<nixpkgs/nixos>` and enables
sshd + a root ssh-authorized key. Reboot into the stub. Every
subsequent rebuild uses the flake.

**Rationale**:
- Installing *directly* against our flake means the very first boot
  needs working sops decryption, which means needing the host's
  ssh key, which doesn't exist until after first boot. Chicken-and-
  egg. Stub → flake lets us land the host, harvest its ssh key,
  then switch to secrets on the second rebuild.
- Using NixOS-published ISOs avoids maintaining our own installer
  image. Gemini-produced the custom VHDX on nuc-1; we treat that
  as a historical artifact, not part of the long-term story.

**Rejected alternatives**:
- **Pre-built custom image per host.** The Proxmox-side VHDX route
  (journal §2) works but rebuilding three custom images every time
  the stub needs tweaking is friction we don't need. Our flake IS
  the golden image; the ISO is just the loader.
- **`nixos-anywhere`.** Appealing, but requires outbound SSH from
  the workstation to the VM during install. The VM sits behind the
  XCP-ng console only until P2 brings Tailscale up. We could do it
  after P2, but P1 must land first anyway.
- **NixOS infect (replacing running Linux on the VM).** The VMs
  were booted to the NixOS ISO directly; no existing OS to infect.

**Why 24.05 specifically**: matches `system.stateVersion = "24.05"`
already pinned in each host's `configuration.nix`. Later upgrades
bump both together.

### P1.W4 — hardware-configuration.nix in git

**Decision**: Commit the generated `hardware-configuration.nix`
back into the repo, one file per VM, imported explicitly by that
VM's `configuration.nix` (currently commented out).

**Rationale**: reproducibility. If a VM dies, we provision a fresh
VM with the **same virtual hardware** (XCP-ng VM spec is stable:
2 vCPU / 4 GB / 40 GB), run `nixos-install --flake .#<host>`, done.
No regenerate-hw-config step needed because the committed file
already matches.

**Risk**: if someone changes the VM spec (adds a disk, swaps the
NIC model), the committed file becomes wrong. Mitigation: treat
`hardware-configuration.nix` as derived-but-committed, like
`Cargo.lock`. Re-generate and commit on hardware changes.

### P2.W1 — Tailscale module options

**Decision**: expose `sys.tailscale.{enable, authKeyFile, tags,
advertiseRoutes, ssh}`. See plan.md P2.W1.T1 subtasks for shapes.

**Why a module wrapping `services.tailscale` exists**:
- Our convention is `sys.<area>.<option>`, not the raw nixpkgs
  namespace, so a single host config line turns the feature on
  without needing to remember the 4 services.tailscale.* knobs.
- `authKeyFile` forces sops-nix integration — you cannot accidentally
  commit an authkey.
- Ensures the firewall holes (41641/udp) happen in lockstep with
  enabling the service.

**Rejected**: putting Tailscale init directly into `base.nix`. Some
future host might not want it (a bastion that talks to the LAN
directly, e.g.). Opt-in keeps it honest.

### P2.W2 — Inventory as Nix, not TOML/YAML

**Decision**: `nix-configs/inventory.nix` is a plain Nix attrset,
imported via `specialArgs` in `flake.nix`.

**Rationale**:
- The flake is already evaluating Nix. Parsing YAML from Nix is
  ugly. Nix expressions compose.
- Gleam can still read inventory via `nix eval --json
  .#lib.inventory` — one eval, typed JSON out.
- Changes to inventory go through the same review channel as
  configs.

**Rejected**: a YAML file parsed both by Nix (via `builtins.fromJSON
(builtins.readFile ...)` after a yaml→json step) and by the Gleam
CLI. Adds a format boundary without buying anything.

### P3.W1 — Age key derivation

**Decision**: each VM's **ssh_host_ed25519_key** IS its age key
(via `ssh-to-age`). `sops-nix` is configured to read
`/etc/ssh/ssh_host_ed25519_key` directly — no separate age file on
disk.

**Rationale**:
- Only one secret to protect per VM.
- The ssh host key already survives rebuilds (it's in
  `/etc/ssh/`, not `/nix/store`).
- Operators don't need to distribute an age key separately; the
  ssh key is already there.

**Rejected**:
- Shared age key across all hosts. Nicer for ops but means one
  compromised VM exposes all secrets. Hard no.
- Per-host age key stored in the repo encrypted with an admin
  master key. Needs a second key to rotate the first — complexity
  with no gain.

### P3.W2 — `.sops.yaml` creation rules

**Decision**: one `secrets/<host>.yaml` per host, plus a shared
`secrets/cluster.yaml` for anything spanning hosts (e.g. the k3s
join token, by definition shared). Creation rules grant:

- **workstation admin age key** → all files (so humans can `sops
  edit`).
- **per-host age pubkey** → that host's file.
- **all three cluster hosts** → `cluster.yaml` (k3s token).

**Rationale**:
- Minimum-privilege: worker-1 can't read master's unique secrets.
- Rotation: remove one host from `cluster.yaml` creation_rules and
  `sops updatekeys` rewrites every payload without re-typing the
  secret.

### P4.W1 — First cluster rebuild without Longhorn

**Decision**: the master's first rebuild enables k3s with
`--disable traefik --disable servicelb` (already the default in
our `k3s/server.nix`) and **no Longhorn**. Longhorn is P5.

**Rationale**: form the cluster, validate it, *then* add storage.
Longhorn without a working kube api is undebugabble.

**Rejected**: enabling everything at once to save a rebuild round-
trip. The rebuild is 30 seconds; the debugging when something goes
wrong is hours. Not worth it.

### P4.W4 — Kubeconfig workflow

**Decision**: `sys secrets get kubeconfig` (a subcommand added in
P3.W4) extracts `/etc/rancher/k3s/k3s.yaml` over ssh, rewrites the
`server:` URL from `https://127.0.0.1:6443` to
`https://<master-tailscale-addr>:6443`, and prints to stdout.
Users pipe it into `~/.kube/configs/nas1.yaml` and add a
`KUBECONFIG=~/.kube/configs/nas1.yaml:~/.kube/config` style merge
or set a context.

**Rationale**:
- The server URL rewrite is necessary (the k3s.yaml default
  localhost doesn't work from the workstation).
- Tailscale addr is the stable admin endpoint (LAN addr is DHCP).
- Keeping the extraction in Gleam lets us validate the YAML parses
  and the context name matches the host before writing.

**Rejected**: `kubectl config view --raw --merge` on the master
node. Works but requires kubectl on the workstation before the
workstation has a kubeconfig. Chicken-and-egg.

### P5.W1 — Longhorn vs alternatives

**Under discussion. Current lean: Longhorn**.

**Why Longhorn**:
- Multi-replica block storage across the 3 nodes → can survive a
  worker loss.
- Web UI gives immediate operational visibility.
- Well-documented NixOS story via Helm + a host-level open-iscsi
  module (or via `services.longhorn`, if stable — check release
  notes at implementation time).

**Why maybe not Longhorn**:
- Needs iSCSI in the kernel → requires a node reboot to pick up
  the iscsid service. One-time cost, tolerable.
- Longhorn's default behaviour is to use `/var/lib/longhorn` on
  every node. Our nodes have 40 GB root disks — too small. Solution:
  mount one of the SATA drives per node as `/var/lib/longhorn`,
  declare it in `hardware-configuration.nix`. Doable but extra
  config work.

**Alternatives ranked**:
1. **NFS backed by a ZFS pool on nas-1 dom0** — simpler, but dom0
   now does double duty (hypervisor + storage), which is
   architecturally muddy. Also no RWX→RWO isolation story.
2. **OpenEBS hostpath + rsync-cron backups** — cheap, but no HA.
3. **Rook-Ceph** — overkill for 3 nodes with shared-ish backing
   storage.

**Decision deferred until P5 start**; document the pick in a P5
section here.

### P5.W4 — GKE parity via kustomize

**Decision**: all workload manifests under
`nix-configs/k3s/manifests/` are organised as:

```
manifests/
  base/                 # platform-agnostic
  overlays/nas1/        # nas1-specific: StorageClass=longhorn, tailscale annotations
  overlays/gke/         # gke-specific: StorageClass=standard-rwo, Workload Identity, GCP load balancer
```

**Rationale**:
- `kubectl apply -k overlays/nas1` deploys locally; `-k overlays/gke`
  deploys to GKE. Diffs are explicit and reviewable.
- Forces us to notice every time an overlay grows a new field — that
  field is a GKE-portability risk.

---

## Non-decisions (defer)

| Topic | Why deferred |
|-------|--------------|
| Monitoring stack (Prometheus/Grafana/Loki) | Post-P5. Cluster must exist before observability is useful. |
| GitOps (Flux / ArgoCD) | Post-P5. Manifests need to exist first; then choose a drift-correction mechanism. |
| Backup story | Post-Longhorn. Longhorn has snapshots; day-2 concern. |
| Multi-tenancy / RBAC | Out of scope for "dev cluster". Will become a requirement when GKE migration happens. |

---

## Non-goals (deliberate)

- **HA control plane.** 1 master, 2 workers. If master dies, the
  workload stays up but no schedule changes. Acceptable for a dev
  cluster; GKE handles this once we migrate.
- **Air-gapped operation.** We fetch images from registries. Local
  registry mirror is a future nice-to-have.
- **Custom kernel modules.** We stay on the `nixos-unstable` default
  kernel. iSCSI for Longhorn is the only module consideration; it's
  upstream.
- **Multi-cluster federation.** One cluster on nas-1, eventually one
  on GKE. No federation between them.

---

## Change control

This design doc is updated **before** a commit whose behaviour
deviates from it. If you find yourself editing code first, stop, edit
the doc, commit that, then resume. (The pre-commit hook does not
enforce this; social contract does.)

For reversals — a rejected alternative later becoming the chosen
path — add a dated row to the section explaining what changed and
why. Don't rewrite history.
