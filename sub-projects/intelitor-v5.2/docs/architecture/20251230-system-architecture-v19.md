# Indrajaal System Architecture v19.0 (Unified)

**Date**: 20251230-0010 CEST
**Status**: ACTIVE DESIGN
**Layering**: Fractal Holonic Architecture

---

## 1.0 The Fractal Holon (The Atom)
Every component in the system adheres to this structure:

```elixir
defmodule Indrajaal.Core.Holon do
  # System 1: Operations (The Doing)
  # - The actual business logic (e.g., Video Processing, Database Write)
  # - Highly optimized, potentially Rust NIFs.

  # System 2: Coordination (The Balancing)
  # - Anti-oscillation (Jitter)
  # - Mycelial Gossip (State sharing)

  # System 3: Control (The Guard)
  # - Resource Limits (Compute Credits)
  # - Active Inference (Surprise Minimization)

  # System 4: Intelligence (The Future)
  # - Simulation (Monte Carlo)
  # - Planning (Genetic Optimization)

  # System 5: Policy (The Identity)
  # - Cryptographic DNA Verification
  # - STAMP Safety Constraints
end
```

---

## 2.0 The Neural Network (The Connections)

### 2.1 The Unified Control Bus (Zenoh)
*   **Event Sourcing**: All messages persisted for Time Travel.
*   **Priority Lanes**: P0 (Safety) > P1 (Ops) > P2 (Logs).

### 2.2 The Mycelial Mesh (Tailscale)
*   **Discovery**: Zero-config peer finding.
*   **Holography**: Every node holds a low-res copy of the Global State.

---

## 3.0 The Cortex (The Brain)

### 3.1 Prajna (AI)
*   **Local**: Flash-Lite (Fast, on-device).
*   **Global**: Pro (Deep reasoning, expensive).
*   **Function**: Intent Parsing, Anomaly Detection, Code Generation.

### 3.2 The Guardian (Safety Kernel)
*   **Nature**: Deterministic, Agda-Verified.
*   **Function**: Vetoes unsafe AI proposals. Enforces Constitution.

---

## 4.0 The Body (Infrastructure)

### 4.1 CEPAF (Genetic Engine)
*   **Language**: F# DSL.
*   **Function**: Evolves container configs via genetic algorithms.

### 4.2 Jain Node (Viral Substrate)
*   **Capability**: Self-bootstrapping from bare metal.
*   **Constraint**: Cryptographically bound to the Safety Constitution.

---

## 5.0 The Interface (The Senses)

### 5.1 Proprioceptive Cockpit
*   **Input**: Entropy Heatmaps, Particle Flows.
*   **Output**: Intent-Based Commands ("Fix this").

---

## 6.0 Data Flow

$$ \text{Sensor} \to \text{Active Inference} \to \text{Surprise?} \to \text{Cortex (Plan)} \to \text{Guardian (Veto/Approve)} \to \text{Holon (Act)} $$

```