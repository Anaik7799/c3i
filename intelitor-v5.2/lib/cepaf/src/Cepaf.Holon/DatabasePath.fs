/// Universal Holon Database Path Resolution for F#
///
/// WHAT: Provides deterministic path resolution for all holon-specific databases
///       using the Universal Holon Identifier (UHI) naming system.
///
/// WHY:
/// - Ensures consistent database path structure across all holons
/// - Enables cross-holon database discovery
/// - Supports migration from legacy paths
/// - Enforces SC-DBNAME-001 to SC-DBNAME-010 constraints
///
/// CONSTRAINTS:
/// - SC-DBNAME-001: All holon databases MUST follow UHI naming
/// - SC-DBNAME-002: FQDN resolution MUST be deterministic
/// - SC-DBNAME-008: Cross-runtime access MUST use Zenoh
/// - SC-DBNAME-009: LOCAL access MUST be direct (no Zenoh)
///
/// UHI Format: {runtime}:{layer}:{domain}:{type}:{instance}
///
/// Examples:
///   "ex:l3:kms:srv:main"           -> Elixir L3 KMS Service
///   "fs:l4:prj:agt:cockpit"        -> F# L4 Prajna Agent
///   "ex:l5:grd:reg:guardian"       -> Elixir L5 Guardian Register
module Cepaf.Holon.DatabasePath

open System
open System.IO

// ============================================================================
// Types
// ============================================================================

/// Runtime type enumeration
type Runtime =
    | Elixir
    | FSharp
    | Zig
    | Rust

/// Fractal layer enumeration
type FractalLayer =
    | L0  // Runtime
    | L1  // Function
    | L2  // Component
    | L3  // Holon
    | L4  // Container
    | L5  // Node
    | L6  // Cluster
    | L7  // Federation

/// Domain codes
type Domain =
    | Kms   // Knowledge Management System
    | Prj   // Prajna C3I Cockpit
    | Grd   // Guardian Safety Kernel
    | Snt   // Sentinel Health Monitor
    | Imm   // Immutable Register
    | Fnd   // Founder Directive
    | Zen   // Zenoh Communication
    | Bio   // Biomorphic Systems
    | Pln   // Planning System
    | Evo   // Evolution Engine
    | Ctx   // Cortex AI
    | Tst   // Test Infrastructure
    | Dev   // Developer Knowledge
    | Sre   // SRE Operations
    | Prd   // Product Lifecycle
    | Obs   // Observability

/// Holon type
type HolonType =
    | Srv   // Service
    | Agt   // Agent
    | Reg   // Register/Registry
    | Str   // Store
    | Brg   // Bridge
    | Pub   // Publisher
    | Sub   // Subscriber
    | Wrk   // Worker

/// Database type
type DatabaseType =
    | State     // state.sqlite
    | History   // history.duckdb
    | Vectors   // vectors.sqlite
    | Register  // register.duckdb
    | Analytics // analytics.duckdb

/// Universal Holon Identifier
type UHI = {
    Runtime: Runtime
    Layer: FractalLayer
    Domain: Domain
    Type: HolonType
    Instance: string
}

/// Fully Qualified Database Name
type FQDN = {
    UHI: UHI
    DatabaseType: DatabaseType
}

/// Parse result
type ParseResult<'T> =
    | Success of 'T
    | Error of string

// ============================================================================
// Constants
// ============================================================================

let private basePath = "data/holons"

let private dbTypeToFile = function
    | State -> "state.sqlite"
    | History -> "history.duckdb"
    | Vectors -> "vectors.sqlite"
    | Register -> "register.duckdb"
    | Analytics -> "analytics.duckdb"

let private runtimeToCode = function
    | Elixir -> "ex"
    | FSharp -> "fs"
    | Zig -> "zig"
    | Rust -> "rs"

let private codeToRuntime = function
    | "ex" -> Some Elixir
    | "fs" -> Some FSharp
    | "zig" -> Some Zig
    | "rs" -> Some Rust
    | _ -> None

let private layerToCode = function
    | L0 -> "l0" | L1 -> "l1" | L2 -> "l2" | L3 -> "l3"
    | L4 -> "l4" | L5 -> "l5" | L6 -> "l6" | L7 -> "l7"

let private codeToLayer = function
    | "l0" -> Some L0 | "l1" -> Some L1 | "l2" -> Some L2 | "l3" -> Some L3
    | "l4" -> Some L4 | "l5" -> Some L5 | "l6" -> Some L6 | "l7" -> Some L7
    | _ -> None

let private domainToCode = function
    | Kms -> "kms" | Prj -> "prj" | Grd -> "grd" | Snt -> "snt"
    | Imm -> "imm" | Fnd -> "fnd" | Zen -> "zen" | Bio -> "bio"
    | Pln -> "pln" | Evo -> "evo" | Ctx -> "ctx" | Tst -> "tst"
    | Dev -> "dev" | Sre -> "sre" | Prd -> "prd" | Obs -> "obs"

let private codeToDomain = function
    | "kms" -> Some Kms | "prj" -> Some Prj | "grd" -> Some Grd | "snt" -> Some Snt
    | "imm" -> Some Imm | "fnd" -> Some Fnd | "zen" -> Some Zen | "bio" -> Some Bio
    | "pln" -> Some Pln | "evo" -> Some Evo | "ctx" -> Some Ctx | "tst" -> Some Tst
    | "dev" -> Some Dev | "sre" -> Some Sre | "prd" -> Some Prd | "obs" -> Some Obs
    | _ -> None

let private typeToCode = function
    | Srv -> "srv" | Agt -> "agt" | Reg -> "reg" | Str -> "str"
    | Brg -> "brg" | Pub -> "pub" | Sub -> "sub" | Wrk -> "wrk"

let private codeToType = function
    | "srv" -> Some Srv | "agt" -> Some Agt | "reg" -> Some Reg | "str" -> Some Str
    | "brg" -> Some Brg | "pub" -> Some Pub | "sub" -> Some Sub | "wrk" -> Some Wrk
    | _ -> None

let private dbTypeToCode = function
    | State -> "state" | History -> "history" | Vectors -> "vectors"
    | Register -> "register" | Analytics -> "analytics"

let private codeToDbType = function
    | "state" -> Some State | "history" -> Some History | "vectors" -> Some Vectors
    | "register" -> Some Register | "analytics" -> Some Analytics
    | _ -> None

// ============================================================================
// UHI Functions
// ============================================================================

/// Creates a UHI from components
let createUHI runtime layer domain htype instance =
    { Runtime = runtime; Layer = layer; Domain = domain; Type = htype; Instance = instance }

/// Converts UHI to string format
let uhiToString (uhi: UHI) =
    sprintf "%s:%s:%s:%s:%s"
        (runtimeToCode uhi.Runtime)
        (layerToCode uhi.Layer)
        (domainToCode uhi.Domain)
        (typeToCode uhi.Type)
        uhi.Instance

/// Parses a UHI string
let parseUHI (s: string) : ParseResult<UHI> =
    let parts = s.Split(':')
    if parts.Length <> 5 then
        Error "Invalid UHI format: expected 5 parts separated by :"
    else
        let runtime = codeToRuntime parts.[0]
        let layer = codeToLayer parts.[1]
        let domain = codeToDomain parts.[2]
        let htype = codeToType parts.[3]
        let instance = parts.[4]

        match runtime, layer, domain, htype with
        | Some r, Some l, Some d, Some t when not (String.IsNullOrEmpty instance) ->
            Success { Runtime = r; Layer = l; Domain = d; Type = t; Instance = instance }
        | None, _, _, _ -> Error $"Invalid runtime code: {parts.[0]}"
        | _, None, _, _ -> Error $"Invalid layer code: {parts.[1]}"
        | _, _, None, _ -> Error $"Invalid domain code: {parts.[2]}"
        | _, _, _, None -> Error $"Invalid type code: {parts.[3]}"
        | _ -> Error "Invalid instance: cannot be empty"

// ============================================================================
// FQDN Functions
// ============================================================================

/// Creates a FQDN from UHI and database type
let createFQDN uhi dbType = { UHI = uhi; DatabaseType = dbType }

/// Converts FQDN to string format
let fqdnToString (fqdn: FQDN) =
    sprintf "%s:%s" (uhiToString fqdn.UHI) (dbTypeToCode fqdn.DatabaseType)

/// Parses a FQDN string
let parseFQDN (s: string) : ParseResult<FQDN> =
    let parts = s.Split(':')
    if parts.Length <> 6 then
        Error "Invalid FQDN format: expected 6 parts separated by :"
    else
        let uhiStr = String.Join(":", parts.[0..4])
        match parseUHI uhiStr with
        | Error e -> Error e
        | Success uhi ->
            match codeToDbType parts.[5] with
            | Some dbType -> Success { UHI = uhi; DatabaseType = dbType }
            | None -> Error $"Invalid database type: {parts.[5]}"

// ============================================================================
// Path Resolution
// ============================================================================

/// Resolves a FQDN to a file path
let resolve (fqdn: FQDN) =
    let uhi = fqdn.UHI
    let fileName = dbTypeToFile fqdn.DatabaseType
    Path.Combine(
        basePath,
        runtimeToCode uhi.Runtime,
        layerToCode uhi.Layer,
        domainToCode uhi.Domain,
        uhi.Instance,
        fileName
    )

/// Resolves a FQDN string to a file path
let resolveString (fqdnStr: string) : ParseResult<string> =
    match parseFQDN fqdnStr with
    | Success fqdn -> Success (resolve fqdn)
    | Error e -> Error e

/// Returns the directory path for a holon
let holonDir (uhi: UHI) =
    Path.Combine(
        basePath,
        runtimeToCode uhi.Runtime,
        layerToCode uhi.Layer,
        domainToCode uhi.Domain,
        uhi.Instance
    )

/// Returns all database paths for a holon
let allDatabases (uhi: UHI) =
    let dir = holonDir uhi
    [
        State, Path.Combine(dir, dbTypeToFile State)
        History, Path.Combine(dir, dbTypeToFile History)
        Vectors, Path.Combine(dir, dbTypeToFile Vectors)
        Register, Path.Combine(dir, dbTypeToFile Register)
        Analytics, Path.Combine(dir, dbTypeToFile Analytics)
    ] |> Map.ofList

// ============================================================================
// Cross-Runtime Helpers
// ============================================================================

/// Checks if UHI is an Elixir holon
let isElixirHolon (uhi: UHI) = uhi.Runtime = Elixir

/// Checks if UHI is an F# holon
let isFSharpHolon (uhi: UHI) = uhi.Runtime = FSharp

/// Returns the Zenoh topic for cross-holon database access
let zenohTopic (uhi: UHI) (operation: string) =
    sprintf "indrajaal/db/%s/%s/%s/%s/%s"
        (runtimeToCode uhi.Runtime)
        (layerToCode uhi.Layer)
        (domainToCode uhi.Domain)
        uhi.Instance
        operation

// ============================================================================
// Legacy Path Migration
// ============================================================================

/// Maps a legacy path to FQDN
let fromLegacy (legacyPath: string) : ParseResult<string> =
    let mappings =
        [ ("data/kms/holons.db", "ex:l3:kms:srv:main:state")
          ("data/kms/analytics.duckdb", "ex:l3:kms:srv:main:history")
          ("data/holons/founder_directive/state.sqlite", "ex:l5:fnd:reg:founder:state")
          ("data/holons/founder_directive/history.duckdb", "ex:l5:fnd:reg:founder:history")
          ("data/holons/prajna_register.duckdb", "ex:l5:prj:srv:prajna:register")
          ("data/smriti/planning.db", "fs:l4:pln:srv:main:state")
          ("data/kms/smriti.db", "ex:l3:kms:str:smriti:state") ]
        |> Map.ofList
    match Map.tryFind legacyPath mappings with
    | Some fqdn -> Success fqdn
    | None ->
        if legacyPath.StartsWith("data/kms/") && legacyPath.EndsWith("/holons.db") then
            let parts = legacyPath.Split('/')
            if parts.Length >= 3 then
                Success $"ex:l3:kms:srv:{parts.[2]}:state"
            else
                Error "Unknown legacy path pattern"
        elif legacyPath.StartsWith("data/kms/") && legacyPath.EndsWith("/analytics.duckdb") then
            let parts = legacyPath.Split('/')
            if parts.Length >= 3 then
                Success $"ex:l3:kms:srv:{parts.[2]}:history"
            else
                Error "Unknown legacy path pattern"
        else
            Error $"Unknown legacy path: {legacyPath}"

// ============================================================================
// Domain Registry
// ============================================================================

/// Returns all registered domains with descriptions
let domainRegistry =
    [ (Kms, "Knowledge Management System")
      (Prj, "Prajna C3I Cockpit")
      (Grd, "Guardian Safety Kernel")
      (Snt, "Sentinel Health Monitor")
      (Imm, "Immutable Register")
      (Fnd, "Founder Directive")
      (Zen, "Zenoh Communication")
      (Bio, "Biomorphic Systems")
      (Pln, "Planning System")
      (Evo, "Evolution Engine")
      (Ctx, "Cortex AI")
      (Tst, "Test Infrastructure")
      (Dev, "Developer Knowledge")
      (Sre, "SRE Operations")
      (Prd, "Product Lifecycle")
      (Obs, "Observability") ]
    |> Map.ofList

// ============================================================================
// Manifest Support
// ============================================================================

/// Manifest structure for holon metadata
type HolonManifest = {
    Version: string
    UHI: string
    FQUN: string
    CreatedAt: DateTime
    UpdatedAt: DateTime
    Runtime: {| Type: string; Version: string |}
    Databases: Map<string, {| Type: string; Version: string; SchemaVersion: int |}>
    Capabilities: string list
    ParentUHI: string option
    ChildrenUHI: string list
    ZenohTopics: {| Publish: string list; Subscribe: string list |}
    Checksum: string
}

/// Creates a default manifest for a holon
let createManifest (uhi: UHI) =
    let uhiStr = uhiToString uhi
    let now = DateTime.UtcNow
    {
        Version = "1.0.0"
        UHI = uhiStr
        FQUN = $"kms/l3/{domainToCode uhi.Domain}/default/{uhi.Instance}"
        CreatedAt = now
        UpdatedAt = now
        Runtime = {| Type = runtimeToCode uhi.Runtime; Version = "10.0.0" |}
        Databases = Map.ofList [
            "state", {| Type = "sqlite"; Version = "3.47.0"; SchemaVersion = 1 |}
            "history", {| Type = "duckdb"; Version = "1.2.0"; SchemaVersion = 1 |}
        ]
        Capabilities = ["read"; "write"]
        ParentUHI = None
        ChildrenUHI = []
        ZenohTopics = {|
            Publish = [zenohTopic uhi "state"]
            Subscribe = ["indrajaal/coord/heartbeat"]
        |}
        Checksum = ""
    }
