namespace Cepaf.Tests

open Xunit
open System
open Cepaf.Cockpit.Domain
open Cepaf.Cockpit.Safety
open Cepaf.Cockpit.SmartMetrics

// =============================================================================
// PRAJNA COCKPIT TESTS
// =============================================================================
// Verification of F# port of Prajna
// =============================================================================

module PrajnaTests =

    // -------------------------------------------------------------------------
    // DOMAIN TYPE TESTS
    // -------------------------------------------------------------------------

    [<Fact>]
    let ``Trend calculation works correctly`` () =
        let expected: Trend = Rising
        Assert.Equal(expected, Domain.computeTrend 10.0 15.0)
        
        let expectedFast: Trend = RisingFast
        Assert.Equal(expectedFast, Domain.computeTrend 10.0 20.0)
        
        let expectedFalling: Trend = Falling
        Assert.Equal(expectedFalling, Domain.computeTrend 10.0 5.0)
        
        let expectedStable: Trend = Stable
        Assert.Equal(expectedStable, Domain.computeTrend 10.0 10.0)

    [<Fact>]
    let ``SmartMetric staleness detection works`` () =
        let metric = SmartMetric.Create("CPU", "%", 50.0)
        // Not stale immediately
        Assert.False(Domain.isStale metric 5)
        
        // Stale after time passes (simulation)
        let staleMetric = { metric with LastUpdated = DateTime.UtcNow.AddSeconds(-10.0) }
        Assert.True(Domain.isStale staleMetric 5)

    // -------------------------------------------------------------------------
    // SAFETY GUARDIAN TESTS
    // -------------------------------------------------------------------------

    [<Fact>]
    let ``Guardian approves safe proposal`` () =
        let guardian = GuardianAgent()
        let proposal = {
            Id = "test-1"
            Action = ScaleUp 5
            Source = "Test"
            Timestamp = DateTime.UtcNow
        }
        
        let result = guardian.Validate(proposal) |> Async.RunSynchronously
        match result with
        | Approved p -> Assert.Equal(proposal, p)
        | Vetoed _ -> Assert.Fail("Should have approved safe proposal")

    [<Fact>]
    let ``Guardian vetoes unsafe resource request`` () =
        let guardian = GuardianAgent()
        let proposal = {
            Id = "test-2"
            Action = ScaleUp 100 // Limit is 50
            Source = "Test"
            Timestamp = DateTime.UtcNow
        }
        
        let result = guardian.Validate(proposal) |> Async.RunSynchronously
        match result with
        | Approved _ -> Assert.Fail("Should have vetoed unsafe proposal")
        | Vetoed (reason, fallback) -> 
            match reason with
            | ResourceLimitExceeded _ -> ()
            | _ -> Assert.Fail("Wrong violation reason")
            
            // Check fallback
            match fallback.Action with
            | ScaleUp 50 -> ()
            | _ -> Assert.Fail("Fallback should clamp to max limit")

    [<Fact>]
    let ``Guardian vetoes forbidden command`` () =
        let guardian = GuardianAgent()
        let proposal = {
            Id = "test-3"
            Action = ExecCommand "rm -rf /"
            Source = "Test"
            Timestamp = DateTime.UtcNow
        }
        
        let result = guardian.Validate(proposal) |> Async.RunSynchronously
        match result with
        | Approved _ -> Assert.Fail("Should have vetoed forbidden command")
        | Vetoed (reason, _) ->
            match reason with
            | DangerousPattern _ -> ()
            | _ -> Assert.Fail("Should detect dangerous pattern")

    // -------------------------------------------------------------------------
    // SMART METRICS TESTS
    // -------------------------------------------------------------------------

    [<Fact>]
    let ``MetricsAgent stores and retrieves metrics`` () =
        let agent = MetricsAgent()
        
        // Update
        agent.Update("cpu", 45.0, "%")
        System.Threading.Thread.Sleep(50) // Allow mailbox process
        
        // Get
        let result = agent.Get("cpu") |> Async.RunSynchronously
        Assert.True(result.IsSome)
        Assert.Equal(45.0, result.Value.Value)
        
        // Update again
        agent.Update("cpu", 55.0, "%")
        System.Threading.Thread.Sleep(50)
        
        let result2 = agent.Get("cpu") |> Async.RunSynchronously
        Assert.Equal(55.0, result2.Value.Value)
        let expectedTrend: Trend = RisingFast
        Assert.Equal(expectedTrend, result2.Value.Trend)

    [<Fact>]
    let ``MetricsAgent detects anomalies`` () =
        let agent = MetricsAgent()
        
        // Normal
        agent.Update("mem", 20.0, "%")
        
        // Testing pure logic for anomaly
        let thresholds : MetricThresholds = { 
            AdvisoryLow = None; AdvisoryHigh = None
            CautionLow = None; CautionHigh = None
            WarningLow = None; WarningHigh = Some 80.0 
        }
        
        let metric = { SmartMetric.Create("disk", "%", 85.0) with Thresholds = Some thresholds }
        let level = SmartMetric.EvaluateLevel(85.0, Some thresholds)
        
        let expectedLevel: AlarmLevel = Warning
        Assert.Equal(expectedLevel, level)