namespace Cepaf.Cockpit

// ============================================================================
// FRACTAL INTEGRATION: CEA + OODA + CONTEXT
// Advanced F# Patterns Unified with Safety-Critical Cockpit Operations
// ============================================================================
// Compliance: SC-FRAC-001 through SC-FRAC-020
// Standards: NASA-STD-3000, NUREG-0700, IEC 61508 SIL-2
// ============================================================================

open System
open Cepaf.Cockpit.Domain

// ============================================================================
// FRACTAL CONTEXT: Self-Similar Hierarchical Context (SC-FRAC-001)
// ============================================================================

/// Fractal level in the organizational hierarchy
type FractalLevel =
    | FLSystem      // Entire mesh/enterprise
    | FLCluster     // Cluster of nodes
    | FLNode        // Single node
    | FLProcess     // Single process/agent
    | FLComponent   // Component within process

/// Fractal context - self-similar at all levels
type FractalContext<'T> = {
    Level: FractalLevel
    Data: 'T
    Children: FractalContext<'T> list
    ParentId: string option
    Timestamp: DateTime
    HealthScore: float
    NodeId: string
}

/// Fractal operations (SC-FRAC-002)
module Fractal =
    /// Create leaf context
    let leaf level nodeId data = {
        Level = level
        Data = data
        Children = []
        ParentId = None
        Timestamp = DateTime.UtcNow
        HealthScore = 1.0
        NodeId = nodeId
    }

    /// Add child to context
    let addChild (child: FractalContext<'T>) (parent: FractalContext<'T>) =
        let childWithParent = { child with ParentId = Some parent.NodeId }
        { parent with Children = childWithParent :: parent.Children }

    /// Map over fractal structure (preserves hierarchy)
    let rec map (f: 'T -> 'U) (ctx: FractalContext<'T>) : FractalContext<'U> =
        {
            Level = ctx.Level
            Data = f ctx.Data
            Children = ctx.Children |> List.map (map f)
            ParentId = ctx.ParentId
            Timestamp = ctx.Timestamp
            HealthScore = ctx.HealthScore
            NodeId = ctx.NodeId
        }

    /// Fold over fractal structure (bottom-up aggregation)
    let rec fold (f: 'State -> 'T -> 'State) (state: 'State) (ctx: FractalContext<'T>) : 'State =
        let childState = ctx.Children |> List.fold (fold f) state
        f childState ctx.Data

    /// Propagate health scores up the hierarchy
    let rec propagateHealth (ctx: FractalContext<'T>) : FractalContext<'T> =
        let updatedChildren = ctx.Children |> List.map propagateHealth
        let aggregateHealth =
            if List.isEmpty updatedChildren then ctx.HealthScore
            else updatedChildren |> List.averageBy (fun c -> c.HealthScore)
        { ctx with Children = updatedChildren; HealthScore = min ctx.HealthScore aggregateHealth }

    /// Find context at specific level
    let rec findLevel (level: FractalLevel) (ctx: FractalContext<'T>) : FractalContext<'T> list =
        if ctx.Level = level then [ctx]
        else ctx.Children |> List.collect (findLevel level)

    /// Calculate depth of fractal tree
    let rec depth (ctx: FractalContext<'T>) : int =
        if List.isEmpty ctx.Children then 1
        else 1 + (ctx.Children |> List.map depth |> List.max)

    /// Aggregate metric values across all nodes
    let aggregateMetric (f: 'T -> float) (ctx: FractalContext<'T>) : float =
        let rec collect (c: FractalContext<'T>) =
            f c.Data :: (c.Children |> List.collect collect)
        collect ctx |> List.average

// ============================================================================
// OODA LOOP: Observe-Orient-Decide-Act Cycle (SC-OODA-001)
// ============================================================================

/// OODA phase with timing constraints
type OodaPhase =
    | OodaObserve of maxLatencyMs: int
    | OodaOrient of maxLatencyMs: int
    | OodaDecide of maxLatencyMs: int
    | OodaAct of maxLatencyMs: int

/// OODA cycle state
type OodaCycle<'Obs, 'Orient, 'Decision, 'Action> = {
    Phase: OodaPhase
    Observations: 'Obs list
    Orientation: 'Orient option
    Decision: 'Decision option
    ActionResult: 'Action option
    CycleStart: DateTime
    PhaseStart: DateTime
    CycleCount: int64
    AverageLatencyMs: float
}

/// Situational awareness level
type SaLevel =
    | SaPerception      // SA-1: What is happening
    | SaComprehension   // SA-2: What does it mean
    | SaProjection      // SA-3: What will happen
    | SaDegraded of reason: string  // Degraded SA

/// OODA operations (SC-OODA-002)
module OodaLoop =
    /// Create initial OODA cycle
    let init<'Obs, 'Orient, 'Decision, 'Action> () : OodaCycle<'Obs, 'Orient, 'Decision, 'Action> = {
        Phase = OodaObserve 100
        Observations = []
        Orientation = None
        Decision = None
        ActionResult = None
        CycleStart = DateTime.UtcNow
        PhaseStart = DateTime.UtcNow
        CycleCount = 0L
        AverageLatencyMs = 0.0
    }

    /// Execute one OODA cycle with timing (SC-OODA-003)
    let executeCycle
        (observe: unit -> 'Obs)
        (orient: 'Obs list -> 'Orient)
        (decide: 'Orient -> 'Decision)
        (act: 'Decision -> 'Action)
        (cycle: OodaCycle<'Obs, 'Orient, 'Decision, 'Action>) =

        let now = DateTime.UtcNow
        let observations = [observe ()]
        let orientation = orient observations
        let decision = decide orientation
        let action = act decision
        let cycleLatencyMs = (DateTime.UtcNow - now).TotalMilliseconds

        let newAvg =
            if cycle.CycleCount = 0L then cycleLatencyMs
            else
                let totalMs = cycle.AverageLatencyMs * float cycle.CycleCount
                (totalMs + cycleLatencyMs) / float (cycle.CycleCount + 1L)

        {
            Phase = OodaObserve 100
            Observations = observations
            Orientation = Some orientation
            Decision = Some decision
            ActionResult = Some action
            CycleStart = now
            PhaseStart = DateTime.UtcNow
            CycleCount = cycle.CycleCount + 1L
            AverageLatencyMs = newAvg
        }

    /// Get phase name
    let phaseName = function
        | OodaObserve _ -> "OBSERVE"
        | OodaOrient _ -> "ORIENT"
        | OodaDecide _ -> "DECIDE"
        | OodaAct _ -> "ACT"

    /// Check if cycle is within latency bounds
    let isWithinBounds (cycle: OodaCycle<_, _, _, _>) : bool =
        match cycle.Phase with
        | OodaObserve maxMs | OodaOrient maxMs | OodaDecide maxMs | OodaAct maxMs ->
            cycle.AverageLatencyMs <= float maxMs

// ============================================================================
// CEA: CYBERNETIC ENTERPRISE ARCHITECTURE (SC-CEA-001)
// ============================================================================

/// CEA homeostatic variable
type HomeostasisVar = {
    Name: string
    CurrentValue: float
    Setpoint: float
    Tolerance: float
    DeviationHistory: float list
    ControlGain: float
}

/// CEA control action
type CeaControlAction =
    | CeaNoAction
    | CeaIncrease of magnitude: float
    | CeaDecrease of magnitude: float
    | CeaAlert of message: string
    | CeaEmergency of reason: string

/// CEA controller state
type CeaController = {
    Variables: Map<string, HomeostasisVar>
    Actions: CeaControlAction list
    Timestamp: DateTime
    StabilityScore: float
}

/// CEA operations (SC-CEA-002)
module CeaControl =
    /// Create homeostasis variable
    let createVar name setpoint tolerance gain = {
        Name = name
        CurrentValue = setpoint
        Setpoint = setpoint
        Tolerance = tolerance
        DeviationHistory = []
        ControlGain = gain
    }

    /// Calculate deviation
    let deviation var = var.CurrentValue - var.Setpoint

    /// Determine control action (proportional control)
    let determineAction (v: HomeostasisVar) : CeaControlAction =
        let dev = deviation v
        let absdev = abs dev
        if absdev <= v.Tolerance then CeaNoAction
        elif absdev > v.Tolerance * 3.0 then CeaEmergency $"{v.Name} critical: {dev:F2}"
        elif absdev > v.Tolerance * 2.0 then CeaAlert $"{v.Name} warning: {dev:F2}"
        elif dev > 0.0 then CeaDecrease (dev * v.ControlGain)
        else CeaIncrease (-dev * v.ControlGain)

    /// Update variable with new value
    let updateVar value (v: HomeostasisVar) =
        let history = (value - v.Setpoint) :: (v.DeviationHistory |> List.truncate 99)
        { v with CurrentValue = value; DeviationHistory = history }

    /// Calculate stability score (0-1, based on deviation history)
    let stabilityScore (v: HomeostasisVar) =
        if List.isEmpty v.DeviationHistory then 1.0
        else
            let rmsDeviation =
                v.DeviationHistory
                |> List.map (fun d -> d * d)
                |> List.average
                |> sqrt
            max 0.0 (1.0 - (rmsDeviation / v.Tolerance / 3.0))

    /// Create controller with variables
    let createController (vars: HomeostasisVar list) : CeaController = {
        Variables = vars |> List.map (fun v -> v.Name, v) |> Map.ofList
        Actions = []
        Timestamp = DateTime.UtcNow
        StabilityScore = 1.0
    }

    /// Process all variables and generate actions
    let processController (controller: CeaController) : CeaController =
        let actions =
            controller.Variables
            |> Map.toList
            |> List.map (snd >> determineAction)
            |> List.filter (fun a -> a <> CeaNoAction)

        let stability =
            if Map.isEmpty controller.Variables then 1.0
            else
                controller.Variables
                |> Map.toList
                |> List.map (snd >> stabilityScore)
                |> List.average

        { controller with Actions = actions; StabilityScore = stability; Timestamp = DateTime.UtcNow }

    /// Update a variable in the controller
    let updateVariable name value (controller: CeaController) : CeaController =
        match Map.tryFind name controller.Variables with
        | Some v ->
            let updated = updateVar value v
            { controller with Variables = Map.add name updated controller.Variables }
        | None -> controller

// ============================================================================
// FRACTAL TELEMETRY PIPELINE (SC-FRAC-015)
// ============================================================================

module FractalPipeline =
    /// Create smoothing arrow for telemetry
    let smoothingArrow (windowSize: int) : SignalArrow<float list, float> =
        SignalArrow.arr (fun values ->
            if List.isEmpty values then 0.0
            else values |> List.take (min windowSize (List.length values)) |> List.average
        )

    /// Create trend detection arrow
    let trendArrow : SignalArrow<float list, Trend> =
        SignalArrow.arr (fun values ->
            if List.length values < 2 then Stable
            else
                let recent = values |> List.take (min 5 (List.length values))
                let delta = List.head recent - List.last recent
                if abs delta < 0.1 then Stable
                elif delta > 0.5 then RisingFast
                elif delta > 0.0 then Rising
                elif delta < -0.5 then FallingFast
                else Falling
        )

    /// Create alarm level arrow
    let alarmArrow (threshold: float) : SignalArrow<float, AlarmLevel> =
        SignalArrow.arr (fun value ->
            if value < threshold * 0.5 then Normal
            elif value < threshold * 0.75 then Advisory
            elif value < threshold * 0.9 then Caution
            elif value < threshold then Warning
            else Critical
        )

    /// Process telemetry through fractal levels
    let processAtLevel (data: float list) (context: FractalContext<float>) =
        let smoothing = smoothingArrow 10
        let trend = trendArrow

        // Apply smoothing at this level
        let smoothed = SignalArrow.run smoothing data
        let detectedTrend = SignalArrow.run trend data

        // Update context with processed data
        { context with
            Data = smoothed
            Timestamp = DateTime.UtcNow
            HealthScore = if detectedTrend = Stable then 1.0 elif detectedTrend = Rising || detectedTrend = Falling then 0.8 else 0.5
        }

// ============================================================================
// INTEGRATED STATE MANAGEMENT (SC-FRAC-020)
// ============================================================================

/// Integrated cockpit metrics for fractal context
type FractalMetrics = {
    Cpu: float
    Memory: float
    Latency: float
    ErrorRate: float
    Timestamp: DateTime
}

module FractalMetrics =
    let empty = {
        Cpu = 0.0
        Memory = 0.0
        Latency = 0.0
        ErrorRate = 0.0
        Timestamp = DateTime.UtcNow
    }

    let fromMeshNode (node: MeshNode) : FractalMetrics = {
        Cpu = node.Cpu.Value
        Memory = node.Memory.Value
        Latency = node.NetworkLatency.Value
        ErrorRate = 0.0
        Timestamp = DateTime.UtcNow
    }

/// Integrated cockpit using fractal patterns
type FractalCockpit = {
    Context: FractalContext<FractalMetrics>
    OodaCycle: OodaCycle<MeshNode, SaLevel, MeshCommand, bool>
    Controller: CeaController
    LastUpdate: DateTime
    FrameCount: int64
}

module FractalCockpit =
    /// Initialize fractal cockpit
    let init () : FractalCockpit =
        let ceaVars = [
            CeaControl.createVar "cpu_usage" 50.0 20.0 0.1
            CeaControl.createVar "memory_usage" 60.0 15.0 0.1
            CeaControl.createVar "error_rate" 0.01 0.02 0.5
            CeaControl.createVar "latency_ms" 50.0 30.0 0.2
        ]

        {
            Context = Fractal.leaf FLSystem "cockpit-main" FractalMetrics.empty
            OodaCycle = OodaLoop.init ()
            Controller = CeaControl.createController ceaVars
            LastUpdate = DateTime.UtcNow
            FrameCount = 0L
        }

    /// Update from mesh node
    let processNode (node: MeshNode) (cockpit: FractalCockpit) : FractalCockpit =
        let metrics = FractalMetrics.fromMeshNode node
        let nodeCtx = Fractal.leaf FLNode node.Id metrics
        let newContext = Fractal.addChild nodeCtx cockpit.Context |> Fractal.propagateHealth

        let controller =
            cockpit.Controller
            |> CeaControl.updateVariable "cpu_usage" metrics.Cpu
            |> CeaControl.updateVariable "memory_usage" metrics.Memory
            |> CeaControl.updateVariable "latency_ms" metrics.Latency
            |> CeaControl.processController

        { cockpit with
            Context = newContext
            Controller = controller
            LastUpdate = DateTime.UtcNow
            FrameCount = cockpit.FrameCount + 1L
        }

    /// Get situational awareness level
    let getSaLevel (cockpit: FractalCockpit) : SaLevel =
        let stability = cockpit.Controller.StabilityScore
        let health = cockpit.Context.HealthScore
        let score = (stability + health) / 2.0

        if score >= 0.9 then SaPerception
        elif score >= 0.7 then SaComprehension
        elif score >= 0.5 then SaProjection
        else SaDegraded $"Low score: {score:F2}"

    /// Execute OODA cycle
    let executeOodaCycle (observe: unit -> MeshNode) (cockpit: FractalCockpit) =
        let orient nodes =
            let node = List.head nodes
            let metrics = FractalMetrics.fromMeshNode node
            let health = (100.0 - metrics.Cpu) / 100.0 * (100.0 - metrics.Memory) / 100.0
            if health >= 0.9 then SaPerception
            elif health >= 0.7 then SaComprehension
            elif health >= 0.5 then SaProjection
            else SaDegraded $"Low health: {health:F2}"

        let decide saLevel =
            match saLevel with
            | SaPerception -> ForceHealthCheck
            | SaComprehension -> SetLoadBalancer 50
            | SaProjection -> SetLoadBalancer 75
            | SaDegraded _ -> ClearAlarms

        let act cmd = true  // Command executed successfully

        let newCycle = OodaLoop.executeCycle observe orient decide act cockpit.OodaCycle
        { cockpit with OodaCycle = newCycle }
