defmodule Indrajaal.Cockpit.Prajna.Supervisor do
  @moduledoc """
  PRAJNA C3I Mesh Cockpit - Supervisor

  WHAT: Supervision tree for the PRAJNA AI-Enhanced Cockpit system.

  WHY: Ensures fault-tolerant operation of all cockpit components with
       proper restart strategies for safety-critical monitoring.

  ## Supervision Tree

  ```
  Prajna.Supervisor
  ├── Prajna.SmartMetrics       - Real-time metric collection
  ├── Prajna.GitMetricsBridge    - Git Intelligence → SmartMetrics bridge
  ├── Prajna.SentinelBridge     - Sentinel ↔ SmartMetrics sync (30s)
  ├── Prajna.PrometheusVerifier - PROMETHEUS proof-token verification
  ├── Prajna.ImmutableState     - Cryptographic state chain
  ├── Prajna.DualChannel        - SIL-4 dual-channel verification (SC-REG-007)
  ├── Prajna.Watchdog           - Independent heartbeat monitor (SC-PRIME-001)
  ├── Prajna.AiCopilot          - AI intelligence engine
  ├── Prajna.Orchestrator       - Main cockpit state machine
  ├── Prajna.Immune.Mara            - Adversarial chaos agent
  ├── Prajna.Immune.AntibodySupervisor - Dynamic Antibody spawner
  ├── Prajna.AlarmsIntegration      - Alarms domain integration (L11)
  ├── Prajna.AccessControlIntegration - Access Control domain integration (L12)
  ├── Prajna.GuardianIntegration    - Guardian safety kernel integration (L13)
  ├── Prajna.SentinelIntegration    - Sentinel/Immune system integration (L14)
  ├── Prajna.VideoIntegration       - Video domain integration (L15)
  ├── Prajna.DevicesIntegration     - Devices domain integration (L16)
  ├── Prajna.AnalyticsIntegration   - Analytics domain integration (L17)
  ├── Prajna.ComplianceIntegration  - Compliance domain integration (L18)
  └── Prajna.InfraIntegration       - Infrastructure and tree status (L19)
  ```

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-27 |
  | Author | Cybernetic Architect |
  | STAMP | SC-AGT-020 (Actor Isolation) |
  """

  use Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl Supervisor
  def init(opts) do
    children = [
      # L0: Centralized Configuration (SC-CONFIG-001)
      {Indrajaal.Cockpit.Prajna.Config, opts},
      # L1: Core metrics collection
      {Indrajaal.Cockpit.Prajna.SmartMetrics, opts},
      # L1.5: Git Intelligence → SmartMetrics bridge (SC-BRIDGE-003, SC-BIO-EXT-001)
      {Indrajaal.Cockpit.Prajna.GitMetricsBridge, opts},
      # L2: Sentinel integration (SC-PRAJNA-004)
      {Indrajaal.Cockpit.Prajna.SentinelBridge, opts},
      # L3: PROMETHEUS verification (SC-PROM-001)
      {Indrajaal.Cockpit.Prajna.PrometheusVerifier, opts},
      # L4: Immutable state chain (SC-REG-001)
      {Indrajaal.Cockpit.Prajna.ImmutableState, opts},
      # L5: Dual-channel verification (SC-REG-007, SC-PRIME-001)
      {Indrajaal.Cockpit.Prajna.DualChannel, opts},
      # L6: Watchdog timer (SC-PRIME-001, AOR-CONST-002)
      {Indrajaal.Cockpit.Prajna.Watchdog, opts},
      # L7: AI copilot with Founder validation (SC-PRAJNA-002)
      {Indrajaal.Cockpit.Prajna.AiCopilot, opts},
      # L8: Orchestrator (SC-PRAJNA-001)
      {Indrajaal.Cockpit.Prajna.Orchestrator, opts},
      # L9: Chaos testing (SC-IMMUNE-001)
      {Indrajaal.Cockpit.Prajna.Immune.Mara, opts},
      # L10: Antibody dynamic supervisor (SC-IMMUNE-001)
      {Indrajaal.Cockpit.Prajna.Immune.AntibodySupervisor, opts},
      # L11: Alarms domain integration (SC-PRAJNA-004)
      {Indrajaal.Cockpit.Prajna.AlarmsIntegration, opts},
      # L12: Access Control domain integration (SC-PRAJNA-004)
      {Indrajaal.Cockpit.Prajna.AccessControlIntegration, opts},
      # L13: Guardian safety kernel integration (SC-PRAJNA-004)
      {Indrajaal.Cockpit.Prajna.GuardianIntegration, opts},
      # L13.1: Guardian Circuit Breaker (SC-SIL4-001)
      {Indrajaal.Cockpit.Prajna.Guardian.CircuitBreaker, opts},
      # L14: Sentinel and Immune system integration (SC-PRAJNA-004)
      {Indrajaal.Cockpit.Prajna.SentinelIntegration, opts},
      # L15: Video domain integration (SC-PRAJNA-004)
      {Indrajaal.Cockpit.Prajna.VideoIntegration, opts},
      # L16: Devices domain integration (SC-PRAJNA-004)
      {Indrajaal.Cockpit.Prajna.DevicesIntegration, opts},
      # L17: Analytics domain integration (SC-PRAJNA-004)
      {Indrajaal.Cockpit.Prajna.AnalyticsIntegration, opts},
      # L18: Compliance domain integration (SC-PRAJNA-004)
      {Indrajaal.Cockpit.Prajna.ComplianceIntegration, opts},
      # L19: Infrastructure and tree status (SC-PRAJNA-004)
      {Indrajaal.Cockpit.Prajna.InfraIntegration, opts}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
