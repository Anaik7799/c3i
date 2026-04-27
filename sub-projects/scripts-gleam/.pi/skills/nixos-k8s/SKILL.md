---
name: nixos-k8s
description: Declarative workflows for deploying and managing Kubernetes (K3s/K8s) clusters on NixOS. Use this skill to configure services.k3s, manage multi-node deployments, and define declarative K8s manifests in Nix.
---

# NixOS Kubernetes Management

This skill provides declarative patterns for managing Kubernetes infrastructure on NixOS.

## 1. K3s Multi-Node Setup (Recommended)

### Server Node (Control Plane)
```nixos
services.k3s = {
  enable = true;
  role = "server";
  tokenFile = "/var/lib/secrets/k3s-token";
  extraFlags = "--disable traefik"; # Optional: use custom ingress
};
```

### Agent Node (Worker)
```nixos
services.k3s = {
  enable = true;
  role = "agent";
  serverAddr = "https://<server-ip>:6443";
  tokenFile = "/var/lib/secrets/k3s-token";
};
```

## 2. Declarative Manifests
Define Kubernetes resources directly in `configuration.nix`:
```nixos
services.k3s.manifests.my-app.content = {
  apiVersion = "v1";
  kind = "Pod";
  metadata.name = "nginx";
  spec.containers = [{ name = "nginx"; image = "nginx"; }];
};
```

## 3. Best Practices
- **Secrets**: Always use `tokenFile` pointing to a file managed by `sops-nix` or `agenix`.
- **Networking**: Ensure ports `6443` (API) and `8472` (Flannel) are open in `networking.firewall`.
- **Garbage Collection**: Enable `nix.gc` to prevent container image accumulation from filling the disk.
- **Air-Gap**: Use `services.k3s.images` to pre-load images into the Nix store.

## 4. Troubleshooting
- Check logs: `journalctl -u k3s`
- Verify context: `KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl get nodes`
