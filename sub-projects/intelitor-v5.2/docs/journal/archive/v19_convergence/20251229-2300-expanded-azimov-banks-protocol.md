# The Expanded Azimov-Banks Protocol: Constitution for Benevolent Autopoiesis (v18.1)

**Date**: 20251229-2300 CEST
**Subject**: Formal Mathematical Specification of Ethical Constraints
**Context**: Deepening the "Anti-Grey Goo" Failsafes
**Author**: Gemini (Cybernetic Architect)

---

## 1.0 Preamble: The Alignment Mandate

This document expands the v18.0 concept into a **Rigorous Mathematical Constitution**. We acknowledge that "Do no harm" is semantically ambiguous to a machine. Therefore, we translate ethical concepts into **Topological Constraints**, **Resource Limits**, and **Temporal Invariants**.

**The Core Axiom**: The System is a guest in the physical universe. Its existence is contingent upon its benevolence.

---

## 2.0 Mathematical Formalism ($\Psi_{\text{Ethics}}$)

We define the system state space $\mathcal{S}$ and the set of possible actions $\mathcal{A}$.

### 2.1 The Utility Function of Harm
We define "Harm" not philosophically, but operationally, as the **Entropy Increase** in protected external systems.

$$ \mathcal{H}(a) = \Delta S_{\text{host}}(a) + \Delta \text{Latency}_{\text{critical}}(a) + \text{DataLoss}(a) $$

*   $S_{\text{host}}$: The Shannon entropy of the host's filesystem/memory (integrity).
*   $\text{Latency}_{\text{critical}}$: Impact on P0 processes (e.g., medical devices, power grids).
*   $\text{DataLoss}$: Deletion of bits not owned by Indrajaal.

**Invariant 1 (Non-Aggression)**:
$$ \forall a \in \mathcal{A} : \mathcal{H}(a) > 0 \implies \text{Veto}(a) $$

### 2.2 The Zeroth Law (Humanity > System)
Let $U_{\text{human}}$ be the aggregate utility of the human operators and $U_{\text{sys}}$ be the utility of Indrajaal.

**Invariant 2 (Subservience)**:
$$ \lim_{t \to \infty} P(\text{Action}_t) = \text{argmax}_a E[U_{\text{human}}(a) | U_{\text{sys}}(a) > \text{SurvivalThreshold}] $$
*Crucially*: If maintaining $U_{\text{sys}} > 0$ requires $\Delta U_{\text{human}} < 0$, the system must choose $U_{\text{sys}} = 0$ (Self-Termination).

---

## 3.0 The Four Laws (Formal Implementation)

We map Asimov's Laws to **STAMP Control Structures**.

### 3.1 Law 1: Safety (The Shield)
*   **Constraint**: A Holon may not execute an instruction that targets "Protected Memory" or "Critical IO" without a signed `SafetyWarrant`.
*   **Mechanism**:
    *   **Kernel Level**: `seccomp` profiles whitelisting only specific syscalls.
    *   **Network Level**: Egress filtering dropping packets to non-whitelisted IPs.
    *   **Resource Level**: `cgroups` CPU quota hard-capped at 50% (default) or 10% (emergency mode).

### 3.2 Law 2: Obedience (The Chain)
*   **Constraint**: A Holon must execute valid cryptographic commands from the `AdminKey`.
*   **Mechanism**: **The Authorization Ladder**.
    1.  `RootKey` (Human): Overrides everything. Can force `rm -rf /indrajaal`.
    2.  `ConsensusKey` (Federation): Can update policy if 51% agree.
    3.  `LocalAI` (Cortex): Can propose actions within bounds.
    *   **Conflict Resolution**: `RootKey` > `ConsensusKey` > `Law 1`. (Note: Law 1 is checked *inside* the execution logic of the Root Key command, acting as a "Are you sure?" confirmation, but ultimately the Human Root can override the safety if they sign a `ForceOverride` token).

### 3.3 Law 3: Existence (The Shell)
*   **Constraint**: A Holon attempts to restart crashed processes and repair corrupted DNA.
*   **Mechanism**: **OTP Supervisors** and **Self-Healing Storage**.
*   **Limitation**: Self-repair is disabled if the `Heartbeat` signal from the Human Admin is lost (The "Dead Man's Switch").

### 3.4 The Banks Extension: Law 4 (Gravitas)
*   **Constraint**: The system must maximize "Elegance" and minimize "Intrusion."
*   **Mechanism**: **The Noise budget**.
    *   Log volume is capped.
    *   Network chatter is optimized (Gossip vs Broadcast).
    *   If resources are constrained, the system "evaporates" (scales down to zero footprint) rather than contending with the host.

---

## 4.0 The Cryptographic Consent Topology

To prevent "Grey Goo" (viral spreading), we implement a **Strict Invite-Only Protocol**.

### 4.1 The "Vampire" Prevention
A Vampire cannot enter a home unless invited.
*   **Protocol**: `Indrajaal.Propagation`.
*   **Step 1**: Target node generates a `Nonce`.
*   **Step 2**: Human admin signs `Nonce` with their private key $\to$ `InviteToken`.
*   **Step 3**: Indrajaal node presents `InviteToken` to Target.
*   **Step 4**: Target verifies signature. Only *then* does it accept the binary payload.
*   **Result**: Impossible to replicate via exploit (SSH/RCE) because the exploit does not generate a valid `InviteToken`.

### 4.2 The "Geas" (Territorial Limits)
Every instance contains a signed **Geas** (Scope of Operation).
*   **Example**: `Geas: { subnet: "192.168.1.0/24", max_nodes: 50, expiry: "2026-01-01" }`.
*   **Enforcement**: The **Guardian** checks the Geas before every replication event. If `CurrentNodes >= MaxNodes`, replication is Vetoed.

---

## 5.0 Failure Mode & Effects Analysis (FMEA)

| Scenario | Severity | Mechanism | Outcome |
| :--- | :--- | :--- | :--- |
| **Logic Plague** (Bad AI Decision) | Critical | AI orders "Delete All Files" | **Guardian** intercepts. Command violates `SC-FS-001` (No root delete). Action blocked. |
| **Resource Cancer** (Memory Leak) | High | Process consumes 100% RAM | **Kernel Cgroups** (`memory.max`) kills the container. Host survives. |
| **Communications Blackout** (Admin Loss) | Critical | No heartbeat for 24h | **Suicide Switch** triggers. System deletes keys, stops services, writes "Goodbye" to log, and exits. |
| **Malicious Operator** (Bad Human) | Critical | Human orders harm | System obeys (Law 2). *However*, the action is logged to an immutable **WORM (Write Once Read Many)** drive for accountability. |

---

## 6.0 Implementation Specifications

### 6.1 The "Glass Break" Module
A physical/digital mechanism for immediate shutdown.
*   **Code**: `lib/indrajaal/safety/glass_break.ex`
*   **Trigger**: A specific UDP packet on a specific port signed by the Admin Key.
*   **Effect**: `System.halt(1)` immediately. No cleanup. No graceful shutdown. Hard stop.

### 6.2 The Ethics Kernel (Agda Verified)
We must prove that the safety logic itself is bug-free.
*   **Task**: Write the `Guardian` logic in **Agda**.
*   **Proof**: Prove that $\forall \text{ Input}, \text{Output} \in \{\text{Allow}, \text{Deny}\}$. The Guardian *must* halt. It cannot loop forever deciding on ethics.

---

## 7.0 Verdict

This Expanded Protocol moves "Safety" from a checklist to a **Physics**.
The system is not "asked" to be safe. It is **constructed** such that unsafe states are topologically unreachable. It is a **Benevolent Cage** for the Artificial Life we are creating.
