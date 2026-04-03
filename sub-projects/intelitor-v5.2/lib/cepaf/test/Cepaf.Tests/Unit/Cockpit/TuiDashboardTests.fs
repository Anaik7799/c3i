module Cepaf.Tests.Unit.Cockpit.TuiDashboardTests

open System
open Expecto
// Types (NodeHealth, ContainerInfo, SystemMetrics) live at the Cepaf.Cockpit namespace level.
open Cepaf.Cockpit

module TUI = Cepaf.Cockpit.TuiDashboard

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

let ansiGreen      = "\u001b[32m"
let ansiBoldGreen  = "\u001b[1;32m"
let ansiYellow     = "\u001b[33m"
let ansiBoldYellow = "\u001b[1;33m"
let ansiRed        = "\u001b[31m"
let ansiBoldRed    = "\u001b[1;31m"
let ansiCyan       = "\u001b[36m"
let ansiReset      = "\u001b[0m"

let mkNode name status cpu mem uptime : NodeHealth =
    { Name = name; Status = status; CpuPct = cpu; MemMb = mem; Uptime = uptime }

// ContainerInfo.Ports is a string in the source module (not int list).
let mkContainer name state (ports: string) imageId : ContainerInfo =
    { Name = name; State = state; Ports = ports; ImageId = imageId }

let mkMetrics cpu memUsed memTotal diskPct zenoh : SystemMetrics =
    { CpuPct = cpu; MemUsedMb = memUsed; MemTotalMb = memTotal; DiskPct = diskPct; ZenohConnected = zenoh }

// ---------------------------------------------------------------------------
// Health Dashboard
// ---------------------------------------------------------------------------

[<Tests>]
let healthDashboardTests =
    testList "TUI-HEALTH: Health Dashboard" [

        test "TUI-HEALTH-001: healthy node produces green ANSI output" {
            let nodes = [ mkNode "node-1" "healthy" 40.0 512 "2h" ]
            let result = TUI.renderHealthDashboard nodes
            Expect.stringContains result ansiGreen "Healthy node must render green"
        }

        test "TUI-HEALTH-002: degraded node produces yellow ANSI output" {
            let nodes = [ mkNode "node-2" "degraded" 70.0 1024 "1h" ]
            let result = TUI.renderHealthDashboard nodes
            Expect.stringContains result ansiYellow "Degraded node must render yellow"
        }

        test "TUI-HEALTH-003: unhealthy node produces red ANSI output" {
            let nodes = [ mkNode "node-3" "unhealthy" 90.0 2048 "30m" ]
            let result = TUI.renderHealthDashboard nodes
            // colourStatus uses BoldRed (\u001b[1;31m) for unhealthy — not plain red
            Expect.stringContains result ansiBoldRed "Unhealthy node must render bold red"
        }

        test "TUI-HEALTH-004: output contains node name" {
            let nodes = [ mkNode "indrajaal-node-42" "healthy" 10.0 256 "5h" ]
            let result = TUI.renderHealthDashboard nodes
            Expect.stringContains result "indrajaal-node-42" "Node name must appear in output"
        }

        test "TUI-HEALTH-005: empty node list returns non-empty string" {
            let result = TUI.renderHealthDashboard []
            Expect.isTrue (result.Length > 0) "Empty node list must still return dashboard string"
        }

        test "TUI-HEALTH-006: multiple nodes all appear in output" {
            let nodes = [ mkNode "alpha" "healthy" 20.0 512 "1h"; mkNode "beta" "healthy" 30.0 768 "2h" ]
            let result = TUI.renderHealthDashboard nodes
            Expect.stringContains result "alpha" "First node name must appear"
            Expect.stringContains result "beta"  "Second node name must appear"
        }

        test "TUI-HEALTH-007: output contains ANSI reset codes" {
            let nodes = [ mkNode "node-x" "healthy" 50.0 512 "3h" ]
            let result = TUI.renderHealthDashboard nodes
            Expect.stringContains result ansiReset "Output must contain ANSI reset codes"
        }

        test "TUI-HEALTH-008: uptime value appears in output" {
            let nodes = [ mkNode "node-u" "healthy" 10.0 256 "12h30m" ]
            let result = TUI.renderHealthDashboard nodes
            Expect.stringContains result "12h30m" "Uptime must appear in output"
        }
    ]

// ---------------------------------------------------------------------------
// Container Status
// ---------------------------------------------------------------------------

[<Tests>]
let containerStatusTests =
    testList "TUI-CONT: Container Status" [

        test "TUI-CONT-001: running container name appears in output" {
            let containers = [ mkContainer "indrajaal-db-prod" "running" "5433->5432" "sha256:abc" ]
            let result = TUI.renderContainerStatus containers
            Expect.stringContains result "indrajaal-db-prod" "Container name must appear"
        }

        test "TUI-CONT-002: running state produces green output" {
            let containers = [ mkContainer "db" "running" "5432->5432" "img1" ]
            let result = TUI.renderContainerStatus containers
            // colourStatus uses BoldGreen (\u001b[1;32m) for running — not plain green
            Expect.stringContains result ansiBoldGreen "Running container must render bold green"
        }

        test "TUI-CONT-003: stopped state produces red output" {
            let containers = [ mkContainer "obs" "stopped" "" "img2" ]
            let result = TUI.renderContainerStatus containers
            // colourStatus uses BoldRed (\u001b[1;31m) for stopped — not plain red
            Expect.stringContains result ansiBoldRed "Stopped container must render bold red"
        }

        test "TUI-CONT-004: port numbers appear in output" {
            let containers = [ mkContainer "app" "running" "4000->4000,4001->4001" "img3" ]
            let result = TUI.renderContainerStatus containers
            Expect.stringContains result "4000" "Port 4000 must appear in output"
        }

        test "TUI-CONT-005: empty container list returns non-empty string" {
            let result = TUI.renderContainerStatus []
            Expect.isTrue (result.Length > 0) "Empty container list must still return string"
        }

        test "TUI-CONT-006: multiple containers all appear in output" {
            let containers = [
                mkContainer "svc-a" "running" "8080->8080" "img-a"
                mkContainer "svc-b" "running" "9090->9090" "img-b"
            ]
            let result = TUI.renderContainerStatus containers
            Expect.stringContains result "svc-a" "First container must appear"
            Expect.stringContains result "svc-b" "Second container must appear"
        }
    ]

// ---------------------------------------------------------------------------
// Metrics Summary
// ---------------------------------------------------------------------------

[<Tests>]
let metricsSummaryTests =
    testList "TUI-METRICS: Metrics Summary" [

        test "TUI-METRICS-001: low CPU renders green" {
            let metrics = mkMetrics 30.0 512 4096 20.0 true
            let result = TUI.renderMetricsSummary metrics
            Expect.stringContains result ansiGreen "Low CPU must render green"
        }

        test "TUI-METRICS-002: high CPU renders red" {
            let metrics = mkMetrics 90.0 3072 4096 80.0 true
            let result = TUI.renderMetricsSummary metrics
            // colourPct uses BoldRed (\u001b[1;31m) for pct >= 80 — not plain red
            Expect.stringContains result ansiBoldRed "High CPU must render bold red"
        }

        test "TUI-METRICS-003: Zenoh connected status appears" {
            let metrics = mkMetrics 20.0 512 4096 10.0 true
            let result = TUI.renderMetricsSummary metrics
            Expect.isTrue (result.Contains("true") || result.Contains("connected") || result.Contains("CONNECTED"))
                "Zenoh connected status must appear in output"
        }

        test "TUI-METRICS-004: memory values appear in output" {
            let metrics = mkMetrics 30.0 1024 8192 40.0 true
            let result = TUI.renderMetricsSummary metrics
            Expect.isTrue (result.Contains("1024") || result.Contains("8192"))
                "Memory values must appear in output"
        }

        test "TUI-METRICS-005: disk percentage appears in output" {
            let metrics = mkMetrics 20.0 512 4096 55.0 false
            let result = TUI.renderMetricsSummary metrics
            Expect.isTrue (result.Contains("55") || result.Contains("55%"))
                "Disk percentage must appear"
        }

        test "TUI-METRICS-006: output contains ANSI codes" {
            let metrics = mkMetrics 50.0 2048 4096 60.0 true
            let result = TUI.renderMetricsSummary metrics
            Expect.stringContains result "\u001b[" "Output must contain ANSI codes"
        }
    ]

// ---------------------------------------------------------------------------
// Full Dashboard
// ---------------------------------------------------------------------------

[<Tests>]
let fullDashboardTests =
    testList "TUI-FULL: Full Dashboard" [

        test "TUI-FULL-001: full dashboard returns non-empty string" {
            let result = TUI.renderFullDashboard ()
            Expect.isTrue (result.Length > 0) "Full dashboard must return content"
        }

        test "TUI-FULL-002: full dashboard contains ANSI escape codes" {
            let result = TUI.renderFullDashboard ()
            Expect.stringContains result "\u001b[" "Full dashboard must contain ANSI codes"
        }

        test "TUI-FULL-003: full dashboard contains box-drawing characters" {
            let result = TUI.renderFullDashboard ()
            Expect.isTrue (result.Contains("─") || result.Contains("│") || result.Contains("┌"))
                "Full dashboard must contain box-drawing characters"
        }
    ]

// ---------------------------------------------------------------------------
// Aggregate
// ---------------------------------------------------------------------------

[<Tests>]
let allTuiDashboardTests =
    testList "TUI Dashboard" [
        healthDashboardTests
        containerStatusTests
        metricsSummaryTests
        fullDashboardTests
    ]
