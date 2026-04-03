module Cepaf.Knowledge.Topology

open System
open System.IO
open System.Text.RegularExpressions
open Cepaf.Knowledge.Schema

// TO-BE Structure Definition
type ToBeStructure = {
    Domain: string
    SubDomain: string option
    Concept: string
}

// AS-IS Pattern Recognition
type AsIsPattern = 
    | JournalEntry of date: string * topic: string
    | Plan of date: string * topic: string
    | Specification of topic: string
    | Guide of topic: string
    | Unknown of filename: string

module TopologyMapper =
    
    // AS-IS Recognition Logic
    let classifyAsIs (path: string) =
        let filename = Path.GetFileNameWithoutExtension(path)
        let dir = Path.GetDirectoryName(path)
        
        if filename.StartsWith("2025") && dir.Contains("journal") then
            // e.g. 20251230-my-topic
            let parts = filename.Split('-')
            if parts.Length > 1 then JournalEntry(parts[0], String.concat "-" parts[1..])
            else Unknown(filename)
        elif dir.Contains("plans") then
            Plan(DateTime.Now.ToString("yyyyMMdd"), filename)
        elif dir.Contains("spec") || filename.Contains("Spec") then
            Specification(filename)
        else
            Unknown(filename)

    // Transformation Logic (Topology Mapping)
    let mapToBe (pattern: AsIsPattern) : ToBeStructure =
        match pattern with
        | JournalEntry (_, topic) -> { Domain = "Log"; SubDomain = Some "Evolution"; Concept = topic }
        | Plan (_, topic) -> { Domain = "Strategy"; SubDomain = Some "Planning"; Concept = topic }
        | Specification (topic) -> { Domain = "Core"; SubDomain = Some "Architecture"; Concept = topic }
        | Guide (topic) -> { Domain = "Learning"; SubDomain = Some "Guides"; Concept = topic }
        | Unknown (name) -> { Domain = "Inbox"; SubDomain = None; Concept = name }

    // Statistical Sampling
    let sampleAndMap (files: string list) =
        files 
        |> List.map (fun f -> 
            let pattern = classifyAsIs f
            let target = mapToBe pattern
            (f, pattern, target)
        )
