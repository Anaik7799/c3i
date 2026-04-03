# Journal Entry: Unified SIL-6 Service & Interface Index

**Date:** March 24, 2026
**Version:** v21.3.1-SIL6
**Author:** Gemini (Cybernetic Architect)
**Status:** COMPREHENSIVE INDEX FINALIZED
**Objective:** Provide a single, authoritative reference for all architectural planes, services, and web GUI interfaces within the Indrajaal ecosystem.

---

## 1. Architectural Service Map
This section details the background services and substrates that compose the Indrajaal organism.

### 🗄️ Data Plane (Authoritative Substrate)
| Service Name | Type | Container/Runtime | Role |
| :--- | :--- | :--- | :--- |
| **PostgreSQL 17** | Database | `indrajaal-db-prod` | Primary transactional storage for 19 Ash domains. |
| **TimescaleDB** | Extension | `indrajaal-db-prod` | High-performance time-series storage for Alarms/Metrics. |
| **SMRITI SQLite** | Local DB | BEAM / F# | Real-time holon state (OLTP) - authoritative source of truth. |
| **SMRITI DuckDB** | Analytical DB| BEAM / F# | Columnar evolution history and high-dimensional analytics. |
| **Redis** | Cache | `indrajaal-ex-app-1` | Distributed session state and PubSub buffer. |

### 🛰️ Control Plane (Zenoh Mesh)
| Service Name | Type | Container/Runtime | Role |
| :--- | :--- | :--- | :--- |
| **Zenoh Router 1-3** | Router | `zenoh-router-1..3` | 2oo3 voting mesh for distributed consensus. |
| **Zenoh NIF Proxy** | Rust/NIF | Elixir Wrapper | Substrate-level safety gate enforcing ProofTokens. |
| **CEPAF Bridge** | F# Service | `cepaf-bridge` | Orchestration link between Elixir and F#. |
| **MCP Server** | F# Service | `Cepaf.Sentinel.MCP`| High-speed agent interface for Claude/Gemini. |

### 🧠 Cognitive Plane (Cortex & Intelligence)
| Service Name | Type | Runtime | Role |
| :--- | :--- | :--- | :--- |
| **Synapse** | GenServer | Elixir | Central router for all AI/ML queries (Local & API). |
| **FastOODA** | GenServer | Elixir | Real-time sensor processing loop (20ms target). |
| **Drift Monitor** | GenServer | Elixir | Real-time KL Divergence calculation for homeostasis. |
| **Homeostasis** | GenServer | Elixir | Autonomic metabolic regulator (CPU/Memory/Queue). |
| **Vision Holon** | ML Service | `ml-runner-1..2` | Local YOLO-based object/threat detection. |
| **Digital Twin** | F# Holon | `indrajaal-chaya` | Predictive shadow simulation of the entire mesh. |

### 🛡️ Safety & Immune Plane (The Simplex Kernel)
| Service Name | Type | Runtime | Role |
| :--- | :--- | :--- | :--- |
| **Guardian** | GenServer | Elixir | Deterministic Safety Kernel; vetoes unsafe mutations. |
| **Sentinel** | GenServer | Elixir | Active threat hunter; manages quarantine and antibodies. |
| **Consensus Aggregator**| GenServer | Elixir | Unifies Elixir and F# integrity metrics. |
| **Prometheus Verifier** | Module | Elixir | Cryptographic ProofToken generator and DAG auditor. |

---

## 2. F# CEPAF Substrate Map (Infrastructure Plane)
Indrajaal's infrastructure is governed by the **CEPAF (Cybernetic Execution and Performance Architect)** framework, implemented in F# (net10.0).

### 🚀 Core Orchestration & Lifecycle
| Project | Role | Key Modules |
| :--- | :--- | :--- |
| **`Cepaf`** | Primary Mesh Orchestrator | `PanopticonOrchestrator`, `ServiceDAG`, `ChainVerifier`, `AOREngine`. |
| **`Cepaf.Podman`** | Container Substrate Driver | `PodmanClient`, `VolumeManager`, `NetworkEnforcer`. |
| **`Cepaf.Config`** | Distributed Configuration | `ComposeGenerator`, `MeshConfig`, `ConfigBridge`. |
| **`Cepaf.Bridge`** | Elixir-F# RPC Link | `Server`, `PortHandler`, `JsonRpc`. |

### 🧠 Planning & Evolution
| Project | Role | Key Modules |
| :--- | :--- | :--- |
| **`Cepaf.Planning`** | Authoritative Task Substrate | `Manager`, `Repository`, `EvolutionObservability`, `SafetyKernel`. |
| **`Cepaf.Evolution.Service`** | Morphogenic Analytics | `MutationTracker`, `DriftAnalyzer`. |
| **`Cepaf.GitIntelligence`** | Mutation Lineage | `Provenance`, `CommitSigner`, `LineageAudit`. |

### 🖥️ HMI & Cockpit
| Project | Role | Key Modules |
| :--- | :--- | :--- |
| **`Cepaf.Cockpit`** | Unified UI Logic | `DarkCockpitUI`, `SituationalAwareness`, `AiCopilot`, `SmartMetrics`. |
| **`Cepaf.Cockpit.Avalonia`** | Cross-Platform Desktop GUI | `App`, `MainWindow`, `ViewDispatcher`. |
| **`Cepaf.Cockpit.CLI`** | TUI / Command-Line HMI | `PanopticonTui`, `CommandParser`. |
| **`Cepaf.Sentinel.MCP`** | Agent Control Plane | `ZenohTools`, `EvolutionTools`, `McpProtocol`. |

### 🗃️ Knowledge & SMRITI (L7)
| Project | Role | Key Modules |
| :--- | :--- | :--- |
| **`Cepaf.Smriti.Semantic`** | Fractal Knowledge Engine | `VectorSimilarity`, `TripleStore`, `QueryEngine`, `VirtualGraph`. |
| **`Cepaf.Knowledge`** | Knowledge Graph Ingest | `ZettelParser`, `LinkResolver`. |
| **`Cepaf.Holon`** | State Serialization | `HolonStore`, `VersionVector`. |
| **`Semantic.Bridge`** | Auxiliary SMRITI Bridge | `ZettelProcessor`, `VectorSearch`. |
| **`Cepaf.Immune`** | F# Digital Immune System | `Mara` (Chaos engineering & recovery logic). |

---

## 3. Web GUI Interface Index (Port 4000)
The primary human-machine interface (HMI). All links are relative to `http://localhost:4000`.

### 🧠 Prajna C3I Mesh Cockpit
| Interface Name | Route | Purpose |
| :--- | :--- | :--- |
| **Unified Cockpit** | `/cockpit` | Main dashboard combining all C3I elements. |
| **Mesh Topology** | `/cockpit/mesh` | Real-time graph of the 14-node biomorphic mesh. |
| **Alarm Center** | `/cockpit/alarms` | Advanced alarm management (d-prime detection). |
| **Health Sparklines** | `/cockpit/health-sparklines` | Real-time Biomorphic Vital Signs (sub-50ms). |
| **Sentinel Dashboard** | `/cockpit/sentinel` | Threat hunting and antibody status. |
| **Guardian Dashboard** | `/cockpit/guardian` | Safety Kernel policy enforcement monitoring. |
| **Knowledge Graph** | `/cockpit/knowledge` | SMRITI-backed fractal knowledge base. |
| **Git Intelligence** | `/cockpit/git-intelligence` | Evolution lineage and mutation traceability. |
| **AI Copilot** | `/cockpit/ai-copilot` | Agent-mediated system orchestration chat. |

### 🚔 Operations Center
| Interface Name | Route | Purpose |
| :--- | :--- | :--- |
| **Active Alarms** | `/operations/alarms` | Front-line tactical alarm response view. |
| **Alarm Investigation** | `/operations/alarms/:id` | Forensic deep-dive into specific security incidents. |
| **Access Dashboard** | `/operations/access` | Live monitoring of sites, zones, and entry points. |
| **Video Wall** | `/operations/video` | High-density streaming matrix for vision holons. |
| **Dispatch Console** | `/operations/dispatch` | Emergency responder coordination and command. |

---

## 3. Infrastructure & Observability Endpoints
Specialized interfaces for substrate monitoring and developer introspection.

| Service / Tool | Port | Web UI Links | Purpose |
| :--- | :--- | :--- | :--- |
| **Digital Twin** | **4002** | `/` | Shadow simulation of task distribution and mesh health. |
| **Zenoh Control** | **8000** | `/`, `/info`, `/sessions` | Runtime mesh topology and link metrics. |
| **Grafana / SigNoz**| **3000** | `/` | Visualizer for distributed traces and quantitative metrics. |
| **Prometheus** | **9090** | `/` | Direct time-series query interface and alerts. |
| **Loki** | **3100** | `/` | Web interface for distributed log exploration. |
| **LiveDashboard** | **4000** | `/dev/dashboard` | Direct BEAM VM introspection (Dev only). |

---

## 4. Operational Invariants
- **High-Fidelity Bridge:** If mesh quorum is unstable, use `mcp sentinel-zenoh evolution_snapshot` for high-fidelity substrate data.
- **Visual Standard:** All interfaces comply with **NASA-STD-3000** visual density mandates.
- **Safety Protocol:** Destructive actions require the **Arm & Fire FSM** sign-off visible in the Guardian dashboard.

**Signature:** `0x7E...F4A` (Cybernetic Architect)
"Every service is indexed. Every interface is proven. Homeostasis is the foundation of sight."
