# Implementation

Per-phase file edits and exact commands. Read alongside
[`plan.md`](plan.md) (WBS) and [`design.md`](design.md) (rationale).
Every block is labeled with its task ID so you can jump via grep.

**Conventions**:

- `$REPO` = `/mnt/c/dev/elixir/sys` on the workstation.
- All `gleam run` / `cargo` / `nix` invocations assume you're in
  the devshell (`nix develop` or direnv-activated).
- When a command must run **on a VM**, the block shows `root@<vm>#`.
- When it runs **on the workstation**, `ws$`.
- The console-only steps (XCP-ng VNC) are tagged `(console)`.

After every step, run the matching checks from [`tests.md`](tests.md)
under the same ID before moving on.

---

## P1 — NixOS on VMs

### P1.W1.T1 — Boot `nix-k8s-master` from the ISO (console)

(console)
1. XCP-ng Center → `nix-k8s-master` → attach `nixos-24.05-minimal-x86_64.iso` to the virtual DVD drive.
2. Force-reboot. Wait for the `[root@nixos:~]#` prompt.

### P1.W1.T2 — Partition (VM console, as root)

```bash
root@nixos:~# parted /dev/sda -- mklabel gpt
root@nixos:~# parted /dev/sda -- mkpart ESP fat32 1MiB 513MiB
root@nixos:~# parted /dev/sda -- set 1 esp on
root@nixos:~# parted /dev/sda -- mkpart primary ext4 513MiB 100%
root@nixos:~# mkfs.fat -F 32 -n BOOT /dev/sda1
root@nixos:~# mkfs.ext4 -L nixos /dev/sda2
root@nixos:~# mount /dev/disk/by-label/nixos /mnt
root@nixos:~# mkdir -p /mnt/boot
root@nixos:~# mount /dev/disk/by-label/BOOT /mnt/boot
```

### P1.W1.T3 — Stub `configuration.nix` + hardware-configuration.nix

```bash
root@nixos:~# nixos-generate-config --root /mnt
root@nixos:~# cat > /mnt/etc/nixos/configuration.nix <<'EOF'
{ config, pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nix-k8s-master";    # change per VM
  networking.useDHCP = true;                 # DHCP until P2 puts us on Tailscale
  time.timeZone = "UTC";

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.PermitRootLogin = "prohibit-password";
  };
  users.users.root.openssh.authorizedKeys.keys = [
    # paste the workstation admin pubkey here
    "ssh-ed25519 AAAA... admin@workstation"
  ];

  environment.systemPackages = with pkgs; [ git vim htop ];
  system.stateVersion = "24.05";
}
EOF
```

### P1.W1.T4 — Install + reboot

```bash
root@nixos:~# nixos-install --no-root-passwd
root@nixos:~# reboot
```
(console) Detach the ISO during the reboot window.

### P1.W1.T5 — Workstation-side SSH setup

```bash
ws$ ssh-keyscan -H <master-dhcp-ip> >> ~/.ssh/known_hosts
ws$ cat >> ~/.ssh/config <<'EOF'

Host nix-k8s-master
  HostName <master-dhcp-ip>
  User root
  IdentityFile ~/.ssh/id_ed25519
EOF
ws$ ssh nix-k8s-master 'hostname && nixos-version'
```
Expected: `nix-k8s-master` + a 24.05-flavoured NixOS version string.

### P1.W2 / P1.W3 — Repeat for workers

Identical to P1.W1 with `networking.hostName` set to `nix-k8s-worker-1` / `-2`.

### P1.W4.T1 — Pull `hardware-configuration.nix` back

```bash
ws$ for h in nix-k8s-master nix-k8s-worker-1 nix-k8s-worker-2; do
      scp "root@$h:/etc/nixos/hardware-configuration.nix" \
          "$REPO/nix-configs/hosts/nas1/$h/hardware-configuration.nix"
    done
```

### P1.W4.T2 — Un-comment the imports

In each `nix-configs/hosts/nas1/<vm>/configuration.nix`:

```nix
# BEFORE
# ./hardware-configuration.nix    # generated on the VM after install

# AFTER
./hardware-configuration.nix
```

### P1.W4.T3 — `sys check`

```bash
ws$ cd $REPO/scripts
ws$ gleam run -m sys_scripts -- check
```

Expected: 6/6 pass, including the `nix eval (devShell +
nixosConfigurations)` step with real hardware configs in place.

### P1.W4.T4 — `deploy plan` against every host

```bash
ws$ for h in nix-k8s-master nix-k8s-worker-1 nix-k8s-worker-2; do
      gleam run -m sys_scripts -- deploy plan nixos "$h"
    done
```

Expected: clean JSON summaries per host, all 3 print their real
`system = "x86_64-linux"` and their k3s role.

---

## P2 — Mesh & inventory

### P2.W1.T1 — Tailscale module

Create `nix-configs/modules/tailscale.nix`:

```nix
{ config, lib, pkgs, ... }:
let cfg = config.sys.tailscale; in {
  options.sys.tailscale = {
    enable = lib.mkEnableOption "tailscale mesh";
    authKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to a file containing a Tailscale authkey. Populate via
        sops-nix once P3 lands; null until then prevents accidental
        plaintext authkeys in the store.
      '';
    };
    tags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "tag:k3s" ];
    };
    advertiseRoutes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
    ssh = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      openFirewall = true;
      extraUpFlags =
        [ "--ssh=${lib.boolToString cfg.ssh}" ]
        ++ lib.optionals (cfg.tags != [ ])
             [ "--advertise-tags=${lib.concatStringsSep "," cfg.tags}" ]
        ++ lib.optionals (cfg.advertiseRoutes != [ ])
             [ "--advertise-routes=${lib.concatStringsSep "," cfg.advertiseRoutes}" ];
      authKeyFile = cfg.authKeyFile;
    };
  };
}
```

### P2.W1.T2 — Import from host configs

Add to each `nix-configs/hosts/nas1/<vm>/configuration.nix` imports:

```nix
../../../modules/tailscale.nix
```

And set:

```nix
sys.tailscale.enable = true;
# sys.tailscale.authKeyFile = config.sops.secrets.tailscale-authkey.path;  # P3
```

### P2.W2.T1 — Inventory file

Create `nix-configs/inventory.nix`:

```nix
{
  hosts = {
    nix-k8s-master = {
      lanAddr = "192.168.1.10";        # replace with DHCP lease
      tailscaleAddr = null;             # populated after first `tailscale up`
      role = "k3s-server";
      sshUser = "root";
    };
    nix-k8s-worker-1 = {
      lanAddr = "192.168.1.11";
      tailscaleAddr = null;
      role = "k3s-agent";
      sshUser = "root";
    };
    nix-k8s-worker-2 = {
      lanAddr = "192.168.1.12";
      tailscaleAddr = null;
      role = "k3s-agent";
      sshUser = "root";
    };
  };
  hypervisors = {
    nas-1 = { lanAddr = "192.168.1.219"; kind = "xcp-ng"; };
    nuc-1 = { lanAddr = null;            kind = "proxmox"; };
  };
}
```

### P2.W2.T2 — Pass inventory via `specialArgs`

Edit `flake.nix`:

```nix
let
  inventory = import ./nix-configs/inventory.nix;

  mkNixosHost = hostPath:
    nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inventory; };
      modules = [
        sops-nix.nixosModules.sops
        hostPath
      ];
    };
```

### P2.W2.T3 — Deploy module reads inventory

Edit `nix-configs/modules/deploy.nix` to accept `inventory` via its
function head and add a `useInventory` flag:

```nix
{ config, lib, inventory, ... }:
let
  cfg = config.sys.deploy;
  hostName = config.networking.hostName;
  fromInventory =
    if cfg.useInventory && inventory.hosts ? ${hostName} then
      let h = inventory.hosts.${hostName}; in
      if h.tailscaleAddr != null then "${h.sshUser}@${h.tailscaleAddr}"
      else if h.lanAddr        != null then "${h.sshUser}@${h.lanAddr}"
      else null
    else null;
in {
  options.sys.deploy = {
    useInventory = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Default targetHost from inventory.hosts.<this>.";
    };
    targetHost = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = fromInventory;
      example = "root@10.0.0.10";
    };
  };
}
```

### P2.W4 — `sys inventory` command

Create `scripts/src/sys_scripts/commands/inventory.gleam`:

```gleam
//// `inventory` — read-only view of nix-configs/inventory.nix.
////
//// Implemented as a thin wrapper over `nix eval --json .#lib.inventory`
//// so Nix stays the source of truth.

import gleam/io
import gleam/list
import gleam/string
import shellout
import sys_scripts/workspace

pub fn run(args: List(String)) -> Result(Nil, Nil) {
  case args {
    [] | ["list"]         -> list_hosts()
    ["show", name, ..]    -> show_host(name)
    ["ping"]              -> ping_all()
    _ -> {
      io.println_error("usage: inventory [list|show <name>|ping]")
      Error(Nil)
    }
  }
}
// ... list_hosts/show_host/ping_all implementations use
// nix eval --json and shellout to `tailscale ping`.
```

Add `Inventory` to the dispatcher `Command` type, wire `parse/1`,
update the keyword list in `every_known_keyword_is_wired_test`.

---

## P3 — Secrets

### P3.W1.T1 — Extract age pubkeys

```bash
ws$ mkdir -p $REPO/secrets
ws$ for h in nix-k8s-master nix-k8s-worker-1 nix-k8s-worker-2; do
      ssh "$h" cat /etc/ssh/ssh_host_ed25519_key.pub \
        | nix run nixpkgs#ssh-to-age \
        | tee "/tmp/$h.agepub"
    done
```

### P3.W1.T2 — Workstation admin age key

```bash
ws$ nix run nixpkgs#age -- -o ~/.config/sops/age/keys.txt -p --generate
ws$ nix run nixpkgs#age-keygen -- -y ~/.config/sops/age/keys.txt
```
Copy the resulting `age1...` pubkey — it goes into `.sops.yaml`.

### P3.W2.T1 — `.sops.yaml`

Create `secrets/.sops.yaml`:

```yaml
keys:
  - &admin          age1ADMINPUBKEYHERE
  - &master         age1MASTERHOSTKEYHERE
  - &worker1        age1WORKER1HOSTKEYHERE
  - &worker2        age1WORKER2HOSTKEYHERE

creation_rules:
  - path_regex: secrets/cluster\.yaml$
    key_groups:
      - age: [*admin, *master, *worker1, *worker2]

  - path_regex: secrets/nix-k8s-master\.yaml$
    key_groups:
      - age: [*admin, *master]

  - path_regex: secrets/nix-k8s-worker-1\.yaml$
    key_groups:
      - age: [*admin, *worker1]

  - path_regex: secrets/nix-k8s-worker-2\.yaml$
    key_groups:
      - age: [*admin, *worker2]
```

### P3.W2.T2 — Populate `secrets/cluster.yaml`

```bash
ws$ TOKEN=$(openssl rand -hex 32)
ws$ TAILSCALE_AUTHKEY="tskey-auth-..."   # from the Tailscale admin console
ws$ cat > /tmp/cluster.plain <<EOF
k3s-token: "$TOKEN"
tailscale-authkey: "$TAILSCALE_AUTHKEY"
EOF
ws$ nix run nixpkgs#sops -- --encrypt \
      --input-type yaml --output-type yaml \
      /tmp/cluster.plain > $REPO/secrets/cluster.yaml
ws$ shred -u /tmp/cluster.plain
ws$ git -C $REPO add secrets/cluster.yaml secrets/.sops.yaml
```

### P3.W3 — Wire into NixOS

In each host config:

```nix
sys.secrets.enable = true;

sops.secrets.k3s-token = {
  sopsFile = ../../../secrets/cluster.yaml;
  owner = "root";
};
sops.secrets.tailscale-authkey = {
  sopsFile = ../../../secrets/cluster.yaml;
  owner = "root";
};

sys.k3s.server.tokenFile = config.sops.secrets.k3s-token.path;   # on master
sys.k3s.agent.tokenFile  = config.sops.secrets.k3s-token.path;   # on workers
sys.tailscale.authKeyFile = config.sops.secrets.tailscale-authkey.path;
```

### P3.W4 — `sys secrets` command

```bash
ws$ cd $REPO/scripts
ws$ touch src/sys_scripts/commands/secrets.gleam
```

Implementation sketch:

```gleam
pub fn run(args: List(String)) -> Result(Nil, Nil) {
  case args {
    ["list"]          -> list_files()
    ["validate"]      -> validate_all()
    ["edit", path]    -> edit(path)
    _ -> usage()
  }
}
```

`validate` shells out to `sops -d` on every `secrets/*.yaml` and
asserts the result is non-empty. `edit` is a transparent `sops` shim.

---

## P4 — K3s cluster

### P4.W1 — First real deploy

```bash
ws$ gleam run -m sys_scripts -- deploy apply nixos nix-k8s-master --execute
```

Internally: `nixos-rebuild switch --flake .#nix-k8s-master --target-host root@<tailscale-addr> --use-remote-sudo`.

### P4.W1.T3 — Sanity

```bash
ws$ ssh nix-k8s-master sudo \
        kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml get nodes
```

Expected: 1 node, master, Ready, version v1.30+.

### P4.W2 / P4.W3 — Workers

```bash
ws$ gleam run -m sys_scripts -- deploy apply nixos nix-k8s-worker-1 --execute
ws$ gleam run -m sys_scripts -- deploy apply nixos nix-k8s-worker-2 --execute
```

### P4.W4 — Kubeconfig

Add a new `sys secrets get kubeconfig` subcommand that:

1. `ssh master sudo cat /etc/rancher/k3s/k3s.yaml`
2. `yq '.clusters[0].cluster.server = "https://<tailscale-addr>:6443"'`
3. Prints to stdout.

Usage:

```bash
ws$ mkdir -p ~/.kube/configs
ws$ gleam run -m sys_scripts -- secrets get kubeconfig > ~/.kube/configs/nas1.yaml
ws$ chmod 600 ~/.kube/configs/nas1.yaml
ws$ kubectl --kubeconfig ~/.kube/configs/nas1.yaml get nodes
```

---

## P5 — Storage, ingress, GKE parity

### P5.W1 — Longhorn

On every host config, enable iscsi:

```nix
services.openiscsi = {
  enable = true;
  name = config.networking.hostName;
};
environment.systemPackages = with pkgs; [ openiscsi ];
```

Create `nix-configs/k3s/manifests/base/longhorn/`:

```bash
ws$ helm repo add longhorn https://charts.longhorn.io
ws$ helm template longhorn longhorn/longhorn \
      --namespace longhorn-system \
      --set defaultSettings.defaultDataPath=/var/lib/longhorn \
      > $REPO/nix-configs/k3s/manifests/base/longhorn/longhorn.yaml
```

Apply via the next `deploy apply` (adds a post-rebuild `kubectl apply`
step, or via GitOps later).

### P5.W2 — Ingress

Defer decision. If Traefik: re-enable via `extraFlags` on the k3s
server. If NGINX: `helm template` under
`nix-configs/k3s/manifests/base/ingress-nginx/`.

### P5.W3 — Gitea

```bash
ws$ helm template gitea gitea-charts/gitea \
      --namespace gitea \
      --set postgresql.enabled=true \
      --set service.http.type=ClusterIP \
      --set ingress.enabled=true \
      > $REPO/nix-configs/k3s/manifests/base/gitea/gitea.yaml
ws$ kubectl --context nas1 apply -k $REPO/nix-configs/k3s/manifests/overlays/nas1
```

### P5.W4 — GKE parity smoke

```bash
ws$ nix run nixpkgs#kind -- create cluster --name sys-parity
ws$ kubectl --context kind-sys-parity apply -k $REPO/nix-configs/k3s/manifests/overlays/gke
ws$ kubectl --context kind-sys-parity get pods -A
```

Any manifest diffs go into `docs/gke-parity.md`.

---

## Per-phase commit discipline

Each **workstream** is a single commit if it fits in one logical
change. Each **task** is a commit if the workstream is large (e.g.
P3.W3 is 5 host-config edits; one commit is fine).

Commit messages follow the existing pattern: conventional commits +
body explaining intent. The pre-commit hook (`sys check --fast`)
gates every commit.

After each phase completes, append a **status** line to
`plans/README.md`'s tracker table and update
`docs/nixos-k8s-plan.md`'s Status header with the current phase.
