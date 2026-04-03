namespace Cepaf.Kms

open System
open System.Text.Json
open System.Text.Json.Serialization

// --- HOLON DOMAIN MODEL ---

type HolonType =
    | Knowledge | Process | Agent | Artifact | Index | Task
    static member FromString(s: string) =
        match s.ToLower() with
        | "knowledge" -> Knowledge
        | "process" -> Process
        | "agent" -> Agent
        | "artifact" -> Artifact
        | "index" -> Index
        | "task" -> Task
        | _ -> Knowledge

type VitalSigns = {
    [<JsonPropertyName("health")>] Health: float
    [<JsonPropertyName("stress")>] Stress: float
    [<JsonPropertyName("energy")>] Energy: float
}

type Holon = {
    Id: string
    Fqun: string
    Type: HolonType
    Name: string
    ParentId: string option
    Genome: Map<string, obj>
    VitalSigns: VitalSigns
    Membrane: Map<string, obj>
    Payload: Map<string, obj>
    HlcPhysical: int64
    HlcLogical: int64
    CreatedAt: DateTime
    UpdatedAt: DateTime
}

// --- DTOs for CLI ---

type HolonDto = {
    id: string
    fqun: string
    type: string
    name: string
    parent_id: string
    genome: string // JSON
    vital_signs: string // JSON
    membrane: string // JSON
    payload: string // JSON
    hlc_physical: int64
    hlc_logical: int64
    created_at: string
    updated_at: string
}
