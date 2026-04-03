namespace Cepaf.Core

open System

/// Type-safe State Machines with phantom types for compile-time transition validation.
/// Ensures only valid state transitions can be expressed at the type level.
///
/// WHAT: Phantom-typed state machines with compile-time validation
/// WHY: Prevents invalid state transitions at compile time, not runtime
/// CONSTRAINTS:
///   - SC-FSH-050: State transitions must be type-safe
///   - SC-FSH-051: Invalid transitions must be compile errors
///   - SC-FSH-052: State machine must be serializable for persistence
///
/// TDG Compliance:
///   - TDG-FSH-050: All valid transitions tested
///   - TDG-FSH-051: Type system prevents invalid transitions (compile-time)
///
/// AOR Compliance:
///   - AOR-FSH-025: Use typed state machines for workflow state
module StateMachine =

    // =========================================================================
    // PHANTOM TYPE MARKERS
    // =========================================================================

    /// Phantom type for state markers (no runtime representation)
    type StateMarker = class end

    /// Initial state marker
    type Initial = class inherit StateMarker end

    /// In-progress state marker
    type InProgress = class inherit StateMarker end

    /// Completed state marker
    type Completed = class inherit StateMarker end

    /// Failed state marker
    type Failed = class inherit StateMarker end

    /// Cancelled state marker
    type Cancelled = class inherit StateMarker end

    // =========================================================================
    // TYPED STATE MACHINE
    // =========================================================================

    /// State machine with phantom type tracking current state
    type Machine<'State, 'Data when 'State :> StateMarker> = private {
        Data: 'Data
        EnteredAt: DateTimeOffset
        History: (string * DateTimeOffset) list
    }

    /// State machine operations
    module Machine =
        /// Create initial state machine
        let create (data: 'Data) : Machine<Initial, 'Data> = {
            Data = data
            EnteredAt = DateTimeOffset.UtcNow
            History = [("Initial", DateTimeOffset.UtcNow)]
        }

        /// Create machine with specific state (internal helper for domain state machines)
        let inline internal createWithState<'State, 'Data when 'State :> StateMarker> (stateName: string) (data: 'Data) : Machine<'State, 'Data> = {
            Data = data
            EnteredAt = DateTimeOffset.UtcNow
            History = [(stateName, DateTimeOffset.UtcNow)]
        }

        /// Get the data from machine
        let getData (m: Machine<'State, 'Data>) = m.Data

        /// Get state entry time
        let getEnteredAt (m: Machine<'State, 'Data>) = m.EnteredAt

        /// Get state history
        let getHistory (m: Machine<'State, 'Data>) = m.History

        /// Internal state transition helper
        let private transition<'From, 'To, 'Data when 'From :> StateMarker and 'To :> StateMarker>
            (stateName: string)
            (transform: 'Data -> 'Data)
            (m: Machine<'From, 'Data>) : Machine<'To, 'Data> =
            {
                Data = transform m.Data
                EnteredAt = DateTimeOffset.UtcNow
                History = (stateName, DateTimeOffset.UtcNow) :: m.History
            }

        // =====================================================================
        // VALID TRANSITIONS (Type-safe at compile time)
        // =====================================================================

        /// Initial -> InProgress transition
        let start (transform: 'Data -> 'Data) (m: Machine<Initial, 'Data>) : Machine<InProgress, 'Data> =
            transition "InProgress" transform m

        /// Initial -> InProgress (no data change)
        let startSimple (m: Machine<Initial, 'Data>) : Machine<InProgress, 'Data> =
            transition "InProgress" id m

        /// InProgress -> Completed transition
        let complete (transform: 'Data -> 'Data) (m: Machine<InProgress, 'Data>) : Machine<Completed, 'Data> =
            transition "Completed" transform m

        /// InProgress -> Completed (no data change)
        let completeSimple (m: Machine<InProgress, 'Data>) : Machine<Completed, 'Data> =
            transition "Completed" id m

        /// InProgress -> Failed transition
        let fail (transform: 'Data -> 'Data) (m: Machine<InProgress, 'Data>) : Machine<Failed, 'Data> =
            transition "Failed" transform m

        /// InProgress -> Failed (no data change)
        let failSimple (m: Machine<InProgress, 'Data>) : Machine<Failed, 'Data> =
            transition "Failed" id m

        /// InProgress -> Cancelled transition
        let cancel (transform: 'Data -> 'Data) (m: Machine<InProgress, 'Data>) : Machine<Cancelled, 'Data> =
            transition "Cancelled" transform m

        /// Initial -> Cancelled transition (can cancel before starting)
        let cancelInitial (transform: 'Data -> 'Data) (m: Machine<Initial, 'Data>) : Machine<Cancelled, 'Data> =
            transition "Cancelled" transform m

        /// Failed -> Initial transition (retry)
        let retry (transform: 'Data -> 'Data) (m: Machine<Failed, 'Data>) : Machine<Initial, 'Data> =
            transition "Initial (Retry)" transform m

        /// Modify data without changing state
        let modify (f: 'Data -> 'Data) (m: Machine<'State, 'Data>) : Machine<'State, 'Data> =
            { m with Data = f m.Data }

    // =========================================================================
    // CONTAINER STATE MACHINE (Domain-specific)
    // =========================================================================

    /// Container lifecycle states
    module ContainerStates =
        type Created = class inherit StateMarker end
        type Starting = class inherit StateMarker end
        type Running = class inherit StateMarker end
        type Stopping = class inherit StateMarker end
        type Stopped = class inherit StateMarker end
        type Removing = class inherit StateMarker end
        type Removed = class inherit StateMarker end
        type Error = class inherit StateMarker end

    /// Container data
    type ContainerData = {
        Id: string
        Name: string
        Image: string
        StartedAt: DateTimeOffset option
        StoppedAt: DateTimeOffset option
        ExitCode: int option
        ErrorMessage: string option
    }

    /// Container state machine operations
    module Container =
        open ContainerStates

        let create (name: string) (image: string) : Machine<Created, ContainerData> =
            Machine.createWithState<Created, ContainerData> "Created" {
                Id = Guid.NewGuid().ToString("N").Substring(0, 12)
                Name = name
                Image = image
                StartedAt = None
                StoppedAt = None
                ExitCode = None
                ErrorMessage = None
            }

        let start (m: Machine<Created, ContainerData>) : Machine<Starting, ContainerData> =
            { Data = m.Data; EnteredAt = DateTimeOffset.UtcNow; History = ("Starting", DateTimeOffset.UtcNow) :: m.History }

        let running (m: Machine<Starting, ContainerData>) : Machine<Running, ContainerData> =
            let data = { m.Data with StartedAt = Some DateTimeOffset.UtcNow }
            { Data = data; EnteredAt = DateTimeOffset.UtcNow; History = ("Running", DateTimeOffset.UtcNow) :: m.History }

        let stop (m: Machine<Running, ContainerData>) : Machine<Stopping, ContainerData> =
            { Data = m.Data; EnteredAt = DateTimeOffset.UtcNow; History = ("Stopping", DateTimeOffset.UtcNow) :: m.History }

        let stopped (exitCode: int) (m: Machine<Stopping, ContainerData>) : Machine<Stopped, ContainerData> =
            let data = { m.Data with StoppedAt = Some DateTimeOffset.UtcNow; ExitCode = Some exitCode }
            { Data = data; EnteredAt = DateTimeOffset.UtcNow; History = ("Stopped", DateTimeOffset.UtcNow) :: m.History }

        let error (message: string) (m: Machine<'State, ContainerData>) : Machine<Error, ContainerData> =
            let data = { m.Data with ErrorMessage = Some message }
            { Data = data; EnteredAt = DateTimeOffset.UtcNow; History = ("Error", DateTimeOffset.UtcNow) :: m.History }

    // =========================================================================
    // AGENT TASK STATE MACHINE (Domain-specific)
    // =========================================================================

    /// Agent task lifecycle states
    module TaskStates =
        type Pending = class inherit StateMarker end
        type Assigned = class inherit StateMarker end
        type Executing = class inherit StateMarker end
        type Blocked = class inherit StateMarker end
        type Succeeded = class inherit StateMarker end
        type Failed = class inherit StateMarker end
        type Cancelled = class inherit StateMarker end

    /// Agent task data
    type TaskData = {
        TaskId: string
        AgentId: string option
        Description: string
        Priority: int
        AssignedAt: DateTimeOffset option
        StartedAt: DateTimeOffset option
        CompletedAt: DateTimeOffset option
        Result: Result<string, string> option
        RetryCount: int
    }

    /// Agent task state machine operations
    module AgentTask =
        open TaskStates

        let create (description: string) (priority: int) : Machine<Pending, TaskData> =
            Machine.createWithState<Pending, TaskData> "Pending" {
                TaskId = Guid.NewGuid().ToString("N").Substring(0, 8)
                AgentId = None
                Description = description
                Priority = priority
                AssignedAt = None
                StartedAt = None
                CompletedAt = None
                Result = None
                RetryCount = 0
            }

        let assign (agentId: string) (m: Machine<Pending, TaskData>) : Machine<Assigned, TaskData> =
            let data = { m.Data with AgentId = Some agentId; AssignedAt = Some DateTimeOffset.UtcNow }
            { Data = data; EnteredAt = DateTimeOffset.UtcNow; History = ("Assigned", DateTimeOffset.UtcNow) :: m.History }

        let execute (m: Machine<Assigned, TaskData>) : Machine<Executing, TaskData> =
            let data = { m.Data with StartedAt = Some DateTimeOffset.UtcNow }
            { Data = data; EnteredAt = DateTimeOffset.UtcNow; History = ("Executing", DateTimeOffset.UtcNow) :: m.History }

        let block (reason: string) (m: Machine<Executing, TaskData>) : Machine<Blocked, TaskData> =
            { Data = m.Data; EnteredAt = DateTimeOffset.UtcNow; History = ($"Blocked: {reason}", DateTimeOffset.UtcNow) :: m.History }

        let unblock (m: Machine<Blocked, TaskData>) : Machine<Executing, TaskData> =
            { Data = m.Data; EnteredAt = DateTimeOffset.UtcNow; History = ("Unblocked", DateTimeOffset.UtcNow) :: m.History }

        let succeed (result: string) (m: Machine<Executing, TaskData>) : Machine<Succeeded, TaskData> =
            let data = { m.Data with CompletedAt = Some DateTimeOffset.UtcNow; Result = Some (Ok result) }
            { Data = data; EnteredAt = DateTimeOffset.UtcNow; History = ("Succeeded", DateTimeOffset.UtcNow) :: m.History }

        let fail (error: string) (m: Machine<Executing, TaskData>) : Machine<Failed, TaskData> =
            let data = { m.Data with CompletedAt = Some DateTimeOffset.UtcNow; Result = Some (Error error) }
            { Data = data; EnteredAt = DateTimeOffset.UtcNow; History = ("Failed", DateTimeOffset.UtcNow) :: m.History }

        let retry (m: Machine<Failed, TaskData>) : Machine<Pending, TaskData> =
            let data = { m.Data with RetryCount = m.Data.RetryCount + 1; Result = None; CompletedAt = None }
            { Data = data; EnteredAt = DateTimeOffset.UtcNow; History = ($"Retry #{data.RetryCount}", DateTimeOffset.UtcNow) :: m.History }

        let cancel (m: Machine<'State, TaskData>) : Machine<Cancelled, TaskData> =
            let data = { m.Data with CompletedAt = Some DateTimeOffset.UtcNow }
            { Data = data; EnteredAt = DateTimeOffset.UtcNow; History = ("Cancelled", DateTimeOffset.UtcNow) :: m.History }

    // =========================================================================
    // OODA LOOP STATE MACHINE
    // =========================================================================

    /// OODA loop states
    module OODAStates =
        type Observe = class inherit StateMarker end
        type Orient = class inherit StateMarker end
        type Decide = class inherit StateMarker end
        type Act = class inherit StateMarker end

    /// OODA loop data
    type OODAData<'Observation, 'Context, 'Decision, 'Action> = {
        LoopId: string
        Iteration: int
        Observation: 'Observation option
        Context: 'Context option
        Decision: 'Decision option
        Action: 'Action option
        StartedAt: DateTimeOffset
        CompletedPhases: string list
    }

    /// OODA loop state machine
    module OODALoop =
        open OODAStates

        let start<'O, 'C, 'D, 'A> () : Machine<Observe, OODAData<'O, 'C, 'D, 'A>> =
            Machine.createWithState<Observe, OODAData<'O, 'C, 'D, 'A>> "Observe" {
                LoopId = Guid.NewGuid().ToString("N").Substring(0, 8)
                Iteration = 1
                Observation = None
                Context = None
                Decision = None
                Action = None
                StartedAt = DateTimeOffset.UtcNow
                CompletedPhases = []
            }

        let observe (observation: 'O) (m: Machine<Observe, OODAData<'O, 'C, 'D, 'A>>) : Machine<Orient, OODAData<'O, 'C, 'D, 'A>> =
            let data = { m.Data with Observation = Some observation; CompletedPhases = "Observe" :: m.Data.CompletedPhases }
            { Data = data; EnteredAt = DateTimeOffset.UtcNow; History = ("Orient", DateTimeOffset.UtcNow) :: m.History }

        let orient (context: 'C) (m: Machine<Orient, OODAData<'O, 'C, 'D, 'A>>) : Machine<Decide, OODAData<'O, 'C, 'D, 'A>> =
            let data = { m.Data with Context = Some context; CompletedPhases = "Orient" :: m.Data.CompletedPhases }
            { Data = data; EnteredAt = DateTimeOffset.UtcNow; History = ("Decide", DateTimeOffset.UtcNow) :: m.History }

        let decide (decision: 'D) (m: Machine<Decide, OODAData<'O, 'C, 'D, 'A>>) : Machine<Act, OODAData<'O, 'C, 'D, 'A>> =
            let data = { m.Data with Decision = Some decision; CompletedPhases = "Decide" :: m.Data.CompletedPhases }
            { Data = data; EnteredAt = DateTimeOffset.UtcNow; History = ("Act", DateTimeOffset.UtcNow) :: m.History }

        let act (action: 'A) (m: Machine<Act, OODAData<'O, 'C, 'D, 'A>>) : Machine<Observe, OODAData<'O, 'C, 'D, 'A>> =
            let data = {
                m.Data with
                    Action = Some action
                    CompletedPhases = "Act" :: m.Data.CompletedPhases
                    Iteration = m.Data.Iteration + 1
                    // Reset for next iteration
                    Observation = None
                    Context = None
                    Decision = None
            }
            { Data = data; EnteredAt = DateTimeOffset.UtcNow; History = ("Observe (next)", DateTimeOffset.UtcNow) :: m.History }

    // =========================================================================
    // STATE MACHINE UTILITIES
    // =========================================================================

    /// Utilities for state machine introspection
    module Utils =
        /// Get current state name from history
        let currentStateName (m: Machine<'S, 'D>) =
            m.History |> List.tryHead |> Option.map fst |> Option.defaultValue "Unknown"

        /// Get time spent in current state
        let timeInCurrentState (m: Machine<'S, 'D>) =
            DateTimeOffset.UtcNow - m.EnteredAt

        /// Get total transitions count
        let transitionCount (m: Machine<'S, 'D>) =
            m.History.Length

        /// Check if machine has been in a specific state
        let hasBeenInState (stateName: string) (m: Machine<'S, 'D>) =
            m.History |> List.exists (fun (s, _) -> s.Contains(stateName))

        /// Get time of first entry into state
        let firstEntryTime (stateName: string) (m: Machine<'S, 'D>) =
            m.History
            |> List.filter (fun (s, _) -> s.Contains(stateName))
            |> List.tryLast
            |> Option.map snd
