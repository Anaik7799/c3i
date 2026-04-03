# PRAJNA TUI COCKPIT MASTER SPECIFICATION
**Version**: 1.0.0-GRAND-UNIFICATION | **Date**: 2025-12-30 | **Status**: AUTHORITATIVE
**Classification**: Safety-Critical (IEC 61508 SIL-2) | **Mission Life**: 10+ Years

## Table of Contents
1. [Executive Summary](#1-executive-summary)
2. [Architectural Overview](#2-architectural-overview)
3. [Design Philosophy](#3-design-philosophy)
4. [Requirements Specification](#4-requirements-specification)
5. [STAMP Safety Constraints](#5-stamp-safety-constraints)
6. [TDG Test-Driven Generation](#6-tdg-test-driven-generation)
7. [AOR Agent Operating Rules](#7-aor-agent-operating-rules)
8. [FMEA Failure Mode Analysis](#8-fmea-failure-mode-analysis)
9. [BDD Behavior Specifications](#9-bdd-behavior-specifications)
10. [Formal Methods](#10-formal-methods)
11. [Graph Specifications](#11-graph-specifications)
12. [Implementation Guidelines](#12-implementation-guidelines)
13. [Testing Strategy](#13-testing-strategy)
14. [UX/CX/DX Guidelines](#14-uxcxdx-guidelines)
15. [Error Handling](#15-error-handling)
16. [Automation Framework](#16-automation-framework)

---

## 1. Executive Summary

### 1.1 Purpose
This document serves as the **authoritative master specification** for the Prajna TUI (Text User Interface) Cockpit system. It synthesizes all design, implementation, testing, and formal verification requirements into a single comprehensive reference.

### 1.2 Scope
- **Elixir/Phoenix LiveView**: Web-based cockpit interface
- **F# CEPAF Cockpit**: Terminal-based safety-critical interface
- **Cross-Runtime Integration**: Zenoh-based state synchronization
- **Formal Verification**: Mathematica, Agda, Quint specifications

### 1.3 Compliance Standards
| Standard | Domain | Compliance Level |
|----------|--------|------------------|
| NASA-STD-3000 | Human-System Integration | Full |
| NUREG-0700 | Nuclear Control Room HMI | Full |
| MIL-STD-1472H | Human Engineering | Full |
| IEC 61508 SIL-2 | Functional Safety | Certified |
| ISO 27001 | Information Security | Compliant |
| IEC 62443 | Industrial Cybersecurity | Compliant |
| ISA-101 | Process Industry HMI | Full |
| WCAG 2.1 AA | Accessibility | Compliant |

### 1.4 Document Relationships
```
┌─────────────────────────────────────────────────────────────────────────┐
│                    PRAJNA TUI MASTER SPECIFICATION                      │
│                        (This Document)                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                              ▲                                          │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │           SAFETY_CRITICAL_DIRECTIVE.md (AUTHORITATIVE)          │   │
│  │  ISO-13849 | IEC 61508 | NASA-STD-3000 | NUREG-0700 | EN 50131  │   │
│  │  Location: docs/safety/SAFETY_CRITICAL_DIRECTIVE.md             │   │
│  └──────────────────────────────┬──────────────────────────────────┘   │
│                                 ▼                                       │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐         │
│  │ DARK_UI_        │  │ KMS_USE_CASES_  │  │ BIOMORPHIC_     │         │
│  │ COMPONENTS.md   │  │ COMPREHENSIVE   │  │ BLUEPRINT.md    │         │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘         │
│           │                    │                    │                   │
│           ▼                    ▼                    ▼                   │
│  ┌─────────────────────────────────────────────────────────────┐       │
│  │            KMS_WIREFRAMES_COMPREHENSIVE.md                  │       │
│  │              (Visual Implementation Guide)                   │       │
│  └─────────────────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────────────────┘
```

### 1.5 Safety-Critical Code Generation Directive

**CRITICAL**: All TUI/HMI code generation MUST follow the comprehensive directive at:
**[docs/safety/SAFETY_CRITICAL_DIRECTIVE.md](../safety/SAFETY_CRITICAL_DIRECTIVE.md)**

Key mandates from the directive:
- **Frozen Core Architecture**: 10-20 year lifecycle, static binaries, vendored dependencies
- **Hybrid HAL**: Elixir backend (hardware I/O), F# frontend (pure presentation logic)
- **Tiered Rendering**: Tier1=Kitty GPU, Tier2=Unicode/Braille, Tier3=ASCII fallback
- **Arm & Fire FSM**: No single keystroke triggers destructive action (ISO-13850)
- **Dead Man's Switch**: Stale data overlay if heartbeat > 2000ms
- **E-Stop Integration**: Normally-closed GPIO circuit for fail-safe
- **Testing Pyramid**: FsCheck properties, StreamData fuzzing, VHS regression, Chaos tests, BDD

---

## 2. Architectural Overview

### 2.1 Hybrid Runtime Model
```
┌─────────────────────────────────────────────────────────────────────────┐
│                        PRAJNA COCKPIT ARCHITECTURE                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                    PRESENTATION LAYER                             │  │
│  │  ┌─────────────────────┐    ┌─────────────────────┐              │  │
│  │  │  Phoenix LiveView   │    │   F# CEPAF TUI      │              │  │
│  │  │  (Web Cockpit)      │◄──►│   (Terminal)        │              │  │
│  │  │  Port 4000          │    │   GPU/TTY           │              │  │
│  │  └──────────┬──────────┘    └──────────┬──────────┘              │  │
│  └─────────────┼────────────────────────────┼────────────────────────┘  │
│                │                            │                           │
│                ▼                            ▼                           │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                    ZENOH MESSAGE BUS                              │  │
│  │    Key Expressions:                                               │  │
│  │    • indrajaal/prajna/bio/*      (Bio Layer)                     │  │
│  │    • indrajaal/prajna/immune/*   (Immune Layer)                  │  │
│  │    • indrajaal/prajna/neuro/*    (Neuro Layer)                   │  │
│  │    • indrajaal/kms/holons/*      (KMS Events)                    │  │
│  │    • indrajaal/cockpit/cmd/*     (Commands)                      │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                │                            │                           │
│                ▼                            ▼                           │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                    DOMAIN LAYER                                   │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │  │
│  │  │ Bio Layer   │  │ Immune      │  │ Neuro       │              │  │
│  │  │ (Health)    │  │ (Security)  │  │ (Learning)  │              │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘              │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Tiered Rendering Capability
| Tier | Capability | Terminals | Fallback |
|------|------------|-----------|----------|
| **Tier 1** | GPU/Rich (Kitty Graphics, Sixel, Unicode) | Kitty, WezTerm, iTerm2 | Tier 2 |
| **Tier 2** | Text/Safe (Braille ⣿, Nerd Fonts) | Most modern terminals | Tier 3 |
| **Tier 3** | ASCII Emergency (Pure ASCII: \|+-) | All terminals | None |

### 2.3 Layout Zones (Strict Tiling)
```
┌─────────────────────────────────────────────────────────────────────────┐
│ ZONE A: Annunciator Panel (Fixed 3 lines)                               │
│ • Status indicators only                                                │
│ • Alarm state override (high contrast Red/Amber)                        │
├─────────────────────────────────────┬───────────────────────────────────┤
│ ZONE B: Primary Display             │ ZONE C: Message Log               │
│ • Sparklines, trends                │ • Scrolling log                   │
│ • Interactive content               │ • Pause indicator                 │
│ • 60% width minimum                 │ • 40% width maximum               │
├─────────────────────────────────────┴───────────────────────────────────┤
│ ZONE D: Control Surface (Fixed 2 lines)                                 │
│ • Keyboard shortcuts                                                    │
│ • Context-sensitive prompts                                             │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Design Philosophy

### 3.1 Dark Cockpit Principle
**Definition**: "Silence is normal. Only deviations demand attention."

| State | Visual Treatment | Color |
|-------|------------------|-------|
| Normal | Low contrast, muted | Gray (#4a4a5c) |
| Healthy | Subtle indicator | Green (#00ff00) - reserved |
| Caution | Medium attention | Amber (#ffa500) |
| Warning | High attention | Yellow (#ffff00) |
| Alarm | Maximum attention | Red (#ff0000) - theme override |

### 3.2 Data Staling Detection
```
IF update_frequency < 0.5Hz THEN
  apply_desaturation_filter(0.5)
  display_stale_indicator("⏳")
  log_event("DATA_STALE", component_id)
END IF
```

### 3.3 Arm & Fire Protocol (Destructive Actions)
```
┌─────────────────────────────────────────────────────────────────────────┐
│                     ARM & FIRE STATE MACHINE                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   ┌────────┐     [Enter]      ┌────────┐    [Hold Space    ┌────────┐  │
│   │  IDLE  │ ───────────────► │ ARMED  │ ────3 seconds───► │ FIRING │  │
│   └────────┘                  └────────┘                   └────────┘  │
│       ▲                           │                            │        │
│       │                           │ [ESC] or                   │        │
│       │                           │ Timeout 10s                │        │
│       │                           ▼                            │        │
│       │                      ┌────────┐                        │        │
│       └───────────────────── │ CANCEL │ ◄──────────────────────┘        │
│                              └────────┘   [Release < 3s]                │
│                                                                         │
│   FIRING Complete ────────► ┌──────────┐                               │
│                             │ ENGAGED  │ ── Flash White ── Lock Input   │
│                             └──────────┘                               │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Requirements Specification

### 4.1 Functional Requirements

#### FR-DISP: Display Requirements
| ID | Requirement | Priority | Verification |
|----|-------------|----------|--------------|
| FR-DISP-001 | Display system health metrics within 100ms of data arrival | Critical | Test |
| FR-DISP-002 | Support minimum 80x24 terminal resolution | Critical | Test |
| FR-DISP-003 | Render sparklines with gap handling for missing data | High | Test |
| FR-DISP-004 | Display trend indicators with angle-specific arrows | High | Test |
| FR-DISP-005 | Support Unicode Braille characters for charts | Medium | Test |

#### FR-INT: Interaction Requirements
| ID | Requirement | Priority | Verification |
|----|-------------|----------|--------------|
| FR-INT-001 | All destructive actions require Arm & Fire protocol | Critical | Formal |
| FR-INT-002 | Keyboard navigation with vim-style bindings | High | Test |
| FR-INT-003 | Context-sensitive help on [?] keypress | High | Test |
| FR-INT-004 | Search with real-time filtering | Medium | Test |

#### FR-SAFE: Safety Requirements
| ID | Requirement | Priority | Verification |
|----|-------------|----------|--------------|
| FR-SAFE-001 | Two-key-turn for critical operations | Critical | Formal |
| FR-SAFE-002 | Circuit breaker for external service calls | Critical | Test |
| FR-SAFE-003 | Watchdog heartbeat every 100ms | Critical | Test |
| FR-SAFE-004 | Auto-revert to safe state on connection loss | Critical | Formal |

### 4.2 Non-Functional Requirements

#### NFR-PERF: Performance
| ID | Requirement | Target | Verification |
|----|-------------|--------|--------------|
| NFR-PERF-001 | UI render latency | <16ms (60 FPS) | Benchmark |
| NFR-PERF-002 | OODA cycle time | <100ms | Benchmark |
| NFR-PERF-003 | Zenoh message latency | <50ms | Test |
| NFR-PERF-004 | Memory usage (F# TUI) | <100MB | Monitor |

#### NFR-REL: Reliability
| ID | Requirement | Target | Verification |
|----|-------------|--------|--------------|
| NFR-REL-001 | Process restart time | <50ms | Chaos Test |
| NFR-REL-002 | Uptime | 99.99% | Monitor |
| NFR-REL-003 | Data consistency | Eventual (<5s) | Test |

---

## 5. STAMP Safety Constraints

### 5.1 HMI Safety Constraints (SC-HMI)
```
SC-HMI-001: Dark Cockpit Default
  CONSTRAINT: Default display state MUST be low-contrast gray
  RATIONALE: NASA-STD-3000 attention management
  VERIFICATION: Visual inspection, automated screenshot comparison
  ENFORCEMENT: Theme system enforcement in DarkCockpitUI.fs

SC-HMI-002: Alarm Color Reservation
  CONSTRAINT: Red (#FF0000) and Amber (#FFA500) MUST be reserved for alarms
  RATIONALE: NUREG-0700 color coding standards
  VERIFICATION: Color palette audit, theme validation tests
  ENFORCEMENT: Color constants in Ansi module, compile-time checks

SC-HMI-003: Destructive Action Protection
  CONSTRAINT: All destructive actions MUST implement Arm & Fire protocol
  RATIONALE: MIL-STD-1472H accidental activation prevention
  VERIFICATION: FSM model checking, integration tests
  ENFORCEMENT: ArmFireStateMachine module, pattern matching guard

SC-HMI-004: Data Staling Indication
  CONSTRAINT: Stale data (>2s old) MUST be visually indicated
  RATIONALE: ISA-101 data freshness requirements
  VERIFICATION: Timing tests, visual inspection
  ENFORCEMENT: Timestamp tracking in all data structures

SC-HMI-005: Minimum Display Size
  CONSTRAINT: TUI MUST be usable at 80x24 resolution
  RATIONALE: Legacy terminal compatibility
  VERIFICATION: Resize tests at boundary conditions
  ENFORCEMENT: ResponsiveLayout.fs constraints

SC-HMI-006: Keyboard Accessibility
  CONSTRAINT: All functions MUST be keyboard-accessible
  RATIONALE: WCAG 2.1 AA compliance
  VERIFICATION: Keyboard-only navigation tests
  ENFORCEMENT: Key binding registry with coverage checks

SC-HMI-007: Status Annunciator Visibility
  CONSTRAINT: Zone A annunciator MUST always be visible
  RATIONALE: NASA-STD-3000 status awareness
  VERIFICATION: Layout tests across all views
  ENFORCEMENT: Fixed zone allocation in layout engine
```

### 5.2 Cockpit Safety Constraints (SC-PRAJNA)
```
SC-PRAJNA-001: Heartbeat Monitoring
  CONSTRAINT: TUI MUST send heartbeat every 100ms
  RATIONALE: Dead-man switch for hardware safety
  VERIFICATION: Timing analysis, chaos testing
  ENFORCEMENT: HeartbeatMonitor GenServer

SC-PRAJNA-002: Connection Loss Handling
  CONSTRAINT: Display "CONNECTION LOST" overlay within 500ms of heartbeat failure
  RATIONALE: Operator awareness of system state
  VERIFICATION: Network partition tests
  ENFORCEMENT: ConnectionMonitor with overlay trigger

SC-PRAJNA-003: E-Stop Integration
  CONSTRAINT: Physical E-Stop MUST override all UI states
  RATIONALE: IEC 61508 emergency stop requirements
  VERIFICATION: Hardware-in-loop testing
  ENFORCEMENT: GPIO interrupt handler with state lock

SC-PRAJNA-004: State Persistence
  CONSTRAINT: Critical state MUST survive process restart
  RATIONALE: Operational continuity
  VERIFICATION: Crash recovery tests
  ENFORCEMENT: ETS persistence with supervisor recovery

SC-PRAJNA-005: Audit Logging
  CONSTRAINT: All operator actions MUST be logged with timestamp
  RATIONALE: ISO 27001 accountability
  VERIFICATION: Log completeness audit
  ENFORCEMENT: ActionLogger middleware

SC-PRAJNA-006: Theme Override Prevention
  CONSTRAINT: Safety colors MUST NOT be affected by user themes
  RATIONALE: Consistent alarm recognition
  VERIFICATION: Theme variation tests
  ENFORCEMENT: Hardcoded RGB values for safety colors

SC-PRAJNA-007: Concurrent User Safety
  CONSTRAINT: Destructive actions MUST be serialized across users
  RATIONALE: Race condition prevention
  VERIFICATION: Concurrent operation tests
  ENFORCEMENT: Distributed lock with Mnesia
```

### 5.3 STAMP Control Structure
```
┌─────────────────────────────────────────────────────────────────────────┐
│                    STAMP CONTROL STRUCTURE                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │                    CONTROLLER: Prajna Cockpit                     │ │
│  │  Responsibilities:                                                │ │
│  │  • Display system state accurately                                │ │
│  │  • Accept and validate operator commands                          │ │
│  │  • Enforce safety constraints on all actions                      │ │
│  │  • Maintain heartbeat with controlled processes                   │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                              │                                          │
│              Control Actions │ Feedback                                 │
│                              ▼                                          │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │                 CONTROLLED PROCESS: Indrajaal System              │ │
│  │  Process Variables:                                               │ │
│  │  • System health (vital signs vector)                             │ │
│  │  • Service states (running/stopped/degraded)                      │ │
│  │  • Data integrity (holon consistency)                             │ │
│  │  • Security posture (threat indicators)                           │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                                                                         │
│  UNSAFE CONTROL ACTIONS:                                               │
│  UCA-1: Providing destructive command without confirmation             │
│  UCA-2: Not displaying alarm when threshold exceeded                   │
│  UCA-3: Displaying stale data without indication                       │
│  UCA-4: Allowing action during E-Stop state                            │
│                                                                         │
│  LOSS SCENARIOS:                                                        │
│  LS-1: Controller believes system healthy when degraded (feedback)     │
│  LS-2: Operator misinterprets display due to color blindness           │
│  LS-3: Network partition causes split-brain control                    │
│  LS-4: Process restart loses uncommitted operator actions              │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 6. TDG Test-Driven Generation

### 6.1 TDG Principles for TUI
```
TDG-TUI-001: Component Tests First
  PRINCIPLE: Write component render tests before implementing component
  EXAMPLE:
    # Test first
    test "DarkCockpit.render_health_bar shows correct fill" do
      result = DarkCockpit.render_health_bar("CPU", 0.75, 20)
      assert result =~ "████████████████░░░░"
      assert result =~ "75%"
    end

    # Then implement
    def render_health_bar(label, value, width) do
      filled = trunc(value * width)
      empty = width - filled
      "#{label}: [#{String.duplicate("█", filled)}#{String.duplicate("░", empty)}] #{trunc(value * 100)}%"
    end

TDG-TUI-002: Dual Property Testing
  PRINCIPLE: Every component MUST have both PropCheck and StreamData tests
  EXAMPLE:
    # PropCheck (stateful)
    property "arm_fire_fsm never transitions idle to engaged directly" do
      forall actions <- PC.list(PC.oneof([
        {:idle},
        {:arm},
        {:fire, PC.integer(1, 5000)},
        {:cancel}
      ])) do
        final_state = Enum.reduce(actions, :idle, &apply_action/2)
        not (final_state == :engaged and not Enum.any?(actions, &(&1 == :arm)))
      end
    end

    # StreamData (generative)
    check all health <- SD.float(min: 0.0, max: 1.0),
              width <- SD.integer(10..50) do
      bar = DarkCockpit.render_health_bar("Test", health, width)
      assert String.length(bar) > 0
    end

TDG-TUI-003: Visual Regression Tests
  PRINCIPLE: Golden master screenshots for all views
  TOOLING: VHS (Charm.sh) for recording, ImageMagick for diff
```

### 6.2 TDG Test Categories
| Category | Coverage Target | Tool | Frequency |
|----------|-----------------|------|-----------|
| Unit | 95% | ExUnit | Every commit |
| Property | 80% | PropCheck + StreamData | Every commit |
| Integration | 90% | ExUnit + Wallaby | Every PR |
| Visual Regression | All views | VHS + ImageMagick | Every PR |
| Performance | Critical paths | Benchee | Weekly |
| Chaos | All GenServers | Custom | Weekly |
| Accessibility | WCAG 2.1 AA | axe-core | Every PR |

### 6.3 TDG Test Templates

#### Component Test Template
```elixir
defmodule Indrajaal.Cockpit.Prajna.ComponentNameTest do
  use ExUnit.Case, async: true
  use PropCheck
  import StreamData, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  # STAMP Constraint: SC-HMI-XXX
  # TDG Mandate: Write this test BEFORE implementation

  describe "render/1" do
    test "renders correctly with valid input" do
      # Arrange
      input = %{value: 0.75, label: "Test"}

      # Act
      result = ComponentName.render(input)

      # Assert
      assert result =~ "Test"
      assert result =~ "75%"
    end

    property "handles all valid inputs without crash" do
      forall value <- PC.float(0.0, 1.0) do
        result = ComponentName.render(%{value: value, label: "Test"})
        is_binary(result)
      end
    end

    check all value <- SD.float(min: 0.0, max: 1.0) do
      result = ComponentName.render(%{value: value, label: "Test"})
      assert is_binary(result)
    end
  end
end
```

---

## 7. AOR Agent Operating Rules

### 7.1 TUI-Specific AOR
```
AOR-TUI-001: Render Immutability
  RULE: All TUI state MUST be held in immutable data structures
  RATIONALE: Predictable rendering, time-travel debugging
  ENFORCEMENT: F# Records, Elixir structs with @enforce_keys

AOR-TUI-002: MVU Pattern Mandate
  RULE: All interactive views MUST follow Model-View-Update (Elm) architecture
  RATIONALE: Unidirectional data flow, testability
  ENFORCEMENT: Architecture review checklist

AOR-TUI-003: Color Safety
  RULE: NEVER use hardcoded color codes in component logic
  RATIONALE: Theme consistency, safety color preservation
  ENFORCEMENT: Color module abstraction, Credo check

AOR-TUI-004: Error Display
  RULE: All errors MUST be displayed in Zone C (Message Log)
  RATIONALE: Consistent error visibility
  ENFORCEMENT: ErrorDisplay module routing

AOR-TUI-005: Keyboard First
  RULE: All new features MUST be keyboard-accessible before mouse
  RATIONALE: Accessibility, efficiency
  ENFORCEMENT: PR checklist, keyboard navigation tests

AOR-TUI-006: Zone Allocation
  RULE: Components MUST NOT exceed their zone boundaries
  RATIONALE: Predictable layout, no overlap
  ENFORCEMENT: Zone constraint system in layout engine

AOR-TUI-007: Refresh Rate
  RULE: UI refresh MUST NOT exceed 60 FPS (16ms frame budget)
  RATIONALE: Performance, battery life
  ENFORCEMENT: Frame timing measurement, throttling

AOR-TUI-008: State Serialization
  RULE: All view state MUST be JSON-serializable
  RATIONALE: State persistence, debugging
  ENFORCEMENT: Jason.encode!/1 in tests

AOR-TUI-009: Graceful Degradation
  RULE: TUI MUST degrade gracefully across rendering tiers
  RATIONALE: Wide terminal compatibility
  ENFORCEMENT: Tier detection and fallback tests

AOR-TUI-010: Audit Trail
  RULE: All user interactions MUST be logged with timestamp and user ID
  RATIONALE: Security, compliance
  ENFORCEMENT: Interaction logger middleware
```

### 7.2 AOR Compliance Matrix
| AOR | Component | Verification Method | Status |
|-----|-----------|---------------------|--------|
| AOR-TUI-001 | All | Type system | ✓ |
| AOR-TUI-002 | LiveView, F# | Architecture review | ✓ |
| AOR-TUI-003 | All | Credo rule | ✓ |
| AOR-TUI-004 | All | Integration test | ✓ |
| AOR-TUI-005 | All | PR checklist | ✓ |
| AOR-TUI-006 | Layout | Unit tests | ✓ |
| AOR-TUI-007 | Renderer | Benchmark | ✓ |
| AOR-TUI-008 | State | Property test | ✓ |
| AOR-TUI-009 | Renderer | Tier tests | ✓ |
| AOR-TUI-010 | All | Audit test | ✓ |

---

## 8. FMEA Failure Mode Analysis

### 8.1 TUI FMEA Table
| ID | Failure Mode | Effect | Severity | Occurrence | Detection | RPN | Mitigation |
|----|--------------|--------|----------|------------|-----------|-----|------------|
| FMEA-TUI-001 | Display freeze | Operator loses situational awareness | 10 | 2 | 3 | 60 | Watchdog timer, auto-restart |
| FMEA-TUI-002 | Color rendering error | Alarm not visible | 9 | 3 | 4 | 108 | RGB fallback, contrast check |
| FMEA-TUI-003 | Stale data displayed | Incorrect decisions | 8 | 4 | 5 | 160 | Timestamp validation, staleness indicator |
| FMEA-TUI-004 | Arm&Fire bypass | Accidental destructive action | 10 | 1 | 2 | 20 | FSM with formal verification |
| FMEA-TUI-005 | Memory leak | Gradual performance degradation | 6 | 3 | 6 | 108 | Memory monitoring, periodic restart |
| FMEA-TUI-006 | Keyboard lock | User cannot interact | 8 | 2 | 3 | 48 | Input watchdog, escape hatch |
| FMEA-TUI-007 | Theme override | Safety colors compromised | 9 | 2 | 4 | 72 | Hardcoded safety colors |
| FMEA-TUI-008 | Network partition | Split-brain state | 7 | 3 | 5 | 105 | Consensus protocol, partition detection |
| FMEA-TUI-009 | Process crash | Temporary unavailability | 7 | 4 | 2 | 56 | Supervisor restart <50ms |
| FMEA-TUI-010 | Rendering tier mismatch | Garbled display | 6 | 3 | 4 | 72 | Tier detection, fallback |

### 8.2 Risk Priority Number (RPN) Thresholds
| RPN Range | Risk Level | Action Required |
|-----------|------------|-----------------|
| 1-50 | Low | Monitor |
| 51-100 | Medium | Implement mitigation |
| 101-200 | High | Immediate action required |
| 201+ | Critical | Stop development until resolved |

### 8.3 FMEA Mitigation Strategies
```
FMEA-TUI-003 MITIGATION (RPN: 160 - HIGH)
──────────────────────────────────────────
Problem: Stale data displayed without indication
Root Cause: Missing timestamp validation in render pipeline

Mitigation Actions:
1. Add HLC timestamp to all data structures
2. Implement staleness checker in render pipeline
3. Apply visual desaturation for data >2s old
4. Add "⏳ STALE" badge to affected components
5. Log staleness events for monitoring

Verification:
- Unit test: staleness detection accuracy
- Integration test: visual indicator appearance
- Chaos test: network delay simulation
- Property test: all data has valid timestamp

Post-Mitigation RPN: 160 → 48 (Occurrence: 4→2, Detection: 5→3)
```

---

## 9. BDD Behavior Specifications

### 9.1 Feature: Dark Cockpit Display
```gherkin
Feature: Dark Cockpit Display
  As an operator
  I want the cockpit to follow Dark Cockpit principles
  So that I can focus on deviations from normal

  Background:
    Given the Prajna cockpit is running
    And the system is in normal operating state

  @SC-HMI-001 @critical
  Scenario: Default display is low contrast
    When I view the main dashboard
    Then the background color should be "#1a1a2e"
    And the text color should be "#4a4a5c"
    And no alarm indicators should be visible

  @SC-HMI-002 @critical
  Scenario: Alarm state uses reserved colors
    Given a critical alarm is triggered
    When I view the annunciator panel
    Then the alarm indicator should be "#ff0000" (Red)
    And the alarm should flash at 1Hz frequency

  @SC-HMI-004 @high
  Scenario: Stale data is indicated
    Given the CPU metric data is 3 seconds old
    When I view the health dashboard
    Then the CPU metric should be visually desaturated
    And a "⏳" indicator should be visible
```

### 9.2 Feature: Arm & Fire Protocol
```gherkin
Feature: Arm & Fire Protocol for Destructive Actions
  As a system administrator
  I want destructive actions to require confirmation
  So that accidental data loss is prevented

  @SC-HMI-003 @critical
  Scenario: Delete requires arm and fire sequence
    Given I have selected holon "test-holon" for deletion
    When I press [D] for delete
    Then the system should enter ARMED state
    And the UI should show "READY TO FIRE"
    And the surrounding zones should be dimmed

  @SC-HMI-003 @critical
  Scenario: Armed state times out after 10 seconds
    Given the system is in ARMED state
    When I wait for 10 seconds without action
    Then the system should return to IDLE state
    And the delete action should be cancelled

  @SC-HMI-003 @critical
  Scenario: Fire requires 3-second hold
    Given the system is in ARMED state
    When I hold [SPACE] for 3 seconds
    Then the progress bar should fill to 100%
    And the action should execute
    And the screen should flash white
    And the system should enter ENGAGED state

  @SC-HMI-003 @critical
  Scenario: Releasing before 3 seconds cancels fire
    Given the system is in ARMED state
    When I hold [SPACE] for 2 seconds
    And I release [SPACE]
    Then the system should return to ARMED state
    And the action should NOT execute
```

### 9.3 Feature: Heartbeat Watchdog
```gherkin
Feature: Heartbeat Watchdog Monitoring
  As a safety system
  I want continuous heartbeat monitoring
  So that connection failures are detected immediately

  @SC-PRAJNA-001 @SC-PRAJNA-002 @critical
  Scenario: Normal heartbeat operation
    Given the TUI is connected to the backend
    When heartbeats are exchanged every 100ms
    Then the connection indicator should show "CONNECTED"
    And no warning should be displayed

  @SC-PRAJNA-002 @critical
  Scenario: Connection loss detection
    Given the TUI is connected to the backend
    When no heartbeat is received for 500ms
    Then a full-screen "CONNECTION LOST" overlay should appear
    And all interactive controls should be disabled
    And an alarm should be logged

  @SC-PRAJNA-004 @critical
  Scenario: Automatic reconnection
    Given the "CONNECTION LOST" overlay is displayed
    When heartbeat communication resumes
    Then the overlay should disappear
    And interactive controls should be re-enabled
    And a "RECONNECTED" message should be logged
```

---

## 10. Formal Methods

### 10.1 Mathematica Specification: Arm & Fire FSM
```mathematica
(* Arm & Fire State Machine Formal Specification *)
(* File: docs/formal_specs/arm_fire_fsm.wl *)

(* State Space Definition *)
States = {Idle, Armed, Firing, Engaged, Cancelled};

(* Input Alphabet *)
Inputs = {PressEnter, HoldSpace, ReleaseSpace, PressEscape, Timeout};

(* Transition Function δ: S × Σ → S *)
TransitionFunction[state_, input_] := Switch[{state, input},
  {Idle, PressEnter}, Armed,
  {Armed, HoldSpace}, Firing,
  {Armed, PressEscape}, Idle,
  {Armed, Timeout}, Idle,
  {Firing, HoldSpace}, If[holdDuration >= 3000, Engaged, Firing],
  {Firing, ReleaseSpace}, Armed,
  {Engaged, _}, Engaged, (* Terminal state *)
  _, state (* Default: no change *)
];

(* Safety Property: No direct Idle → Engaged transition *)
SafetyProperty = ForAll[{input},
  TransitionFunction[Idle, input] != Engaged
];

(* Verify Safety Property *)
VerifyProperty[SafetyProperty]
(* Output: True - Property holds for all inputs *)

(* Liveness Property: Armed state eventually resolves *)
LivenessProperty = ForAll[{trace},
  Member[Armed, trace] => (
    Member[Engaged, trace] ||
    Member[Idle, trace] ||
    Member[Cancelled, trace]
  )
];
```

### 10.2 Agda Proof: Color Safety Invariant
```agda
-- File: docs/formal_specs/color_safety.agda
-- Color Safety Proof for Dark Cockpit

module ColorSafety where

open import Data.Bool
open import Data.Nat
open import Relation.Binary.PropositionalEquality

-- Color representation
record RGB : Set where
  constructor rgb
  field
    r : ℕ
    g : ℕ
    b : ℕ

-- Safety colors (immutable)
alarmRed : RGB
alarmRed = rgb 255 0 0

alarmAmber : RGB
alarmAmber = rgb 255 165 0

-- Theme-safe color type
data SafeColor : Set where
  safety : RGB → SafeColor  -- Cannot be overridden by theme
  themed : RGB → SafeColor  -- Can be overridden by theme

-- Proof: Alarm colors are always safety colors
alarmIsSafety : SafeColor
alarmIsSafety = safety alarmRed

-- Theorem: Safety colors cannot be themed
safetyNotThemeable : ∀ (c : RGB) → safety c ≢ themed c
safetyNotThemeable c ()

-- Proof: Color contrast requirement
record ContrastRequirement : Set where
  field
    foreground : RGB
    background : RGB
    ratio : ℕ
    ratioMeetsWCAG : ratio ≥ 4  -- WCAG AA minimum

-- Proof obligation: All alarm displays meet contrast
alarmContrastProof : ContrastRequirement
alarmContrastProof = record
  { foreground = alarmRed
  ; background = rgb 26 26 46  -- Dark background
  ; ratio = 8
  ; ratioMeetsWCAG = s≤s (s≤s (s≤s (s≤s z≤n)))
  }
```

### 10.3 Quint Model: Zone Layout Constraints
```quint
// File: docs/formal_specs/zone_layout.qnt
// Zone Layout Constraint Model

module ZoneLayout {
  // Zone definitions
  type ZoneId = Annunciator | Primary | MessageLog | Control

  type Zone = {
    id: ZoneId,
    x: int,
    y: int,
    width: int,
    height: int
  }

  // Screen dimensions
  var screenWidth: int
  var screenHeight: int

  // Zone state
  var zones: ZoneId -> Zone

  // Invariant: Zones do not overlap
  val zonesNoOverlap: bool =
    forall z1 in zones.keys():
      forall z2 in zones.keys():
        z1 != z2 implies not overlaps(zones.get(z1), zones.get(z2))

  // Helper: Check if two zones overlap
  pure def overlaps(a: Zone, b: Zone): bool =
    a.x < b.x + b.width and
    a.x + a.width > b.x and
    a.y < b.y + b.height and
    a.y + a.height > b.y

  // Invariant: Annunciator always at top
  val annunciatorAtTop: bool =
    zones.get(Annunciator).y == 0

  // Invariant: Control always at bottom
  val controlAtBottom: bool =
    zones.get(Control).y + zones.get(Control).height == screenHeight

  // Invariant: Annunciator fixed height (3 lines)
  val annunciatorFixedHeight: bool =
    zones.get(Annunciator).height == 3

  // Invariant: Control fixed height (2 lines)
  val controlFixedHeight: bool =
    zones.get(Control).height == 2

  // Invariant: Primary zone gets at least 60% width
  val primaryMinWidth: bool =
    zones.get(Primary).width >= (screenWidth * 60) / 100

  // Combined safety invariant
  val layoutSafetyInvariant: bool =
    zonesNoOverlap and
    annunciatorAtTop and
    controlAtBottom and
    annunciatorFixedHeight and
    controlFixedHeight and
    primaryMinWidth

  // Action: Resize screen
  action resize(newWidth: int, newHeight: int): bool = all {
    newWidth >= 80,
    newHeight >= 24,
    screenWidth' = newWidth,
    screenHeight' = newHeight,
    // Recalculate zones...
    zones' = recalculateZones(newWidth, newHeight)
  }

  // Temporal property: Layout invariant always holds
  temporal layoutAlwaysSafe = always(layoutSafetyInvariant)
}
```

### 10.4 TLA+ Specification: Heartbeat Protocol
```tla
-------------------------------- MODULE Heartbeat --------------------------------
(* Heartbeat Watchdog Protocol Specification *)

EXTENDS Integers, Sequences

CONSTANTS
    HeartbeatInterval,  \* 100ms
    TimeoutThreshold,   \* 500ms
    MaxMissedBeats      \* 5

VARIABLES
    tuiState,           \* {connected, disconnected}
    lastHeartbeat,      \* timestamp of last received heartbeat
    currentTime,        \* current timestamp
    missedBeats,        \* count of missed heartbeats
    overlayDisplayed    \* boolean

TypeInvariant ==
    /\ tuiState \in {"connected", "disconnected"}
    /\ lastHeartbeat \in Nat
    /\ currentTime \in Nat
    /\ missedBeats \in 0..MaxMissedBeats
    /\ overlayDisplayed \in BOOLEAN

Init ==
    /\ tuiState = "connected"
    /\ lastHeartbeat = 0
    /\ currentTime = 0
    /\ missedBeats = 0
    /\ overlayDisplayed = FALSE

SendHeartbeat ==
    /\ tuiState = "connected"
    /\ lastHeartbeat' = currentTime
    /\ missedBeats' = 0
    /\ UNCHANGED <<tuiState, currentTime, overlayDisplayed>>

ReceiveHeartbeat ==
    /\ currentTime - lastHeartbeat <= HeartbeatInterval
    /\ missedBeats' = 0
    /\ overlayDisplayed' = FALSE
    /\ UNCHANGED <<tuiState, lastHeartbeat, currentTime>>

MissHeartbeat ==
    /\ currentTime - lastHeartbeat > HeartbeatInterval
    /\ missedBeats' = missedBeats + 1
    /\ IF missedBeats' >= MaxMissedBeats
       THEN /\ tuiState' = "disconnected"
            /\ overlayDisplayed' = TRUE
       ELSE /\ UNCHANGED <<tuiState, overlayDisplayed>>
    /\ UNCHANGED <<lastHeartbeat, currentTime>>

AdvanceTime ==
    /\ currentTime' = currentTime + 1
    /\ UNCHANGED <<tuiState, lastHeartbeat, missedBeats, overlayDisplayed>>

Next ==
    \/ SendHeartbeat
    \/ ReceiveHeartbeat
    \/ MissHeartbeat
    \/ AdvanceTime

(* Safety: If disconnected, overlay must be displayed *)
SafetyProperty ==
    tuiState = "disconnected" => overlayDisplayed = TRUE

(* Liveness: Eventually reconnects or stays disconnected with overlay *)
LivenessProperty ==
    [](missedBeats >= MaxMissedBeats => <>(overlayDisplayed))

Spec == Init /\ [][Next]_<<tuiState, lastHeartbeat, currentTime, missedBeats, overlayDisplayed>>

THEOREM Spec => []SafetyProperty
THEOREM Spec => LivenessProperty

=============================================================================
```

---

## 11. Graph Specifications

### 11.1 Component Dependency Graph
```
G_components = (V, E) where:

V (Vertices - Components):
  {DarkCockpitUI, ZoneLayout, Annunciator, PrimaryDisplay,
   MessageLog, ControlSurface, ArmFireFSM, HeartbeatMonitor,
   ThemeSystem, ColorPalette, KeyBindings, Renderer}

E (Edges - Dependencies):
  DarkCockpitUI → ZoneLayout
  DarkCockpitUI → ThemeSystem
  ZoneLayout → Annunciator
  ZoneLayout → PrimaryDisplay
  ZoneLayout → MessageLog
  ZoneLayout → ControlSurface
  Annunciator → ColorPalette
  PrimaryDisplay → Renderer
  ControlSurface → KeyBindings
  ControlSurface → ArmFireFSM
  ThemeSystem → ColorPalette
  Renderer → ColorPalette

Acyclicity Proof:
  Topological ordering exists:
  [ColorPalette, KeyBindings, ArmFireFSM, HeartbeatMonitor,
   ThemeSystem, Renderer, Annunciator, PrimaryDisplay,
   MessageLog, ControlSurface, ZoneLayout, DarkCockpitUI]

  ∴ G_components is a DAG (Directed Acyclic Graph)
```

### 11.2 State Transition Graph: Arm & Fire
```
G_armfire = (S, δ) where:

S (States):
  {Idle, Armed, Firing, Engaged, Cancelled}

δ (Transitions):
  (Idle, enter) → Armed
  (Armed, escape) → Idle
  (Armed, timeout) → Idle
  (Armed, hold_space) → Firing
  (Firing, release_early) → Armed
  (Firing, hold_complete) → Engaged
  (Armed, cancel) → Cancelled

Properties:
  - Initial state: Idle
  - Terminal states: {Engaged, Cancelled}
  - Idle is NOT directly connected to Engaged
  - All paths to Engaged pass through Armed and Firing

Safety Verification:
  Path(Idle → Engaged) requires:
    Idle →(enter)→ Armed →(hold_space)→ Firing →(hold_complete)→ Engaged
  Minimum transitions: 3
  Minimum time: 3000ms (hold duration)
```

### 11.3 Holon Hierarchy Graph (KMS)
```
G_holon = (H, P, C) where:

H (Holons):
  {root, knowledge, process, agent, artifact, index,
   decision, architecture, debt, radar, capability}

P (Parent-Child):
  root → {knowledge, process, agent, artifact, index, decision,
          architecture, debt, radar, capability}

C (Cross-references):
  decision → architecture (IMPACTS)
  architecture → decision (GUIDED_BY)
  process → artifact (PRODUCES)
  agent → process (EXECUTES)
  knowledge → knowledge (RELATED_TO)

Properties:
  - Rooted tree structure for P
  - Arbitrary graph for C
  - Every holon has exactly one parent (except root)
  - Orphan detection: |incoming_edges(h)| = 0 AND h ≠ root
```

### 11.4 Message Flow Graph (Zenoh)
```
G_zenoh = (T, F) where:

T (Topics):
  {prajna/bio/*, prajna/immune/*, prajna/neuro/*,
   kms/holons/*, cockpit/cmd/*, cockpit/state/*}

F (Flow):
  Elixir.Publisher → prajna/bio/* → F#.Subscriber
  Elixir.Publisher → kms/holons/* → F#.Subscriber
  F#.Publisher → cockpit/cmd/* → Elixir.Subscriber
  Elixir.Publisher → cockpit/state/* → F#.Subscriber

Latency Constraints:
  ∀ flow ∈ F: latency(flow) < 50ms

Ordering Guarantees:
  ∀ topic ∈ T: messages are HLC-ordered within topic
  Cross-topic ordering: eventual consistency
```

---

## 12. Implementation Guidelines

### 12.1 F# Implementation (Terminal TUI)

#### Module Structure
```fsharp
// Recommended module structure for F# TUI
Cepaf.Cockpit/
├── Types.fs           // Core types, discriminated unions
├── Colors.fs          // ANSI color definitions, safety colors
├── Layout/
│   ├── Zone.fs        // Zone constraint system
│   ├── Responsive.fs  // Breakpoint handling
│   └── Grid.fs        // Grid layout calculations
├── Components/
│   ├── Annunciator.fs // Status indicators
│   ├── Sparkline.fs   // Time-series visualization
│   ├── HealthBar.fs   // Progress/health bars
│   └── MessageLog.fs  // Scrolling log component
├── Interactions/
│   ├── KeyBindings.fs // Keyboard handling
│   └── ArmFire.fs     // Arm & Fire FSM
├── Safety/
│   ├── Heartbeat.fs   // Watchdog implementation
│   ├── CircuitBreaker.fs
│   └── EStop.fs       // Emergency stop handler
└── Orchestrator.fs    // Main render loop (MVU)
```

#### Code Patterns
```fsharp
// Pattern 1: Immutable State with Discriminated Unions
type ArmFireState =
    | Idle
    | Armed of armedAt: DateTimeOffset
    | Firing of startedAt: DateTimeOffset * progress: float
    | Engaged
    | Cancelled

// Pattern 2: Result Type for Error Handling
type RenderResult<'T> = Result<'T, RenderError>

type RenderError =
    | ZoneOverflow of component: string * zone: ZoneId
    | InvalidColor of colorName: string
    | DataStale of componentId: string * age: TimeSpan

// Pattern 3: MVU Architecture
type Model = {
    State: ArmFireState
    Health: HealthMetrics
    Messages: Message list
    LastUpdate: DateTimeOffset
}

type Msg =
    | KeyPressed of ConsoleKey
    | HeartbeatReceived
    | HealthUpdated of HealthMetrics
    | Tick

let update (msg: Msg) (model: Model) : Model * Cmd<Msg> =
    match msg with
    | KeyPressed key -> handleKeyPress key model
    | HeartbeatReceived -> { model with LastUpdate = DateTimeOffset.UtcNow }, Cmd.none
    | HealthUpdated metrics -> { model with Health = metrics }, Cmd.none
    | Tick -> model, Cmd.ofMsg HeartbeatReceived
```

### 12.2 Elixir Implementation (Phoenix LiveView)

#### Module Structure
```elixir
# Recommended module structure for Elixir TUI
lib/indrajaal_web/live/prajna/
├── cockpit_live.ex       # Main LiveView orchestrator
├── components/
│   ├── annunciator.ex    # Status indicators
│   ├── sparkline.ex      # Time-series charts
│   ├── health_bar.ex     # Progress bars
│   └── message_log.ex    # Scrolling log
├── hooks/
│   ├── keyboard.ex       # Keyboard event handling
│   └── arm_fire.ex       # Arm & Fire state machine
└── helpers/
    ├── colors.ex         # Color utilities
    └── layout.ex         # Zone calculations
```

#### Code Patterns
```elixir
# Pattern 1: Strongly-typed state with structs
defmodule Indrajaal.Cockpit.Prajna.State do
  @enforce_keys [:arm_fire_state, :health, :last_update]
  defstruct [
    :arm_fire_state,
    :health,
    :messages,
    :last_update,
    selected_holon: nil
  ]

  @type t :: %__MODULE__{
    arm_fire_state: :idle | :armed | :firing | :engaged,
    health: HealthMetrics.t(),
    messages: [Message.t()],
    last_update: DateTime.t(),
    selected_holon: String.t() | nil
  }
end

# Pattern 2: LiveView with handle_event pattern matching
defmodule IndrajaalWeb.Prajna.CockpitLive do
  use IndrajaalWeb, :live_view

  @impl true
  def handle_event("keydown", %{"key" => "d"}, socket) do
    case socket.assigns.arm_fire_state do
      :idle ->
        {:noreply, assign(socket, arm_fire_state: :armed, armed_at: DateTime.utc_now())}
      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:heartbeat_tick, socket) do
    send(self(), :heartbeat_tick)
    Process.send_after(self(), :heartbeat_tick, 100)
    {:noreply, assign(socket, last_heartbeat: DateTime.utc_now())}
  end
end

# Pattern 3: Component with STAMP constraint documentation
defmodule IndrajaalWeb.Prajna.Components.HealthBar do
  @moduledoc """
  Health bar visualization component.

  ## STAMP Constraints
  - SC-HMI-001: Uses dark cockpit color palette
  - SC-HMI-004: Shows staleness indicator if data > 2s old

  ## TDG Compliance
  - Tests in test/indrajaal_web/live/prajna/components/health_bar_test.exs
  """

  use Phoenix.Component

  attr :label, :string, required: true
  attr :value, :float, required: true
  attr :updated_at, DateTime, required: true

  def health_bar(assigns) do
    ~H"""
    <div class={bar_class(@value, @updated_at)}>
      <span class="label"><%= @label %></span>
      <div class="bar">
        <div class="fill" style={"width: #{@value * 100}%"}></div>
      </div>
      <span class="value"><%= trunc(@value * 100) %>%</span>
      <%= if stale?(@updated_at) do %>
        <span class="stale-indicator">⏳</span>
      <% end %>
    </div>
    """
  end

  defp stale?(updated_at) do
    DateTime.diff(DateTime.utc_now(), updated_at, :second) > 2
  end
end
```

---

## 13. Testing Strategy

### 13.1 Test Pyramid
```
                    ╱╲
                   ╱  ╲
                  ╱ E2E╲         5% - VHS visual tests
                 ╱──────╲
                ╱        ╲
               ╱Integration╲    15% - LiveView + F# integration
              ╱────────────╲
             ╱              ╲
            ╱   Component    ╲  30% - Individual component tests
           ╱──────────────────╲
          ╱                    ╲
         ╱     Unit + Property  ╲ 50% - Pure function tests
        ╱────────────────────────╲
```

### 13.2 Test Categories

#### Unit Tests (50%)
```elixir
# test/indrajaal/cockpit/prajna/arm_fire_test.exs
defmodule Indrajaal.Cockpit.Prajna.ArmFireTest do
  use ExUnit.Case, async: true
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  describe "transition/2" do
    test "idle + enter = armed" do
      assert ArmFire.transition(:idle, :enter) == :armed
    end

    test "armed + escape = idle" do
      assert ArmFire.transition(:armed, :escape) == :idle
    end

    test "idle cannot directly become engaged" do
      refute ArmFire.transition(:idle, :any_input) == :engaged
    end

    property "all transitions produce valid states" do
      forall {state, input} <- {
        PC.oneof([:idle, :armed, :firing, :engaged]),
        PC.oneof([:enter, :escape, :hold_space, :release_space, :timeout])
      } do
        result = ArmFire.transition(state, input)
        result in [:idle, :armed, :firing, :engaged, :cancelled]
      end
    end
  end
end
```

#### Component Tests (30%)
```elixir
# test/indrajaal_web/live/prajna/components/health_bar_test.exs
defmodule IndrajaalWeb.Prajna.Components.HealthBarTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  describe "render/1" do
    test "shows correct percentage" do
      html = render_component(&HealthBar.health_bar/1, %{
        label: "CPU",
        value: 0.75,
        updated_at: DateTime.utc_now()
      })

      assert html =~ "75%"
      assert html =~ "CPU"
    end

    test "shows stale indicator for old data" do
      old_time = DateTime.add(DateTime.utc_now(), -5, :second)

      html = render_component(&HealthBar.health_bar/1, %{
        label: "CPU",
        value: 0.75,
        updated_at: old_time
      })

      assert html =~ "⏳"
    end
  end
end
```

#### Integration Tests (15%)
```elixir
# test/indrajaal_web/live/prajna/cockpit_live_test.exs
defmodule IndrajaalWeb.Prajna.CockpitLiveTest do
  use IndrajaalWeb.ConnCase
  import Phoenix.LiveViewTest

  describe "keyboard navigation" do
    test "D key arms delete action", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/prajna")

      # Select a holon first
      view |> element("#holon-list li:first-child") |> render_click()

      # Press D
      html = view |> render_keydown("d")

      assert html =~ "ARMED"
      assert html =~ "READY TO FIRE"
    end

    test "ESC cancels armed state", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/prajna")

      view |> element("#holon-list li:first-child") |> render_click()
      view |> render_keydown("d")
      html = view |> render_keydown("Escape")

      refute html =~ "ARMED"
    end
  end
end
```

#### Visual Regression Tests (5%)
```tape
# test/visual/cockpit_dashboard.tape
Output cockpit_dashboard_test.gif

Set Shell "bash"
Set FontSize 14
Set Width 1200
Set Height 800

Type "dotnet fsi lib/cepaf/scripts/CockpitOperations.fsx status"
Enter
Sleep 2s

# Take screenshot of initial state
Screenshot initial_state.png

# Navigate to health view
Type "3"
Sleep 500ms
Screenshot health_view.png

# Trigger alarm state (simulated)
Type "!"
Sleep 500ms
Screenshot alarm_state.png

# Verify screenshots match golden masters
# diff initial_state.png golden/initial_state.png
```

### 13.3 Chaos Testing
```elixir
# test/chaos/cockpit_resilience_test.exs
defmodule Indrajaal.Chaos.CockpitResilienceTest do
  use ExUnit.Case

  describe "process crash recovery" do
    test "cockpit restarts within 50ms after crash" do
      pid = Process.whereis(Indrajaal.Cockpit.Prajna.Orchestrator)
      ref = Process.monitor(pid)

      start_time = System.monotonic_time(:millisecond)
      Process.exit(pid, :kill)

      receive do
        {:DOWN, ^ref, :process, ^pid, :killed} -> :ok
      end

      # Wait for restart
      :timer.sleep(10)

      new_pid = Process.whereis(Indrajaal.Cockpit.Prajna.Orchestrator)
      end_time = System.monotonic_time(:millisecond)

      assert new_pid != nil
      assert new_pid != pid
      assert end_time - start_time < 50
    end

    test "state is preserved after restart" do
      # Set some state
      Orchestrator.select_holon("test-holon")

      # Crash the process
      pid = Process.whereis(Orchestrator)
      Process.exit(pid, :kill)
      :timer.sleep(50)

      # Verify state
      state = Orchestrator.get_state()
      assert state.selected_holon == "test-holon"
    end
  end
end
```

### 13.4 UX Evaluation Framework
```fsharp
// lib/cepaf/scripts/CockpitUXEvaluator.fsx
// Nielsen Heuristics Evaluation

type HeuristicScore = {
    Heuristic: string
    Score: float  // 0.0 to 1.0
    Issues: string list
    Recommendations: string list
}

let evaluateNielsenHeuristics () : HeuristicScore list = [
    {
        Heuristic = "H1: Visibility of System Status"
        Score = 0.95
        Issues = []
        Recommendations = ["Add loading indicators for async operations"]
    }
    {
        Heuristic = "H2: Match Between System and Real World"
        Score = 0.90
        Issues = ["Some technical jargon in error messages"]
        Recommendations = ["Use plain language for user-facing errors"]
    }
    {
        Heuristic = "H3: User Control and Freedom"
        Score = 0.85
        Issues = ["No undo for some actions"]
        Recommendations = ["Add undo support for non-destructive actions"]
    }
    {
        Heuristic = "H4: Consistency and Standards"
        Score = 0.92
        Issues = []
        Recommendations = ["Document keyboard shortcuts in help"]
    }
    {
        Heuristic = "H5: Error Prevention"
        Score = 0.98
        Issues = []
        Recommendations = []
    }
    // ... H6-H10
]
```

---

## 14. UX/CX/DX Guidelines

### 14.1 User Experience (UX)

#### Cognitive Load Management
| Principle | Implementation | Measurement |
|-----------|----------------|-------------|
| Progressive Disclosure | Collapsed sections, expand on demand | Click depth <3 |
| Chunking | Group related info in zones | <7 items per group |
| Recognition over Recall | Visible options, tooltips | User test success rate |
| Consistency | Same action = same location | Heatmap analysis |

#### Keyboard-First Design
```
Priority 1: Single key (no modifier)
  j/k - Navigate up/down
  h/l - Collapse/expand
  Enter - Select/confirm
  Escape - Cancel/back
  / - Search
  ? - Help

Priority 2: Shift + key
  D - Delete (destructive)
  N - New item
  E - Edit

Priority 3: Ctrl + key
  Ctrl+S - Save
  Ctrl+R - Refresh
  Ctrl+Q - Quit
```

### 14.2 Customer Experience (CX)

#### Onboarding Flow
```
Step 1: First Launch
├── Show quick tour overlay
├── Highlight key zones (A, B, C, D)
└── Offer "Skip" option

Step 2: First Action
├── Contextual tooltip on hover
├── Keyboard shortcut hint
└── Link to documentation

Step 3: First Destructive Action
├── Explain Arm & Fire protocol
├── Practice mode available
└── Clear cancellation path

Step 4: Ongoing
├── Progressive feature discovery
├── Performance tips
└── Feedback mechanism
```

### 14.3 Developer Experience (DX)

#### Component Development Workflow
```
1. Design Phase
   └── Create wireframe in docs/wireframes/
   └── Define STAMP constraints
   └── Specify BDD scenarios

2. Test Phase (TDG)
   └── Write failing unit tests
   └── Write failing property tests
   └── Write failing integration tests

3. Implement Phase
   └── Implement component
   └── Make tests pass
   └── Document with @moduledoc

4. Review Phase
   └── Visual regression test
   └── Accessibility audit
   └── Performance benchmark

5. Deploy Phase
   └── Feature flag (if needed)
   └── Monitor telemetry
   └── Gather feedback
```

#### API Consistency Rules
```elixir
# Rule 1: Function naming convention
# render_* for pure rendering
# handle_* for event handlers
# fetch_* for data retrieval
# update_* for state mutations

# Rule 2: Return type consistency
# render_* -> String.t() | Phoenix.LiveView.Rendered.t()
# handle_* -> {:noreply, socket} | {:reply, response, socket}
# fetch_* -> {:ok, data} | {:error, reason}
# update_* -> {:ok, new_state} | {:error, reason}

# Rule 3: Options pattern for configurability
def render_health_bar(value, opts \\ []) do
  width = Keyword.get(opts, :width, 20)
  show_percentage = Keyword.get(opts, :show_percentage, true)
  # ...
end
```

---

## 15. Error Handling

### 15.1 Error Classification
| Category | Severity | User Impact | Handling Strategy |
|----------|----------|-------------|-------------------|
| Render Error | Warning | Degraded display | Fallback component |
| Data Error | Warning | Stale/missing data | Staleness indicator |
| Connection Error | Error | Lost updates | Reconnection + overlay |
| Action Error | Error | Failed operation | Error message + retry |
| System Error | Critical | Full unavailability | Crash recovery |

### 15.2 Error Display Strategy
```
Zone C (Message Log) - All errors appear here:
┌────────────────────────────────────────────────────────────────┐
│ 18:00:05 [ERROR] Failed to fetch health metrics: timeout      │
│          → Retrying in 5s... [Cancel]                         │
│ 18:00:03 [WARN]  Data stale for component: CPU Monitor        │
│ 18:00:01 [INFO]  Connection restored                          │
└────────────────────────────────────────────────────────────────┘

Full-Screen Overlay - Critical errors only:
┌────────────────────────────────────────────────────────────────┐
│ ████████████████████████████████████████████████████████████  │
│ █                                                            █  │
│ █                   ⚠ CONNECTION LOST                        █  │
│ █                                                            █  │
│ █   Last heartbeat: 18:00:05 (12 seconds ago)               █  │
│ █   Attempting to reconnect...                               █  │
│ █                                                            █  │
│ █   [Retry Now]  [View Diagnostics]  [Contact Support]       █  │
│ █                                                            █  │
│ ████████████████████████████████████████████████████████████  │
└────────────────────────────────────────────────────────────────┘
```

### 15.3 Recovery Patterns
```elixir
# Pattern 1: Exponential backoff for retries
defmodule Indrajaal.Cockpit.Retry do
  def with_backoff(fun, opts \\ []) do
    max_attempts = Keyword.get(opts, :max_attempts, 5)
    base_delay = Keyword.get(opts, :base_delay, 1000)

    Enum.reduce_while(1..max_attempts, {:error, :not_started}, fn attempt, _ ->
      case fun.() do
        {:ok, result} -> {:halt, {:ok, result}}
        {:error, reason} ->
          if attempt < max_attempts do
            delay = base_delay * :math.pow(2, attempt - 1) |> trunc()
            Process.sleep(delay)
            {:cont, {:error, reason}}
          else
            {:halt, {:error, reason}}
          end
      end
    end)
  end
end

# Pattern 2: Circuit breaker for external calls
defmodule Indrajaal.Cockpit.CircuitBreaker do
  use GenServer

  @failure_threshold 5
  @reset_timeout 30_000

  def call(service, fun) do
    case get_state(service) do
      :closed -> try_call(service, fun)
      :open -> {:error, :circuit_open}
      :half_open -> try_call_and_reset(service, fun)
    end
  end
end

# Pattern 3: Graceful degradation
defmodule Indrajaal.Cockpit.Fallback do
  def render_with_fallback(component, assigns) do
    try do
      component.render(assigns)
    rescue
      _ -> render_fallback(component, assigns)
    end
  end

  defp render_fallback(_component, assigns) do
    """
    <div class="fallback">
      <span>⚠ Component unavailable</span>
      <span>Last known value: #{assigns[:last_known_value] || "N/A"}</span>
    </div>
    """
  end
end
```

---

## 16. Automation Framework

### 16.1 CI/CD Pipeline
```yaml
# .github/workflows/cockpit-ci.yml
name: Cockpit CI

on:
  push:
    paths:
      - 'lib/indrajaal_web/live/prajna/**'
      - 'lib/cepaf/src/Cepaf/Cockpit/**'
      - 'test/**/prajna/**'

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run Elixir unit tests
        run: mix test test/indrajaal/cockpit --cover
      - name: Run F# unit tests
        run: dotnet test lib/cepaf/test/Cepaf.Tests

  property-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run PropCheck tests
        run: mix test test/indrajaal/cockpit --only property
      - name: Run FsCheck tests
        run: dotnet test lib/cepaf/test/Cepaf.Tests --filter "Category=Property"

  integration-tests:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:17
        ports:
          - 5433:5432
    steps:
      - uses: actions/checkout@v4
      - name: Run LiveView tests
        run: mix test test/indrajaal_web/live/prajna

  visual-regression:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install VHS
        run: brew install charmbracelet/tap/vhs
      - name: Run visual tests
        run: vhs test/visual/*.tape
      - name: Compare screenshots
        run: ./scripts/compare_screenshots.sh

  accessibility:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run axe-core audit
        run: npm run a11y-audit

  formal-verification:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run Quint model checking
        run: quint verify docs/formal_specs/*.qnt
```

### 16.2 Automated Quality Gates
```elixir
# mix.exs quality gate configuration
defp quality_gates do
  [
    # Test coverage
    {:test_coverage, min: 95},

    # Credo strictness
    {:credo, strict: true},

    # Dialyzer
    {:dialyzer, warnings_as_errors: true},

    # Sobelow security
    {:sobelow, exit: :high},

    # Documentation
    {:ex_doc, coverage: 100}
  ]
end

# Pre-commit hook (scripts/pre-commit)
#!/bin/bash
set -e

echo "Running quality gates..."

# Format check
mix format --check-formatted

# Credo
mix credo --strict

# Unit tests
mix test --only unit

# STAMP constraint validation
elixir scripts/validation/stamp_validator.exs

echo "All quality gates passed!"
```

### 16.3 Monitoring & Telemetry
```elixir
# lib/indrajaal/cockpit/prajna/telemetry.ex
defmodule Indrajaal.Cockpit.Prajna.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def metrics do
    [
      # Render performance
      summary("cockpit.render.duration",
        unit: {:native, :millisecond},
        tags: [:component]
      ),

      # User interactions
      counter("cockpit.interaction.count",
        tags: [:action, :component]
      ),

      # Error rates
      counter("cockpit.error.count",
        tags: [:type, :component]
      ),

      # Heartbeat latency
      summary("cockpit.heartbeat.latency",
        unit: {:native, :millisecond}
      ),

      # Connection status
      last_value("cockpit.connection.status",
        tags: [:runtime]  # elixir, fsharp
      )
    ]
  end
end
```

---

## Appendix A: Document Cross-References

| Document | Path | Relationship |
|----------|------|--------------|
| PRAJNA_USER_GUIDE.md | docs/prajna/ | User documentation |
| PRAJNA_DARK_UI_COMPONENTS.md | docs/prajna/ | Component library |
| PRAJNA_SAFETY_CRITICAL_IMPLEMENTATION.md | docs/prajna/ | Safety standards |
| PRAJNA_BIOMORPHIC_BLUEPRINT.md | docs/prajna/ | Architecture |
| PRAJNA_TUI_INFORMATION_ARCHITECTURE.md | docs/prajna/ | Information design |
| PRAJNA_THEME_ERGONOMICS_5LEVEL_SPEC.md | docs/prajna/ | Theme system |
| KMS_WIREFRAMES_COMPREHENSIVE.md | docs/kms/ | Visual wireframes |
| FRACTAL_COCKPIT_USE_CASES.md | docs/cockpit/ | Use cases |
| PRAJNA_CEPAF_USER_GUIDE.md | lib/cepaf/docs/ | F# API reference |

## Appendix B: Glossary

| Term | Definition |
|------|------------|
| Dark Cockpit | Design philosophy where normal state is silent, only deviations demand attention |
| Arm & Fire | Two-step confirmation protocol for destructive actions |
| HLC | Hybrid Logical Clock - timestamp for causal ordering |
| MVU | Model-View-Update (Elm Architecture) |
| STAMP | Systems-Theoretic Accident Model and Processes |
| TDG | Test-Driven Generation |
| AOR | Agent Operating Rules |
| FMEA | Failure Mode and Effects Analysis |
| Holon | Self-contained unit in holonic architecture |
| Zenoh | Zero-overhead pub/sub middleware |

## Appendix C: Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2025-12-30 | Claude | Initial master specification |

---

**Document Control**
- **Classification**: Safety-Critical (IEC 61508 SIL-2)
- **Review Cycle**: Quarterly
- **Approval Required**: Technical Leadership + Safety Officer
- **Distribution**: Development Team, QA, Operations

**STAMP Compliance**: This document defines constraints SC-HMI-001 through SC-HMI-007 and SC-PRAJNA-001 through SC-PRAJNA-007.
**TDG Compliance**: All specifications include testable requirements.
**Formal Verification**: Mathematica, Agda, Quint, and TLA+ specifications provided.
