namespace Cepaf.Smriti

open System
open System.Collections.Generic

// Run 1: Domain Hardening - Strict Type Definitions
// Compliant with Backstage "Entity" Specification

module Domain =

    // Renamed cases to avoid collision with EntitySpec
    type EntityKind =
        | KindComponent
        | KindAPI
        | KindResource
        | KindSystem
        | KindDomain
        | KindGroup
        | KindUser
        | KindTemplate
        | KindLocation
        | KindCostMetric
        | KindSearchIndex
        | KindPlugin
        | KindUserSettings
        | KindUnknown of string

    type Lifecycle =
        | Experimental
        | Production
        | Deprecated
        | Unknown of string

    type EntityRef = {
        Kind: string
        Namespace: string
        Name: string
    }

    type EntityMetadata = {
        Name: string
        Namespace: string
        Uid: string option
        Title: string option
        Description: string option
        Tags: string list
        Labels: Map<string, string>
        Annotations: Map<string, string>
        Links: Map<string, string>
    }

    // Spec definitions tailored for different Kinds
    type ComponentSpec = {
        Type: string
        Lifecycle: Lifecycle
        Owner: string
        System: string option
        DependsOn: string list
        ProvidesApis: string list
        ConsumesApis: string list
    }

    type ApiSpec = {
        Type: string // openapi, grpc, graphql
        Lifecycle: Lifecycle
        Owner: string
        Definition: string // The raw IDL text
    }

    type CostSpec = {
        CloudProvider: string // AWS, GCP, Azure, OnPrem
        ResourceId: string
        DailyCost: float
        Currency: string
        Trend: string // "up", "down", "flat"
    }

    type PluginSpec = {
        Id: string
        EntryPoints: Map<string, string> // "frontend" -> "/plugins/...", "backend" -> "/api/..."
        ConfigSchema: string // JSON Schema
    }

    type UserSettingsSpec = {
        Theme: string
        StarredEntities: string list
        PinnedMenu: string list
    }

    // Discriminated Union for Polymorphic Specs
    type EntitySpec =
        | Component of ComponentSpec
        | Api of ApiSpec
        | System of {| Owner: string; Domain: string option |}
        | Domain of {| Owner: string |}
        | Resource of {| Type: string; Owner: string; DependsOn: string list |}
        | Group of {| Profile: Map<string,obj>; Parent: string option; Children: string list |}
        | User of {| Profile: Map<string,obj>; MemberOf: string list |}
        | Template of Map<string, obj> // Dynamic
        | CostMetric of CostSpec
        | Plugin of PluginSpec
        | UserSettings of UserSettingsSpec
        | Generic of Map<string, obj>  // Fallback

    type CatalogEntity = {
        ApiVersion: string
        Kind: EntityKind
        Metadata: EntityMetadata
        Spec: EntitySpec
    }

    // Helper for safe casting
    module EntityHelper =
        let getRef (e: CatalogEntity) = 
            sprintf "%O:%s/%s" e.Kind e.Metadata.Namespace e.Metadata.Name

        let isProduction (e: CatalogEntity) =
            match e.Spec with
            | Component c -> c.Lifecycle = Production
            | Api a -> a.Lifecycle = Production
            | _ -> false
