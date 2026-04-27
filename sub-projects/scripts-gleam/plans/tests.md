# Test Plan

Layered verification for every phase. Runs exactly two ways:

- **Automated** — `gleam run -m sys_scripts -- check` and its
  extensions. Machine-verifiable; gates every commit.
- **Manual** — `ws$ ...` blocks in this doc that a human runs and
  visually confirms. Reserved for steps that cross the
  workstation↔VM boundary (SSH, physical console).

Every test has a **setup**, a **command**, and an **assertion** —
the thing you compare the output against. Tests are labelled with
the plan task they verify (`P{phase}.W{workstream}.T{task}`).

## Test layers

| Layer | Where | Speed | Purpose |
|-------|-------|-------|---------|
| L1 — unit | `crates/sysctl/src/**.rs`, `scripts/test/*.gleam` | <5s | Pure functions: parsers, formatters, builders. |
| L2 — integration | `scripts/test/*.gleam` with `shellout`, rust `tests/*.rs` with `tempfile` | <60s | One tool + real IO, no network. |
| L3 — system | `sys check` full suite | <2min | Every language's toolchain, against the real tree. |
| L4 — acceptance | Manual `ws$` / `ssh` blocks in this doc | minutes–hours | Asserts observable cluster state. |

Pre-commit hook runs L1+L2 (`sys check --fast`). CI runs L1+L2+L3.
L4 is gated by phase completion.

---

## Shared fixtures

All L1/L2 tests rely on these repo-local fixtures:

| Path | Contents |
|------|----------|
| `crates/sysctl/src/skills.rs` inline `stage_skill` helper | `tempfile::TempDir` + synthesized `SKILL.md`. |
| `.pi/skills/` | Real 8-skill tree; `sysctl skills list` integration asserts discovery here. |
| `nix-configs/hosts/nas1/*/configuration.nix` | Real NixOS configs; `nix eval` asserts evaluation. |

Nothing else. Do **not** add a test-only fixture directory at the
repo root; prefer `tempfile` for throwaway data.

---

## Verifying P1 — NixOS on VMs

### P1.W1.T4 — L4 acceptance: VM is installed NixOS

Setup: master has been rebooted off the ISO.

```bash
ws$ ssh nix-k8s-master 'hostname'
nix-k8s-master

ws$ ssh nix-k8s-master 'nixos-version'
24.05.XXXX.<hash> (Uakari)

ws$ ssh nix-k8s-master 'readlink /run/current-system'
/nix/store/<hash>-nixos-system-nix-k8s-master-24.05...
```

Assertion: all three commands succeed via ssh, return sane values.

Failure modes and fixes:

| Failure | Likely cause | Fix |
|---------|--------------|-----|
| `ssh: Connection refused` | sshd not enabled in stub | Re-`nixos-install` with `services.openssh.enable = true` |
| `Permission denied (publickey)` | admin pubkey not in stub | Paste pubkey into `configuration.nix`, re-install |
| Wrong hostname | stub copy-paste error | `ssh` via IP, `nixos-rebuild switch` after correcting the stub |

### P1.W4.T3 — L3 system: full `sys check`

Setup: all three `hardware-configuration.nix` files committed and
imports un-commented.

```bash
ws$ cd $REPO/scripts
ws$ gleam run -m sys_scripts -- check
```

Assertion: final line reads `summary: 6 passed, 0 failed`. Any
failure here blocks P2.

### P1.W4.T4 — L3 system: `deploy plan` per host

```bash
ws$ for h in nix-k8s-master nix-k8s-worker-1 nix-k8s-worker-2; do
      gleam run -m sys_scripts -- deploy plan nixos "$h"
    done
```

Assertion per host: JSON contains `"system": "x86_64-linux"` and
`"k3sRole"` matches expectation (`server` for master, `agent` for
workers).

Grep one-liner:

```bash
ws$ gleam run -m sys_scripts -- deploy plan nixos nix-k8s-master \
    | grep -oE '"k3sRole": "[a-z]+"'
"k3sRole": "server"
```

---

## Verifying P2 — Mesh & inventory

### P2.W1.T3 — L3 system: tailscale module compiles

```bash
ws$ gleam run -m sys_scripts -- check
```

Assertion: `nix eval (devShell + nixosConfigurations)` check still
passes. If the tailscale module has a syntax/type error, this check
fails with a readable location.

### P2.W1 — L4 acceptance: VM joins tailnet

Setup: a reusable tailscale authkey written temporarily into
`/var/lib/tailscale/authkey` on each VM (until P3 wires sops).

```bash
ws$ gleam run -m sys_scripts -- deploy apply nixos nix-k8s-master --execute
ws$ ssh nix-k8s-master 'tailscale status'
100.x.y.z  nix-k8s-master  <user>     linux  -
```

Assertion: node appears in the tailnet with a `100.` address and
status `idle` (no errors). Rerun on workers.

### P2.W2.T2 — L2 integration: flake evaluates with specialArgs

```bash
ws$ nix eval --json --no-write-lock-file \
      $REPO#nixosConfigurations.nix-k8s-master.config.networking.hostName \
    | jq -r .
nix-k8s-master
```

Assertion: value is a plain string (not a Nix error). Failure here
means `specialArgs = { inherit inventory; }` didn't plumb through
correctly.

### P2.W3 — L2 integration: targetHost defaults from inventory

```bash
ws$ nix eval --json --no-write-lock-file \
      $REPO#nixosConfigurations.nix-k8s-master.config.sys.deploy.targetHost \
    | jq -r .
root@100.x.y.z
```

Assertion: non-null, matches `inventory.hosts.nix-k8s-master.tailscaleAddr`
with `sshUser` prefix.

### P2.W4 — L1 unit + L2 integration: inventory command

L1 unit tests (to be added alongside `inventory.gleam`):

```gleam
pub fn parse_inventory_args_test() {
  parse([])         |> should.equal(Ok(List))
  parse(["list"])   |> should.equal(Ok(List))
  parse(["show","x"]) |> should.equal(Ok(Show("x")))
  parse(["show"])   |> should.equal(Error(MissingArgument))
}
```

L2 integration (runs `nix eval` end-to-end):

```bash
ws$ gleam run -m sys_scripts -- inventory list
nix-k8s-master     192.168.1.10     100.x.y.z   k3s-server
nix-k8s-worker-1   192.168.1.11     100.x.y.w   k3s-agent
nix-k8s-worker-2   192.168.1.12     100.x.y.v   k3s-agent
```

Assertion: 3 rows, correct roles, tailscale addresses populated.

---

## Verifying P3 — Secrets

### P3.W1.T1 — L4 acceptance: host age key derivation

```bash
ws$ ssh nix-k8s-master cat /etc/ssh/ssh_host_ed25519_key.pub \
      | nix run nixpkgs#ssh-to-age
age1...
```

Assertion: output begins with `age1`, no error.

### P3.W2.T2 — L2 integration: sops decrypts cluster.yaml

Setup: admin age key present at `~/.config/sops/age/keys.txt`.

```bash
ws$ nix run nixpkgs#sops -- -d $REPO/secrets/cluster.yaml
k3s-token: "aabbcc..."
tailscale-authkey: "tskey-auth-..."
```

Assertion: exit 0, yaml output, **not committed** to git in plaintext.

### P3.W3 — L3 system: `sys check` with secrets enabled

```bash
ws$ gleam run -m sys_scripts -- check
```

Assertion: full 6/6 pass. The `nix eval` step now evaluates
`config.sops.secrets.k3s-token.path`, which means the module
plumbing works even without the ciphertext present (sops-nix
defers decryption to activation time, not evaluation time).

### P3.W3 — L4 acceptance: k3s starts with decrypted token

Post-deploy (covered in P4 tests):

```bash
ws$ ssh nix-k8s-master \
      'sudo cat /var/lib/rancher/k3s/server/node-token | head -c 10 && echo'
K10...
```

Assertion: first bytes are `K10`, the sentinel for a k3s v2 token.
That proves sops-nix successfully decrypted + fed the token into
the service.

### P3.W4 — L1 unit: secrets parser

```gleam
pub fn parse_secrets_args_test() {
  parse(["list"])          |> should.equal(Ok(List))
  parse(["validate"])      |> should.equal(Ok(Validate))
  parse(["edit", "p.yaml"])|> should.equal(Ok(Edit("p.yaml")))
  parse(["edit"])          |> should.equal(Error(_))
}
```

### P3.W4 — L2 integration: validate picks up tamper

Setup: deliberately corrupt `secrets/cluster.yaml` (flip a byte in
the ciphertext).

```bash
ws$ gleam run -m sys_scripts -- secrets validate
error: failed to decrypt secrets/cluster.yaml
exit code: 1
```

Assertion: non-zero exit, clear message. Restore file afterward.

---

## Verifying P4 — K3s cluster

### P4.W1.T3 — L4 acceptance: single-node control plane

```bash
ws$ ssh nix-k8s-master \
      'sudo KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl get nodes'
NAME             STATUS   ROLES                  AGE     VERSION
nix-k8s-master   Ready    control-plane,master   2m      v1.30.X+k3s1
```

Assertion: 1 Ready node, name matches host, role includes
`control-plane`.

### P4.W2 / P4.W3 — L4 acceptance: workers join

```bash
ws$ ssh nix-k8s-master \
      'sudo KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl get nodes'
NAME               STATUS   ROLES                  AGE    VERSION
nix-k8s-master     Ready    control-plane,master   10m    v1.30.X+k3s1
nix-k8s-worker-1   Ready    <none>                 2m     v1.30.X+k3s1
nix-k8s-worker-2   Ready    <none>                 1m     v1.30.X+k3s1
```

Assertion: 3 Ready nodes. STATUS columns all `Ready`. AGE is
monotonic with install order.

Failure modes:

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Worker stuck `NotReady` | Flannel VXLAN 8472/udp blocked | Confirm nftables rule from `k3s/agent.nix` loaded |
| Worker never appears | Token mismatch | `sops -d secrets/cluster.yaml` — compare to `/var/lib/rancher/k3s/server/node-token` on master |
| `unable to recognize "..."` | kubectl version drift | Use `ssh master kubectl` instead of workstation kubectl for now |

### P4.W4 — L4 acceptance: kubeconfig works from workstation

```bash
ws$ gleam run -m sys_scripts -- secrets get kubeconfig \
      > ~/.kube/configs/nas1.yaml
ws$ chmod 600 ~/.kube/configs/nas1.yaml
ws$ KUBECONFIG=~/.kube/configs/nas1.yaml kubectl get nodes
NAME               STATUS   ROLES                  AGE   VERSION
nix-k8s-master     Ready    control-plane,master   15m   v1.30.X+k3s1
nix-k8s-worker-1   Ready    <none>                 7m    v1.30.X+k3s1
nix-k8s-worker-2   Ready    <none>                 6m    v1.30.X+k3s1
```

Assertion: identical `kubectl get nodes` output as the on-master
version. Different server URL in the yaml — but the cluster behind
it is the same.

---

## Verifying P5 — Storage, ingress, GKE parity

### P5.W1 — L4 acceptance: Longhorn healthy

```bash
ws$ kubectl --context nas1 -n longhorn-system get pods
NAME                                                READY   STATUS    RESTARTS   AGE
engine-image-ei-<hash>-<node>                       1/1     Running   0          ...
instance-manager-<hash>                             1/1     Running   0          ...
longhorn-driver-deployer-<hash>                     1/1     Running   0          ...
longhorn-manager-<hash>                             1/1     Running   0          ...
longhorn-ui-<hash>                                  1/1     Running   0          ...
csi-attacher-<hash>                                 1/1     Running   0          ...
csi-provisioner-<hash>                              1/1     Running   0          ...
csi-resizer-<hash>                                  1/1     Running   0          ...
csi-snapshotter-<hash>                              1/1     Running   0          ...
```

Assertion: every pod `Running` with `1/1` ready. `longhorn-manager`
should have one replica per node (3 total).

### P5.W1.T4 — L4 acceptance: PVC bind smoke

```bash
ws$ cat <<EOF | kubectl --context nas1 apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: smoke
  namespace: default
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
  storageClassName: longhorn
EOF
ws$ kubectl --context nas1 get pvc smoke
NAME    STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS
smoke   Bound    pvc-<uuid>                                 1Gi        RWO            longhorn
```

Assertion: `STATUS = Bound` within 30 seconds.

```bash
ws$ kubectl --context nas1 run smokepod --rm -it --image=busybox \
      --overrides '{ "spec": { "volumes": [{"name":"v","persistentVolumeClaim":{"claimName":"smoke"}}],
                               "containers":[{"name":"c","image":"busybox","stdin":true,"tty":true,"volumeMounts":[{"mountPath":"/data","name":"v"}]}] } }' \
      --command sh -- -c 'echo hello > /data/file && cat /data/file'
hello
```

Assertion: writes and reads back `hello`.

Tear down:
```bash
ws$ kubectl --context nas1 delete pvc smoke
```

### P5.W3 — L4 acceptance: Gitea pods Running

```bash
ws$ kubectl --context nas1 -n gitea get pods
NAME                         READY   STATUS    RESTARTS   AGE
gitea-0                      1/1     Running   0          ...
gitea-postgresql-0           1/1     Running   0          ...
```

Assertion: both pods `Running`. Persist across a pod delete:

```bash
ws$ kubectl --context nas1 -n gitea delete pod gitea-0
ws$ kubectl --context nas1 -n gitea wait --for=condition=Ready pod/gitea-0 --timeout=120s
pod/gitea-0 condition met
```

Then open Gitea via the ingress, confirm the pre-restart state (a
test repo) survived.

### P5.W4 — L4 acceptance: GKE parity

```bash
ws$ nix run nixpkgs#kind -- create cluster --name sys-parity
ws$ kubectl --context kind-sys-parity apply \
      -k $REPO/nix-configs/k3s/manifests/overlays/gke
ws$ kubectl --context kind-sys-parity get pods -A
```

Assertion: all pods eventually Running **or** the failures are
documented in `docs/gke-parity.md` as "expected differences"
(e.g. `kind` doesn't have a LoadBalancer controller; a pending
LB service is acceptable).

Tear down:
```bash
ws$ nix run nixpkgs#kind -- delete cluster --name sys-parity
```

---

## Regression budget

After each phase lands, **every prior phase's L1/L2/L3 tests must
still pass**. L4 tests are phase-scoped — you don't re-verify "VM
boots NixOS" after P5 unless something changed.

The CI job (`.github/workflows/check.yml`) runs L3 (`sys check`
full) on every push. If CI goes red, revert before doing anything
else.

---

## Adding a new test

When you add a new `sys` subcommand or a new Rust module:

1. **L1 unit** goes next to the code (`#[cfg(test)] mod tests`
   in Rust, `*_test.gleam` in Gleam).
2. **L2 integration** uses real IO but throwaway state (`TempDir`,
   `simplifile` against a temp dir, `shellout` against `echo`/
   `true`).
3. **L3 system** is added to `commands/check.gleam`'s `enumerate`
   function with an appropriate `slow:` flag.
4. **L4 acceptance** — if applicable — lands here in `tests.md`
   with a task ID tying it back to `plan.md`.

Every layer should have at least one test for any behaviour that
a user can trigger. If a layer is empty for a feature, explain why
in the commit message.
