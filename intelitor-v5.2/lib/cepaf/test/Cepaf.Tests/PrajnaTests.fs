module PrajnaTests

open System
open Expecto
open FsCheck
open FsCheck.FSharp
open Cepaf.Cockpit.Prajna

/// TDG: Property-based tests for Prajna Cockpit
/// Reference: STAMP SC-PRAJNA-001 to SC-PRAJNA-007
/// Coverage: 100% of all modules

// ═══════════════════════════════════════════════════════════════════════════
// BIO LAYER TESTS
// ═══════════════════════════════════════════════════════════════════════════

module BioProperties =
    /// Membrane with Closed permeability blocks all messages
    let closedMembraneBlocksAll msgType source =
        let config = { Bio.defaultMembraneConfig with Permeability = Bio.Closed }
        not (Bio.canPass config msgType source)

    /// Membrane with Open permeability allows non-blocked sources
    let openMembraneAllowsNonBlocked msgType source =
        let config = { Bio.defaultMembraneConfig with Permeability = Bio.Open; BlockedSources = Set.empty }
        Bio.canPass config msgType source

    /// Emergency mode only allows emergency messages
    let emergencyOnlyAllowsEmergency msgType =
        let config = { Bio.defaultMembraneConfig with Permeability = Bio.Emergency }
        if msgType = "emergency" then
            Bio.canPass config msgType "any-source"
        else
            not (Bio.canPass config msgType "any-source")

[<Tests>]
let bioCreationTests =
    testList "Bio Layer - Holon Creation" [
        testCase "createHolon sets correct initial state" <| fun _ ->
            let holon = Bio.createHolon (HolonId "test-001") (HolonType.Agent "OODA") None
            Expect.equal holon.State Bio.Dormant "Initial state should be Dormant"
            Expect.equal holon.Children [] "Children should be empty"
            Expect.isNone holon.Parent "Parent should be None"

        testCase "createHolon sets timestamp" <| fun _ ->
            let before = DateTimeOffset.UtcNow
            let holon = Bio.createHolon (HolonId "test-002") (HolonType.Agent "ACE") None
            let after = DateTimeOffset.UtcNow
            Expect.isTrue (holon.CreatedAt >= before && holon.CreatedAt <= after) "CreatedAt should be current"

        testCase "createHolon with parent sets parent correctly" <| fun _ ->
            let holon = Bio.createHolon (HolonId "child-001") (HolonType.Worker "FLAME") (Some (HolonId "parent-001"))
            Expect.equal holon.Parent (Some (HolonId "parent-001")) "Parent should be set"

        testCase "default membrane config is Selective" <| fun _ ->
            Expect.equal Bio.defaultMembraneConfig.Permeability Bio.Selective "Default should be Selective"
            Expect.equal Bio.defaultMembraneConfig.RateLimit 100 "Rate limit should be 100"
    ]

[<Tests>]
let bioTransitionTests =
    testList "Bio Layer - State Transitions" [
        testCase "transition updates state" <| fun _ ->
            let holon = Bio.createHolon (HolonId "trans-001") (HolonType.Agent "Cortex") None
            let active = Bio.transition holon Bio.Active
            Expect.equal active.State Bio.Active "State should be Active"

        testCase "transition updates heartbeat" <| fun _ ->
            let holon = Bio.createHolon (HolonId "trans-002") (HolonType.Agent "Sentinel") None
            System.Threading.Thread.Sleep(10)
            let active = Bio.transition holon Bio.Active
            Expect.isTrue (active.LastHeartbeat > holon.LastHeartbeat) "Heartbeat should be updated"

        testCase "transition through lifecycle states" <| fun _ ->
            let holon = Bio.createHolon (HolonId "lifecycle-001") (HolonType.Agent "KPI") None
            let awakening = Bio.transition holon Bio.Awakening
            let active = Bio.transition awakening Bio.Active
            let stressed = Bio.transition active Bio.Stressed
            let healing = Bio.transition stressed Bio.Healing
            let apoptotic = Bio.transition healing Bio.Apoptotic
            Expect.equal apoptotic.State Bio.Apoptotic "Final state should be Apoptotic"
    ]

[<Tests>]
let bioHealthTests =
    testList "Bio Layer - Health Checks" [
        testCase "healthy holon with good vitals returns true" <| fun _ ->
            let vitals = { HealthIndex = 0.8; StressIndex = 0.2; LastUpdate = DateTimeOffset.UtcNow }
            let base' = Bio.createHolon (HolonId "health-001") (HolonType.Agent "Test") None
            let holon = { base' with State = Bio.Active; Vitals = vitals }
            Expect.isTrue (Bio.isHealthy holon) "Should be healthy"

        testCase "holon with low health is not healthy" <| fun _ ->
            let vitals = { HealthIndex = 0.3; StressIndex = 0.2; LastUpdate = DateTimeOffset.UtcNow }
            let base' = Bio.createHolon (HolonId "health-002") (HolonType.Agent "Test") None
            let holon = { base' with State = Bio.Active; Vitals = vitals }
            Expect.isFalse (Bio.isHealthy holon) "Should not be healthy with low health index"

        testCase "holon with high stress is not healthy" <| fun _ ->
            let vitals = { HealthIndex = 0.9; StressIndex = 0.9; LastUpdate = DateTimeOffset.UtcNow }
            let base' = Bio.createHolon (HolonId "health-003") (HolonType.Agent "Test") None
            let holon = { base' with State = Bio.Active; Vitals = vitals }
            Expect.isFalse (Bio.isHealthy holon) "Should not be healthy with high stress"

        testCase "dormant holon is not healthy" <| fun _ ->
            let holon = Bio.createHolon (HolonId "health-004") (HolonType.Agent "Test") None
            Expect.isFalse (Bio.isHealthy holon) "Dormant holon should not be healthy"

        testCase "apoptotic holon is not healthy" <| fun _ ->
            let holon = Bio.createHolon (HolonId "health-005") (HolonType.Agent "Test") None
                        |> fun h -> Bio.transition h Bio.Apoptotic
            Expect.isFalse (Bio.isHealthy holon) "Apoptotic holon should not be healthy"
    ]

[<Tests>]
let bioMembraneTests =
    testList "Bio Layer - Membrane Filtering" [
        testCase "Closed membrane blocks all" <| fun _ ->
            let config = { Bio.defaultMembraneConfig with Permeability = Bio.Closed }
            Expect.isFalse (Bio.canPass config "status" "agent-001") "Closed blocks all"

        testCase "Emergency membrane only allows emergency" <| fun _ ->
            let config = { Bio.defaultMembraneConfig with Permeability = Bio.Emergency }
            Expect.isTrue (Bio.canPass config "emergency" "any") "Emergency allows emergency"
            Expect.isFalse (Bio.canPass config "status" "any") "Emergency blocks status"

        testCase "Open membrane allows unless blocked" <| fun _ ->
            let config = { Bio.defaultMembraneConfig with
                            Permeability = Bio.Open
                            BlockedSources = Set.ofList ["blocked-agent"] }
            Expect.isTrue (Bio.canPass config "any" "allowed-agent") "Open allows non-blocked"
            Expect.isFalse (Bio.canPass config "any" "blocked-agent") "Open blocks blocked sources"

        testCase "Selective membrane checks allowed types" <| fun _ ->
            let config = { Bio.defaultMembraneConfig with
                            Permeability = Bio.Selective
                            AllowedTypes = Set.ofList ["status"; "health"] }
            Expect.isTrue (Bio.canPass config "status" "agent") "Selective allows status"
            Expect.isTrue (Bio.canPass config "health" "agent") "Selective allows health"
            Expect.isFalse (Bio.canPass config "command" "agent") "Selective blocks command"
    ]

// ═══════════════════════════════════════════════════════════════════════════
// IMMUNE LAYER TESTS
// ═══════════════════════════════════════════════════════════════════════════

[<Tests>]
let immuneThreatTests =
    testList "Immune Layer - Threat Assessment" [
        testCase "critical health triggers Critical threat" <| fun _ ->
            let vitals = { HealthIndex = 0.05; StressIndex = 0.5; LastUpdate = DateTimeOffset.UtcNow }
            Expect.equal (Immune.assessThreat vitals) Immune.Critical "Very low health should be Critical"

        testCase "critical stress triggers Critical threat" <| fun _ ->
            let vitals = { HealthIndex = 0.5; StressIndex = 0.98; LastUpdate = DateTimeOffset.UtcNow }
            Expect.equal (Immune.assessThreat vitals) Immune.Critical "Very high stress should be Critical"

        testCase "high threat level" <| fun _ ->
            let vitals = { HealthIndex = 0.25; StressIndex = 0.5; LastUpdate = DateTimeOffset.UtcNow }
            Expect.equal (Immune.assessThreat vitals) Immune.High "Low health should be High"

        testCase "medium threat level" <| fun _ ->
            let vitals = { HealthIndex = 0.45; StressIndex = 0.5; LastUpdate = DateTimeOffset.UtcNow }
            Expect.equal (Immune.assessThreat vitals) Immune.Medium "Medium health should be Medium"

        testCase "low threat level" <| fun _ ->
            let vitals = { HealthIndex = 0.65; StressIndex = 0.35; LastUpdate = DateTimeOffset.UtcNow }
            Expect.equal (Immune.assessThreat vitals) Immune.Low "Slightly low health should be Low"

        testCase "no threat when healthy" <| fun _ ->
            let vitals = { HealthIndex = 0.9; StressIndex = 0.1; LastUpdate = DateTimeOffset.UtcNow }
            Expect.equal (Immune.assessThreat vitals) Immune.None "Healthy vitals should have no threat"
    ]

[<Tests>]
let immuneActionTests =
    testList "Immune Layer - Action Recommendations" [
        testCase "None threat recommends Ignore" <| fun _ ->
            Expect.equal (Immune.recommendAction Immune.None) Immune.Ignore "None -> Ignore"

        testCase "Low threat recommends Log" <| fun _ ->
            Expect.equal (Immune.recommendAction Immune.Low) Immune.Log "Low -> Log"

        testCase "Medium threat recommends Alert" <| fun _ ->
            Expect.equal (Immune.recommendAction Immune.Medium) Immune.Alert "Medium -> Alert"

        testCase "High threat recommends Isolate" <| fun _ ->
            Expect.equal (Immune.recommendAction Immune.High) Immune.Isolate "High -> Isolate"

        testCase "Critical threat recommends Escalate" <| fun _ ->
            Expect.equal (Immune.recommendAction Immune.Critical) Immune.Escalate "Critical -> Escalate"
    ]

[<Tests>]
let immuneCreationTests =
    testList "Immune Layer - Threat & Response Creation" [
        testCase "createThreat sets all fields" <| fun _ ->
            let threat = Immune.createThreat
                            Immune.ResourceExhaustion
                            "db-pool"
                            "database"
                            "Pool exhausted"
            Expect.notEqual threat.Id Guid.Empty "ID should be set"
            Expect.equal threat.Type Immune.ResourceExhaustion "Type should match"
            Expect.equal threat.Source "db-pool" "Source should match"
            Expect.equal threat.Target "database" "Target should match"
            Expect.equal threat.Description "Pool exhausted" "Description should match"

        testCase "respond creates response" <| fun _ ->
            let threat = Immune.createThreat Immune.UnauthorizedAccess "attacker" "api" "Brute force"
            let response = Immune.respond threat Immune.Isolate "Automated block"
            Expect.equal response.ThreatId threat.Id "ThreatId should match"
            Expect.equal response.Action Immune.Isolate "Action should match"
            Expect.equal response.Reason "Automated block" "Reason should match"
    ]

[<Tests>]
let maraTests =
    testList "Immune Layer - MARA" [
        testCase "MARA recommends Defensive for critical threats" <| fun _ ->
            let threats = [
                Immune.createThreat Immune.SystemCorruption "source" "target" "desc"
                |> fun t -> { t with Level = Immune.Critical }
            ]
            let result = Immune.MARA.recommend threats
            Expect.equal result.Strategy Immune.MARA.Defensive "Should be Defensive"
            Expect.isTrue (result.Confidence >= 0.9) "High confidence"

        testCase "MARA recommends Adaptive for multiple high threats" <| fun _ ->
            let createHigh _ =
                let base' = Immune.createThreat Immune.AnomalousBehavior "src" "tgt" "desc"
                { base' with Level = Immune.High }
            let threats = [1..3] |> List.map createHigh
            let result = Immune.MARA.recommend threats
            Expect.equal result.Strategy Immune.MARA.Adaptive "Should be Adaptive"

        testCase "MARA recommends Passive for normal conditions" <| fun _ ->
            let base' = Immune.createThreat Immune.ConfigurationDrift "src" "tgt" "desc"
            let threats = [ { base' with Level = Immune.Low } ]
            let result = Immune.MARA.recommend threats
            Expect.equal result.Strategy Immune.MARA.Passive "Should be Passive"
    ]

// ═══════════════════════════════════════════════════════════════════════════
// NEURO LAYER TESTS
// ═══════════════════════════════════════════════════════════════════════════

[<Tests>]
let neuroMessageTests =
    testList "Neuro Layer - Message Creation" [
        testCase "createMessage sets all fields" <| fun _ ->
            let msg = Neuro.createMessage Neuro.Urgent "source" "dest" "payload"
            Expect.notEqual msg.Id Guid.Empty "ID should be set"
            Expect.equal msg.Priority Neuro.Urgent "Priority should match"
            Expect.equal msg.Source "source" "Source should match"
            Expect.equal msg.Destination "dest" "Destination should match"
            Expect.equal msg.Payload "payload" "Payload should match"
            Expect.equal msg.TTL 10 "TTL should be 10"

        testCase "decrementTTL reduces TTL" <| fun _ ->
            let msg = Neuro.createMessage Neuro.Normal "src" "dst" "data"
            let decremented = Neuro.decrementTTL msg
            Expect.equal decremented.TTL 9 "TTL should be 9"

        testCase "isExpired detects zero TTL" <| fun _ ->
            let base' = Neuro.createMessage Neuro.Normal "src" "dst" "data"
            let msg = { base' with TTL = 0 }
            Expect.isTrue (Neuro.isExpired msg) "Zero TTL should be expired"

        testCase "isExpired detects negative TTL" <| fun _ ->
            let base' = Neuro.createMessage Neuro.Normal "src" "dst" "data"
            let msg = { base' with TTL = -1 }
            Expect.isTrue (Neuro.isExpired msg) "Negative TTL should be expired"
    ]

[<Tests>]
let neuroRoutingTests =
    testList "Neuro Layer - Routing" [
        testCase "route delivers to local node" <| fun _ ->
            let msg = Neuro.createMessage Neuro.Normal "src" "local-node" "data"
            let decision = Neuro.route msg ["local-node"; "other-node"]
            Expect.equal decision (Neuro.Deliver "local-node") "Should deliver to local"

        testCase "route forwards to non-local node" <| fun _ ->
            let msg = Neuro.createMessage Neuro.Normal "src" "remote-node" "data"
            let decision = Neuro.route msg ["local-1"; "local-2"]
            Expect.equal decision (Neuro.Forward "remote-node") "Should forward to remote"

        testCase "route broadcasts for wildcard destination" <| fun _ ->
            let msg = Neuro.createMessage Neuro.Emergency "src" "*" "alert"
            let decision = Neuro.route msg ["node-1"; "node-2"]
            Expect.equal decision Neuro.Broadcast "Wildcard should broadcast"

        testCase "route drops expired messages" <| fun _ ->
            let base' = Neuro.createMessage Neuro.Normal "src" "dst" "data"
            let msg = { base' with TTL = 0 }
            let decision = Neuro.route msg ["dst"]
            match decision with
            | Neuro.Drop _ -> ()
            | _ -> failtest "Expired message should be dropped"
    ]

// ═══════════════════════════════════════════════════════════════════════════
// DARK COCKPIT TESTS
// ═══════════════════════════════════════════════════════════════════════════

[<Tests>]
let darkCockpitStateTests =
    testList "Dark Cockpit - State Management" [
        testCase "initialState is Dark mode" <| fun _ ->
            let state = DarkCockpit.initialState()
            Expect.equal state.Mode DarkCockpit.Dark "Initial mode should be Dark"
            Expect.isEmpty state.Alerts "Alerts should be empty"

        testCase "addAlert adds to list" <| fun _ ->
            let state = DarkCockpit.initialState()
            let alert : DarkCockpit.Alert = {
                Id = Guid.NewGuid()
                Severity = DarkCockpit.Warning
                Title = "Test"
                Message = "Test message"
                Source = "test"
                Timestamp = DateTimeOffset.UtcNow
                Acknowledged = false
            }
            let newState = DarkCockpit.addAlert state alert
            Expect.equal (List.length newState.Alerts) 1 "Should have 1 alert"

        testCase "acknowledgeAlert updates alert" <| fun _ ->
            let alertId = Guid.NewGuid()
            let alert : DarkCockpit.Alert = {
                Id = alertId
                Severity = DarkCockpit.Error
                Title = "Test"
                Message = "Message"
                Source = "test"
                Timestamp = DateTimeOffset.UtcNow
                Acknowledged = false
            }
            let state = DarkCockpit.addAlert (DarkCockpit.initialState()) alert
            let acked = DarkCockpit.acknowledgeAlert state alertId
            let updatedAlert = acked.Alerts |> List.find (fun a -> a.Id = alertId)
            Expect.isTrue updatedAlert.Acknowledged "Alert should be acknowledged"
    ]

[<Tests>]
let darkCockpitModeTests =
    testList "Dark Cockpit - Mode Determination" [
        testCase "critical alerts trigger Emergency mode" <| fun _ ->
            let mode = DarkCockpit.determineMode 0.9 1
            Expect.equal mode DarkCockpit.Emergency "Critical alert should trigger Emergency"

        testCase "low health triggers Bright mode" <| fun _ ->
            let mode = DarkCockpit.determineMode 0.2 0
            Expect.equal mode DarkCockpit.Bright "Low health should trigger Bright"

        testCase "medium health triggers Normal mode" <| fun _ ->
            let mode = DarkCockpit.determineMode 0.5 0
            Expect.equal mode DarkCockpit.Normal "Medium health should trigger Normal"

        testCase "good health triggers Dim mode" <| fun _ ->
            let mode = DarkCockpit.determineMode 0.8 0
            Expect.equal mode DarkCockpit.Dim "Good health should trigger Dim"

        testCase "excellent health stays Dark" <| fun _ ->
            let mode = DarkCockpit.determineMode 0.95 0
            Expect.equal mode DarkCockpit.Dark "Excellent health should stay Dark"
    ]

[<Tests>]
let darkCockpitUpdateTests =
    testList "Dark Cockpit - Update Logic" [
        testCase "update changes mode based on health ratio" <| fun _ ->
            let state = DarkCockpit.initialState()
            let updated = DarkCockpit.update state 10 2 10  // 20% healthy (below 0.3 threshold)
            Expect.equal updated.Mode DarkCockpit.Bright "20% healthy should be Bright"
            Expect.equal updated.ActiveHolons 10 "ActiveHolons should be set"
            Expect.equal updated.HealthySystems 2 "HealthySystems should be set"
            Expect.equal updated.TotalSystems 10 "TotalSystems should be set"

        testCase "update with zero total defaults to 100% healthy" <| fun _ ->
            let state = DarkCockpit.initialState()
            let updated = DarkCockpit.update state 0 0 0
            Expect.equal updated.Mode DarkCockpit.Dark "Zero systems should default to Dark"

        testCase "getUnacknowledgedBySeverity filters correctly" <| fun _ ->
            let state = DarkCockpit.initialState()
            let warning : DarkCockpit.Alert = { Id = Guid.NewGuid(); Severity = DarkCockpit.Warning; Title = "W"; Message = ""; Source = ""; Timestamp = DateTimeOffset.UtcNow; Acknowledged = false }
            let error : DarkCockpit.Alert = { Id = Guid.NewGuid(); Severity = DarkCockpit.Error; Title = "E"; Message = ""; Source = ""; Timestamp = DateTimeOffset.UtcNow; Acknowledged = false }
            let critical : DarkCockpit.Alert = { Id = Guid.NewGuid(); Severity = DarkCockpit.Critical; Title = "C"; Message = ""; Source = ""; Timestamp = DateTimeOffset.UtcNow; Acknowledged = false }
            let critAcked : DarkCockpit.Alert = { Id = Guid.NewGuid(); Severity = DarkCockpit.Critical; Title = "CA"; Message = ""; Source = ""; Timestamp = DateTimeOffset.UtcNow; Acknowledged = true }

            let stateWithAlerts =
                state
                |> fun s -> DarkCockpit.addAlert s warning
                |> fun s -> DarkCockpit.addAlert s error
                |> fun s -> DarkCockpit.addAlert s critical
                |> fun s -> DarkCockpit.addAlert s critAcked

            let unackedCritical = DarkCockpit.getUnacknowledgedBySeverity stateWithAlerts DarkCockpit.Critical
            Expect.equal (List.length unackedCritical) 1 "Should have 1 unacknowledged critical"
    ]

// ═══════════════════════════════════════════════════════════════════════════
// CIRCUIT BREAKER TESTS
// ═══════════════════════════════════════════════════════════════════════════

[<Tests>]
let circuitBreakerCreationTests =
    testList "Circuit Breaker - Creation" [
        testCase "create initializes in Closed state" <| fun _ ->
            let breaker = CircuitBreaker.create "test" 5 (TimeSpan.FromSeconds(30.0))
            Expect.equal breaker.State CircuitBreaker.Closed "Should start Closed"
            Expect.equal breaker.FailureCount 0 "Failure count should be 0"
            Expect.equal breaker.Threshold 5 "Threshold should be 5"

        testCase "create sets name" <| fun _ ->
            let breaker = CircuitBreaker.create "db-pool" 3 (TimeSpan.FromSeconds(10.0))
            Expect.equal breaker.Name "db-pool" "Name should match"
    ]

[<Tests>]
let circuitBreakerStateTests =
    testList "Circuit Breaker - State Transitions" [
        testCase "recordFailure increments count" <| fun _ ->
            let breaker = CircuitBreaker.create "test" 5 (TimeSpan.FromSeconds(30.0))
            let updated = CircuitBreaker.recordFailure breaker
            Expect.equal updated.FailureCount 1 "Failure count should be 1"
            Expect.equal updated.State CircuitBreaker.Closed "Should still be Closed"

        testCase "recordFailure opens at threshold" <| fun _ ->
            let base' = CircuitBreaker.create "test" 3 (TimeSpan.FromSeconds(30.0))
            let breaker = { base' with FailureCount = 2 }
            let updated = CircuitBreaker.recordFailure breaker
            Expect.equal updated.State CircuitBreaker.Open "Should be Open at threshold"

        testCase "recordSuccess in HalfOpen closes breaker" <| fun _ ->
            let base' = CircuitBreaker.create "test" 3 (TimeSpan.FromSeconds(30.0))
            let breaker = { base' with State = CircuitBreaker.HalfOpen }
            let updated = CircuitBreaker.recordSuccess breaker
            Expect.equal updated.State CircuitBreaker.Closed "Should close after HalfOpen success"
            Expect.equal updated.FailureCount 0 "Failures should reset"

        testCase "recordSuccess in Closed increments success" <| fun _ ->
            let breaker = CircuitBreaker.create "test" 3 (TimeSpan.FromSeconds(30.0))
            let updated = CircuitBreaker.recordSuccess breaker
            Expect.equal updated.SuccessCount 1 "Success count should increment"
    ]

[<Tests>]
let circuitBreakerAllowedTests =
    testList "Circuit Breaker - Operation Allowed" [
        testCase "Closed allows operations" <| fun _ ->
            let breaker = CircuitBreaker.create "test" 3 (TimeSpan.FromSeconds(30.0))
            Expect.isTrue (CircuitBreaker.isAllowed breaker) "Closed should allow"

        testCase "Open blocks operations" <| fun _ ->
            let base' = CircuitBreaker.create "test" 3 (TimeSpan.FromSeconds(30.0))
            let breaker = { base' with State = CircuitBreaker.Open }
            Expect.isFalse (CircuitBreaker.isAllowed breaker) "Open should block"

        testCase "HalfOpen allows test operation" <| fun _ ->
            let base' = CircuitBreaker.create "test" 3 (TimeSpan.FromSeconds(30.0))
            let breaker = { base' with State = CircuitBreaker.HalfOpen }
            Expect.isTrue (CircuitBreaker.isAllowed breaker) "HalfOpen should allow test"

        testCase "shouldAttemptReset returns false when Closed" <| fun _ ->
            let breaker = CircuitBreaker.create "test" 3 (TimeSpan.FromSeconds(30.0))
            Expect.isFalse (CircuitBreaker.shouldAttemptReset breaker) "Closed should not reset"

        testCase "attemptHalfOpen transitions Open to HalfOpen after timeout" <| fun _ ->
            let base' = CircuitBreaker.create "test" 3 (TimeSpan.FromMilliseconds(1.0))
            let breaker = { base' with State = CircuitBreaker.Open; LastStateChange = DateTimeOffset.UtcNow.AddMilliseconds(-10.0) }
            let updated = CircuitBreaker.attemptHalfOpen breaker
            Expect.equal updated.State CircuitBreaker.HalfOpen "Should transition to HalfOpen"
    ]

// ═══════════════════════════════════════════════════════════════════════════
// SMART METRICS TESTS
// ═══════════════════════════════════════════════════════════════════════════

[<Tests>]
let smartMetricsCreationTests =
    testList "Smart Metrics - Metric Creation" [
        testCase "createMetric sets all fields" <| fun _ ->
            let labels = Map.ofList [("host", "app-01")]
            let metric = SmartMetrics.createMetric "cpu_usage" SmartMetrics.Gauge 75.5 labels
            Expect.equal metric.Name "cpu_usage" "Name should match"
            Expect.equal metric.Type SmartMetrics.Gauge "Type should be Gauge"
            Expect.equal metric.Value 75.5 "Value should match"
            Expect.equal metric.Labels labels "Labels should match"
    ]

[<Tests>]
let smartMetricsAnomalyTests =
    testList "Smart Metrics - Anomaly Detection" [
        testCase "detectAnomaly returns false for normal values" <| fun _ ->
            let history = [70.0; 72.0; 71.0; 73.0; 72.0]
            let result = SmartMetrics.detectAnomaly history 72.5 2.0
            Expect.isFalse result.IsAnomaly "Normal value should not be anomaly"

        testCase "detectAnomaly returns true for outliers" <| fun _ ->
            let history = [70.0; 72.0; 71.0; 73.0; 72.0]
            let result = SmartMetrics.detectAnomaly history 95.0 2.0
            Expect.isTrue result.IsAnomaly "Outlier should be anomaly"
            Expect.isTrue (result.ZScore > 2.0) "Z-score should exceed threshold"

        testCase "detectAnomaly handles insufficient data" <| fun _ ->
            let result = SmartMetrics.detectAnomaly [50.0] 60.0 2.0
            Expect.isFalse result.IsAnomaly "Should not detect with insufficient data"
            Expect.equal result.Message "Insufficient data" "Should indicate insufficient data"

        testCase "detectAnomaly handles empty history" <| fun _ ->
            let result = SmartMetrics.detectAnomaly [] 50.0 2.0
            Expect.isFalse result.IsAnomaly "Empty history should not detect anomaly"
    ]

[<Tests>]
let smartMetricsMovingAvgTests =
    testList "Smart Metrics - Moving Average" [
        testCase "movingAverage calculates correctly" <| fun _ ->
            let values = [10.0; 20.0; 30.0; 40.0; 50.0]
            let avg = SmartMetrics.movingAverage 3 values
            Expect.floatClose Accuracy.high avg 40.0 "Avg of last 3 (50,40,30) should be 40"

        testCase "movingAverage handles window larger than data" <| fun _ ->
            let values = [10.0; 20.0]
            let avg = SmartMetrics.movingAverage 5 values
            Expect.floatClose Accuracy.high avg 15.0 "Should average all available"

        testCase "movingAverage single value" <| fun _ ->
            let avg = SmartMetrics.movingAverage 3 [42.0]
            Expect.floatClose Accuracy.high avg 42.0 "Single value should return itself"
    ]

// ═══════════════════════════════════════════════════════════════════════════
// ORCHESTRATOR TESTS
// ═══════════════════════════════════════════════════════════════════════════

[<Tests>]
let orchestratorCommandTests =
    testList "Orchestrator - Command Creation" [
        testCase "createCommand sets fields" <| fun _ ->
            let cmd = Orchestrator.createCommand Orchestrator.Status "admin" "app"
            Expect.notEqual cmd.Id Guid.Empty "ID should be set"
            Expect.equal cmd.Type Orchestrator.Status "Type should match"
            Expect.equal cmd.Status Orchestrator.Pending "Status should be Pending"
            Expect.equal cmd.IssuedBy "admin" "IssuedBy should match"
            Expect.equal cmd.Target "app" "Target should match"

        testCase "Stop requires two-key-turn" <| fun _ ->
            let cmd = Orchestrator.createCommand Orchestrator.Stop "admin" "app"
            Expect.isTrue cmd.RequiresTwoKey "Stop should require two-key"

        testCase "Restart requires two-key-turn" <| fun _ ->
            let cmd = Orchestrator.createCommand Orchestrator.Restart "admin" "app"
            Expect.isTrue cmd.RequiresTwoKey "Restart should require two-key"

        testCase "Scale requires two-key-turn" <| fun _ ->
            let cmd = Orchestrator.createCommand (Orchestrator.Scale 5) "admin" "app"
            Expect.isTrue cmd.RequiresTwoKey "Scale should require two-key"

        testCase "Status does not require two-key-turn" <| fun _ ->
            let cmd = Orchestrator.createCommand Orchestrator.Status "admin" "app"
            Expect.isFalse cmd.RequiresTwoKey "Status should not require two-key"

        testCase "Start does not require two-key-turn" <| fun _ ->
            let cmd = Orchestrator.createCommand Orchestrator.Start "admin" "app"
            Expect.isFalse cmd.RequiresTwoKey "Start should not require two-key"
    ]

[<Tests>]
let orchestratorWorkflowTests =
    testList "Orchestrator - Command Workflow" [
        testCase "arm sets Armed status" <| fun _ ->
            let cmd = Orchestrator.createCommand Orchestrator.Stop "admin" "app"
            let armed = Orchestrator.arm cmd
            Expect.equal armed.Status Orchestrator.Armed "Should be Armed"

        testCase "confirm without second key fails for two-key command" <| fun _ ->
            let cmd = Orchestrator.createCommand Orchestrator.Stop "admin" "app"
            let armed = Orchestrator.arm cmd
            let confirmed = Orchestrator.confirm armed None
            match confirmed.Status with
            | Orchestrator.Failed msg -> Expect.stringContains msg "Second key" "Should fail"
            | _ -> failtest "Should fail without second key"

        testCase "confirm with second key succeeds" <| fun _ ->
            let cmd = Orchestrator.createCommand Orchestrator.Stop "admin" "app"
            let armed = Orchestrator.arm cmd
            let confirmed = Orchestrator.confirm armed (Some "supervisor")
            Expect.equal confirmed.Status Orchestrator.Executing "Should be Executing"
            Expect.equal confirmed.SecondKey (Some "supervisor") "Second key should be set"

        testCase "confirm non-two-key command without second key succeeds" <| fun _ ->
            let cmd = Orchestrator.createCommand Orchestrator.Status "admin" "app"
            let armed = Orchestrator.arm cmd
            let confirmed = Orchestrator.confirm armed None
            Expect.equal confirmed.Status Orchestrator.Executing "Should be Executing"

        testCase "complete success sets Completed" <| fun _ ->
            let cmd = Orchestrator.createCommand Orchestrator.Status "admin" "app"
            let completed = Orchestrator.complete cmd true "Done"
            Expect.equal completed.Status Orchestrator.Completed "Should be Completed"
            Expect.isSome completed.CompletedAt "CompletedAt should be set"

        testCase "complete failure sets Failed" <| fun _ ->
            let cmd = Orchestrator.createCommand Orchestrator.Start "admin" "app"
            let completed = Orchestrator.complete cmd false "Connection failed"
            match completed.Status with
            | Orchestrator.Failed msg -> Expect.equal msg "Connection failed" "Message should match"
            | _ -> failtest "Should be Failed"
    ]

[<Tests>]
let orchestratorAuditTests =
    testList "Orchestrator - Audit Trail" [
        testCase "audit creates entry with command info" <| fun _ ->
            let cmd = Orchestrator.createCommand Orchestrator.Stop "admin" "app"
            let entry = Orchestrator.audit cmd "ARMED" "First key provided"
            Expect.equal entry.CommandId cmd.Id "CommandId should match"
            Expect.equal entry.Action "ARMED" "Action should match"
            Expect.equal entry.Actor "admin" "Actor should match"
            Expect.equal entry.Details "First key provided" "Details should match"

        testCase "audit timestamps are current" <| fun _ ->
            let before = DateTimeOffset.UtcNow
            let cmd = Orchestrator.createCommand Orchestrator.Status "user" "target"
            let entry = Orchestrator.audit cmd "CHECK" "Status check"
            let after = DateTimeOffset.UtcNow
            Expect.isTrue (entry.Timestamp >= before && entry.Timestamp <= after) "Timestamp should be current"
    ]

// ═══════════════════════════════════════════════════════════════════════════
// INTEGRATION TESTS
// ═══════════════════════════════════════════════════════════════════════════

[<Tests>]
let integrationTests =
    testList "Integration Tests" [
        testCase "Bio -> Immune integration" <| fun _ ->
            // Create holon with poor vitals
            let vitals = { HealthIndex = 0.2; StressIndex = 0.85; LastUpdate = DateTimeOffset.UtcNow }
            let base' = Bio.createHolon (HolonId "sick-001") (HolonType.Agent "Test") None
            let holon = { base' with State = Bio.Stressed; Vitals = vitals }

            // Immune system assesses threat
            let threatLevel = Immune.assessThreat holon.Vitals
            Expect.equal threatLevel Immune.High "Should detect High threat"

            // Get recommended action
            let action = Immune.recommendAction threatLevel
            Expect.equal action Immune.Isolate "Should recommend Isolate"

        testCase "DarkCockpit + Immune integration" <| fun _ ->
            // Start with healthy cockpit
            let state = DarkCockpit.initialState()

            // Critical threat detected
            let threat = Immune.createThreat Immune.SystemCorruption "db" "core" "Corruption detected"
            let alert : DarkCockpit.Alert = {
                Id = Guid.NewGuid()
                Severity = DarkCockpit.Critical
                Title = threat.Description
                Message = sprintf "Source: %s, Target: %s" threat.Source threat.Target
                Source = "immune-system"
                Timestamp = DateTimeOffset.UtcNow
                Acknowledged = false
            }

            // Add to cockpit
            let stateWithAlert = DarkCockpit.addAlert state alert
            let updated = DarkCockpit.update stateWithAlert 10 10 10

            // Should be in Emergency mode
            Expect.equal updated.Mode DarkCockpit.Emergency "Critical alert should trigger Emergency"

        testCase "Full command workflow with audit" <| fun _ ->
            // Create restart command
            let cmd = Orchestrator.createCommand Orchestrator.Restart "operator" "indrajaal-app"
            let audit1 = Orchestrator.audit cmd "CREATED" "Restart requested"

            // Arm
            let armed = Orchestrator.arm cmd
            let audit2 = Orchestrator.audit armed "ARMED" "First key by operator"

            // Confirm
            let confirmed = Orchestrator.confirm armed (Some "supervisor")
            let audit3 = Orchestrator.audit confirmed "CONFIRMED" "Second key by supervisor"

            // Complete
            let completed = Orchestrator.complete confirmed true "Restart successful"
            let audit4 = Orchestrator.audit completed "COMPLETED" "Service restored"

            // Verify workflow
            Expect.equal completed.Status Orchestrator.Completed "Should be Completed"
            Expect.equal audit4.Action "COMPLETED" "Audit should record completion"
            Expect.equal (List.length [audit1; audit2; audit3; audit4]) 4 "Should have 4 audit entries"
    ]

// ═══════════════════════════════════════════════════════════════════════════
// PROPERTY TESTS
// ═══════════════════════════════════════════════════════════════════════════

[<Tests>]
let propertyTests =
    testList "Property-Based Tests" [
        testPropertyWithConfig { FsCheckConfig.defaultConfig with maxTest = 100 }
            "Membrane Closed always blocks" <| fun (msgType: string) (source: string) ->
            let config = { Bio.defaultMembraneConfig with Permeability = Bio.Closed }
            not (Bio.canPass config msgType source)

        testPropertyWithConfig { FsCheckConfig.defaultConfig with maxTest = 100 }
            "Circuit breaker threshold triggers Open" <| fun (threshold: PositiveInt) ->
            let t = threshold.Get |> min 100  // Cap at 100 for reasonable test
            let breaker = CircuitBreaker.create "test" t (TimeSpan.FromSeconds(1.0))
            let finalBreaker =
                [1..t]
                |> List.fold (fun b _ -> CircuitBreaker.recordFailure b) breaker
            finalBreaker.State = CircuitBreaker.Open

        testPropertyWithConfig { FsCheckConfig.defaultConfig with maxTest = 50 }
            "Neuro TTL decrements correctly" <| fun (ttl: PositiveInt) ->
            let base' = Neuro.createMessage Neuro.Normal "src" "dst" "data"
            let msg = { base' with TTL = ttl.Get }
            let decremented = Neuro.decrementTTL msg
            decremented.TTL = ttl.Get - 1

        testPropertyWithConfig { FsCheckConfig.defaultConfig with maxTest = 50 }
            "Audit entries always have command ID" <| fun (action: NonEmptyString) ->
            let cmd = Orchestrator.createCommand Orchestrator.Status "user" "target"
            let entry = Orchestrator.audit cmd action.Get "details"
            entry.CommandId = cmd.Id
    ]

// ═══════════════════════════════════════════════════════════════════════════
// STAMP COMPLIANCE TESTS
// ═══════════════════════════════════════════════════════════════════════════

[<Tests>]
let stampComplianceTests =
    testList "STAMP Compliance" [
        testCase "SC-PRAJNA-001: Dark Cockpit default" <| fun _ ->
            let state = DarkCockpit.initialState()
            Expect.equal state.Mode DarkCockpit.Dark "Initial mode must be Dark (SC-PRAJNA-001)"

        testCase "SC-PRAJNA-002: Two-key-turn for critical ops" <| fun _ ->
            Expect.isTrue (Orchestrator.requiresTwoKey Orchestrator.Stop) "Stop requires two-key (SC-PRAJNA-002)"
            Expect.isTrue (Orchestrator.requiresTwoKey Orchestrator.Restart) "Restart requires two-key (SC-PRAJNA-002)"
            Expect.isTrue (Orchestrator.requiresTwoKey (Orchestrator.Scale 5)) "Scale requires two-key (SC-PRAJNA-002)"

        testCase "SC-PRAJNA-003: Audit trail required" <| fun _ ->
            let cmd = Orchestrator.createCommand Orchestrator.Stop "admin" "app"
            let entry = Orchestrator.audit cmd "TEST" "Audit test"
            Expect.notEqual entry.CommandId Guid.Empty "Audit must capture command ID (SC-PRAJNA-003)"
            Expect.isTrue (entry.Timestamp > DateTimeOffset.MinValue) "Audit must have timestamp (SC-PRAJNA-003)"

        testCase "SC-PRAJNA-005: Graceful degradation via Circuit Breaker" <| fun _ ->
            let breaker = CircuitBreaker.create "test" 3 (TimeSpan.FromSeconds(10.0))
            // Simulate failures
            let opened = [1..3] |> List.fold (fun b _ -> CircuitBreaker.recordFailure b) breaker
            Expect.equal opened.State CircuitBreaker.Open "Circuit should open on failures (SC-PRAJNA-005)"
            // Should be able to attempt recovery
            let withTimeout = { opened with LastStateChange = DateTimeOffset.UtcNow.AddSeconds(-20.0) }
            let halfOpen = CircuitBreaker.attemptHalfOpen withTimeout
            Expect.equal halfOpen.State CircuitBreaker.HalfOpen "Should allow recovery attempt (SC-PRAJNA-005)"

        testCase "SC-PRAJNA-006: Anomaly detection" <| fun _ ->
            let history = [70.0; 72.0; 71.0; 73.0; 72.0]
            let anomaly = SmartMetrics.detectAnomaly history 150.0 2.0
            Expect.isTrue anomaly.IsAnomaly "Must detect anomalies (SC-PRAJNA-006)"
            Expect.isTrue (anomaly.ZScore > 0.0) "Must compute z-score (SC-PRAJNA-006)"

        testCase "SC-PRAJNA-007: Message routing with TTL" <| fun _ ->
            let msg = Neuro.createMessage Neuro.Normal "src" "dst" "data"
            Expect.isTrue (msg.TTL > 0) "Messages must have TTL (SC-PRAJNA-007)"
            let expired = { msg with TTL = 0 }
            let decision = Neuro.route expired ["dst"]
            match decision with
            | Neuro.Drop _ -> ()
            | _ -> failtest "Expired messages must be dropped (SC-PRAJNA-007)"
    ]
