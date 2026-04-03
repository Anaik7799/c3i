module Cepaf.Tests.Unit.Cockpit.HealthBarsTests

open System
open Expecto

module HB = Cepaf.Cockpit.HealthBars

open Cepaf.Cockpit

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

let ansiGreen  = "\u001b[32m"
let ansiYellow = "\u001b[33m"
let ansiRed    = "\u001b[31m"
let ansiReset  = "\u001b[0m"

let mkBar name health state ports : ContainerBar =
    { Name = name; HealthPct = health; State = state; Ports = ports }

// ---------------------------------------------------------------------------
// Bar rendering
// ---------------------------------------------------------------------------

[<Tests>]
let barRenderTests =
    testList "HB-BAR: Bar Rendering" [

        test "HB-BAR-001: renderBar returns non-empty string" {
            let result = HB.renderBar "CPU" 50.0 HB.MaxBarWidth
            Expect.isTrue (result.Length > 0) "renderBar must return a non-empty string"
        }

        test "HB-BAR-002: renderBar label appears in output" {
            let result = HB.renderBar "MyLabel" 50.0 40
            Expect.stringContains result "MyLabel" "Label must appear in bar output"
        }

        test "HB-BAR-003: filled char appears in non-zero bar" {
            let result = HB.renderBar "X" 50.0 40
            Expect.stringContains result HB.FilledChar "Filled char must appear for 50% value"
        }

        test "HB-BAR-004: zero value bar contains only empty chars or zero label" {
            let result = HB.renderBar "Zero" 0.0 40
            // Either all empty chars or the value 0 should appear
            Expect.isTrue (result.Contains(HB.EmptyChar) || result.Contains("0"))
                "Zero bar must contain empty char or 0 label"
        }

        test "HB-BAR-005: low value (< 60%) renders green (SC-HMI-010)" {
            let result = HB.renderBar "CPU" 40.0 40
            Expect.stringContains result ansiGreen "Value < 60% must render green"
        }

        test "HB-BAR-006: medium value (60-79%) renders yellow" {
            let result = HB.renderBar "CPU" 70.0 40
            Expect.stringContains result ansiYellow "Value 60-79% must render yellow"
        }

        test "HB-BAR-007: high value (>= 80%) renders red" {
            let result = HB.renderBar "CPU" 85.0 40
            Expect.stringContains result ansiRed "Value >= 80% must render red"
        }

        test "HB-BAR-008: maxWidth constant is 40" {
            Expect.equal HB.MaxBarWidth 40 "MaxBarWidth must equal 40"
        }
    ]

// ---------------------------------------------------------------------------
// CPU bar
// ---------------------------------------------------------------------------

[<Tests>]
let cpuBarTests =
    testList "HB-CPU: CPU Bar" [

        test "HB-CPU-001: renderCpuBar low returns green" {
            let result = HB.renderCpuBar 30.0
            Expect.stringContains result ansiGreen "CPU 30% must render green"
        }

        test "HB-CPU-002: renderCpuBar high returns red" {
            let result = HB.renderCpuBar 90.0
            Expect.stringContains result ansiRed "CPU 90% must render red"
        }

        test "HB-CPU-003: renderCpuBar returns non-empty string" {
            let result = HB.renderCpuBar 50.0
            Expect.isTrue (result.Length > 0) "CPU bar must return content"
        }

        test "HB-CPU-004: renderCpuBar 100% returns red" {
            let result = HB.renderCpuBar 100.0
            Expect.stringContains result ansiRed "CPU 100% must render red"
        }
    ]

// ---------------------------------------------------------------------------
// Memory bar
// ---------------------------------------------------------------------------

[<Tests>]
let memoryBarTests =
    testList "HB-MEM: Memory Bar" [

        test "HB-MEM-001: renderMemoryBar low usage returns green" {
            let result = HB.renderMemoryBar 512 8192  // 6.25%
            Expect.stringContains result ansiGreen "Low memory must render green"
        }

        test "HB-MEM-002: renderMemoryBar high usage returns red" {
            let result = HB.renderMemoryBar 7500 8192  // ~91%
            Expect.stringContains result ansiRed "High memory must render red"
        }

        test "HB-MEM-003: renderMemoryBar returns non-empty string" {
            let result = HB.renderMemoryBar 1024 4096
            Expect.isTrue (result.Length > 0) "Memory bar must return content"
        }

        test "HB-MEM-004: renderMemoryBar zero total returns non-empty string" {
            // Edge case: zero total should not crash
            let result = HB.renderMemoryBar 0 0
            Expect.isTrue (result.Length > 0) "Zero-total memory bar must not crash"
        }
    ]

// ---------------------------------------------------------------------------
// Disk bar
// ---------------------------------------------------------------------------

[<Tests>]
let diskBarTests =
    testList "HB-DISK: Disk Bar" [

        test "HB-DISK-001: renderDiskBar low returns green" {
            let result = HB.renderDiskBar 20.0
            Expect.stringContains result ansiGreen "Disk 20% must render green"
        }

        test "HB-DISK-002: renderDiskBar high returns red" {
            let result = HB.renderDiskBar 95.0
            Expect.stringContains result ansiRed "Disk 95% must render red"
        }

        test "HB-DISK-003: renderDiskBar returns non-empty string" {
            let result = HB.renderDiskBar 50.0
            Expect.isTrue (result.Length > 0) "Disk bar must return content"
        }
    ]

// ---------------------------------------------------------------------------
// Container bars
// ---------------------------------------------------------------------------

[<Tests>]
let containerBarsTests =
    testList "HB-CBARS: Container Bars" [

        test "HB-CBARS-001: container name appears in output" {
            let containers = [ mkBar "my-service" 90.0 "running" [8080] ]
            let result = HB.renderContainerBars containers
            Expect.stringContains result "my-service" "Container name must appear in output"
        }

        test "HB-CBARS-002: healthy container (>= 80%) renders green (inverted threshold)" {
            let containers = [ mkBar "healthy-svc" 90.0 "running" [4000] ]
            let result = HB.renderContainerBars containers
            Expect.stringContains result ansiGreen "Health >= 80% must render green"
        }

        test "HB-CBARS-003: low health (< 50%) renders red" {
            let containers = [ mkBar "sick-svc" 30.0 "degraded" [] ]
            let result = HB.renderContainerBars containers
            Expect.stringContains result ansiRed "Health < 50% must render red"
        }

        test "HB-CBARS-004: empty list returns non-empty string" {
            let result = HB.renderContainerBars []
            Expect.isTrue (result.Length > 0) "Empty container list must return string"
        }

        test "HB-CBARS-005: multiple containers all appear in output" {
            let containers = [
                mkBar "svc-alpha" 80.0 "running" [8000]
                mkBar "svc-beta"  60.0 "running" [9000]
            ]
            let result = HB.renderContainerBars containers
            Expect.stringContains result "svc-alpha" "First container must appear"
            Expect.stringContains result "svc-beta"  "Second container must appear"
        }
    ]

// ---------------------------------------------------------------------------
// Aggregate
// ---------------------------------------------------------------------------

[<Tests>]
let allHealthBarsTests =
    testList "Health Bars" [
        barRenderTests
        cpuBarTests
        memoryBarTests
        diskBarTests
        containerBarsTests
    ]
