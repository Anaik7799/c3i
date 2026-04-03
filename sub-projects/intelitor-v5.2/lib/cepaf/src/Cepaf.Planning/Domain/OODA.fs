// =============================================================================
// OODA.fs - OODA Loop Engine for Planning System
// =============================================================================
// STAMP: SC-PLAN-022, SC-OODA-001
// AOR: AOR-PLAN-022, AOR-CAE-001
// Criticality: Level 1 (CRITICAL) - Foundation / Level 3 (IMPORTANT)
// =============================================================================

namespace Cepaf.Planning.Domain

open System
open Cepaf.Planning.Core
open Cepaf.Planning.Core.Ids

/// Observation from the Observe phase
type Observation = {
    Id: Guid
    Source: string          // Where the observation came from
    Content: string         // What was observed
    Timestamp: Timestamp
    Confidence: float       // 0.0 - 1.0
    Tags: Set<string>
    Metadata: Map<string, string>
}

module Observation =
    let create source content confidence =
        {
            Id = Guid.NewGuid()
            Source = source
            Content = content
            Timestamp = DateTimeOffset.UtcNow
            Confidence = max 0.0 (min 1.0 confidence)
            Tags = Set.empty
            Metadata = Map.empty
        }

    let withTags tags (obs: Observation) = { obs with Tags = tags }
    let addTag tag (obs: Observation) = { obs with Tags = obs.Tags |> Set.add tag }
    let withMetadata key value (obs: Observation) : Observation =
        { obs with Metadata = obs.Metadata |> Map.add key value }

/// Orientation analysis from the Orient phase
type Orientation = {
    Observations: Observation list
    Patterns: string list       // Identified patterns
    Threats: string list        // Potential threats/risks
    Opportunities: string list  // Potential opportunities
    Constraints: string list    // Current constraints
    Analysis: string            // Summary analysis
    Timestamp: Timestamp
}

module Orientation =
    let create observations analysis =
        {
            Observations = observations
            Patterns = []
            Threats = []
            Opportunities = []
            Constraints = []
            Analysis = analysis
            Timestamp = DateTimeOffset.UtcNow
        }

    let withPatterns patterns ori = { ori with Patterns = patterns }
    let withThreats threats ori = { ori with Threats = threats }
    let withOpportunities opps ori = { ori with Opportunities = opps }
    let withConstraints cons ori = { ori with Constraints = cons }

/// Course of Action (COA) from the Decide phase
type CourseOfAction = {
    Id: Guid
    Name: string
    Description: string
    Pros: string list
    Cons: string list
    Risk: float             // 0.0 - 1.0
    Effort: float           // Relative effort (0.0 - 10.0)
    Impact: float           // Expected impact (0.0 - 10.0)
    Score: float            // Calculated score
    Timestamp: Timestamp
}

module CourseOfAction =
    /// Calculate COA score using weighted formula
    /// Score = (Impact × (1 - Risk)) / (Effort + 0.1)
    let calculateScore risk effort impact =
        (impact * (1.0 - risk)) / (effort + 0.1)

    let create name description =
        {
            Id = Guid.NewGuid()
            Name = name
            Description = description
            Pros = []
            Cons = []
            Risk = 0.5
            Effort = 5.0
            Impact = 5.0
            Score = 0.0
            Timestamp = DateTimeOffset.UtcNow
        }

    let withPros pros coa = { coa with Pros = pros }
    let withCons cons coa = { coa with Cons = cons }

    let setMetrics risk effort impact coa =
        let score = calculateScore risk effort impact
        { coa with Risk = risk; Effort = effort; Impact = impact; Score = score }

    let recalculateScore coa =
        { coa with Score = calculateScore coa.Risk coa.Effort coa.Impact }

/// Action from the Act phase
type OODAAction = {
    Id: Guid
    COAId: Guid             // Reference to selected COA
    Description: string
    TaskIds: TaskId list    // Tasks affected/created
    StartedAt: Timestamp option
    CompletedAt: Timestamp option
    Result: string option
    Success: bool option
}

module OODAAction =
    let create coaId description =
        {
            Id = Guid.NewGuid()
            COAId = coaId
            Description = description
            TaskIds = []
            StartedAt = None
            CompletedAt = None
            Result = None
            Success = None
        }

    let start action =
        { action with StartedAt = Some DateTimeOffset.UtcNow }

    let complete result success action =
        { action with
            CompletedAt = Some DateTimeOffset.UtcNow
            Result = Some result
            Success = Some success }

    let withTasks taskIds action =
        { action with TaskIds = taskIds }

/// OODA Cycle state
type OODACycle = {
    Id: OODACycleId
    ContextType: string         // "task", "project", "sprint", "ad-hoc"
    ContextId: string           // ID of the context entity
    Phase: OODAPhase
    Observations: Observation list
    Orientation: Orientation option
    COAs: CourseOfAction list
    SelectedCOA: Guid option
    Actions: OODAAction list
    StartedAt: Timestamp
    CompletedAt: Timestamp option
    CycleTimeMs: int64 option
    Metrics: Map<string, float>
}

/// OODA cycle operations
module OODACycle =

    /// Create a new OODA cycle for a context
    let create contextType contextId : OODACycle =
        {
            Id = newOODACycleId ()
            ContextType = contextType
            ContextId = contextId
            Phase = Observe
            Observations = []
            Orientation = None
            COAs = []
            SelectedCOA = None
            Actions = []
            StartedAt = DateTimeOffset.UtcNow
            CompletedAt = None
            CycleTimeMs = None
            Metrics = Map.empty
        }

    /// Create for a task
    let forTask (taskId: TaskId) = create "task" (taskIdValue taskId)

    /// Create for a project
    let forProject (projectId: ProjectId) = create "project" (projectIdValue projectId)

    /// Create for a sprint
    let forSprint (sprintId: SprintId) = create "sprint" (sprintIdValue sprintId)

    /// Create ad-hoc cycle
    let adhoc (description: string) = create "ad-hoc" description

    // === OBSERVE Phase ===

    /// Add an observation
    let observe source content confidence (cycle: OODACycle) : OODACycle =
        let observation = Observation.create source content confidence
        { cycle with
            Observations = observation :: cycle.Observations
            Phase = Observe }

    /// Add multiple observations
    let observeMany (observations: (string * string * float) list) (cycle: OODACycle) : OODACycle =
        let obs = observations |> List.map (fun (s, c, conf) -> Observation.create s c conf)
        { cycle with
            Observations = obs @ cycle.Observations
            Phase = Observe }

    /// Check if we have enough observations to proceed
    let hasEnoughObservations (minCount: int) (cycle: OODACycle) : bool =
        cycle.Observations.Length >= minCount

    // === ORIENT Phase ===

    /// Perform orientation analysis
    let orient analysis patterns threats opportunities constraints (cycle: OODACycle) : OODACycle =
        let orientation =
            Orientation.create cycle.Observations analysis
            |> Orientation.withPatterns patterns
            |> Orientation.withThreats threats
            |> Orientation.withOpportunities opportunities
            |> Orientation.withConstraints constraints
        { cycle with
            Orientation = Some orientation
            Phase = Orient }

    /// Simple orientation with just analysis
    let orientSimple analysis (cycle: OODACycle) : OODACycle =
        orient analysis [] [] [] [] cycle

    // === DECIDE Phase ===

    /// Add a course of action
    let addCOA name description pros cons risk effort impact (cycle: OODACycle) : OODACycle =
        let coa =
            CourseOfAction.create name description
            |> CourseOfAction.withPros pros
            |> CourseOfAction.withCons cons
            |> CourseOfAction.setMetrics risk effort impact
        { cycle with
            COAs = coa :: cycle.COAs
            Phase = Decide }

    /// Select a specific COA
    let selectCOA (coaId: Guid) (cycle: OODACycle) : OODACycle =
        { cycle with
            SelectedCOA = Some coaId
            Phase = Decide }

    /// Auto-select the best COA by score
    let autoSelectBestCOA (cycle: OODACycle) : OODACycle =
        let bestCOA =
            cycle.COAs
            |> List.sortByDescending (fun c -> c.Score)
            |> List.tryHead
        { cycle with
            SelectedCOA = bestCOA |> Option.map (fun c -> c.Id)
            Phase = Decide }

    /// Get the selected COA
    let getSelectedCOA (cycle: OODACycle) : CourseOfAction option =
        cycle.SelectedCOA
        |> Option.bind (fun id -> cycle.COAs |> List.tryFind (fun c -> c.Id = id))

    // === ACT Phase ===

    /// Execute an action
    let act description taskIds (cycle: OODACycle) : OODACycle =
        let coaId = cycle.SelectedCOA |> Option.defaultValue Guid.Empty
        let action =
            OODAAction.create coaId description
            |> OODAAction.withTasks taskIds
            |> OODAAction.start
        { cycle with
            Actions = action :: cycle.Actions
            Phase = Act }

    /// Complete an action
    let completeAction actionId result success (cycle: OODACycle) : OODACycle =
        let actions =
            cycle.Actions
            |> List.map (fun a ->
                if a.Id = actionId then OODAAction.complete result success a
                else a)
        { cycle with Actions = actions }

    // === Cycle Completion ===

    /// Complete the cycle
    let complete (cycle: OODACycle) : OODACycle =
        let now = DateTimeOffset.UtcNow
        let cycleTime = (now - cycle.StartedAt).TotalMilliseconds |> int64
        { cycle with
            Phase = Complete
            CompletedAt = Some now
            CycleTimeMs = Some cycleTime }

    /// Get current cycle duration in ms
    let getCycleTime (cycle: OODACycle) : int64 =
        match cycle.CycleTimeMs with
        | Some ms -> ms
        | None ->
            let now = DateTimeOffset.UtcNow
            (now - cycle.StartedAt).TotalMilliseconds |> int64

    /// Check if cycle meets latency target (SC-OODA-001: <100ms)
    let meetsLatencyTarget (targetMs: int64) (cycle: OODACycle) : bool =
        getCycleTime cycle <= targetMs

    // === Metrics ===

    /// Add a metric
    let addMetric key value (cycle: OODACycle) : OODACycle =
        { cycle with Metrics = cycle.Metrics |> Map.add key value }

    /// Get observation confidence average
    let getAverageConfidence (cycle: OODACycle) : float =
        if cycle.Observations.IsEmpty then 0.0
        else
            let total = cycle.Observations |> List.sumBy (fun o -> o.Confidence)
            total / float cycle.Observations.Length

    /// Get COA count
    let getCOACount (cycle: OODACycle) : int = cycle.COAs.Length

    /// Get action count
    let getActionCount (cycle: OODACycle) : int = cycle.Actions.Length

    /// Check if cycle is complete
    let isComplete (cycle: OODACycle) : bool =
        cycle.Phase = Complete

    /// Check if cycle is in progress
    let isInProgress (cycle: OODACycle) : bool =
        cycle.Phase <> Complete

/// OODA cycle builder for fluent API
type OODACycleBuilder(contextType: string, contextId: string) =
    let mutable cycle = OODACycle.create contextType contextId

    member _.Observe(source, content, confidence) =
        cycle <- OODACycle.observe source content confidence cycle
        cycle

    member _.Orient(analysis, ?patterns, ?threats, ?opportunities, ?constraints) =
        cycle <- OODACycle.orient
            analysis
            (defaultArg patterns [])
            (defaultArg threats [])
            (defaultArg opportunities [])
            (defaultArg constraints [])
            cycle
        cycle

    member _.AddCOA(name, description, ?pros, ?cons, ?risk, ?effort, ?impact) =
        cycle <- OODACycle.addCOA
            name description
            (defaultArg pros [])
            (defaultArg cons [])
            (defaultArg risk 0.5)
            (defaultArg effort 5.0)
            (defaultArg impact 5.0)
            cycle
        cycle

    member _.SelectBestCOA() =
        cycle <- OODACycle.autoSelectBestCOA cycle
        cycle

    member _.Act(description, ?taskIds) =
        cycle <- OODACycle.act description (defaultArg taskIds []) cycle
        cycle

    member _.Complete() =
        cycle <- OODACycle.complete cycle
        cycle

    member _.Build() = cycle

/// Module containing the OODA builder factory
[<AutoOpen>]
module OODABuilderFactory =
    /// Helper to create builder
    let ooda contextType contextId = OODACycleBuilder(contextType, contextId)
