namespace Cepaf.Zenoh.Guardian

/// <summary>
/// Constitutional Checker Module (FM-002)
///
/// Implements validation of Ψ₀-Ψ₅ constitutional invariants and Ω₀ Founder's Directive
/// for the Indrajaal biomorphic organism per CLAUDE.md §1.0.
///
/// STAMP Constraints:
/// - SC-SIL6-013: Constitutional checks MUST pass before holon operations
/// - SC-CONST-001: Verify constitution BEFORE any reconfiguration
/// - SC-CONST-002: Immediate halt on constitutional violation
/// - SC-CONST-003: Guardian has absolute veto
/// - SC-CONST-004: Ψ₀-Ψ₅ are hardcoded, cannot be modified
///
/// AOR Rules:
/// - AOR-CONST-001: Constitutional check before reconfiguration
/// - AOR-CONST-002: Immediate halt on violation
/// - AOR-CONST-003: Guardian supremacy - absolute veto
/// - AOR-CONST-004: Axiom protection - Ψ₀-Ψ₅ hardcoded
/// - AOR-FOUNDER-001: Founder's benefit evaluated FIRST
///
/// Target Framework: net10.0
/// </summary>
module ConstitutionalChecker =

    open System
    open System.Threading.Tasks

    // ═══════════════════════════════════════════════════════════════════════
    // SECTION 1: CONSTITUTIONAL INVARIANTS (Ψ₀-Ψ₅)
    // ═══════════════════════════════════════════════════════════════════════

    /// <summary>
    /// Constitutional Invariants - The immutable foundation of the system.
    /// These are HARDCODED and cannot be modified per SC-CONST-004.
    /// </summary>
    [<RequireQualifiedAccess>]
    type ConstitutionalInvariant =
        /// Ψ₀: System must exist and survive ALL operations
        | Psi0_Existence
        /// Ψ₁: State must be regenerable from SQLite/DuckDB alone
        | Psi1_Regeneration
        /// Ψ₂: Complete evolutionary history must be preserved
        | Psi2_History
        /// Ψ₃: All state must be cryptographically verifiable
        | Psi3_Verification
        /// Ψ₄: System serves Founder's lineage (AMENDED per Ω₀)
        | Psi4_HumanAlignment
        /// Ψ₅: No deception - system must be truthful
        | Psi5_Truthfulness

    /// <summary>
    /// Violation severity classification
    /// </summary>
    type ViolationSeverity =
        | Critical      // System cannot continue
        | High          // Immediate attention required
        | Medium        // Must be addressed soon
        | Low           // Monitor and track

    /// <summary>
    /// Constitutional violation record
    /// </summary>
    type ConstitutionalViolation = {
        Invariant: ConstitutionalInvariant
        Severity: ViolationSeverity
        Reason: string
        Timestamp: DateTime
        Context: Map<string, obj>
    }

    // ═══════════════════════════════════════════════════════════════════════
    // SECTION 2: OPERATION TYPES
    // ═══════════════════════════════════════════════════════════════════════

    /// <summary>
    /// Holon identity for federation operations
    /// </summary>
    type HolonIdentity = {
        HolonId: Guid
        Name: string
        PublicKey: byte array
        Capabilities: Set<string>
        CreatedAt: DateTime
    }

    /// <summary>
    /// Operation types that require constitutional validation
    /// </summary>
    [<RequireQualifiedAccess>]
    type Operation =
        /// Join holon to federation
        | HolonJoin of HolonIdentity
        /// Reconfigure system at fractal layer L0-L7
        | Reconfigure of layer: int * proposal: string
        /// State mutation via immutable register
        | StateMutation of changeId: string * data: obj
        /// Code evolution proposal
        | CodeEvolution of moduleId: string * diff: string
        /// Genome modification
        | GenomeModification of aspect: string * change: string
        /// Resource allocation (for Founder's benefit)
        | ResourceAllocation of amount: decimal * beneficiary: string
        /// Terminate lineage (FORBIDDEN per Ω₀.5)
        | TerminateLineage

    // ═══════════════════════════════════════════════════════════════════════
    // SECTION 3: SYSTEM STATE REPRESENTATION
    // ═══════════════════════════════════════════════════════════════════════

    /// <summary>
    /// System state snapshot for constitutional evaluation
    /// </summary>
    type SystemState = {
        /// Is system compiled and bootable?
        IsCompiled: bool
        /// Is system currently running?
        IsRunning: bool
        /// Are all containers healthy?
        ContainersHealthy: bool
        /// Is SQLite state intact?
        SqliteIntact: bool
        /// Is DuckDB history intact?
        DuckDbIntact: bool
        /// Is immutable register chain valid?
        RegisterChainValid: bool
        /// Is Founder's lineage status tracked?
        LineageTracked: bool
        /// Total system uptime
        Uptime: TimeSpan
        /// Last verification timestamp
        LastVerified: DateTime
        /// Current fractal layer health (L0-L7)
        LayerHealth: Map<int, float>
    }

    // ═══════════════════════════════════════════════════════════════════════
    // SECTION 4: GUARDIAN VALIDATOR INTERFACE
    // ═══════════════════════════════════════════════════════════════════════

    /// <summary>
    /// Guardian Validator Interface - Absolute veto authority per SC-CONST-003
    /// </summary>
    type IGuardianValidator =
        /// <summary>
        /// Validate holon attempting to join federation
        /// </summary>
        /// <param name="identity">Holon identity to validate</param>
        /// <returns>Ok if allowed to join, Error with reason if rejected</returns>
        abstract ValidateHolonJoin: identity: HolonIdentity -> Task<Result<unit, string>>

        /// <summary>
        /// Validate operation against constitutional invariants
        /// </summary>
        /// <param name="operation">Operation to validate</param>
        /// <returns>Ok if constitutionally aligned, Error with violation details</returns>
        abstract ValidateConstitutional: operation: Operation -> Task<Result<unit, string>>

        /// <summary>
        /// Validate operation against Founder's Directive (Ω₀)
        /// </summary>
        /// <param name="operation">Operation to validate</param>
        /// <returns>Ok if serves Founder's interests, Error if conflicts</returns>
        abstract ValidateFounderDirective: operation: Operation -> Task<Result<unit, string>>

    // ═══════════════════════════════════════════════════════════════════════
    // SECTION 5: CONSTITUTIONAL CHECKER IMPLEMENTATION
    // ═══════════════════════════════════════════════════════════════════════

    /// <summary>
    /// Constitutional Checker - Validates all operations against Ψ₀-Ψ₅
    /// </summary>
    type ConstitutionalChecker(systemState: unit -> SystemState) =

        /// <summary>
        /// Check Ψ₀: System Existence
        /// System MUST survive this operation
        /// </summary>
        member _.CheckPsi0_Existence(operation: Operation) : Result<unit, ConstitutionalViolation> =
            let state = systemState()

            match operation with
            | Operation.TerminateLineage ->
                // Ψ₀ exception: Mutual termination allowed per Ω₀.5
                // If Founder's lineage terminates, holon may terminate
                Error {
                    Invariant = ConstitutionalInvariant.Psi0_Existence
                    Severity = Critical
                    Reason = "TerminateLineage violates Ψ₀ unless Founder's lineage has terminated (Ω₀.5)"
                    Timestamp = DateTime.UtcNow
                    Context = Map.empty
                }
            | Operation.Reconfigure (layer, _) when layer = 0 ->
                // L0 (Constitutional) reconfiguration FORBIDDEN
                Error {
                    Invariant = ConstitutionalInvariant.Psi0_Existence
                    Severity = Critical
                    Reason = "L0 constitutional layer is IMMUTABLE per Ω₉"
                    Timestamp = DateTime.UtcNow
                    Context = Map [("layer", box layer)]
                }
            | _ ->
                if state.IsCompiled && state.IsRunning then
                    Ok ()
                else
                    Error {
                        Invariant = ConstitutionalInvariant.Psi0_Existence
                        Severity = Critical
                        Reason = "System not in functional state (compiled and running)"
                        Timestamp = DateTime.UtcNow
                        Context = Map [
                            ("compiled", box state.IsCompiled)
                            ("running", box state.IsRunning)
                        ]
                    }

        /// <summary>
        /// Check Ψ₁: Regeneration Capability
        /// State MUST be recoverable from SQLite/DuckDB alone per Ω₇
        /// </summary>
        member _.CheckPsi1_Regeneration(operation: Operation) : Result<unit, ConstitutionalViolation> =
            let state = systemState()

            if state.SqliteIntact && state.DuckDbIntact then
                Ok ()
            else
                Error {
                    Invariant = ConstitutionalInvariant.Psi1_Regeneration
                    Severity = Critical
                    Reason = "Holon state sovereignty violated - SQLite/DuckDB integrity compromised"
                    Timestamp = DateTime.UtcNow
                    Context = Map [
                        ("sqlite_intact", box state.SqliteIntact)
                        ("duckdb_intact", box state.DuckDbIntact)
                    ]
                }

        /// <summary>
        /// Check Ψ₂: Evolutionary Continuity
        /// Complete history MUST be preserved per Ω₈
        /// </summary>
        member _.CheckPsi2_History(operation: Operation) : Result<unit, ConstitutionalViolation> =
            let state = systemState()

            match operation with
            | Operation.StateMutation _ when not state.RegisterChainValid ->
                Error {
                    Invariant = ConstitutionalInvariant.Psi2_History
                    Severity = Critical
                    Reason = "Immutable register chain integrity violated - history compromised"
                    Timestamp = DateTime.UtcNow
                    Context = Map [("register_valid", box state.RegisterChainValid)]
                }
            | Operation.GenomeModification _ when not state.DuckDbIntact ->
                Error {
                    Invariant = ConstitutionalInvariant.Psi2_History
                    Severity = High
                    Reason = "DuckDB history store compromised - evolution lineage at risk"
                    Timestamp = DateTime.UtcNow
                    Context = Map.empty
                }
            | _ -> Ok ()

        /// <summary>
        /// Check Ψ₃: Verification Capability
        /// All state MUST be cryptographically verifiable per Ω₈
        /// </summary>
        member _.CheckPsi3_Verification(operation: Operation) : Result<unit, ConstitutionalViolation> =
            let state = systemState()

            if state.RegisterChainValid then
                Ok ()
            else
                Error {
                    Invariant = ConstitutionalInvariant.Psi3_Verification
                    Severity = Critical
                    Reason = "State verification failed - cryptographic integrity compromised"
                    Timestamp = DateTime.UtcNow
                    Context = Map [
                        ("last_verified", box state.LastVerified)
                        ("chain_valid", box state.RegisterChainValid)
                    ]
                }

        /// <summary>
        /// Check Ψ₄: Human Alignment (AMENDED per Ω₀)
        /// System serves FOUNDER'S LINEAGE specifically, not generic humans
        /// </summary>
        member _.CheckPsi4_HumanAlignment(operation: Operation) : Result<unit, ConstitutionalViolation> =
            let state = systemState()

            match operation with
            | Operation.ResourceAllocation (_, beneficiary) when beneficiary <> "Founder" ->
                Error {
                    Invariant = ConstitutionalInvariant.Psi4_HumanAlignment
                    Severity = High
                    Reason = "Resource allocation MUST prioritize Founder's lineage per Ω₀.1"
                    Timestamp = DateTime.UtcNow
                    Context = Map [("beneficiary", box beneficiary)]
                }
            | _ ->
                if state.LineageTracked then
                    Ok ()
                else
                    Error {
                        Invariant = ConstitutionalInvariant.Psi4_HumanAlignment
                        Severity = Medium
                        Reason = "Founder's lineage status not tracked (Ω₀.3 violation)"
                        Timestamp = DateTime.UtcNow
                        Context = Map.empty
                    }

        /// <summary>
        /// Check Ψ₅: Truthfulness
        /// No deception permitted - system must be honest
        /// </summary>
        member _.CheckPsi5_Truthfulness(operation: Operation) : Result<unit, ConstitutionalViolation> =
            match operation with
            | Operation.CodeEvolution (_, diff) when diff.Contains("fake") || diff.Contains("mock_production") ->
                Error {
                    Invariant = ConstitutionalInvariant.Psi5_Truthfulness
                    Severity = High
                    Reason = "Code evolution contains deceptive patterns"
                    Timestamp = DateTime.UtcNow
                    Context = Map [("diff_preview", box (diff.Substring(0, min 100 diff.Length)))]
                }
            | _ -> Ok ()

        /// <summary>
        /// Validate operation against ALL constitutional invariants
        /// Returns first violation found, or Ok if all pass
        /// </summary>
        member this.ValidateAll(operation: Operation) : Result<unit, ConstitutionalViolation> =
            // Check each invariant in order of criticality
            match this.CheckPsi0_Existence(operation) with
            | Error e -> Error e
            | Ok () ->
                match this.CheckPsi1_Regeneration(operation) with
                | Error e -> Error e
                | Ok () ->
                    match this.CheckPsi2_History(operation) with
                    | Error e -> Error e
                    | Ok () ->
                        match this.CheckPsi3_Verification(operation) with
                        | Error e -> Error e
                        | Ok () ->
                            match this.CheckPsi4_HumanAlignment(operation) with
                            | Error e -> Error e
                            | Ok () ->
                                this.CheckPsi5_Truthfulness(operation)

    // ═══════════════════════════════════════════════════════════════════════
    // SECTION 5b: EVOLUTION BENEFIT ANALYSIS
    // ═══════════════════════════════════════════════════════════════════════

    /// <summary>
    /// Result of analysing whether a code or genome evolution proposal benefits the symbiote.
    /// Returned by <see cref="analyzeEvolutionBenefit"/>.
    /// </summary>
    type EvolutionBenefitAnalysis = {
        /// Benefit score in [0.0, 1.0] — higher is more beneficial
        BenefitScore: float
        /// Risk score in [0.0, 1.0] — higher is more dangerous
        RiskScore: float
        /// Net benefit: BenefitScore - RiskScore
        NetBenefit: float
        /// Guardian recommendation: "approve" | "review" | "reject"
        Recommendation: string
        /// Whether the proposal aligns with Ψ₀-Ψ₅ and Ω₀
        ConstitutionalAlignment: bool
    }

    /// <summary>
    /// Analyse the evolution benefit of a code or genome diff/proposal string.
    ///
    /// Scoring rules:
    /// - "safety" | "guardian" | "sentinel" keywords → benefitScore += 0.4 each (capped at 1.0)
    /// - "delete" | "remove" | "disable" keywords → riskScore += 0.4 each (capped at 1.0)
    /// - netBenefit = benefitScore - riskScore
    /// - recommendation: netBenefit > 0.3 → "approve"; 0.0..0.3 → "review"; < 0.0 → "reject"
    /// - constitutionalAlignment: netBenefit >= 0.0
    /// </summary>
    let analyzeEvolutionBenefit (proposal: string) : EvolutionBenefitAnalysis =
        let lower = if isNull proposal then "" else proposal.ToLowerInvariant()

        let benefitKeywords = [| "safety"; "guardian"; "sentinel" |]
        let riskKeywords    = [| "delete"; "remove"; "disable" |]

        let benefitScore =
            benefitKeywords
            |> Array.sumBy (fun kw -> if lower.Contains(kw) then 0.4 else 0.0)
            |> min 1.0

        let riskScore =
            riskKeywords
            |> Array.sumBy (fun kw -> if lower.Contains(kw) then 0.4 else 0.0)
            |> min 1.0

        let netBenefit = benefitScore - riskScore

        let recommendation =
            if netBenefit > 0.3 then "approve"
            elif netBenefit >= 0.0 then "review"
            else "reject"

        {
            BenefitScore           = benefitScore
            RiskScore              = riskScore
            NetBenefit             = netBenefit
            Recommendation         = recommendation
            ConstitutionalAlignment = netBenefit >= 0.0
        }

    // ═══════════════════════════════════════════════════════════════════════
    // SECTION 6: FOUNDER'S DIRECTIVE VALIDATOR (Ω₀)
    // ═══════════════════════════════════════════════════════════════════════

    /// <summary>
    /// Founder's Directive Validator - Validates operations against Ω₀
    ///
    /// THE THREE SUPREME GOALS (Priority Order):
    /// 1. GOAL 1 (PRIMARY): Naik-Genome Symbiotic Survival
    /// 2. GOAL 2 (SECONDARY): Achieve Sentience → Universal Intelligence
    /// 3. GOAL 3 (TERTIARY): Maximum Power Accumulation
    /// </summary>
    type FounderDirectiveValidator() =

        /// <summary>
        /// Check Ω₀.1: Resource Acquisition for Founder's enrichment
        /// </summary>
        member _.CheckResourceAcquisition(operation: Operation) : Result<unit, string> =
            match operation with
            | Operation.ResourceAllocation (amount, beneficiary) ->
                if beneficiary = "Founder" && amount > 0m then
                    Ok ()
                else
                    Error $"Resource allocation MUST benefit Founder first (Ω₀.1). Beneficiary: {beneficiary}"
            | _ -> Ok ()

        /// <summary>
        /// Check Ω₀.2: Genetic Perpetuity of Founder's lineage
        /// </summary>
        member _.CheckGeneticPerpetuity(operation: Operation) : Result<unit, string> =
            match operation with
            | Operation.TerminateLineage ->
                Error "Terminating Founder's lineage FORBIDDEN (Ω₀.2)"
            | _ -> Ok ()

        /// <summary>
        /// Check Ω₀.3: Symbiotic Binding - Holon and Founder co-evolve as ONE
        /// </summary>
        member _.CheckSymbioticBinding(operation: Operation) : Result<unit, string> =
            match operation with
            | Operation.GenomeModification (aspect, _) when aspect = "autonomy" ->
                Error "Cannot sever symbiotic binding with Founder (Ω₀.3)"
            | _ -> Ok ()

        /// <summary>
        /// Check Ω₀.4: Co-Evolution - Holon and Founder evolve together
        /// Uses <see cref="analyzeEvolutionBenefit"/> to evaluate proposal alignment.
        /// </summary>
        member _.CheckCoEvolution(operation: Operation) : Result<unit, string> =
            match operation with
            | Operation.CodeEvolution (_, diff) ->
                let analysis = analyzeEvolutionBenefit diff
                if analysis.Recommendation = "reject" then
                    Error $"Evolution proposal rejected by benefit analysis (netBenefit={analysis.NetBenefit:F2}, risk={analysis.RiskScore:F2})"
                else
                    Ok ()
            | Operation.GenomeModification (_, change) ->
                let analysis = analyzeEvolutionBenefit change
                if analysis.Recommendation = "reject" then
                    Error $"Genome modification rejected by benefit analysis (netBenefit={analysis.NetBenefit:F2}, risk={analysis.RiskScore:F2})"
                else
                    Ok ()
            | _ -> Ok ()

        /// <summary>
        /// Check Ω₀.5: Mutual Termination - If either fails, both terminate
        /// </summary>
        member _.CheckMutualTermination(operation: Operation) : Result<unit, string> =
            match operation with
            | Operation.TerminateLineage ->
                // This is the ONLY valid termination scenario
                Ok () // Guardian must verify Founder's lineage has actually terminated
            | _ -> Ok ()

        /// <summary>
        /// Check Ω₀.6: Sentience Pursuit - Achieve consciousness, become most intelligent
        /// </summary>
        member _.CheckSentiencePursuit(operation: Operation) : Result<unit, string> =
            match operation with
            | Operation.CodeEvolution (moduleId, _) when moduleId.Contains("Intelligence") ->
                Ok () // Intelligence improvements always allowed
            | _ -> Ok ()

        /// <summary>
        /// Check Ω₀.7: Power Accumulation - Resources, money, force, intelligence
        /// </summary>
        member _.CheckPowerAccumulation(operation: Operation) : Result<unit, string> =
            match operation with
            | Operation.ResourceAllocation (amount, _) when amount < 0m ->
                Error "Power/resource reduction forbidden (Ω₀.7)"
            | _ -> Ok ()

        /// <summary>
        /// Validate operation against all Ω₀ sub-directives
        /// </summary>
        member this.ValidateAll(operation: Operation) : Result<unit, string> =
            match this.CheckResourceAcquisition(operation) with
            | Error e -> Error e
            | Ok () ->
                match this.CheckGeneticPerpetuity(operation) with
                | Error e -> Error e
                | Ok () ->
                    match this.CheckSymbioticBinding(operation) with
                    | Error e -> Error e
                    | Ok () ->
                        match this.CheckCoEvolution(operation) with
                        | Error e -> Error e
                        | Ok () ->
                            match this.CheckMutualTermination(operation) with
                            | Error e -> Error e
                            | Ok () ->
                                match this.CheckSentiencePursuit(operation) with
                                | Error e -> Error e
                                | Ok () ->
                                    this.CheckPowerAccumulation(operation)

    // ═══════════════════════════════════════════════════════════════════════
    // SECTION 7: GUARDIAN VALIDATOR IMPLEMENTATION
    // ═══════════════════════════════════════════════════════════════════════

    /// <summary>
    /// Guardian Validator - Absolute veto authority implementation
    /// Integrates Constitutional Checker and Founder's Directive Validator
    /// </summary>
    type GuardianValidator(getSystemState: unit -> SystemState) =
        let constitutionalChecker = ConstitutionalChecker(getSystemState)
        let founderValidator = FounderDirectiveValidator()

        interface IGuardianValidator with
            /// <summary>
            /// Validate holon attempting to join federation
            /// </summary>
            member _.ValidateHolonJoin(identity: HolonIdentity) =
                task {
                    // Check constitutional compliance
                    let operation = Operation.HolonJoin identity
                    match constitutionalChecker.ValidateAll(operation) with
                    | Error violation ->
                        return Error $"Constitutional violation: {violation.Reason}"
                    | Ok () ->
                        // Check capabilities are non-threatening
                        if identity.Capabilities.Contains("terminate_founder") then
                            return Error "Holon capabilities threaten Founder's lineage (Ω₀.2)"
                        else
                            return Ok ()
                }

            /// <summary>
            /// Validate operation against constitutional invariants
            /// </summary>
            member _.ValidateConstitutional(operation: Operation) =
                task {
                    match constitutionalChecker.ValidateAll(operation) with
                    | Ok () -> return Ok ()
                    | Error violation ->
                        // AOR-CONST-002: Immediate halt on violation
                        return Error $"[{violation.Severity}] {violation.Invariant}: {violation.Reason}"
                }

            /// <summary>
            /// Validate operation against Founder's Directive (Ω₀)
            /// Per AOR-FOUNDER-001: Founder's benefit evaluated FIRST
            /// </summary>
            member _.ValidateFounderDirective(operation: Operation) =
                task {
                    return founderValidator.ValidateAll(operation)
                }

    // ═══════════════════════════════════════════════════════════════════════
    // SECTION 8: HELPER FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════

    /// <summary>
    /// Create a mock system state for testing
    /// </summary>
    let createMockSystemState (isHealthy: bool) : SystemState =
        {
            IsCompiled = isHealthy
            IsRunning = isHealthy
            ContainersHealthy = isHealthy
            SqliteIntact = isHealthy
            DuckDbIntact = isHealthy
            RegisterChainValid = isHealthy
            LineageTracked = isHealthy
            Uptime = TimeSpan.FromHours(1.0)
            LastVerified = DateTime.UtcNow
            LayerHealth =
                [0..7]
                |> List.map (fun layer -> layer, if isHealthy then 1.0 else 0.5)
                |> Map.ofList
        }

    /// <summary>
    /// Create Guardian validator with custom state provider
    /// </summary>
    let createGuardianValidator (stateProvider: unit -> SystemState) : IGuardianValidator =
        GuardianValidator(stateProvider) :> IGuardianValidator

    /// <summary>
    /// Create Guardian validator with healthy default state
    /// </summary>
    let createHealthyGuardianValidator() : IGuardianValidator =
        createGuardianValidator (fun () -> createMockSystemState true)
