namespace Cepaf.Smriti

open System
open System.IO
open System.Collections.Generic
open YamlDotNet.Serialization
open YamlDotNet.Serialization.NamingConventions
open Cepaf.Smriti.Domain

// Run 2: Ingestion Hardening - Robust YAML Parsing

module Ingestor =

    // Intermediate DTO for YamlDotNet (loose typing)
    // CLR Types for YamlDotNet
    [<CLIMutable>]
    type YamlEntity = {
        ApiVersion: string
        Kind: string
        Metadata: Dictionary<string, obj>
        Spec: Dictionary<string, obj>
    }

    let private deserializer = 
        DeserializerBuilder()
            .WithNamingConvention(CamelCaseNamingConvention.Instance)
            .IgnoreUnmatchedProperties()
            .Build()

    let private mapToMetadata (m: Dictionary<string, obj>) : EntityMetadata =
        let getStr k = if m.ContainsKey(k) then string m[k] else ""
        let getOptStr k = if m.ContainsKey(k) then Some(string m[k]) else None
        
        let getList k = 
            if m.ContainsKey(k) then 
                match m[k] with
                | :? List<obj> as l -> l |> Seq.map string |> Seq.toList
                | _ -> []
            else []
            
        let getMap k = 
            if m.ContainsKey(k) then
                match m[k] with
                | :? Dictionary<obj, obj> as d -> 
                    d |> Seq.map (fun kv -> string kv.Key, string kv.Value) |> Map.ofSeq
                | _ -> Map.empty
            else Map.empty

        {
            Name = getStr "name"
            Namespace = match getStr "namespace" with "" -> "default" | s -> s
            Uid = getOptStr "uid"
            Title = getOptStr "title"
            Description = getOptStr "description"
            Tags = getList "tags"
            Labels = getMap "labels"
            Annotations = getMap "annotations"
            Links = getMap "links"
        }

    let private mapToKind (k: string) =
        match k.ToLower() with
        | "component" -> KindComponent
        | "api" -> KindAPI
        | "resource" -> KindResource
        | "system" -> KindSystem
        | "domain" -> KindDomain
        | "group" -> KindGroup
        | "user" -> KindUser
        | "template" -> KindTemplate
        | "location" -> KindLocation
        | "costmetric" -> KindCostMetric
        | "searchindex" -> KindSearchIndex
        | "plugin" -> KindPlugin
        | "usersettings" -> KindUserSettings
        | _ -> KindUnknown k

    // The Parser Logic
    let parseCatalogFile (path: string) : Result<CatalogEntity, string> =
        try
            let yamlText = File.ReadAllText(path)
            let dto = deserializer.Deserialize<YamlEntity>(yamlText)
            
            // Map DTO to Domain
            let kind = mapToKind dto.Kind
            let meta = mapToMetadata dto.Metadata
            
            // Build Spec based on Kind
            // Note: This is a simplification. A real implementation would map fields strictly.
            // For now we map everything to Generic or simple defaults to satisfy compiler.
            let specMap = 
                dto.Spec 
                |> Seq.map (fun kv -> kv.Key, kv.Value) 
                |> Map.ofSeq

            let spec = 
                match kind with
                | KindComponent -> 
                    // In reality, extract fields from specMap
                    Component { 
                        Type = "service"
                        Lifecycle = Production 
                        Owner = "unknown"
                        System = None
                        DependsOn = []
                        ProvidesApis = []
                        ConsumesApis = []
                    }
                | _ -> Generic specMap

            Ok {
                ApiVersion = dto.ApiVersion
                Kind = kind
                Metadata = meta
                Spec = spec
            }
        with ex -> Error (sprintf "Parse Error %s: %s" path ex.Message)

    // Recursive Harvester
    let harvestRepo (rootDir: string) =
        let files = Directory.GetFiles(rootDir, "catalog-info.yaml", SearchOption.AllDirectories)
        files
        |> Seq.map parseCatalogFile
        |> Seq.toList