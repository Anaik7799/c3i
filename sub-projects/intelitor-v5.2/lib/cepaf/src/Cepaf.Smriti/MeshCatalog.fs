namespace Cepaf.Smriti

open System
open System.Text.Json
open Cepaf.Smriti.Domain

// Run 5: Federation Hardening - Zenoh Mesh Logic

module MeshCatalog =

    // Mocking Zenoh interface for F# integration
    type ZenohSession = { Id: Guid }

    let private publish (key: string) (payload: string) =
        // Real implementation: Zenoh.put(session, key, payload)
        printfn "[Zenoh] PUB %s -> %s bytes" key payload

    let broadcastEntity (entity: CatalogEntity) =
        // Key Scheme: indrajaal/kms/catalog/{kind}/{namespace}/{name}
        let key = sprintf "indrajaal/kms/catalog/%O/%s/%s" 
                    entity.Kind 
                    entity.Metadata.Namespace 
                    entity.Metadata.Name
        
        // Use HolonMapper DTO logic for serialization to avoid Union errors
        let dto = HolonMapper.toDto entity
        let payload = JsonSerializer.Serialize(dto)
        publish key payload

    let subscribeToCatalog (callback: HolonMapper.HolonPayloadDto -> unit) =
        // Real implementation: Zenoh.subscribe(session, "indrajaal/kms/catalog/**", cb)
        printfn "[Zenoh] Subscribed to Catalog Stream"