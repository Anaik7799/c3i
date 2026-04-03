namespace Cepaf.Smriti

open System
open Cepaf.Smriti.Domain

// Run 5: Expansion Hardening - Compliance Scorecard

module Scorecard =

    type CheckResult = 
        | Pass
        | Fail of reason: string
        | Warn of reason: string

    type Rule = {
        Id: string
        Name: string
        Evaluate: CatalogEntity -> CheckResult
        Weight: float
    }

    // --- Standard Rules ---

    let ruleHasOwner = {
        Id = "SC-001"
        Name = "Entity must have an owner"
        Weight = 1.0
        Evaluate = fun e ->
            match e.Spec with
            | Component c -> if String.IsNullOrWhiteSpace(c.Owner) then Fail "No owner" else Pass
            | Api a -> if String.IsNullOrWhiteSpace(a.Owner) then Fail "No owner" else Pass
            | System s -> if String.IsNullOrWhiteSpace(s.Owner) then Fail "No owner" else Pass
            | _ -> Pass // Skip other types
    }

    let ruleHasDescription = {
        Id = "SC-002"
        Name = "Metadata description required"
        Weight = 0.5
        Evaluate = fun e ->
            match e.Metadata.Description with
            | Some d when not (String.IsNullOrWhiteSpace(d)) -> Pass
            | _ -> Warn "Missing description"
    }

    let ruleProductionLifecycle = {
        Id = "SC-003"
        Name = "Production components need PagerDuty link"
        Weight = 2.0
        Evaluate = fun e ->
            match e.Spec with
            | Component c when c.Lifecycle = Production ->
                if e.Metadata.Annotations.ContainsKey("pagerduty.com/integration-key") 
                then Pass 
                else Fail "Production service missing PagerDuty"
            | _ -> Pass
    }

    let AllRules = [ruleHasOwner; ruleHasDescription; ruleProductionLifecycle]

    // --- Engine ---

    type ScoreReport = {
        EntityRef: string
        Score: float
        MaxScore: float
        Results: (string * CheckResult) list
    }

    let evaluate (entity: CatalogEntity) : ScoreReport =
        let results = 
            AllRules 
            |> List.map (fun r -> (r.Name, r.Evaluate entity))
        
        let score = 
            AllRules 
            |> List.fold (fun acc r -> 
                match r.Evaluate entity with 
                | Pass -> acc + r.Weight 
                | _ -> acc
            ) 0.0

        let maxScore = AllRules |> List.sumBy (fun r -> r.Weight)

        {
            EntityRef = sprintf "%O:%s" entity.Kind entity.Metadata.Name
            Score = score
            MaxScore = maxScore
            Results = results
        }
