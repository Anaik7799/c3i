# Fractal Test Infrastructure - Complete Guide

**Version**: 21.3.0 Founder's Covenant
**Date**: 2026-01-03
**Status**: Production Ready

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [5-Level Test Framework](#3-5-level-test-framework)
4. [1-5 Order Effects Model](#4-1-5-order-effects-model)
5. [Implementation](#5-implementation)
6. [Jenkins CI/CD Integration](#6-jenkins-cicd-integration)
7. [STAMP Constraints](#7-stamp-constraints)
8. [AOR Rules](#8-aor-rules)
9. [Usage Guide](#9-usage-guide)
10. [API Reference](#10-api-reference)

---

## 1. Overview

### 1.1 Purpose

The Fractal Test Infrastructure provides a unified, multi-level testing system that combines the best capabilities of modern test frameworks:

| Framework | Capability Adopted |
|-----------|-------------------|
| **Playwright** | Cross-browser testing, parallel execution, multi-language support |
| **Cypress** | Developer experience, real-time feedback, time-travel debugging |
| **Cucumber/SpecFlow** | BDD, Gherkin syntax, living documentation |
| **Katalon** | Visual test recording, centralized test repository |
| **Karate** | API/UI unified testing, embedded JSON assertions |
| **pytest** | Fixtures, parametrization, plugin ecosystem |
| **PropCheck** | Property-based testing with shrinking |
| **Expecto/FsCheck** | F# test framework with property testing |

### 1.2 Key Features

- **5-Level Coverage**: TDG → FMEA → Formal → Graph → BDD
- **1-5 Order Effects**: Cascade analysis from immediate to ecosystem-wide
- **Dual Language**: Elixir + F# unified infrastructure
- **Jenkins CI/CD**: Full pipeline integration with parallel execution
- **38 LiveView Pages**: Complete Wallaby + Chrome E2E coverage (SC-COV-008)
- **30 Domains**: All business domains covered with domain-specific tests
- **90+ F# Modules**: Category theory, Bio/Immune/Neuro layers

---

## 2. Architecture

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                    PRAJNA TEST COCKPIT (Unified GUI)                         │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                         JENKINS CI/CD LAYER                             │ │
│  │  Jenkinsfile → Parallel Stages → Quality Gates → Artifacts → Reports   │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                    │                                         │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                    5-LEVEL FRACTAL TEST LAYERS                          │ │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐           │ │
│  │  │ Level 1 │ │ Level 2 │ │ Level 3 │ │ Level 4 │ │ Level 5 │           │ │
│  │  │   TDG   │ │  FMEA   │ │ Formal  │ │  Graph  │ │   BDD   │           │ │
│  │  │PropCheck│ │   RPN   │ │  Agda   │ │Coverage │ │Cucumber │           │ │
│  │  │ExUnitPr │ │Analysis │ │  Quint  │ │ Paths   │ │SpecFlow│           │ │
│  │  │StreamDat│ │Mitigat. │ │Mathemat.│ │  FSM    │ │Playwrit│           │ │
│  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘           │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                    │                                         │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                    EFFECT CHAIN TRACKING                                │ │
│  │  1st (0-100ms) → 2nd (100ms-10s) → 3rd (10s-60s) → 4th (1-5m) → 5th    │ │
│  │  Immediate       Adjacent           Integration     Capability  Ecosystem│ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                    │                                         │
│  ┌────────────────────┬────────────────────┬────────────────────────────┐   │
│  │   ELIXIR LAYER     │    F# LAYER        │    BROWSER LAYER           │   │
│  │   test_cockpit.ex  │  TestCockpit.fs    │    Playwright/Puppeteer    │   │
│  │   GenServer        │  JenkinsIntegr.fs  │    Screenshots/Videos      │   │
│  └────────────────────┴────────────────────┴────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                    TELEMETRY & OBSERVABILITY                            │ │
│  │  :telemetry.execute → SigNoz/Grafana → Dashboard → Alerts              │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 2.1 File Structure

```
lib/
├── indrajaal/cockpit/prajna/
│   └── test_cockpit.ex        # Elixir GenServer for test orchestration
├── cepaf/src/Cepaf/Cockpit/
│   ├── TestCockpit.fs         # F# Test Cockpit module
│   └── JenkinsIntegration.fs  # Jenkins CI/CD integration
test/
├── features/                   # Cucumber BDD features
├── puppeteer/                  # Playwright browser tests
├── indrajaal/                  # Domain-specific tests
docs/
├── testing/
│   ├── FRACTAL_TEST_FRAMEWORK_MASTER_PLAN.md
│   └── FRACTAL_TEST_INFRASTRUCTURE_GUIDE.md
├── formal_specs/               # Agda, Quint, Mathematica files
Jenkinsfile                     # CI/CD pipeline definition
```

---

## 3. 5-Level Test Framework

### Level 1: TDG (Test-Driven Generation)

**Purpose**: Property-based testing with automatic test case generation

**Tools**:
- PropCheck (Elixir)
- ExUnitProperties (Elixir)
- StreamData (Elixir)
- FsCheck (F#)

**STAMP Constraint**: SC-COV-006

**Example**:
```elixir
use PropCheck
import ExUnitProperties, except: [property: 2, property: 3, check: 2]
alias PropCheck.BasicTypes, as: PC
alias StreamData, as: SD

# PropCheck property
property "alarm state transitions are valid" do
  forall state <- PC.oneof([:pending, :active, :acknowledged, :resolved]) do
    valid_transition?(state)
  end
end

# ExUnitProperties property
check all(alarm <- SD.map_of(SD.atom(:alphanumeric), SD.term())) do
  assert validate_alarm(alarm)
end
```

### Level 2: FMEA (Failure Mode Effects Analysis)

**Purpose**: Risk-based testing with RPN (Risk Priority Number) analysis

**Components**:
- Severity (1-10)
- Occurrence (1-10)
- Detection (1-10)
- RPN = S × O × D

**STAMP Constraint**: SC-COV-005 (FMEA for RPN > 50 paths)

**Example**:
```elixir
@tag :fmea
test "alarm processing failure mode - RPN 72" do
  # Failure Mode: Alarm dropped during storm
  # Severity: 8 (safety impact)
  # Occurrence: 3 (rare)
  # Detection: 3 (good monitoring)
  # RPN: 72 > 50 → requires test

  assert {:ok, _} = AlarmProcessor.handle_storm_condition(alarm)
end
```

### Level 3: Formal Verification

**Purpose**: Mathematical proofs for core system invariants

**Tools**:
- Agda (dependent types, proofs)
- Quint (temporal logic, state machines)
- Mathematica (symbolic verification)

**STAMP Constraint**: SC-COV-003

**Example (Quint)**:
```quint
module AlarmInvariants {
  type AlarmState = Pending | Active | Acknowledged | Resolved

  temporal alarmEventuallyResolves {
    always(alarm.state == Active implies eventually(alarm.state == Resolved))
  }

  invariant noOrphanedAlarms {
    forall a in alarms: a.assigned_to != null or a.state == Pending
  }
}
```

### Level 4: Graph-Based Path Analysis

**Purpose**: Code coverage with path analysis and FSM coverage

**Tools**:
- ExCoveralls
- Coveralls
- Custom FSM analyzer

**STAMP Constraints**: SC-COV-001 (100% static), SC-COV-002 (95% runtime)

**Metrics**:
- Line coverage
- Branch coverage
- Path coverage
- FSM state coverage
- FSM transition coverage

### Level 5: BDD (Behavior-Driven Development)

**Purpose**: User journey testing with living documentation

**Tools**:
- Cucumber (Elixir)
- SpecFlow (F#)
- Playwright (Browser automation)
- Puppeteer (Screenshots)

**STAMP Constraints**: SC-COV-004, SC-COV-008

**Example**:
```gherkin
Feature: Alarm Acknowledgment
  As an ARC operator
  I want to acknowledge alarms
  So that the customer knows we're responding

  Background:
    Given I am logged in as an ARC operator
    And there is an active alarm for site "SITE-001"

  Scenario: Successful alarm acknowledgment
    When I click "Acknowledge" on the alarm
    Then the alarm status should change to "Acknowledged"
    And a notification should be sent to the customer
    And the SLA timer should pause

  @smoke @critical
  Scenario: Acknowledge multiple alarms
    Given there are 5 active alarms
    When I select all alarms
    And I click "Acknowledge Selected"
    Then all 5 alarms should be acknowledged
```

---

## 4. 1-5 Order Effects Model

### Effect Orders

| Order | Time Scale | Description | Example |
|-------|------------|-------------|---------|
| **1st** | 0-100ms | Immediate, direct action | Alarm parsed, initial classification |
| **2nd** | 100ms-10s | Adjacent systems react | Correlation engine triggered, zone mapping |
| **3rd** | 10s-60s | Integration effects cascade | Workflow triggered, notification sent |
| **4th** | 1-5min | Capabilities unlock | Dispatch recommended, SLA timer started |
| **5th** | 5min+ | Ecosystem-wide effects | Compliance logged, pattern learned |

### Effect Chain Example (Alarm Processing)

```
Command: process_alarm(alarm_id)

1st Order (Immediate):
  ├── Alarm received and parsed
  ├── Initial classification assigned
  └── Telemetry emitted: [:alarm, :received]

2nd Order (Adjacent):
  ├── Correlation engine triggered
  ├── Zone mapping applied
  ├── Sentinel notified
  └── Dashboard updated

3rd Order (Integration):
  ├── Workflow engine triggered
  ├── Notification service called
  ├── Customer notified
  └── Report generator queued

4th Order (Capability):
  ├── Dispatch recommendations generated
  ├── Response team assigned
  ├── SLA timer started
  └── Video evidence linked

5th Order (Ecosystem):
  ├── Compliance audit logged
  ├── Analytics updated
  ├── Pattern hunter learns
  └── AI model retrained
```

---

## 5. Implementation

### 5.1 Elixir Test Cockpit

**File**: `lib/indrajaal/cockpit/prajna/test_cockpit.ex`

```elixir
defmodule Indrajaal.Cockpit.Prajna.TestCockpit do
  use GenServer

  # Start the cockpit
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Run all 5 levels
  def run_all do
    GenServer.call(__MODULE__, :run_all, :infinity)
  end

  # Run specific level (1-5)
  def run_level(level) when level in 1..5 do
    GenServer.call(__MODULE__, {:run_level, level}, :infinity)
  end

  # Run domain tests
  def run_domain(domain) do
    GenServer.call(__MODULE__, {:run_domain, domain}, :infinity)
  end

  # Get coverage report
  def coverage_report do
    GenServer.call(__MODULE__, :coverage_report)
  end
end
```

### 5.2 F# Test Cockpit

**File**: `lib/cepaf/src/Cepaf/Cockpit/TestCockpit.fs`

```fsharp
module Cepaf.Cockpit.TestCockpit

type TestLevel = TDG | FMEA | Formal | Graph | BDD

type EffectOrder = Immediate | Adjacent | Integration | Capability | Ecosystem

let runAllLevels () : Map<TestLevel, TestResult> =
    [TDG; FMEA; Formal; Graph; BDD]
    |> List.map (fun level -> (level, runLevel level))
    |> Map.ofList

let runTDGTests () : TestResult = ...
let runFMEATests () : TestResult = ...
let runFormalVerification () : TestResult = ...
let runGraphAnalysis () : TestResult = ...
let runBDDTests () : TestResult = ...
```

### 5.3 Jenkins Integration

**File**: `lib/cepaf/src/Cepaf/Cockpit/JenkinsIntegration.fs`

```fsharp
module Cepaf.Cockpit.JenkinsIntegration

let generateJenkinsfile (config: PipelineConfig) : string = ...
let triggerBuild (url: string) (job: string) (token: string) = ...
let getBuildStatus (url: string) (job: string) (build: int) = ...
```

---

## 6. Jenkins CI/CD Integration

### 6.1 Pipeline Stages

```
Checkout → Dependencies → Compile → 5-Level Tests → Quality Gates → Coverage
                              │
                              ├── Level 1: TDG (parallel)
                              ├── Level 2: FMEA (parallel)
                              ├── Level 3: Formal (parallel)
                              ├── Level 4: Graph (parallel)
                              ├── Level 5: BDD (parallel)
                              └── F# CEPAF Tests (parallel)
```

### 6.2 Quality Gates

| Gate | Requirement |
|------|-------------|
| Format | `mix format --check-formatted` passes |
| Credo | Zero issues with `--strict` |
| Sobelow | Zero security vulnerabilities |
| Dialyzer | Type analysis passes |
| Coverage | ≥95% overall |

### 6.3 Artifacts

- `compile.log` - Compilation output
- `tdg_results.log` - Property test results
- `fmea_results.log` - FMEA analysis
- `formal_results.log` - Formal verification
- `graph_results.log` - Coverage analysis
- `bdd_*.log` - BDD scenario results
- `cover/*.html` - Coverage reports
- `screenshots/*` - Browser test screenshots

---

## 7. STAMP Constraints

### Coverage Constraints (SC-COV-*)

| ID | Constraint | Severity |
|----|------------|----------|
| SC-COV-001 | Static coverage ≥ 100% for critical paths | CRITICAL |
| SC-COV-002 | Runtime coverage ≥ 95% overall | HIGH |
| SC-COV-003 | Mathematical proofs for core invariants | HIGH |
| SC-COV-004 | BDD specs for all user journeys | HIGH |
| SC-COV-005 | FMEA for RPN > 50 paths | HIGH |
| SC-COV-006 | TDG compliance mandatory | CRITICAL |
| SC-COV-007 | All 5 levels MUST pass before merge | CRITICAL |
| SC-COV-008 | Puppeteer screenshots for all pages | MEDIUM |

### CI/CD Constraints (SC-CI-*)

| ID | Constraint | Severity |
|----|------------|----------|
| SC-CI-001 | All builds reproducible | CRITICAL |
| SC-CI-002 | Pipeline timeout < 60 minutes | HIGH |
| SC-CI-003 | Test results always published | HIGH |
| SC-CI-004 | Artifacts retained for 30 days | MEDIUM |
| SC-CI-005 | Quality gates mandatory | CRITICAL |
| SC-CI-006 | Security scans on every build | HIGH |
| SC-CI-007 | All 5 levels must pass for merge | CRITICAL |

---

## 8. AOR Rules

### Coverage Rules (AOR-COV-*)

| ID | Rule |
|----|------|
| AOR-COV-001 | All 5 levels MUST pass before release |
| AOR-COV-002 | New features require all 5 levels |
| AOR-COV-003 | Critical bugs require Level 2-5 regression |
| AOR-COV-004 | Formal proofs reviewed quarterly |
| AOR-COV-005 | BDD features for all user-facing changes |
| AOR-COV-006 | Puppeteer tests for all LiveView pages |
| AOR-COV-007 | FMEA update on architecture changes |

### CI/CD Rules (AOR-CI-*)

| ID | Rule |
|----|------|
| AOR-CI-001 | Jenkinsfile validates before push |
| AOR-CI-002 | Parallel stages for independent tests |
| AOR-CI-003 | Fail fast on critical failures |
| AOR-CI-004 | Notify on all build status changes |
| AOR-CI-005 | Cache dependencies between builds |

---

## 9. Usage Guide

### 9.1 Running Tests via Elixir

```elixir
# Start the test cockpit
{:ok, _pid} = Indrajaal.Cockpit.Prajna.TestCockpit.start_link()

# Run all 5 levels
{:ok, results} = Indrajaal.Cockpit.Prajna.TestCockpit.run_all()

# Run specific level
{:ok, tdg_result} = Indrajaal.Cockpit.Prajna.TestCockpit.run_level(1)

# Run domain tests
{:ok, alarms_result} = Indrajaal.Cockpit.Prajna.TestCockpit.run_domain(:alarms)

# Get coverage report
report = Indrajaal.Cockpit.Prajna.TestCockpit.coverage_report()
```

### 9.2 Running Tests via F#

```fsharp
open Cepaf.Cockpit.TestCockpit

// Print status
printStatus ()

// Run all levels
let results = runAllLevels ()

// Run specific level
let tdgResult = runTDGTests ()

// Run F# tests only
let fsharpResult = runFSharpTests ()

// Get coverage report
let report = generateCoverageReport ()
```

### 9.3 Running via Jenkins

```bash
# Trigger build locally
curl -X POST http://localhost:8080/job/indrajaal-fractal-tests/build \
  --user admin:token

# Trigger with parameters
curl -X POST "http://localhost:8080/job/indrajaal-fractal-tests/buildWithParameters?BRANCH=feature/test" \
  --user admin:token
```

### 9.4 Running via devenv Commands

```bash
# Enter devenv shell
devenv shell

# Run all tests
test

# Run with coverage
test-cover

# Run specific test file
mix test test/indrajaal/alarms/alarm_processor_test.exs

# Run property tests only
mix test --only property

# Run FMEA tests only
mix test --only fmea

# Run BDD features
mix test test/features/
```

---

## 10. API Reference

### 10.1 Elixir API

| Function | Description | Return |
|----------|-------------|--------|
| `TestCockpit.start_link/1` | Start the GenServer | `{:ok, pid}` |
| `TestCockpit.run_all/0` | Run all 5 levels | `{:ok, results}` |
| `TestCockpit.run_level/1` | Run specific level (1-5) | `{:ok, result}` |
| `TestCockpit.run_domain/1` | Run domain tests | `{:ok, result}` |
| `TestCockpit.run_browser_tests/0` | Run Playwright tests | `{:ok, result}` |
| `TestCockpit.run_fsharp_tests/0` | Run F# tests | `{:ok, result}` |
| `TestCockpit.coverage_report/0` | Generate coverage report | `report` |
| `TestCockpit.effect_chain_analysis/0` | Get effect chain | `analysis` |

### 10.2 F# API

| Function | Description | Return |
|----------|-------------|--------|
| `TestCockpit.runAllLevels` | Run all 5 levels | `Map<TestLevel, TestResult>` |
| `TestCockpit.runTDGTests` | Run Level 1 | `TestResult` |
| `TestCockpit.runFMEATests` | Run Level 2 | `TestResult` |
| `TestCockpit.runFormalVerification` | Run Level 3 | `TestResult` |
| `TestCockpit.runGraphAnalysis` | Run Level 4 | `TestResult` |
| `TestCockpit.runBDDTests` | Run Level 5 | `TestResult` |
| `TestCockpit.generateCoverageReport` | Generate report | `CoverageReport` |
| `TestCockpit.getEffectChainAnalysis` | Get effect chain | `list` |
| `JenkinsIntegration.generateJenkinsfile` | Generate Jenkinsfile | `string` |
| `JenkinsIntegration.triggerBuild` | Trigger Jenkins build | `Async<bool>` |

---

## Appendix A: Domain Coverage Matrix

| Domain | Level 1 | Level 2 | Level 3 | Level 4 | Level 5 |
|--------|---------|---------|---------|---------|---------|
| access_control | ✓ | ✓ | ✓ | ✓ | ✓ |
| accounts | ✓ | ✓ | ○ | ✓ | ✓ |
| alarms | ✓ | ✓ | ✓ | ✓ | ✓ |
| analytics | ✓ | ○ | ○ | ✓ | ✓ |
| authentication | ✓ | ✓ | ✓ | ✓ | ✓ |
| authorization | ✓ | ✓ | ✓ | ✓ | ✓ |
| ... | ... | ... | ... | ... | ... |

Legend: ✓ = Complete, ○ = Partial, ✗ = Missing

---

## Appendix B: Changelog

### 2026-01-03 - v21.1.0
- Initial release of Fractal Test Infrastructure
- 5-level test framework implemented
- Jenkins CI/CD integration complete
- Elixir and F# test cockpits created
- STAMP constraints SC-COV-001 to SC-COV-008 defined
- AOR rules AOR-COV-001 to AOR-COV-007 defined
