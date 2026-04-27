# Declarative NixOS Kubernetes Development Environment Plan

> **Status (2026-04-22)**: docs filed; layout for the declarative configs
> lives under [`../nix-configs/`](../nix-configs/). No NixOS modules
> written yet — Phase 1 (VM provisioning) is where the actual work starts.
> Load `/skill:nixos-architect` + `/skill:nixos-k8s` when implementing.

## 1. Background & Motivation
The goal is to establish a local, declarative Kubernetes (K8s) cluster on bare-metal hardware using **NixOS**. By leveraging NixOS's unique configuration-as-code approach, we ensure that the local development environment is perfectly reproducible. Once stabilized, the workloads will be migrated to Google Kubernetes Engine (GKE).

## 2. Hardware Overview (nas-1)
The host is a high-performance machine optimized for dense virtualization and AI workloads.

*   **Hypervisor:** XCP-ng 8.3.0 (Xen 4.17.5-13) with IOMMU enabled.
*   **CPU:** AMD Ryzen AI 9 HX PRO 370 (12 Cores / 24 Threads, Zen 5 Architecture).
*   **Memory:** 48 GB DDR5 RAM (~42.6 GB available for VMs).
*   **Storage Topology:**
    *   **NVMe:** 2x 1.8TB SSDs (Local storage for VM OS drives).
    *   **SATA:** 4x 3.7TB HDDs (Available for a large-scale ZFS or Longhorn storage pool).
*   **Networking:** 10Gbps Aquantia + 2.5Gbps Realtek.
*   **Graphics:** Integrated AMD Radeon 890M (Supports hardware acceleration).

## 3. Proposed Solution: NixOS + K3s
We will deploy a 3-node Kubernetes cluster where each node is a NixOS VM.

### 3.1 Architecture
*   **OS Base:** NixOS (Minimal) - All configurations managed via `configuration.nix`.
*   **Nodes:**
    *   `nix-k8s-master`: 2 vCPUs, 4GB RAM, 40GB Disk (Control Plane).
    *   `nix-k8s-worker-1`: 2 vCPUs, 4GB RAM, 40GB Disk.
    *   `nix-k8s-worker-2`: 2 vCPUs, 4GB RAM, 40GB Disk.
*   **K8s Distribution:** K3s (managed natively via the NixOS `services.k3s` module).
*   **Container Runtime:** `containerd` (default in NixOS/K3s).

## 4. Why NixOS?
*   **Reproducibility:** The entire cluster state is defined in a few `.nix` files.
*   **Atomic Rollbacks:** If a configuration change breaks the node, we can roll back instantly.
*   **Declarative Containers:** Container images and settings are versioned alongside the OS.

## 5. Phased Implementation Plan

### Phase 0: Documentation & Baseline
1.  Verify the `nas1-hardware-analysis.md` reflects the NixOS-centric strategy.
2.  Maintain a `nix-configs/` directory in the local workspace to store the declarative manifests.

### Phase 1: NixOS VM Provisioning (In Progress)
1.  **Status:** VMs `nix-k8s-master`, `nix-k8s-worker-1`, and `nix-k8s-worker-2` have been created and booted from the NixOS ISO.
2.  **Action:** Access the VM consoles to perform the initial NixOS installation using a standard `configuration.nix` that enables SSH and K3s.

### Phase 2: Declarative K3s Setup
1.  **Master Node:**
    *   Enable `services.k3s.enable = true;`.
    *   Set `services.k3s.role = "server";`.
    *   Configure firewall rules for K8s API (6443) and K3s communication.
2.  **Worker Nodes:**
    *   Enable `services.k3s.enable = true;`.
    *   Set `services.k3s.role = "agent";`.
    *   Set `services.k3s.serverAddr` and `services.k3s.tokenFile`.

### Phase 3: Storage & GKE Readiness
1.  **Persistent Storage:** Deploy Rancher Longhorn (managed via NixOS or Helm) to provide distributed block storage across the nodes, utilizing the 4x 3.7TB HDDs.
2.  **Ingress:** Use the built-in Traefik ingress controller to simulate GKE's LoadBalancer/Ingress behavior.

## 6. GKE Migration Strategy
1.  **Configuration:** Extract stable Kubernetes YAMLs from the NixOS environment.
2.  **Portability:** Since NixOS ensures the same version of K3s and utilities are used, the transition to GKE is a matter of `kubectl apply` with GKE-specific storage class updates.

## 7. Verification
*   `nixos-rebuild switch` completes without errors on all nodes.
*   `kubectl get nodes` shows all three NixOS nodes as `Ready`.
*   Pods are successfully scheduled and can persist data to the NVMe/SATA storage pools.