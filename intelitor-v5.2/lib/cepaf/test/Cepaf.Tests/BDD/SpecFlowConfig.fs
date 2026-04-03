// =============================================================================
// SpecFlow BDD Configuration for CEPAF F# Tests
// =============================================================================
// STAMP: SC-COV-004, SC-COV-005, SC-TEST-EVO-003, SC-TEST-EVO-005
// AOR: AOR-COV-005, AOR-COV-006, AOR-TEST-EVO-004, AOR-TEST-EVO-008
//
// ## Document Control
// | Field | Value |
// |-------|-------|
// | Version | 1.0.0 |
// | Created | 2026-01-03 |
// | Author | Cybernetic Architect |
// | Reference | SC-COV-*, AOR-TEST-EVO-* |
// =============================================================================

namespace Cepaf.Tests.BDD

open System
open System.Text.RegularExpressions
open Expecto

/// <summary>
/// Gherkin-style BDD framework for F# using Expecto
/// Provides Given/When/Then step definitions with pattern matching
/// </summary>
module SpecFlowConfig =

    // =========================================================================
    // Types
    // =========================================================================

    /// Test context passed between steps
    type ScenarioContext = {
        mutable Data: Map<string, obj>
        mutable LastResult: Result<obj, string>
        mutable ExpectedError: string option
        StartTime: DateTime
    }

    /// Step definition type
    type StepType =
        | Given
        | When
        | Then
        | And
        | But

    /// Step definition with regex pattern
    type StepDefinition = {
        StepType: StepType
        Pattern: Regex
        Handler: ScenarioContext -> string[] -> unit
    }

    /// Feature file structure
    type Feature = {
        Name: string
        Description: string
        Tags: string list
        Background: Step list
        Scenarios: Scenario list
    }

    and Scenario = {
        Name: string
        Tags: string list
        Steps: Step list
    }

    and Step = {
        StepType: StepType
        Text: string
        DocString: string option
        DataTable: string list list option
    }

    // =========================================================================
    // Context Management
    // =========================================================================

    let createContext () = {
        Data = Map.empty
        LastResult = Ok (box ())
        ExpectedError = None
        StartTime = DateTime.UtcNow
    }

    let setContextValue (ctx: ScenarioContext) (key: string) (value: obj) =
        ctx.Data <- ctx.Data.Add(key, value)

    let getContextValue<'T> (ctx: ScenarioContext) (key: string) : 'T option =
        ctx.Data
        |> Map.tryFind key
        |> Option.map (fun v -> v :?> 'T)

    let getContextValueOrFail<'T> (ctx: ScenarioContext) (key: string) : 'T =
        match getContextValue<'T> ctx key with
        | Some v -> v
        | None -> failwithf "Context value '%s' not found" key

    // =========================================================================
    // Step Registry
    // =========================================================================

    let mutable private stepDefinitions: StepDefinition list = []

    let registerStep stepType pattern handler =
        let regex = Regex(pattern, RegexOptions.IgnoreCase)
        stepDefinitions <- {
            StepType = stepType
            Pattern = regex
            Handler = handler
        } :: stepDefinitions

    let given pattern handler = registerStep Given pattern handler
    let when' pattern handler = registerStep When pattern handler
    let then' pattern handler = registerStep Then pattern handler
    let and' pattern handler = registerStep And pattern handler
    let but pattern handler = registerStep But pattern handler

    /// Find and execute step
    let executeStep (ctx: ScenarioContext) (step: Step) =
        let matchingSteps =
            stepDefinitions
            |> List.filter (fun sd ->
                let isMatchingType =
                    sd.StepType = step.StepType ||
                    (step.StepType = And && true) ||  // And can match any type
                    (step.StepType = But && true)     // But can match any type
                isMatchingType && sd.Pattern.IsMatch(step.Text)
            )

        match matchingSteps with
        | [] -> failwithf "No step definition found for: %A %s" step.StepType step.Text
        | [sd] ->
            let m = sd.Pattern.Match(step.Text)
            let groups =
                m.Groups
                |> Seq.cast<Group>
                |> Seq.skip 1  // Skip the full match
                |> Seq.map (fun g -> g.Value)
                |> Seq.toArray
            sd.Handler ctx groups
        | _ -> failwithf "Multiple step definitions match: %A %s" step.StepType step.Text

    // =========================================================================
    // Scenario Execution
    // =========================================================================

    let runScenario (background: Step list) (scenario: Scenario) =
        testCase scenario.Name (fun () ->
            let ctx = createContext ()

            // Run background steps
            for step in background do
                executeStep ctx step

            // Run scenario steps
            for step in scenario.Steps do
                executeStep ctx step
        )

    let runFeature (feature: Feature) =
        testList feature.Name (
            feature.Scenarios
            |> List.map (runScenario feature.Background)
        )

    // =========================================================================
    // Step Builders (Fluent API)
    // =========================================================================

    type FeatureBuilder() =
        let mutable name = ""
        let mutable description = ""
        let mutable tags: string list = []
        let mutable background: Step list = []
        let mutable scenarios: Scenario list = []

        member this.Name(n: string) =
            name <- n
            this

        member this.Description(d: string) =
            description <- d
            this

        member this.Tags(t: string list) =
            tags <- t
            this

        member this.Background(steps: Step list) =
            background <- steps
            this

        member this.Scenario(s: Scenario) =
            scenarios <- s :: scenarios
            this

        member this.Build() : Feature = {
            Name = name
            Description = description
            Tags = tags
            Background = background
            Scenarios = List.rev scenarios
        }

    type ScenarioBuilder() =
        let mutable name = ""
        let mutable tags: string list = []
        let mutable steps: Step list = []

        member this.Name(n: string) =
            name <- n
            this

        member this.Tags(t: string list) =
            tags <- t
            this

        member this.Given(text: string) =
            steps <- { StepType = Given; Text = text; DocString = None; DataTable = None } :: steps
            this

        member this.When(text: string) =
            steps <- { StepType = When; Text = text; DocString = None; DataTable = None } :: steps
            this

        member this.Then(text: string) =
            steps <- { StepType = Then; Text = text; DocString = None; DataTable = None } :: steps
            this

        member this.And(text: string) =
            steps <- { StepType = And; Text = text; DocString = None; DataTable = None } :: steps
            this

        member this.Build() : Scenario = {
            Name = name
            Tags = tags
            Steps = List.rev steps
        }

    // =========================================================================
    // Convenience Functions
    // =========================================================================

    let feature () = FeatureBuilder()
    let scenario () = ScenarioBuilder()

    let step stepType text = {
        StepType = stepType
        Text = text
        DocString = None
        DataTable = None
    }

    // =========================================================================
    // Assertions
    // =========================================================================

    module Expect =
        let toEqual expected actual message =
            if expected <> actual then
                failwithf "%s: Expected %A but got %A" message expected actual

        let toBeTrue condition message =
            if not condition then
                failwith message

        let toBeFalse condition message =
            if condition then
                failwith message

        let toContain (substring: string) (actual: string) message =
            if not (actual.Contains(substring)) then
                failwithf "%s: Expected '%s' to contain '%s'" message actual substring

        let toBeOk result message =
            match result with
            | Ok _ -> ()
            | Error e -> failwithf "%s: Expected Ok but got Error: %A" message e

        let toBeError result message =
            match result with
            | Ok v -> failwithf "%s: Expected Error but got Ok: %A" message v
            | Error _ -> ()

        let toThrow f message =
            try
                f ()
                failwith message
            with
            | _ -> ()
