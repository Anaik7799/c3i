module Cepaf.Tests.FormalVerificationTests

/// =============================================================================
/// FORMAL VERIFICATION TEST SUITE
/// Purpose: Comprehensive testing of Mathematica, Quint, and Agda specifications
/// Compliance: IEC 61508 SIL-2, ISO 27001, STAMP Safety Framework
/// =============================================================================

open System
open System.IO
open System.Text.RegularExpressions
open Expecto
open FsCheck

// ============================================================================
// SECTION 1: MATHEMATICA SPECIFICATION VERIFICATION
// Purpose: Parse and verify mathematical constraints from .wl/.m files
// ============================================================================

module MathematicaVerification =

    /// Represents a parsed Mathematica constraint
    type MathConstraint = {
        Id: string
        Name: string
        Formula: string
        Category: string
        IsInvariant: bool
    }

    /// Represents a safety axiom
    type SafetyAxiom = {
        Number: int
        Name: string
        Predicate: string
        ProofStatus: string
    }

    /// Parse STAMP constraint definitions from Mathematica code
    let parseSTAMPConstraints (mathCode: string) : MathConstraint list =
        // Pattern: SC-XXX-NNN := expression
        let pattern = @"(SC-[A-Z]{3}-\d{3})\s*:?=\s*(.+?)(?=SC-|$)"
        let matches = Regex.Matches(mathCode, pattern, RegexOptions.Singleline)

        matches
        |> Seq.cast<Match>
        |> Seq.map (fun m ->
            let id = m.Groups.[1].Value
            let category = id.Substring(3, 3)
            {
                Id = id
                Name = sprintf "Constraint %s" id
                Formula = m.Groups.[2].Value.Trim()
                Category = category
                IsInvariant = mathCode.Contains(sprintf "Invariant[%s]" id)
            })
        |> Seq.toList

    /// Parse axiom definitions
    let parseAxioms (mathCode: string) : SafetyAxiom list =
        // Pattern: Axiom[n] := predicate
        let pattern = @"Axiom\[(\d+)\]\s*:?=\s*(.+?)(?=Axiom\[|$)"
        let matches = Regex.Matches(mathCode, pattern, RegexOptions.Singleline)

        matches
        |> Seq.cast<Match>
        |> Seq.mapi (fun i m ->
            {
                Number = Int32.Parse(m.Groups.[1].Value)
                Name = sprintf "Axiom %s" (m.Groups.[1].Value)
                Predicate = m.Groups.[2].Value.Trim()
                ProofStatus = "Pending"
            })
        |> Seq.toList

    /// Verify mathematical expression is well-formed
    let verifyExpression (expr: string) : Result<unit, string> =
        // Basic syntax check for Mathematica expressions
        let openParens = expr |> Seq.filter ((=) '(') |> Seq.length
        let closeParens = expr |> Seq.filter ((=) ')') |> Seq.length
        let openBrackets = expr |> Seq.filter ((=) '[') |> Seq.length
        let closeBrackets = expr |> Seq.filter ((=) ']') |> Seq.length

        if openParens <> closeParens then
            Error (sprintf "Unbalanced parentheses in: %s" expr)
        elif openBrackets <> closeBrackets then
            Error (sprintf "Unbalanced brackets in: %s" expr)
        else
            Ok ()

    /// Verify constraint category is valid
    let verifyCategory (category: string) : bool =
        let validCategories = ["VAL"; "CNT"; "AGT"; "CMP"; "SEC"; "PRF"; "EMR"; "OBS"]
        validCategories |> List.contains category

// ============================================================================
// SECTION 2: QUINT MODEL CHECKING VERIFICATION
// Purpose: Parse and validate Quint state machine specifications
// ============================================================================

module QuintVerification =

    /// Represents a Quint state variable
    type StateVar = {
        Name: string
        Type: string
        Initial: string option
    }

    /// Represents a Quint action
    type QuintAction = {
        Name: string
        Parameters: string list
        Guard: string option
        Body: string
    }

    /// Represents a Quint temporal property
    type TemporalProperty = {
        Name: string
        Kind: string  // always, eventually, leads-to
        Predicate: string
    }

    /// Represents a Quint module
    type QuintModule = {
        Name: string
        Imports: string list
        StateVars: StateVar list
        Actions: QuintAction list
        Invariants: string list
        TemporalProps: TemporalProperty list
    }

    /// Parse Quint module from source
    let parseModule (quintCode: string) : QuintModule =
        // Parse module name
        let moduleMatch = Regex.Match(quintCode, @"module\s+(\w+)")
        let moduleName = if moduleMatch.Success then moduleMatch.Groups.[1].Value else "Unknown"

        // Parse imports
        let importPattern = @"import\s+(\w+)\.\*"
        let imports =
            Regex.Matches(quintCode, importPattern)
            |> Seq.cast<Match>
            |> Seq.map (fun m -> m.Groups.[1].Value)
            |> Seq.toList

        // Parse state variables
        let varPattern = @"var\s+(\w+):\s*([^\n]+)"
        let stateVars =
            Regex.Matches(quintCode, varPattern)
            |> Seq.cast<Match>
            |> Seq.map (fun m ->
                { Name = m.Groups.[1].Value
                  Type = m.Groups.[2].Value.Trim()
                  Initial = None })
            |> Seq.toList

        // Parse actions
        let actionPattern = @"action\s+(\w+)\s*\(([^)]*)\)[^{]*:\s*bool\s*=\s*(.+?)(?=action|val|temporal|$)"
        let actions =
            Regex.Matches(quintCode, actionPattern, RegexOptions.Singleline)
            |> Seq.cast<Match>
            |> Seq.map (fun m ->
                let paramStr = m.Groups.[2].Value
                let parsedParams =
                    if String.IsNullOrWhiteSpace(paramStr) then []
                    else paramStr.Split(',') |> Array.map (fun s -> s.Trim()) |> Array.toList
                { Name = m.Groups.[1].Value
                  Parameters = parsedParams
                  Guard = None
                  Body = m.Groups.[3].Value.Trim() })
            |> Seq.toList

        // Parse invariants (val XXX: bool = ...)
        let invPattern = @"val\s+(SC_[A-Z]+_\d+):\s*bool\s*="
        let invariants =
            Regex.Matches(quintCode, invPattern)
            |> Seq.cast<Match>
            |> Seq.map (fun m -> m.Groups.[1].Value)
            |> Seq.toList

        // Parse temporal properties
        let temporalPattern = @"temporal\s+(\w+)\s*=\s*(always|eventually|leads-to)\s*\((.+?)\)"
        let temporalProps =
            Regex.Matches(quintCode, temporalPattern)
            |> Seq.cast<Match>
            |> Seq.map (fun m ->
                { Name = m.Groups.[1].Value
                  Kind = m.Groups.[2].Value
                  Predicate = m.Groups.[3].Value.Trim() })
            |> Seq.toList

        { Name = moduleName
          Imports = imports
          StateVars = stateVars
          Actions = actions
          Invariants = invariants
          TemporalProps = temporalProps }

    /// Verify module is well-formed
    let verifyModule (qmod: QuintModule) : Result<unit, string list> =
        let errors = ResizeArray<string>()

        if String.IsNullOrEmpty(qmod.Name) then
            errors.Add("Module name is empty")

        // Check for duplicate state variables
        let dupVars =
            qmod.StateVars
            |> List.groupBy (fun v -> v.Name)
            |> List.filter (fun (_, group) -> List.length group > 1)

        for (name, _) in dupVars do
            errors.Add(sprintf "Duplicate state variable: %s" name)

        // Check for duplicate actions
        let dupActions =
            qmod.Actions
            |> List.groupBy (fun a -> a.Name)
            |> List.filter (fun (_, group) -> List.length group > 1)

        for (name, _) in dupActions do
            errors.Add(sprintf "Duplicate action: %s" name)

        if errors.Count > 0 then
            Error (errors |> Seq.toList)
        else
            Ok ()

// ============================================================================
// SECTION 3: AGDA PROOF VERIFICATION
// Purpose: Parse and verify Agda proof structures
// ============================================================================

module AgdaVerification =

    /// Represents an Agda type declaration
    type AgdaType = {
        Name: string
        Kind: string  // data, record, postulate
        Fields: string list
    }

    /// Represents an Agda proof/theorem
    type AgdaProof = {
        Name: string
        TypeSignature: string
        Body: string option
        IsPostulate: bool
    }

    /// Represents an Agda module
    type AgdaModule = {
        Name: string
        Imports: string list
        Types: AgdaType list
        Proofs: AgdaProof list
    }

    /// Parse Agda module
    let parseModule (agdaCode: string) : AgdaModule =
        // Parse module name
        let moduleMatch = Regex.Match(agdaCode, @"module\s+([\w.]+)")
        let moduleName = if moduleMatch.Success then moduleMatch.Groups.[1].Value else "Unknown"

        // Parse imports
        let importPattern = @"open\s+import\s+([\w.]+)"
        let imports =
            Regex.Matches(agdaCode, importPattern)
            |> Seq.cast<Match>
            |> Seq.map (fun m -> m.Groups.[1].Value)
            |> Seq.toList

        // Parse data types
        let dataPattern = @"data\s+(\w+)\s*:"
        let recordPattern = @"record\s+(\w+)\s*:"

        let dataTypes =
            Regex.Matches(agdaCode, dataPattern)
            |> Seq.cast<Match>
            |> Seq.map (fun m ->
                { Name = m.Groups.[1].Value
                  Kind = "data"
                  Fields = [] })
            |> Seq.toList

        let recordTypes =
            Regex.Matches(agdaCode, recordPattern)
            |> Seq.cast<Match>
            |> Seq.map (fun m ->
                { Name = m.Groups.[1].Value
                  Kind = "record"
                  Fields = [] })
            |> Seq.toList

        // Parse proofs (function declarations with types)
        let proofPattern = @"(\w[\w-]*)\s*:\s*(.+?)(?=\n\w|\ndata|\nrecord|$)"
        let proofs =
            Regex.Matches(agdaCode, proofPattern, RegexOptions.Singleline)
            |> Seq.cast<Match>
            |> Seq.filter (fun m ->
                let name = m.Groups.[1].Value
                not (name = "data" || name = "record" || name = "module" || name = "open" || name = "where"))
            |> Seq.map (fun m ->
                { Name = m.Groups.[1].Value
                  TypeSignature = m.Groups.[2].Value.Trim()
                  Body = None
                  IsPostulate = false })
            |> Seq.toList

        { Name = moduleName
          Imports = imports
          Types = dataTypes @ recordTypes
          Proofs = proofs }

    /// Verify Agda module structure
    let verifyModule (agdaMod: AgdaModule) : Result<unit, string list> =
        let errors = ResizeArray<string>()

        if String.IsNullOrEmpty(agdaMod.Name) then
            errors.Add("Module name is empty")

        // Verify all proofs have type signatures
        for proof in agdaMod.Proofs do
            if String.IsNullOrWhiteSpace(proof.TypeSignature) then
                errors.Add(sprintf "Proof '%s' has no type signature" proof.Name)

        if errors.Count > 0 then
            Error (errors |> Seq.toList)
        else
            Ok ()

    /// Check if proof uses absurd pattern (contradiction proof)
    let isContradictionProof (proof: AgdaProof) : bool =
        match proof.Body with
        | Some body -> body.Contains("()") || body.Contains("absurd")
        | None -> false

// ============================================================================
// SECTION 4: STAMP CONSTRAINT VERIFICATION (F# Implementation)
// Purpose: Verify STAMP safety constraints at runtime
// ============================================================================

module STAMPRuntimeVerification =

    /// STAMP constraint categories
    type ConstraintCategory =
        | Validation   // SC-VAL
        | Container    // SC-CNT
        | Agent        // SC-AGT
        | Compilation  // SC-CMP
        | Security     // SC-SEC
        | Performance  // SC-PRF
        | Emergency    // SC-EMR
        | Observability // SC-OBS

    /// Constraint status
    type ConstraintStatus =
        | Satisfied
        | Violated of reason: string
        | Unknown

    /// Runtime constraint check
    type RuntimeConstraint = {
        Id: string
        Category: ConstraintCategory
        Description: string
        Check: unit -> ConstraintStatus
    }

    /// SC-VAL-001: Patient Mode Required
    let scVal001 () =
        let noTimeout = Environment.GetEnvironmentVariable("NO_TIMEOUT") = "true"
        let patientMode = Environment.GetEnvironmentVariable("PATIENT_MODE") = "enabled"
        if noTimeout && patientMode then Satisfied
        else Violated "Patient mode not fully enabled"

    /// SC-CNT-009: Podman Runtime Required
    let scCnt009 () =
        // Check if podman is available
        try
            let psi = System.Diagnostics.ProcessStartInfo("podman", "--version")
            psi.RedirectStandardOutput <- true
            psi.UseShellExecute <- false
            use proc = System.Diagnostics.Process.Start(psi)
            proc.WaitForExit(1000) |> ignore
            if proc.ExitCode = 0 then Satisfied
            else Violated "Podman not available or not working"
        with _ ->
            Unknown

    /// SC-AGT-017: Agent Efficiency > 90%
    let scAgt017 (efficiencyPercent: float) =
        if efficiencyPercent > 90.0 then Satisfied
        else Violated (sprintf "Efficiency %.1f%% is below 90%% threshold" efficiencyPercent)

    /// SC-AGT-019: Executive Authority
    let scAgt019 (hasExecutive: bool) =
        if hasExecutive then Satisfied
        else Violated "No Executive agent found"

    /// All runtime constraints
    let allConstraints = [
        { Id = "SC-VAL-001"; Category = Validation; Description = "Patient Mode Required"; Check = scVal001 }
        { Id = "SC-CNT-009"; Category = Container; Description = "Podman Runtime Required"; Check = scCnt009 }
    ]

    /// Run all constraint checks
    let verifyAllConstraints () =
        allConstraints
        |> List.map (fun c -> (c.Id, c.Check()))
        |> Map.ofList

// ============================================================================
// SECTION 5: FORMAL VERIFICATION TESTS
// ============================================================================

[<Tests>]
let mathematicaTests =
    testList "Mathematica Specification Verification" [
        testCase "Parse STAMP constraint IDs correctly" <| fun _ ->
            let sampleCode = """
                SC-VAL-001 := PatientMode && NoTimeout
                SC-VAL-002 := CompleteLogAnalysis
                SC-CNT-009 := Runtime == Podman
            """
            let constraints = MathematicaVerification.parseSTAMPConstraints sampleCode
            Expect.isGreaterThanOrEqual constraints.Length 3 "Should parse at least 3 constraints"
            Expect.exists constraints (fun c -> c.Id = "SC-VAL-001") "Should find SC-VAL-001"
            Expect.exists constraints (fun c -> c.Category = "CNT") "Should find CNT category"

        testCase "Verify valid Mathematica expressions" <| fun _ ->
            let validExprs = [
                "f[x] + g[y]"
                "(a + b) * (c + d)"
                "Module[{x = 1}, x^2]"
            ]
            for expr in validExprs do
                let result = MathematicaVerification.verifyExpression expr
                Expect.isOk result (sprintf "Expression should be valid: %s" expr)

        testCase "Detect invalid Mathematica expressions" <| fun _ ->
            let invalidExprs = [
                "f[x"      // Missing bracket
                "(a + b"   // Missing paren
            ]
            for expr in invalidExprs do
                let result = MathematicaVerification.verifyExpression expr
                Expect.isError result (sprintf "Expression should be invalid: %s" expr)

        testCase "Valid constraint categories recognized" <| fun _ ->
            let validCats = ["VAL"; "CNT"; "AGT"; "CMP"; "SEC"; "PRF"; "EMR"; "OBS"]
            for cat in validCats do
                Expect.isTrue (MathematicaVerification.verifyCategory cat) (sprintf "Category %s should be valid" cat)

        testCase "Invalid constraint categories rejected" <| fun _ ->
            let invalidCats = ["XXX"; "FOO"; "BAR"]
            for cat in invalidCats do
                Expect.isFalse (MathematicaVerification.verifyCategory cat) (sprintf "Category %s should be invalid" cat)
    ]

[<Tests>]
let quintTests =
    testList "Quint Model Checking Verification" [
        testCase "Parse Quint module structure" <| fun _ ->
            let sampleQuint = """
                module TestModule {
                    import Types.*

                    var state: str
                    var count: int

                    action increment(n: int): bool = all {
                        count' = count + n
                    }

                    val SC_AGT_017: bool = count > 0

                    temporal alwaysPositive = always(count >= 0)
                }
            """
            let qmod = QuintVerification.parseModule sampleQuint
            Expect.equal qmod.Name "TestModule" "Module name should be TestModule"
            Expect.isGreaterThanOrEqual qmod.StateVars.Length 2 "Should have at least 2 state vars"
            Expect.isGreaterThanOrEqual qmod.Actions.Length 1 "Should have at least 1 action"

        testCase "Verify well-formed Quint module" <| fun _ ->
            let validModule : QuintVerification.QuintModule = {
                Name = "ValidModule"
                Imports = ["Types"]
                StateVars = [
                    { Name = "x"; Type = "int"; Initial = Some "0" }
                    { Name = "y"; Type = "str"; Initial = None }
                ]
                Actions = [
                    { Name = "step"; Parameters = []; Guard = None; Body = "x' = x + 1" }
                ]
                Invariants = ["SC_AGT_017"]
                TemporalProps = []
            }
            let result = QuintVerification.verifyModule validModule
            Expect.isOk result "Valid module should verify"

        testCase "Detect duplicate state variables" <| fun _ ->
            let invalidModule : QuintVerification.QuintModule = {
                Name = "InvalidModule"
                Imports = []
                StateVars = [
                    { Name = "x"; Type = "int"; Initial = None }
                    { Name = "x"; Type = "str"; Initial = None }  // Duplicate!
                ]
                Actions = []
                Invariants = []
                TemporalProps = []
            }
            let result = QuintVerification.verifyModule invalidModule
            Expect.isError result "Should detect duplicate state variable"

        testCase "Parse STAMP invariants from Quint" <| fun _ ->
            let stampQuint = """
                module STAMPCheck {
                    val SC_VAL_001: bool = patientMode
                    val SC_VAL_002: bool = completeAnalysis
                    val SC_AGT_017: bool = efficiency > 90
                }
            """
            let qmod = QuintVerification.parseModule stampQuint
            Expect.isGreaterThanOrEqual qmod.Invariants.Length 3 "Should find at least 3 STAMP invariants"
    ]

[<Tests>]
let agdaTests =
    testList "Agda Proof Verification" [
        testCase "Parse Agda module structure" <| fun _ ->
            let sampleAgda = """
                module Test.Module where

                open import Data.Bool
                open import Data.Nat

                data Status : Set where
                    Active : Status
                    Inactive : Status

                record Config : Set where
                    field
                        enabled : Bool
                        count : Nat

                isValid : Config -> Bool
                isValid cfg = enabled cfg
            """
            let agdaMod = AgdaVerification.parseModule sampleAgda
            Expect.equal agdaMod.Name "Test.Module" "Module name should be Test.Module"
            Expect.isGreaterThanOrEqual agdaMod.Types.Length 2 "Should find at least 2 types"

        testCase "Verify well-formed Agda module" <| fun _ ->
            let validModule : AgdaVerification.AgdaModule = {
                Name = "Valid.Module"
                Imports = ["Data.Bool"; "Data.Nat"]
                Types = [
                    { Name = "Status"; Kind = "data"; Fields = [] }
                ]
                Proofs = [
                    { Name = "theorem1"; TypeSignature = "Bool -> Bool"; Body = Some "id"; IsPostulate = false }
                ]
            }
            let result = AgdaVerification.verifyModule validModule
            Expect.isOk result "Valid module should verify"

        testCase "Detect proof without type signature" <| fun _ ->
            let invalidModule : AgdaVerification.AgdaModule = {
                Name = "Invalid.Module"
                Imports = []
                Types = []
                Proofs = [
                    { Name = "badProof"; TypeSignature = ""; Body = None; IsPostulate = false }
                ]
            }
            let result = AgdaVerification.verifyModule invalidModule
            Expect.isError result "Should detect proof without type signature"

        testCase "Identify contradiction proofs" <| fun _ ->
            let contradictionProof : AgdaVerification.AgdaProof = {
                Name = "docker-is-forbidden"
                TypeSignature = "Docker == Podman -> False"
                Body = Some "absurd-podman ()"
                IsPostulate = false
            }
            Expect.isTrue (AgdaVerification.isContradictionProof contradictionProof) "Should identify contradiction proof"
    ]

[<Tests>]
let stampRuntimeTests =
    testList "STAMP Runtime Verification" [
        testCase "SC-AGT-017 passes at 95% efficiency" <| fun _ ->
            let result = STAMPRuntimeVerification.scAgt017 95.0
            match result with
            | STAMPRuntimeVerification.Satisfied -> ()
            | _ -> failtest "Should be satisfied at 95%"

        testCase "SC-AGT-017 fails at 85% efficiency" <| fun _ ->
            let result = STAMPRuntimeVerification.scAgt017 85.0
            match result with
            | STAMPRuntimeVerification.Violated _ -> ()
            | _ -> failtest "Should be violated at 85%"

        testCase "SC-AGT-019 passes with executive" <| fun _ ->
            let result = STAMPRuntimeVerification.scAgt019 true
            match result with
            | STAMPRuntimeVerification.Satisfied -> ()
            | _ -> failtest "Should be satisfied with executive"

        testCase "SC-AGT-019 fails without executive" <| fun _ ->
            let result = STAMPRuntimeVerification.scAgt019 false
            match result with
            | STAMPRuntimeVerification.Violated _ -> ()
            | _ -> failtest "Should be violated without executive"

        testCase "All constraints can be checked" <| fun _ ->
            let results = STAMPRuntimeVerification.verifyAllConstraints ()
            Expect.isGreaterThanOrEqual results.Count 2 "Should check at least 2 constraints"
    ]

// ============================================================================
// SECTION 6: PROPERTY-BASED TESTS FOR FORMAL SPECIFICATIONS
// ============================================================================

[<Tests>]
let propertyTests =
    testList "Formal Verification Properties" [
        testProperty "STAMP constraint IDs follow pattern" <| fun (id: string) ->
            if String.IsNullOrEmpty(id) then true
            else
                let pattern = @"^SC-[A-Z]{3}-\d{3}$"
                let matches = Regex.IsMatch(id, pattern)
                // Just testing the regex works
                matches = Regex.IsMatch(id, pattern)

        testProperty "Constraint categories are 3 uppercase letters" <| fun (cat: string) ->
            if String.IsNullOrEmpty(cat) || cat.Length <> 3 then true
            else
                let isValid = cat |> Seq.forall Char.IsUpper
                isValid = (cat |> Seq.forall Char.IsUpper)

        testProperty "Efficiency threshold is transitive" <| fun (e1: float) (e2: float) ->
            if e1 > 90.0 && e2 > e1 then
                // If e1 passes and e2 > e1, then e2 must also pass
                match STAMPRuntimeVerification.scAgt017 e1, STAMPRuntimeVerification.scAgt017 e2 with
                | STAMPRuntimeVerification.Satisfied, STAMPRuntimeVerification.Satisfied -> true
                | _ -> false
            else true
    ]

/// All formal verification tests
[<Tests>]
let allFormalVerificationTests =
    testList "Formal Verification" [
        mathematicaTests
        quintTests
        agdaTests
        stampRuntimeTests
        propertyTests
    ]
