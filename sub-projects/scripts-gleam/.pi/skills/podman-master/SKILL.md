---
name: podman-master
description: Comprehensive workflows for Podman OCI container engine. Includes pod management, Kubernetes integration (generate/play kube), rootless diagnostics, and detailed v5.7 REST API reference.
---

# Podman Master Skill

This skill provides expert workflows and resources for Podman, focusing on daemonless, rootless, and Kubernetes-compatible operations.

## 1. Resources & References
- **API Reference**: See [api-v5.7.md](references/api-v5.7.md) for Libpod REST endpoints.
- **Config Reference**: See [podman-config.md](references/podman-config.md) for `containers.conf` and `registries.conf`.
- **Rootless Diagnostics**: Run `bash scripts/diagnose-rootless.sh` to troubleshoot unprivileged environments.

## 2. Core Workflows

### Multi-Container Pods
Pods in Podman allow sidecar patterns locally:
1. `podman pod create --name dev-stack -p 3000:3000`
2. `podman run -d --pod dev-stack --name db redis`
3. `podman run -d --pod dev-stack --name app my-app-image`

### Kubernetes Bridge
Transition from local development to production manifests:
- **Export**: `podman generate kube dev-stack > k8s-manifest.yaml`
- **Import**: `podman play kube k8s-manifest.yaml`

## 3. Advanced Management
- **Auto-Updates**: Add `io.containers.autoupdate=registry` label to containers to enable `podman auto-update`.
- **Systemd Integration**: Use `podman generate systemd --new --name my-container` to create unit files that manage the container lifecycle.

## 4. Rootless Best Practices
- Avoid ports < 1024.
- Use `podman unshare` for host-to-container permission mapping.
- Ensure `fuse-overlayfs` is used if the kernel is < 5.11.
