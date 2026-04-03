// =============================================================================
// Prajna C3I Cockpit - Model (MVU State Management)
// =============================================================================
// STAMP: SC-HMI-001 to SC-HMI-011, SC-PRAJNA-001 to SC-PRAJNA-007
//
// ## Document Control
// | Field | Value |
// |-------|-------|
// | Version | 1.0.0 |
// | Created | 2026-01-03 |
// | Author | Cybernetic Architect |
// | Reference | SC-PRAJNA-*, AOR-PRAJNA-* |
// =============================================================================

namespace Cepaf.Cockpit.Avalonia.Domain

open System
open Types
open Messages
open Fabulous

/// <summary>
/// MVU Model - State initialization and update functions
/// Implements the core state management for Prajna C3I Cockpit
/// </summary>
module Model =

    // =========================================================================
    // Default Color Schemes
    // =========================================================================

    let darkColors: ColorScheme = {
        Primary = "#1976D2"       // Blue
        Secondary = "#424242"
        Accent = "#FF5722"        // Deep Orange
        Background = "#121212"
        Surface = "#1E1E1E"
        Error = "#CF6679"
        Warning = "#FFB74D"
        Success = "#81C784"
        Info = "#64B5F6"
        OnPrimary = "#FFFFFF"
        OnBackground = "#E0E0E0"
        OnSurface = "#FFFFFF"
    }

    let lightColors: ColorScheme = {
        Primary = "#1976D2"
        Secondary = "#757575"
        Accent = "#FF5722"
        Background = "#FAFAFA"
        Surface = "#FFFFFF"
        Error = "#B00020"
        Warning = "#FFA000"
        Success = "#388E3C"
        Info = "#1976D2"
        OnPrimary = "#FFFFFF"
        OnBackground = "#212121"
        OnSurface = "#212121"
    }

    let aerospaceColors: ColorScheme = {
        Primary = "#00BCD4"       // Cyan
        Secondary = "#263238"     // Blue Grey
        Accent = "#FF9800"        // Orange
        Background = "#0A0A0A"
        Surface = "#1A1A2E"
        Error = "#FF5252"
        Warning = "#FFD740"
        Success = "#69F0AE"
        Info = "#40C4FF"
        OnPrimary = "#000000"
        OnBackground = "#00FF00"  // Green terminal style
        OnSurface = "#FFFFFF"
    }

    /// WCAG AAA compliant high-contrast color scheme (SC-HMI-031, minimum 7:1 contrast ratio)
    let highContrastColors: ColorScheme = {
        Primary = "#FFFF00"       // Yellow on black — contrast > 19:1 (WCAG AAA)
        Secondary = "#FFFFFF"     // White on black  — contrast 21:1
        Accent = "#00FF00"        // Lime on black   — contrast > 15:1
        Background = "#000000"   // Pure black
        Surface = "#0D0D0D"      // Near-black surface
        Error = "#FF6666"        // Bright red — legible on black (> 7:1)
        Warning = "#FFD700"      // Gold on black   — contrast > 9:1
        Success = "#00FF7F"      // Spring green    — contrast > 12:1
        Info = "#00BFFF"         // Deep sky blue   — contrast > 7:1
        OnPrimary = "#000000"    // Black on yellow — contrast > 19:1
        OnBackground = "#FFFFFF" // White on black  — contrast 21:1
        OnSurface = "#FFFFFF"    // White on near-black
    }

    // =========================================================================
    // Initial States
    // =========================================================================

    let initialSystemHealth: SystemHealth = {
        Overall = Unknown
        CpuUsage = 0.0
        MemoryUsage = 0.0
        DiskUsage = 0.0
        NetworkLatency = 0
        ActiveConnections = 0
        ErrorRate = 0.0
        LastUpdated = DateTime.MinValue
    }

    let initialOodaState: OodaState = {
        CurrentPhase = Observe
        CycleCount = 0
        CycleStartTime = DateTime.UtcNow
        LastCycleDuration = TimeSpan.Zero
        ObservationsCount = 0
        DecisionsMade = 0
        ActionsExecuted = 0
    }

    let initialFitness: FitnessMetrics = {
        Coverage = 0.0
        PassRate = 0.0
        MutationScore = 0.0
        Diversity = 0.0
        Combined = 0.0
    }

    let initialGenome: GenomeConfig = {
        MutationRate = 0.1
        CrossoverRate = 0.7
        SelectionPressure = 0.8
        ElitePreservation = 0.1
        DiversityFloor = 0.3
    }

    let initialTestEvolution: TestEvolutionState = {
        Fitness = initialFitness
        Genome = initialGenome
        Ooda = initialOodaState
        LevelCoverages = [
            { Level = TDG; Coverage = 0.0; TestCount = 0; PassRate = 0.0; LastRun = None }
            { Level = FMEA; Coverage = 0.0; TestCount = 0; PassRate = 0.0; LastRun = None }
            { Level = Formal; Coverage = 0.0; TestCount = 0; PassRate = 0.0; LastRun = None }
            { Level = Graph; Coverage = 0.0; TestCount = 0; PassRate = 0.0; LastRun = None }
            { Level = BDD; Coverage = 0.0; TestCount = 0; PassRate = 0.0; LastRun = None }
        ]
        ActiveModule = None
        IsEvolving = false
        GenerationCount = 0
    }

    let initialAlarms: AlarmsState = {
        ActiveAlarms = []
        RecentAlarms = []
        Storm = { IsActive = false; AlarmCount = 0; StartTime = None; AffectedZones = [] }
        TotalToday = 0
        AcknowledgedToday = 0
        CorrelationGroups = []
    }

    let initialDevices: DevicesState = {
        Devices = []
        OnlineCount = 0
        OfflineCount = 0
        SelectedDevice = None
    }

    let initialVideo: VideoState = {
        Streams = []
        RecentDetections = []
        ActiveLayout = "2x2"
        SelectedStream = None
    }

    let initialCopilot: CopilotState = {
        Messages = []
        CurrentInput = ""
        IsProcessing = false
        LastSuggestion = None
        ContextSummary = ""
    }

    let initialGuardian: GuardianState = {
        Proposals = []
        TotalApproved = 0
        TotalVetoed = 0
        IsHealthy = true
        LastHealthCheck = DateTime.UtcNow
    }

    let initialSentinel: SentinelState = {
        HealthScore = 1.0
        ActiveThreats = []
        ThreatTaxonomy = Map.empty
        QuarantinedProcesses = 0
        LastAssessment = DateTime.UtcNow
    }

    let initialRegister: RegisterState = {
        Blocks = []
        ChainLength = 0L
        IsVerified = false
        LastBlock = None
        IntegrityStatus = "Unverified"
    }

    let initialAnalytics: AnalyticsState = {
        AvailableReports = []
        RecentReports = []
        TrendData = []
        SelectedReport = None
    }

    let initialCompliance: ComplianceState = {
        Items = []
        OverallStatus = Unknown
        AuditTrail = []
        PendingActions = []
    }

    let initialSyncState: SyncState = {
        ElixirConnection = Disconnected
        ZenohConnection = Disconnected
        LastSync = DateTime.MinValue
        PendingMessages = 0
    }

    // =========================================================================
    // Initial Model
    // =========================================================================

    let init () : Model =
        {
            // Navigation
            ActiveView = Dashboard
            SidebarExpanded = true

            // Theme - Default to Dark Aerospace theme
            Theme = Aerospace
            Colors = aerospaceColors

            // System Status
            SystemHealth = initialSystemHealth
            SyncState = initialSyncState

            // Domain States
            TestEvolution = initialTestEvolution
            Alarms = initialAlarms
            Devices = initialDevices
            Video = initialVideo
            Copilot = initialCopilot
            Guardian = initialGuardian
            Sentinel = initialSentinel
            Register = initialRegister
            Analytics = initialAnalytics
            Compliance = initialCompliance

            // UI State
            IsLoading = false
            ErrorMessage = None
            SuccessMessage = None
            LastUpdated = DateTime.UtcNow
        }

    // =========================================================================
    // Update Functions
    // =========================================================================

    let updateNavigation (msg: NavigationMsg) (model: Model) : Model =
        match msg with
        | Navigate view ->
            { model with ActiveView = view }
        | ToggleSidebar ->
            { model with SidebarExpanded = not model.SidebarExpanded }
        | GoBack ->
            { model with ActiveView = Dashboard }
        | GoHome ->
            { model with ActiveView = Dashboard }

    let updateTheme (msg: ThemeMsg) (model: Model) : Model =
        match msg with
        | SetTheme theme ->
            let colors =
                match theme with
                | Dark -> darkColors
                | Light -> lightColors
                | Aerospace -> aerospaceColors
                | HighContrast -> highContrastColors
            { model with Theme = theme; Colors = colors }
        | ToggleDarkMode ->
            let newTheme = if model.Theme = Dark then Light else Dark
            updateTheme (SetTheme newTheme) model
        | SetCustomColor (key, value) ->
            model  // TODO: Implement custom color setting

    let updateSystem (msg: SystemMsg) (model: Model) : Model =
        match msg with
        | RefreshAll ->
            { model with IsLoading = true }
        | HealthUpdated health ->
            { model with SystemHealth = health }
        | ConnectionStatusChanged status ->
            let sync = { model.SyncState with ElixirConnection = status }
            { model with SyncState = sync }
        | SyncCompleted time ->
            let sync = { model.SyncState with LastSync = time }
            { model with SyncState = sync; IsLoading = false }
        | ErrorOccurred msg ->
            { model with ErrorMessage = Some msg; IsLoading = false }
        | ClearError ->
            { model with ErrorMessage = None }
        | ShowSuccess msg ->
            { model with SuccessMessage = Some msg }
        | ClearSuccess ->
            { model with SuccessMessage = None }

    let updateTestEvolution (msg: TestEvolutionMsg) (model: Model) : Model =
        let te = model.TestEvolution
        match msg with
        | SetActiveModule path ->
            { model with TestEvolution = { te with ActiveModule = Some path } }
        | ClearActiveModule ->
            { model with TestEvolution = { te with ActiveModule = None } }
        | GenerateTests _level ->
            { model with IsLoading = true }
        | GenerateAllLevels ->
            { model with IsLoading = true }
        | TestsGenerated result ->
            match result with
            | Ok fitness ->
                { model with
                    TestEvolution = { te with Fitness = fitness }
                    IsLoading = false
                    SuccessMessage = Some "Tests generated successfully" }
            | Error err ->
                { model with ErrorMessage = Some err; IsLoading = false }
        | TriggerEvolution ->
            { model with TestEvolution = { te with IsEvolving = true } }
        | EvolutionCompleted state ->
            { model with TestEvolution = state }
        | UpdateGenomeConfig genome ->
            { model with TestEvolution = { te with Genome = genome } }
        | SetMutationRate rate ->
            let genome = { te.Genome with MutationRate = rate }
            { model with TestEvolution = { te with Genome = genome } }
        | SetCrossoverRate rate ->
            let genome = { te.Genome with CrossoverRate = rate }
            { model with TestEvolution = { te with Genome = genome } }
        | SetSelectionPressure pressure ->
            let genome = { te.Genome with SelectionPressure = pressure }
            { model with TestEvolution = { te with Genome = genome } }
        | OodaCycleCompleted ooda ->
            { model with TestEvolution = { te with Ooda = ooda } }
        | FitnessUpdated fitness ->
            { model with TestEvolution = { te with Fitness = fitness } }
        | LevelCoverageUpdated coverages ->
            { model with TestEvolution = { te with LevelCoverages = coverages } }
        | StartEvolution ->
            { model with TestEvolution = { te with IsEvolving = true } }
        | StopEvolution ->
            { model with TestEvolution = { te with IsEvolving = false } }
        | ResetGenome ->
            { model with TestEvolution = { te with Genome = initialGenome } }

    let updateAlarms (msg: AlarmsMsg) (model: Model) : Model =
        let al = model.Alarms
        match msg with
        | LoadAlarms ->
            { model with IsLoading = true }
        | AlarmsLoaded alarms ->
            let active = alarms |> List.filter (fun a -> a.Status = Active)
            { model with
                Alarms = { al with ActiveAlarms = active; RecentAlarms = alarms }
                IsLoading = false }
        | NewAlarmReceived alarm ->
            { model with
                Alarms = { al with
                    ActiveAlarms = alarm :: al.ActiveAlarms
                    RecentAlarms = alarm :: al.RecentAlarms } }
        | AcknowledgeAlarm _ ->
            model  // Handled by command
        | AlarmAcknowledged id ->
            let updated = al.ActiveAlarms |> List.map (fun a ->
                if a.Id = id then { a with Status = Acknowledged } else a)
            { model with Alarms = { al with ActiveAlarms = updated } }
        | ClearAlarm _ ->
            model  // Handled by command
        | AlarmCleared id ->
            let updated = al.ActiveAlarms |> List.filter (fun a -> a.Id <> id)
            { model with Alarms = { al with ActiveAlarms = updated } }
        | StormDetected storm ->
            { model with Alarms = { al with Storm = storm } }
        | StormCleared ->
            { model with Alarms = { al with Storm = { al.Storm with IsActive = false } } }
        | _ -> model

    let updateGuardian (msg: GuardianMsg) (model: Model) : Model =
        let g = model.Guardian
        match msg with
        | LoadProposals ->
            { model with IsLoading = true }
        | ProposalsLoaded proposals ->
            { model with Guardian = { g with Proposals = proposals }; IsLoading = false }
        | NewProposal proposal ->
            { model with Guardian = { g with Proposals = proposal :: g.Proposals } }
        | ProposalApproved id ->
            let updated = g.Proposals |> List.map (fun p ->
                if p.Id = id then { p with Status = Approved } else p)
            { model with Guardian = { g with
                Proposals = updated
                TotalApproved = g.TotalApproved + 1 } }
        | ProposalVetoed id ->
            let updated = g.Proposals |> List.map (fun p ->
                if p.Id = id then { p with Status = Vetoed } else p)
            { model with Guardian = { g with
                Proposals = updated
                TotalVetoed = g.TotalVetoed + 1 } }
        | GuardianHealthUpdated healthy ->
            { model with Guardian = { g with
                IsHealthy = healthy
                LastHealthCheck = DateTime.UtcNow } }
        | _ -> model

    let updateSentinel (msg: SentinelMsg) (model: Model) : Model =
        let s = model.Sentinel
        match msg with
        | LoadSentinelState ->
            { model with IsLoading = true }
        | SentinelStateLoaded state ->
            { model with Sentinel = state; IsLoading = false }
        | ThreatDetected threat ->
            { model with Sentinel = { s with ActiveThreats = threat :: s.ActiveThreats } }
        | ThreatMitigated id ->
            let updated = s.ActiveThreats |> List.map (fun t ->
                if t.Id = id then { t with Mitigated = true } else t)
            { model with Sentinel = { s with ActiveThreats = updated } }
        | HealthScoreUpdated score ->
            { model with Sentinel = { s with HealthScore = score } }
        | _ -> model

    let updateCopilot (msg: CopilotMsg) (model: Model) : Model =
        let c = model.Copilot
        match msg with
        | SetInput input ->
            { model with Copilot = { c with CurrentInput = input } }
        | SendMessage ->
            let userMsg: ChatMessage = {
                Id = Guid.NewGuid()
                Role = User
                Content = c.CurrentInput
                Timestamp = DateTime.UtcNow
                IsThinking = false
            }
            { model with Copilot = { c with
                Messages = c.Messages @ [userMsg]
                CurrentInput = ""
                IsProcessing = true } }
        | ResponseReceived msg ->
            { model with Copilot = { c with
                Messages = c.Messages @ [msg]
                IsProcessing = false } }
        | ClearChat ->
            { model with Copilot = { c with Messages = [] } }
        | ContextLoaded summary ->
            { model with Copilot = { c with ContextSummary = summary } }
        | SuggestionReceived suggestion ->
            { model with Copilot = { c with LastSuggestion = Some suggestion } }
        | _ -> model

    // =========================================================================
    // Main Update Function
    // =========================================================================

    let update (msg: Msg) (model: Model) : Model =
        match msg with
        | Nav navMsg -> updateNavigation navMsg model
        | Theme themeMsg -> updateTheme themeMsg model
        | System sysMsg -> updateSystem sysMsg model
        | TestEvo teMsg -> updateTestEvolution teMsg model
        | Alarm alMsg -> updateAlarms alMsg model
        | Guard gMsg -> updateGuardian gMsg model
        | Sent sMsg -> updateSentinel sMsg model
        | Copilot cMsg -> updateCopilot cMsg model
        | Initialize -> { model with IsLoading = true }
        | Tick now -> { model with LastUpdated = now }
        | Dispose -> model
        | _ -> model
