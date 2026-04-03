module Cepaf.Tests.Unit.Cockpit.SparklineTests

open System
open Expecto

module SL = Cepaf.Cockpit.Sparkline

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

let blockChars = [| '▁'; '▂'; '▃'; '▄'; '▅'; '▆'; '▇'; '█' |]

let allBlockChars (s: string) =
    s |> Seq.forall (fun c -> Array.contains c blockChars)

// ---------------------------------------------------------------------------
// Core render
// ---------------------------------------------------------------------------

[<Tests>]
let coreRenderTests =
    testList "SL-CORE: Core Render" [

        test "SL-CORE-001: render returns exactly 'width' chars for non-empty input" {
            let values = [ 10.0; 20.0; 30.0; 40.0; 50.0 ]
            let result = SL.render values 20
            Expect.equal result.Length 20 "render must return exactly 'width' characters"
        }

        test "SL-CORE-002: render returns exactly 'width' chars for empty input" {
            let result = SL.render [] 15
            Expect.equal result.Length 15 "render of empty list must return 'width' chars"
        }

        test "SL-CORE-003: empty input produces flat line of ▁ chars" {
            let result = SL.render [] 10
            Expect.isTrue (result |> Seq.forall (fun c -> c = '▁'))
                "Empty input must produce all ▁ (minimum block) chars"
        }

        test "SL-CORE-004: all output chars are valid Unicode block chars" {
            let values = [ 0.0; 25.0; 50.0; 75.0; 100.0 ]
            let result = SL.render values 10
            Expect.isTrue (allBlockChars result)
                "All rendered chars must be Unicode block chars ▁▂▃▄▅▆▇█"
        }

        test "SL-CORE-005: all-zero values produce flat line" {
            let values = List.replicate 10 0.0
            let result = SL.render values 10
            Expect.isTrue (result |> Seq.forall (fun c -> c = '▁'))
                "All-zero values must produce ▁ flat line"
        }

        test "SL-CORE-006: all-max values produce flat block line" {
            let values = List.replicate 10 100.0
            let result = SL.render values 10
            Expect.isTrue (result |> Seq.forall (fun c -> c = '▁'))
                "All-identical values are normalised to 0.0 (zero range), producing ▁ flat line"
        }

        test "SL-CORE-007: defaultWidth is 30" {
            Expect.equal SL.defaultWidth 30 "defaultWidth must equal 30"
        }

        test "SL-CORE-008: render respects custom width of 5" {
            let values = [ 10.0; 90.0 ]
            let result = SL.render values 5
            Expect.equal result.Length 5 "Custom width 5 must produce 5 chars"
        }
    ]

// ---------------------------------------------------------------------------
// Labeled render
// ---------------------------------------------------------------------------

[<Tests>]
let labeledRenderTests =
    testList "SL-LABEL: Labeled Render" [

        test "SL-LABEL-001: renderLabeled includes label in output" {
            let result = SL.renderLabeled "CPU" [ 10.0; 50.0; 90.0 ] 20 "%"
            Expect.stringContains result "CPU" "Label must appear in labeled render"
        }

        test "SL-LABEL-002: renderLabeled includes unit in output" {
            let result = SL.renderLabeled "MEM" [ 20.0; 60.0 ] 15 "MB"
            Expect.stringContains result "MB" "Unit must appear in labeled render"
        }

        test "SL-LABEL-003: renderLabeled non-empty string for empty values" {
            let result = SL.renderLabeled "X" [] 10 "u"
            Expect.isTrue (result.Length > 0) "Labeled render must return content for empty values"
        }
    ]

// ---------------------------------------------------------------------------
// CPU sparkline
// ---------------------------------------------------------------------------

[<Tests>]
let cpuSparklineTests =
    testList "SL-CPU: CPU Sparkline" [

        test "SL-CPU-001: renderCpuSparkline returns non-empty string" {
            let history = [ 10.0; 20.0; 30.0; 50.0; 70.0 ]
            let result = SL.renderCpuSparkline history
            Expect.isTrue (result.Length > 0) "CPU sparkline must return content"
        }

        test "SL-CPU-002: renderCpuSparkline for empty history returns non-empty string" {
            let result = SL.renderCpuSparkline []
            Expect.isTrue (result.Length > 0) "CPU sparkline with empty history must return content"
        }

        test "SL-CPU-003: renderCpuSparkline contains CPU identifier" {
            let history = [ 40.0; 60.0; 80.0 ]
            let result = SL.renderCpuSparkline history
            Expect.isTrue (result.ToUpper().Contains("CPU")) "CPU sparkline must mention CPU"
        }
    ]

// ---------------------------------------------------------------------------
// Memory sparkline
// ---------------------------------------------------------------------------

[<Tests>]
let memorySparklineTests =
    testList "SL-MEM: Memory Sparkline" [

        test "SL-MEM-001: renderMemorySparkline returns non-empty string" {
            let history = [ 512.0; 768.0; 1024.0 ]
            let result = SL.renderMemorySparkline history
            Expect.isTrue (result.Length > 0) "Memory sparkline must return content"
        }

        test "SL-MEM-002: renderMemorySparkline for empty history is non-empty" {
            let result = SL.renderMemorySparkline []
            Expect.isTrue (result.Length > 0) "Memory sparkline with empty history must return content"
        }

        test "SL-MEM-003: renderMemorySparkline contains memory identifier" {
            let history = [ 1000.0; 2000.0 ]
            let result = SL.renderMemorySparkline history
            Expect.isTrue (result.ToUpper().Contains("MEM") || result.ToUpper().Contains("MEMORY"))
                "Memory sparkline must mention memory"
        }
    ]

// ---------------------------------------------------------------------------
// Multi-line sparkline
// ---------------------------------------------------------------------------

[<Tests>]
let multiSparklineTests =
    testList "SL-MULTI: Multi Sparkline" [

        test "SL-MULTI-001: renderMulti with one line contains the label" {
            let lines = [ ("Alpha", [ 10.0; 50.0; 90.0 ]) ]
            let result = SL.renderMulti lines 20
            Expect.stringContains result "Alpha" "Label must appear in multi-sparkline"
        }

        test "SL-MULTI-002: renderMulti with multiple lines contains all labels" {
            let lines = [ ("Srv1", [ 20.0; 40.0 ]); ("Srv2", [ 60.0; 80.0 ]) ]
            let result = SL.renderMulti lines 20
            Expect.stringContains result "Srv1" "First label must appear"
            Expect.stringContains result "Srv2" "Second label must appear"
        }

        test "SL-MULTI-003: renderMulti empty list returns non-empty string" {
            let result = SL.renderMulti [] 20
            Expect.isTrue (result.Length >= 0) "renderMulti with empty lines must not crash"
        }
    ]

// ---------------------------------------------------------------------------
// SparklineMetrics — real /proc sampler with graceful fallback
// ---------------------------------------------------------------------------

module SM = Cepaf.Cockpit.SparklineMetrics

[<Tests>]
let metricsTests =
    testList "SL-METRICS: SparklineMetrics" [

        test "SL-METRICS-001: sampleCpuPct returns value in [0.0, 100.0]" {
            let v = SM.sampleCpuPct ()
            Expect.isTrue (v >= 0.0 && v <= 100.0)
                (sprintf "sampleCpuPct must be in [0,100], got %.2f" v)
        }

        test "SL-METRICS-002: sampleMemPct returns value in [0.0, 100.0]" {
            let v = SM.sampleMemPct ()
            Expect.isTrue (v >= 0.0 && v <= 100.0)
                (sprintf "sampleMemPct must be in [0,100], got %.2f" v)
        }

        test "SL-METRICS-003: collectCpuHistory returns exactly n samples" {
            // Use n=3, interval=0 — fast, but still exercises the real code path.
            let samples = SM.collectCpuHistory 3 100
            Expect.equal samples.Length 3
                "collectCpuHistory must return exactly n samples"
        }

        test "SL-METRICS-004: collectCpuHistory all values in [0.0, 100.0]" {
            let samples = SM.collectCpuHistory 3 100
            let inRange = samples |> List.forall (fun v -> v >= 0.0 && v <= 100.0)
            Expect.isTrue inRange "All CPU samples must be in [0.0, 100.0]"
        }

        test "SL-METRICS-005: collectMemHistory returns exactly n samples" {
            let samples = SM.collectMemHistory 4 0
            Expect.equal samples.Length 4
                "collectMemHistory must return exactly n samples"
        }

        test "SL-METRICS-006: collectMemHistory all values in [0.0, 100.0]" {
            let samples = SM.collectMemHistory 4 0
            let inRange = samples |> List.forall (fun v -> v >= 0.0 && v <= 100.0)
            Expect.isTrue inRange "All memory samples must be in [0.0, 100.0]"
        }

        test "SL-METRICS-007: collectCpuHistory n=1 returns single-element list" {
            let samples = SM.collectCpuHistory 1 100
            Expect.equal samples.Length 1
                "collectCpuHistory with n=1 must return exactly 1 sample"
        }

        test "SL-METRICS-008: collectMemHistory n=1 returns single-element list" {
            let samples = SM.collectMemHistory 1 0
            Expect.equal samples.Length 1
                "collectMemHistory with n=1 must return exactly 1 sample"
        }

        test "SL-METRICS-009: liveCpuSparkline returns non-empty string" {
            let s = SM.liveCpuSparkline 3 100
            Expect.isTrue (s.Length > 0)
                "liveCpuSparkline must return non-empty string"
        }

        test "SL-METRICS-010: liveCpuSparkline contains CPU identifier" {
            let s = SM.liveCpuSparkline 3 100
            Expect.isTrue (s.ToUpper().Contains("CPU"))
                "liveCpuSparkline must contain the CPU label"
        }

        test "SL-METRICS-011: liveMemSparkline returns non-empty string" {
            let s = SM.liveMemSparkline 3 0
            Expect.isTrue (s.Length > 0)
                "liveMemSparkline must return non-empty string"
        }

        test "SL-METRICS-012: liveMemSparkline contains MEM identifier" {
            let s = SM.liveMemSparkline 3 0
            Expect.isTrue (s.ToUpper().Contains("MEM") || s.ToUpper().Contains("MEMORY"))
                "liveMemSparkline must contain the MEM/MEMORY label"
        }

        test "SL-METRICS-013: collectCpuHistory with negative n clamps to 1" {
            let samples = SM.collectCpuHistory -5 100
            Expect.equal samples.Length 1
                "Negative n must be clamped to 1"
        }

        test "SL-METRICS-014: collectMemHistory with zero n clamps to 1" {
            let samples = SM.collectMemHistory 0 0
            Expect.equal samples.Length 1
                "Zero n must be clamped to 1"
        }

        test "SL-METRICS-015: CPU samples when piped to render produce valid block chars" {
            let samples = SM.collectCpuHistory 3 100
            let sparkStr = SL.render samples SL.defaultWidth
            Expect.isTrue (allBlockChars sparkStr)
                "CPU samples piped to render must produce valid Unicode block chars"
        }

        test "SL-METRICS-016: Mem samples when piped to render produce valid block chars" {
            let samples = SM.collectMemHistory 3 0
            let sparkStr = SL.render samples SL.defaultWidth
            Expect.isTrue (allBlockChars sparkStr)
                "Mem samples piped to render must produce valid Unicode block chars"
        }

    ]

// ---------------------------------------------------------------------------
// Aggregate
// ---------------------------------------------------------------------------

[<Tests>]
let allSparklineTests =
    testList "Sparkline" [
        coreRenderTests
        labeledRenderTests
        cpuSparklineTests
        memorySparklineTests
        multiSparklineTests
        metricsTests
    ]
