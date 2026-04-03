# 9-Level Cockpit Implementation Plan: GUI, TUI, WebUI (F#)

**Date**: 2026-01-17
**Author**: Claude Opus 4.5
**Status**: ACTIVE DEVELOPMENT
**Version**: 21.3.0-9L-IMPLEMENTATION-PLAN

---

## PART I: EXECUTIVE SUMMARY

This document presents a comprehensive **9-level detailed implementation plan** for the F# Cockpit across three presentation interfaces:

1. **Desktop GUI** (Avalonia + Fabulous)
2. **Terminal TUI** (Raw ANSI + PTY)
3. **Web UI** (F# Bolero/Fable - NOT Phoenix/Elixir)

**Critical Requirement**: Per user directive, the **WebUI MUST be implemented in F#**, using Bolero (F# on Blazor WebAssembly) to maintain language consistency and leverage the existing F# domain model.

---

## PART II: COMPLETE FEATURES INVENTORY

### 2.1 Core Features (All Interfaces)

| Feature ID | Feature Name | Description | Priority | Interfaces |
|------------|--------------|-------------|----------|------------|
| **F001** | Dashboard | System-wide health overview, KPIs, alerts | P0 | GUI, TUI, Web |
| **F002** | Alarms Management | ISA-18.2/EEMUA 191 alarm handling | P0 | GUI, TUI, Web |
| **F003** | Guardian Integration | Safety proposal approval/veto | P0 | GUI, TUI, Web |
| **F004** | Sentinel Monitoring | Threat detection, immune system | P0 | GUI, TUI, Web |
| **F005** | Test Evolution | OODA loop, genetic optimization | P1 | GUI, TUI, Web |
| **F006** | Video Analytics | CCTV, person tracking, VMS | P1 | GUI, Web |
| **F007** | Access Control | Permissions, policies, RBAC | P1 | GUI, TUI, Web |
| **F008** | Analytics/Reports | Trend analysis, report generation | P1 | GUI, Web |
| **F009** | Compliance | Audit trail, regulatory checks | P1 | GUI, Web |
| **F010** | AI Copilot | Chat interface, recommendations | P2 | GUI, Web |
| **F011** | Immutable Register | Blockchain verification | P2 | GUI, TUI, Web |
| **F012** | Devices (IoT) | Device status, control | P2 | GUI, TUI, Web |
| **F013** | Settings | Configuration, theming | P2 | GUI, TUI, Web |

### 2.2 Security Operations Features

| Feature ID | Feature Name | Description | Priority | Interfaces |
|------------|--------------|-------------|----------|------------|
| **S001** | IDS Integration | MITRE ATT&CK, STIX 2.1 | P0 | GUI, TUI, Web |
| **S002** | SIEM Correlation | Splunk, Elastic, Wazuh | P1 | GUI, Web |
| **S003** | Video-Alarm Correlation | Cross-sensor event fusion | P1 | GUI, Web |
| **S004** | Person Tracking | Re-identification, watchlist | P1 | GUI, Web |
| **S005** | Incident Timeline | Evidence package, audit | P1 | GUI, TUI, Web |

### 2.3 Domain-Specific Features

| Domain | Features | Standards | Priority |
|--------|----------|-----------|----------|
| **C3I/Military** | COP, Kill Chain, MIL-STD-2525D, ROE | MIL-STD-1472H | P1 |
| **DCS/SCADA** | Alarm Rationalization, P&ID, Historian | ISA-18.2, IEC 62443 | P1 |
| **Medical** | Patient ID, Alarm Fatigue Mitigation | IEC 62366, FDA 21 CFR 820 | P2 |
| **Aerospace** | Comm Latency, Resource Margins | ECSS-E-ST-10-11C | P2 |
| **Automotive** | Takeover Request, Glance-Based HMI | ISO 26262 ASIL-D | P2 |
| **Control Center** | Shift Handoff, Multi-Operator | ISO 11064 | P1 |

---

## PART III: INTERACTION ASPECTS MATRIX

### 3.1 Nine Interaction Aspects

| Level | Aspect | Description | Artifacts |
|-------|--------|-------------|-----------|
| **I1** | Constitutional | Ψ₀-Ψ₅ invariants, Ω₀ Founder's Directive | Proofs, constraints |
| **I2** | Safety | STAMP SC-* constraints (650+) | Safety cases, FMEA |
| **I3** | Operational | AOR-* rules (400+) | Runbooks, SOPs |
| **I4** | Human Factors | Cognitive load, SA (Endsley) | HF analysis |
| **I5** | Performance | Response time, latency budgets | SLA, metrics |
| **I6** | Accessibility | WCAG 2.1, color blindness | A11y tests |
| **I7** | Security | Auth, encryption, audit trail | Pen tests |
| **I8** | Testing | TDG, BDD, Property, Formal | Test suites |
| **I9** | Deployment | CI/CD, containers, rollback | Pipelines |

### 3.2 Features × Interactions Matrix

```
           │ I1  │ I2  │ I3  │ I4  │ I5  │ I6  │ I7  │ I8  │ I9  │
───────────┼─────┼─────┼─────┼─────┼─────┼─────┼─────┼─────┼─────┤
F001 Dash  │ ●   │ ●   │ ●   │ ●   │ ●   │ ●   │ ●   │ ●   │ ●   │
F002 Alarm │ ●   │ ●   │ ●   │ ●   │ ●   │ ●   │ ●   │ ●   │ ●   │
F003 Guard │ ●   │ ●   │ ●   │ ●   │ ●   │ ◐   │ ●   │ ●   │ ●   │
F004 Sent  │ ●   │ ●   │ ●   │ ●   │ ●   │ ◐   │ ●   │ ●   │ ●   │
F005 Evol  │ ○   │ ●   │ ●   │ ◐   │ ●   │ ◐   │ ◐   │ ●   │ ●   │
F006 Video │ ○   │ ●   │ ●   │ ●   │ ●   │ ◐   │ ●   │ ●   │ ●   │
F007 RBAC  │ ●   │ ●   │ ●   │ ◐   │ ◐   │ ●   │ ●   │ ●   │ ●   │
F008 Anlyt │ ○   │ ◐   │ ●   │ ◐   │ ●   │ ●   │ ◐   │ ●   │ ●   │
F009 Compl │ ●   │ ●   │ ●   │ ◐   │ ◐   │ ●   │ ●   │ ●   │ ●   │
F010 AI    │ ●   │ ●   │ ●   │ ●   │ ●   │ ◐   │ ●   │ ●   │ ●   │
F011 Reg   │ ●   │ ●   │ ◐   │ ○   │ ◐   │ ◐   │ ●   │ ●   │ ●   │
F012 IoT   │ ○   │ ●   │ ●   │ ◐   │ ●   │ ◐   │ ●   │ ●   │ ●   │
F013 Sett  │ ○   │ ◐   │ ●   │ ●   │ ○   │ ●   │ ◐   │ ●   │ ●   │
───────────┴─────┴─────┴─────┴─────┴─────┴─────┴─────┴─────┴─────┘
● = Critical  ◐ = Important  ○ = Optional
```

---

## PART IV: 9-LEVEL GUI IMPLEMENTATION PLAN (AVALONIA + FABULOUS)

### Level 1: Foundation (Week 1-2)

| Task ID | Task | Deliverable | STAMP |
|---------|------|-------------|-------|
| G1.1 | Project setup | Cepaf.Cockpit.Avalonia.fsproj | SC-NET-001 |
| G1.2 | MVU architecture | App.fs, Model.fs, Messages.fs | SC-HMI-001 |
| G1.3 | Theme system | DarkCockpitTheme.fs, Colors.fs | SC-HMI-007 |
| G1.4 | Navigation scaffold | NavigationRail.fs | SC-HMI-006 |
| G1.5 | Base widgets | Gauge.fs, StatusIndicator.fs | SC-HMI-004 |

### Level 2: Core Screens (Week 3-4)

| Task ID | Task | Deliverable | STAMP |
|---------|------|-------------|-------|
| G2.1 | Dashboard screen | DashboardView.fs | SC-HMI-002 |
| G2.2 | Health indicators | HealthGauge.fs, Sparkline.fs | SC-HMI-003 |
| G2.3 | Alarm list | AlarmListView.fs, AlarmCard.fs | SC-ALARM-001 |
| G2.4 | Guardian panel | GuardianView.fs, ProposalCard.fs | SC-PRAJNA-001 |
| G2.5 | Sentinel panel | SentinelView.fs, ThreatList.fs | SC-IMMUNE-001 |

### Level 3: Secondary Screens (Week 5-6)

| Task ID | Task | Deliverable | STAMP |
|---------|------|-------------|-------|
| G3.1 | Video wall | VideoWallView.fs, CameraGrid.fs | SC-VIDEO-001 |
| G3.2 | Analytics | AnalyticsView.fs, ChartComponents.fs | - |
| G3.3 | Compliance | ComplianceView.fs, AuditTrail.fs | SC-REG-001 |
| G3.4 | Access control | AccessControlView.fs | SC-SEC-001 |
| G3.5 | Test evolution | EvolutionView.fs, FitnessGauge.fs | SC-TEST-001 |

### Level 4: Domain Features (Week 7-8)

| Task ID | Task | Deliverable | STAMP |
|---------|------|-------------|-------|
| G4.1 | C3I COP view | CommonOperatingPicture.fs | SC-C3I-001 |
| G4.2 | SCADA mimic | MimicDiagram.fs, ProcessView.fs | SC-SCADA-001 |
| G4.3 | IDS integration | IDSPanel.fs, MitreMappings.fs | SC-SEC-002 |
| G4.4 | Device management | DeviceGrid.fs, DeviceDetail.fs | SC-IOT-001 |
| G4.5 | Settings panel | SettingsView.fs | - |

### Level 5: Advanced Visualization (Week 9-10)

| Task ID | Task | Deliverable | STAMP |
|---------|------|-------------|-------|
| G5.1 | Multi-monitor | MultiScreenManager.fs | SC-HMI-010 |
| G5.2 | Video-alarm fusion | CorrelationView.fs | SC-VIDEO-002 |
| G5.3 | Timeline/Gantt | TimelineView.fs | - |
| G5.4 | 3D situational | SituationalDisplay.fs | SC-HMI-008 |
| G5.5 | Graph visualization | NetworkGraph.fs | - |

### Level 6: Integration (Week 11-12)

| Task ID | Task | Deliverable | STAMP |
|---------|------|-------------|-------|
| G6.1 | Zenoh bridge | ZenohSubscriber.fs | SC-ZENOH-001 |
| G6.2 | HTTP REST client | ElixirBridge.fs | SC-SYNC-001 |
| G6.3 | Guardian RPC | GuardianClient.fs | SC-PRAJNA-001 |
| G6.4 | Sentinel RPC | SentinelClient.fs | SC-IMMUNE-004 |
| G6.5 | SMRITI persistence | SmritiClient.fs | SC-AI-001 |

### Level 7: Testing (Week 13-14)

| Task ID | Task | Deliverable | Count |
|---------|------|-------------|-------|
| G7.1 | Headless GUI tests | HeadlessGUITests.fs | 800 |
| G7.2 | Property tests | GUIPropertyTests.fs | 200 |
| G7.3 | Visual regression | ScreenshotBaselines/ | 100 |
| G7.4 | BDD scenarios | GUI.feature | 150 |
| G7.5 | MC/DC coverage | CoverageReport.xml | 95%+ |

### Level 8: Safety Validation (Week 15-16)

| Task ID | Task | Deliverable | STAMP |
|---------|------|-------------|-------|
| G8.1 | FMEA analysis | GUI_FMEA.md | SC-COV-005 |
| G8.2 | Quint model check | gui_safety.qnt | SC-PROM-004 |
| G8.3 | Response time proof | ResponseTimeProof.agda | SC-PRF-050 |
| G8.4 | Human factors eval | HF_Assessment.md | SC-HMI-001 |
| G8.5 | DO-178C artifacts | Traceability.xlsx | DAL-A |

### Level 9: Deployment (Week 17-18)

| Task ID | Task | Deliverable | STAMP |
|---------|------|-------------|-------|
| G9.1 | Container image | Dockerfile.gui | SC-CNT-009 |
| G9.2 | CI/CD pipeline | .github/workflows/gui.yml | - |
| G9.3 | Installation package | Installer.wix | - |
| G9.4 | Documentation | GUI_User_Guide.md | SC-DOC-001 |
| G9.5 | Release validation | ReleaseChecklist.md | SC-GA-001 |

---

## PART V: 9-LEVEL TUI IMPLEMENTATION PLAN (RAW ANSI)

### Level 1: Foundation (Week 1-2)

| Task ID | Task | Deliverable | STAMP |
|---------|------|-------------|-------|
| T1.1 | Terminal abstraction | Terminal.fs | SC-HMI-001 |
| T1.2 | ANSI renderer | AnsiRenderer.fs | SC-HMI-007 |
| T1.3 | Input handling | KeyboardInput.fs | SC-HMI-004 |
| T1.4 | Screen buffer | ScreenBuffer.fs | - |
| T1.5 | Color palette | TUIColors.fs | SC-HMI-007 |

### Level 2: Core Widgets (Week 3-4)

| Task ID | Task | Deliverable | STAMP |
|---------|------|-------------|-------|
| T2.1 | Text widgets | Label.fs, Box.fs | - |
| T2.2 | Sparklines | Sparkline.fs | SC-HMI-003 |
| T2.3 | Progress bars | ProgressBar.fs, SafetyBar.fs | SC-HMI-003 |
| T2.4 | Spider charts | SpiderChart.fs | - |
| T2.5 | Tables | Table.fs, DataGrid.fs | - |

### Level 3: Screen Layouts (Week 5-6)

| Task ID | Task | Deliverable | STAMP |
|---------|------|-------------|-------|
| T3.1 | Dashboard layout | TUIDashboard.fs | SC-HMI-002 |
| T3.2 | Alarm panel | TUIAlarmPanel.fs | SC-ALARM-001 |
| T3.3 | Guardian panel | TUIGuardianPanel.fs | SC-PRAJNA-001 |
| T3.4 | Sentinel panel | TUISentinelPanel.fs | SC-IMMUNE-001 |
| T3.5 | Status bar | StatusBar.fs | - |

### Level 4: Navigation (Week 7-8)

| Task ID | Task | Deliverable | STAMP |
|---------|------|-------------|-------|
| T4.1 | Screen cycling | ScreenManager.fs | - |
| T4.2 | Keyboard shortcuts | ShortcutHandler.fs | SC-HMI-006 |
| T4.3 | Help overlay | HelpOverlay.fs | - |
| T4.4 | Command palette | CommandPalette.fs | - |
| T4.5 | Two-key-turn | TKTHandler.fs | SC-HMI-004 |

### Level 5: Multi-Terminal (Week 9-10)

| Task ID | Task | Deliverable | STAMP |
|---------|------|-------------|-------|
| T5.1 | Tmux integration | TmuxIntegration.fs | SC-HMI-010 |
| T5.2 | Pane sync | PaneSync.fs | - |
| T5.3 | Remote session | SSHSupport.fs | SC-SEC-001 |
| T5.4 | Screen replay | SessionRecording.fs | - |
| T5.5 | Headless mode | HeadlessMode.fs | SC-TEST-001 |

### Level 6: Integration (Week 11-12)

| Task ID | Task | Deliverable | STAMP |
|---------|------|-------------|-------|
| T6.1 | Zenoh client | ZenohTUIClient.fs | SC-ZENOH-001 |
| T6.2 | HTTP client | HttpTUIClient.fs | SC-SYNC-001 |
| T6.3 | State sync | StateSynchronizer.fs | - |
| T6.4 | Event stream | EventStream.fs | - |
| T6.5 | Offline mode | OfflineCache.fs | - |

### Level 7: Testing (Week 13-14)

| Task ID | Task | Deliverable | Count |
|---------|------|-------------|-------|
| T7.1 | PTY automation | PTYTests.fs | 300 |
| T7.2 | Expect patterns | TUIExpectTests.fs | 150 |
| T7.3 | Property tests | TUIPropertyTests.fs | 100 |
| T7.4 | BDD scenarios | TUI.feature | 80 |
| T7.5 | Snapshot tests | TUISnapshots/ | 50 |

### Level 8: Safety Validation (Week 15-16)

| Task ID | Task | Deliverable | STAMP |
|---------|------|-------------|-------|
| T8.1 | FMEA analysis | TUI_FMEA.md | SC-COV-005 |
| T8.2 | Response time | ResponseTimeTests.fs | SC-PRF-050 |
| T8.3 | Accessibility | TUIAccessibility.md | SC-HMI-011 |
| T8.4 | Degraded mode | DegradedModeTests.fs | SC-EMR-057 |
| T8.5 | Recovery test | RecoveryTests.fs | SC-EMR-060 |

### Level 9: Deployment (Week 17-18)

| Task ID | Task | Deliverable | STAMP |
|---------|------|-------------|-------|
| T9.1 | Static binary | tui_release | SC-CNT-009 |
| T9.2 | CI/CD pipeline | .github/workflows/tui.yml | - |
| T9.3 | Install script | install-tui.sh | - |
| T9.4 | Documentation | TUI_User_Guide.md | SC-DOC-001 |
| T9.5 | Release validation | TUI_Release.md | SC-GA-001 |

---

## PART VI: 9-LEVEL WEBUI (F#) IMPLEMENTATION PLAN (BOLERO/BLAZOR)

**CRITICAL**: Per user directive, WebUI MUST be implemented in F# using Bolero (F# on Blazor WebAssembly), NOT Phoenix/Elixir. This ensures:
- Consistent language across all three interfaces
- Shared domain model (Cepaf.Cockpit.Domain)
- Type-safe client-server communication
- Reuse of F# business logic

### Level 1: Foundation (Week 1-2)

| Task ID | Task | Deliverable | STAMP |
|---------|------|-------------|-------|
| W1.1 | Bolero project setup | Cepaf.Cockpit.Web.fsproj | SC-NET-001 |
| W1.2 | Elmish architecture | App.fs, Model.fs | SC-HMI-001 |
| W1.3 | Router setup | Router.fs | - |
| W1.4 | CSS theme | dark-cockpit.css | SC-HMI-007 |
| W1.5 | Base components | Button.fs, Card.fs | SC-HMI-004 |

**Technology Stack**:
```fsharp
// Cepaf.Cockpit.Web.fsproj
<Project Sdk="Microsoft.NET.Sdk.Razor">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Bolero" Version="0.24.*" />
    <PackageReference Include="Bolero.Server" Version="0.24.*" />
    <PackageReference Include="SignalR.Client" Version="8.*" />
    <PackageReference Include="Fable.Remoting.Client" Version="8.*" />
  </ItemGroup>
  <ItemGroup>
    <ProjectReference Include="../Cepaf.Cockpit/Cepaf.Cockpit.fsproj" />
  </ItemGroup>
</Project>
```

### Level 2: Core Components (Week 3-4)

| Task ID | Task | Deliverable | STAMP |
|---------|------|-------------|-------|
| W2.1 | Dashboard component | Dashboard.fs | SC-HMI-002 |
| W2.2 | Health gauge SVG | HealthGauge.fs | SC-HMI-003 |
| W2.3 | Alarm list | AlarmList.fs, AlarmRow.fs | SC-ALARM-001 |
| W2.4 | Guardian panel | GuardianPanel.fs | SC-PRAJNA-001 |
| W2.5 | Sentinel panel | SentinelPanel.fs | SC-IMMUNE-001 |

**Bolero Component Example**:
```fsharp
// Dashboard.fs
namespace Cepaf.Cockpit.Web.Pages

open Bolero
open Bolero.Html
open Cepaf.Cockpit.Domain

type DashboardPage() =
    inherit ElmishComponent<DashboardModel, DashboardMessage>()

    override this.View model dispatch =
        div [attr.``class`` "dashboard dark-cockpit"] [
            // Health section
            div [attr.``class`` "health-section"] [
                comp<HealthGauge> [
                    "Value" => model.SystemHealth
                    "Label" => "System Health"
                ]
            ]
            // Alarm summary
            div [attr.``class`` "alarm-summary"] [
                comp<AlarmSummary> [
                    "Alarms" => model.ActiveAlarms
                    "OnAlarmClick" => (fun id -> dispatch (SelectAlarm id))
                ]
            ]
            // Guardian status
            div [attr.``class`` "guardian-status"] [
                comp<GuardianStatus> [
                    "PendingCount" => model.PendingProposals
                    "OnNavigate" => (fun () -> dispatch NavigateToGuardian)
                ]
            ]
        ]
```

### Level 3: Secondary Pages (Week 5-6)

| Task ID | Task | Deliverable | STAMP |
|---------|------|-------------|-------|
| W3.1 | Video wall | VideoWall.fs, VideoCell.fs | SC-VIDEO-001 |
| W3.2 | Analytics | Analytics.fs, Charts.fs | - |
| W3.3 | Compliance | Compliance.fs, AuditLog.fs | SC-REG-001 |
| W3.4 | Access control | AccessControl.fs | SC-SEC-001 |
| W3.5 | Test evolution | Evolution.fs | SC-TEST-001 |

### Level 4: Real-Time Features (Week 7-8)

| Task ID | Task | Deliverable | STAMP |
|---------|------|-------------|-------|
| W4.1 | SignalR integration | SignalRClient.fs | SC-SYNC-001 |
| W4.2 | WebSocket Zenoh | ZenohWebBridge.fs | SC-ZENOH-001 |
| W4.3 | Live updates | LiveUpdateService.fs | SC-PRF-050 |
| W4.4 | Stale data indicators | StalenessIndicator.fs | SC-HMI-003 |
| W4.5 | Connection status | ConnectionStatus.fs | - |

**SignalR Hub Integration**:
```fsharp
// ZenohWebBridge.fs - F# SignalR client bridging to Zenoh
namespace Cepaf.Cockpit.Web.Services

open Microsoft.AspNetCore.SignalR.Client
open Cepaf.Cockpit.Domain

type ZenohWebBridge(hubUrl: string) =
    let connection =
        HubConnectionBuilder()
            .WithUrl(hubUrl)
            .WithAutomaticReconnect()
            .Build()

    member _.OnHealthUpdate(callback: SystemHealth -> unit) =
        connection.On<SystemHealth>("HealthUpdate", callback)

    member _.OnAlarmUpdate(callback: Alarm -> unit) =
        connection.On<Alarm>("AlarmUpdate", callback)

    member _.OnThreatUpdate(callback: Threat -> unit) =
        connection.On<Threat>("ThreatUpdate", callback)

    member _.Start() = async {
        do! connection.StartAsync() |> Async.AwaitTask
    }
```

### Level 5: Domain Features (Week 9-10)

| Task ID | Task | Deliverable | STAMP |
|---------|------|-------------|-------|
| W5.1 | C3I COP map | COPMap.fs (Leaflet/OpenLayers) | SC-C3I-001 |
| W5.2 | SCADA mimic | MimicDiagram.fs (SVG) | SC-SCADA-001 |
| W5.3 | IDS dashboard | IDSDashboard.fs | SC-SEC-002 |
| W5.4 | Device grid | DeviceGrid.fs | SC-IOT-001 |
| W5.5 | AI Copilot chat | CopilotChat.fs | SC-AI-002 |

### Level 6: Multi-Screen/Responsive (Week 11-12)

| Task ID | Task | Deliverable | STAMP |
|---------|------|-------------|-------|
| W6.1 | Responsive layout | ResponsiveLayout.css | SC-HMI-010 |
| W6.2 | Multi-window PWA | MultiWindow.fs | SC-HMI-010 |
| W6.3 | Mobile adaptation | MobileLayout.fs | - |
| W6.4 | Touch gestures | TouchHandler.fs | - |
| W6.5 | Offline PWA | ServiceWorker.js | SC-EMR-060 |

### Level 7: Testing (Week 13-14)

| Task ID | Task | Deliverable | Count |
|---------|------|-------------|-------|
| W7.1 | Puppeteer tests | WebPuppeteerTests.fs | 400 |
| W7.2 | Playwright tests | PlaywrightTests.fs | 200 |
| W7.3 | Visual regression | WebScreenshots/ | 100 |
| W7.4 | BDD scenarios | WebUI.feature | 120 |
| W7.5 | Accessibility tests | A11yTests.fs | 50 |

**Puppeteer Test Example**:
```fsharp
// WebPuppeteerTests.fs
namespace Cepaf.Cockpit.Web.Tests

open Expecto
open PuppeteerSharp

[<Tests>]
let webUITests = testList "WebUI Tests" [
    testTask "Dashboard loads and displays health gauge" {
        use! browser = Puppeteer.LaunchAsync(LaunchOptions(Headless = true))
        let! page = browser.NewPageAsync()
        do! page.GoToAsync("http://localhost:5000/")

        let! healthGauge = page.WaitForSelectorAsync(".health-gauge")
        Expect.isNotNull healthGauge "Health gauge should render"

        let! value = page.EvaluateExpressionAsync<float>(".health-gauge .value")
        Expect.isGreaterThanOrEqual value 0.0 "Health value should be >= 0"
    }

    testTask "Alarm list receives live updates" {
        use! browser = Puppeteer.LaunchAsync(LaunchOptions(Headless = true))
        let! page = browser.NewPageAsync()
        do! page.GoToAsync("http://localhost:5000/alarms")

        let! initialCount = page.EvaluateExpressionAsync<int>(".alarm-list .count")

        // Trigger alarm via API
        do! triggerTestAlarm()
        do! page.WaitForTimeoutAsync(2000)

        let! newCount = page.EvaluateExpressionAsync<int>(".alarm-list .count")
        Expect.isGreaterThan newCount initialCount "Alarm count should increase"
    }
]
```

### Level 8: Safety Validation (Week 15-16)

| Task ID | Task | Deliverable | STAMP |
|---------|------|-------------|-------|
| W8.1 | FMEA analysis | WebUI_FMEA.md | SC-COV-005 |
| W8.2 | XSS prevention | SecurityTests.fs | SC-SEC-044 |
| W8.3 | CSRF protection | CSRFTests.fs | SC-SEC-047 |
| W8.4 | Response time SLA | LatencyTests.fs | SC-PRF-050 |
| W8.5 | Formal spec | webui_safety.qnt | SC-PROM-004 |

### Level 9: Deployment (Week 17-18)

| Task ID | Task | Deliverable | STAMP |
|---------|------|-------------|-------|
| W9.1 | WASM bundle | dist/webui.wasm | - |
| W9.2 | ASP.NET host | Program.fs (Kestrel) | SC-CNT-009 |
| W9.3 | Nginx config | nginx.conf | - |
| W9.4 | CI/CD pipeline | .github/workflows/webui.yml | - |
| W9.5 | Documentation | WebUI_Guide.md | SC-DOC-001 |

**Bolero Server Hosting**:
```fsharp
// Program.fs - ASP.NET Core + Bolero
open Microsoft.AspNetCore.Builder
open Microsoft.Extensions.DependencyInjection
open Bolero.Server

[<EntryPoint>]
let main args =
    let builder = WebApplication.CreateBuilder(args)

    builder.Services
        .AddBoleroHost()
        .AddSignalR()
        |> ignore

    let app = builder.Build()

    app.UseStaticFiles()
    app.MapBlazorHub()
    app.MapHub<ZenohHub>("/zenoh-hub")
    app.MapFallbackToFile("index.html")

    app.Run()
    0
```

---

## PART VII: COMPREHENSIVE TEST PLAN

### 7.1 Test Distribution by Interface

| Test Type | GUI | TUI | WebUI | Total |
|-----------|-----|-----|-------|-------|
| Unit Tests | 1,200 | 400 | 600 | 2,200 |
| Integration | 300 | 100 | 200 | 600 |
| Property Tests | 200 | 100 | 150 | 450 |
| BDD Scenarios | 200 | 100 | 150 | 450 |
| Visual Regression | 150 | 50 | 100 | 300 |
| Headless E2E | 300 | 150 | 200 | 650 |
| Performance | 50 | 25 | 50 | 125 |
| Accessibility | 50 | 20 | 50 | 120 |
| Security | 50 | 20 | 80 | 150 |
| FMEA/Hazard | 50 | 30 | 40 | 120 |
| Formal Proofs | 20 | 10 | 15 | 45 |
| **TOTAL** | **2,570** | **1,005** | **1,635** | **5,210** |

### 7.2 BDD Feature Coverage (100% DAG)

```gherkin
@gui @tui @webui
Feature: Dashboard displays system health
  Scenario: Health gauge shows current status
    Given the system is operational
    When I view the Dashboard
    Then the health gauge shall display a value between 0 and 100
    And the gauge color shall reflect the health level

@gui @webui @multiscreen
Feature: Multi-monitor alarm correlation
  Scenario: Alarm triggers cross-monitor updates
    Given I am viewing 4-monitor layout
    When a P1 alarm triggers in Zone "Building-A"
    Then Monitor 1 shall highlight zone on map
    And Monitor 2 shall show alarm at top
    And Monitor 3 shall promote related camera
```

### 7.3 STAMP Constraint Coverage

| Category | Constraints | GUI | TUI | WebUI |
|----------|-------------|-----|-----|-------|
| SC-HMI-* | 25 | 25 | 20 | 25 |
| SC-PRAJNA-* | 15 | 15 | 12 | 15 |
| SC-IMMUNE-* | 12 | 12 | 10 | 12 |
| SC-ALARM-* | 10 | 10 | 8 | 10 |
| SC-SEC-* | 20 | 15 | 12 | 20 |
| SC-VIDEO-* | 8 | 8 | 2 | 8 |
| SC-SYNC-* | 10 | 10 | 8 | 10 |
| SC-PRF-* | 15 | 15 | 12 | 15 |
| **TOTAL** | **115** | **110** | **84** | **115** |

---

## PART VIII: INTEGRATION ARCHITECTURE

### 8.1 Data Flow (All Interfaces)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       COCKPIT DATA ARCHITECTURE                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                      │
│  │     GUI     │  │     TUI     │  │   WebUI     │   PRESENTATION       │
│  │  (Avalonia) │  │   (ANSI)    │  │  (Bolero)   │   LAYER              │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘                      │
│         │                │                │                              │
│         └────────────────┼────────────────┘                              │
│                          │                                               │
│  ┌───────────────────────┴───────────────────────┐                      │
│  │         SHARED DOMAIN MODEL (F#)              │   DOMAIN LAYER        │
│  │  Cepaf.Cockpit.Domain / Cepaf.Cockpit.Prajna  │                      │
│  └───────────────────────┬───────────────────────┘                      │
│                          │                                               │
│  ┌───────────────────────┴───────────────────────┐                      │
│  │              BRIDGE LAYER                     │   INTEGRATION         │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐       │   LAYER              │
│  │  │ Zenoh   │  │ HTTP    │  │ SignalR │       │                      │
│  │  │ Native  │  │ REST    │  │ WS Hub  │       │                      │
│  │  └─────────┘  └─────────┘  └─────────┘       │                      │
│  └───────────────────────┬───────────────────────┘                      │
│                          │                                               │
│  ┌───────────────────────┴───────────────────────┐                      │
│  │         ELIXIR MESH BACKEND                   │   DATA LAYER         │
│  │  Phoenix | Guardian | Sentinel | SMRITI       │                      │
│  └───────────────────────────────────────────────┘                      │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 8.2 SignalR Hub for WebUI

```fsharp
// ZenohHub.fs - ASP.NET SignalR hub bridging Zenoh to WebUI
namespace Cepaf.Cockpit.Web.Hubs

open Microsoft.AspNetCore.SignalR
open Cepaf.Cockpit.Domain

type ZenohHub() =
    inherit Hub()

    member this.BroadcastHealthUpdate(health: SystemHealth) =
        this.Clients.All.SendAsync("HealthUpdate", health)

    member this.BroadcastAlarmUpdate(alarm: Alarm) =
        this.Clients.All.SendAsync("AlarmUpdate", alarm)

    member this.BroadcastThreatUpdate(threat: Threat) =
        this.Clients.All.SendAsync("ThreatUpdate", threat)

// ZenohToSignalRBridge.fs - Background service
type ZenohToSignalRBridge(hub: IHubContext<ZenohHub>, zenoh: ZenohSession) =
    interface IHostedService with
        member _.StartAsync(ct) = task {
            // Subscribe to Zenoh topics and forward to SignalR
            zenoh.Subscribe("prajna/health/*", fun data ->
                hub.Clients.All.SendAsync("HealthUpdate", data)
            )
            zenoh.Subscribe("prajna/alarms/*", fun data ->
                hub.Clients.All.SendAsync("AlarmUpdate", data)
            )
        }
```

---

## PART IX: SCHEDULE SUMMARY

### 9.1 Timeline (18 Weeks Total)

| Phase | Weeks | GUI | TUI | WebUI |
|-------|-------|-----|-----|-------|
| Foundation | 1-2 | L1 | L1 | L1 |
| Core | 3-4 | L2 | L2 | L2 |
| Secondary | 5-6 | L3 | L3 | L3 |
| Domain | 7-8 | L4 | L4 | L4 |
| Advanced | 9-10 | L5 | L5 | L5 |
| Integration | 11-12 | L6 | L6 | L6 |
| Testing | 13-14 | L7 | L7 | L7 |
| Safety | 15-16 | L8 | L8 | L8 |
| Deployment | 17-18 | L9 | L9 | L9 |

### 9.2 Dependencies

```
GUI L1 ─┬─► GUI L2 ─► GUI L3 ─► ... ─► GUI L9
        │
        └─► SHARED DOMAIN ◄─┬─ TUI L1 ─► TUI L2 ─► ... ─► TUI L9
                            │
                            └─ WebUI L1 ─► WebUI L2 ─► ... ─► WebUI L9
```

### 9.3 Resources

| Role | GUI | TUI | WebUI | Total FTE |
|------|-----|-----|-------|-----------|
| F# Developer | 2 | 1 | 2 | 5 |
| UI/UX Designer | 1 | 0.5 | 1 | 2.5 |
| Test Engineer | 1 | 0.5 | 1 | 2.5 |
| Safety Engineer | 0.5 | 0.25 | 0.5 | 1.25 |
| **Total** | **4.5** | **2.25** | **4.5** | **11.25** |

---

## PART X: STAMP CONSTRAINTS FOR COCKPIT UI

### 10.1 New Constraints (SC-COCKPIT-*)

| ID | Constraint | Severity | Interface |
|----|------------|----------|-----------|
| SC-COCKPIT-001 | All UI interfaces MUST share domain model | CRITICAL | All |
| SC-COCKPIT-002 | WebUI MUST be implemented in F# (Bolero) | CRITICAL | WebUI |
| SC-COCKPIT-003 | Response time < 50ms for user interactions | CRITICAL | All |
| SC-COCKPIT-004 | Dark Cockpit philosophy enforced (NASA-STD-3000) | HIGH | All |
| SC-COCKPIT-005 | Two-Key-Turn for destructive operations | CRITICAL | All |
| SC-COCKPIT-006 | Staleness indicator for data > 30s old | HIGH | All |
| SC-COCKPIT-007 | Multi-monitor graceful degradation | HIGH | GUI, WebUI |
| SC-COCKPIT-008 | Headless testing coverage > 95% | CRITICAL | All |
| SC-COCKPIT-009 | WCAG 2.1 AA accessibility compliance | HIGH | All |
| SC-COCKPIT-010 | BDD scenarios for all user journeys | CRITICAL | All |

### 10.2 AOR Rules (AOR-COCKPIT-*)

| ID | Rule |
|----|------|
| AOR-COCKPIT-001 | Use shared F# domain model for all interfaces |
| AOR-COCKPIT-002 | WebUI uses Bolero, NOT Phoenix/Elixir |
| AOR-COCKPIT-003 | Run headless tests before every PR |
| AOR-COCKPIT-004 | Visual regression baselines updated on UI changes |
| AOR-COCKPIT-005 | FMEA review for new UI features |
| AOR-COCKPIT-006 | Human factors evaluation for major changes |
| AOR-COCKPIT-007 | Document all keyboard shortcuts |
| AOR-COCKPIT-008 | Test multi-language support |
| AOR-COCKPIT-009 | Verify color-blind accessibility |
| AOR-COCKPIT-010 | Guardian approval for critical UI changes |

---

## PART XI: RELATED DOCUMENTS

| Document | Location | Purpose |
|----------|----------|---------|
| F# Cockpit Analysis | docs/journal/20260116-fsharp-cockpit-implementation-analysis.md | Design reference |
| CLAUDE.md | CLAUDE.md | System specification |
| Prajna Architecture | docs/architecture/PRAJNA_C3I_COCKPIT.md | C3I requirements |
| STAMP Constraints | docs/safety/STAMP_CONSTRAINTS.md | Safety requirements |
| BDD Features | test/features/cockpit/ | Test scenarios |
| Formal Specs | docs/formal_specs/cockpit_*.qnt | Quint models |

---

**Document Version**: 21.3.0-9L-IMPLEMENTATION-PLAN
**Created**: 2026-01-17
**Author**: Claude Opus 4.5
**Review Status**: Draft - Pending Architecture Review
**Next Steps**: Task breakdown in PROJECT_TODOLIST.md

---

**STAMP Compliance Summary**:
- New constraints: SC-COCKPIT-001 to SC-COCKPIT-010
- New AOR rules: AOR-COCKPIT-001 to AOR-COCKPIT-010
- Test coverage target: 5,210 tests across 3 interfaces
- BDD scenarios: 450 total (150 per interface)
- Formal proofs: 45 (linked to critical paths)
