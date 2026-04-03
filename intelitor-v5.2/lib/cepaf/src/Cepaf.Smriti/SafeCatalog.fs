namespace Cepaf.Smriti

open System
open Cepaf.Smriti.Domain
open Cepaf.Smriti.CheckpointDomain

// Run 6: Safety Hardening - The Safe Catalog Facade
// Wraps HolonMapper with UCR constraints.

module SafeCatalog =

    type CatalogContext = {
        Actor: string
        Registry: ICheckpointRegistry
        DbPath: string
    }

    // Decorator for Ingestion
    let ingestEntity (ctx: CatalogContext) (entity: CatalogEntity) =
        // 1. Calculate State
        // In a real system, we'd fetch the existing entity to get 'PreviousHash'
        let prevHash = "00000000000000000000000000000000" 
        
        // 2. Create Checkpoint
        let checkpoint = CheckpointAdapter.createCheckpoint ctx.Actor Ingestion entity prevHash
        
        // 3. Commit to UCR (The Gatekeeper)
        match ctx.Registry.Commit(checkpoint) with
        | Ok _ ->
            // 4. If Safe, Commit to Operational Store
            HolonMapper.upsertHolon (sprintf "Data Source=%s" ctx.DbPath) entity
            Ok checkpoint.Id
        | Error e ->
            Error (sprintf "UCR Rejected Commit: %s" e)

    // Decorator for Scaffolding
    let registerTemplate (ctx: CatalogContext) (template: CatalogEntity) =
        // Similar logic, potentially with different validation rules
        let prevHash = "00000000000000000000000000000000"
        let checkpoint = CheckpointAdapter.createCheckpoint ctx.Actor Scaffolding template prevHash
        
        match ctx.Registry.Commit(checkpoint) with
        | Ok _ ->
            HolonMapper.upsertHolon (sprintf "Data Source=%s" ctx.DbPath) template
            Ok checkpoint.Id
        | Error e ->
            Error e
