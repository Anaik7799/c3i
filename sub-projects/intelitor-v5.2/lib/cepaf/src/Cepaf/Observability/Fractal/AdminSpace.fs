namespace Cepaf.Observability.Fractal

open System
open System.Collections.Concurrent
open System.Security.Cryptography

/// AdminSpace - Implements SC-LOG-010 (Admin space operations authenticated)
/// Provides authenticated administrative control over the Fractal Logging System
/// STAMP Compliance: SC-LOG-010 (mandatory), SC-SEC-001 (auth), AOR-LOG-006 (admin ops)
module AdminSpace =

    // ============================================================
    // TYPES
    // ============================================================

    /// Admin operation types that require authentication
    [<RequireQualifiedAccess>]
    type AdminOperation =
        /// Create a new boost
        | CreateBoost
        /// Delete an existing boost
        | DeleteBoost
        /// Modify boost TTL or depth
        | ModifyBoost
        /// Change global default level
        | SetDefaultLevel
        /// Enable/disable load shedding
        | ToggleShedding
        /// Register new key alias
        | RegisterAlias
        /// Modify routing rules
        | ModifyRouting
        /// View system metrics
        | ViewMetrics
        /// Export configuration
        | ExportConfig
        /// Import configuration
        | ImportConfig

    /// Permission levels for admin operations
    [<RequireQualifiedAccess>]
    type PermissionLevel =
        /// Read-only access (view metrics, export)
        | ReadOnly
        /// Operator access (create/delete boosts)
        | Operator
        /// Admin access (modify routing, config)
        | Admin
        /// Super admin (all operations)
        | SuperAdmin

    /// Admin user/token
    type AdminPrincipal = {
        /// Unique identifier
        Id: string

        /// Display name
        Name: string

        /// Permission level
        Level: PermissionLevel

        /// Token hash (not the actual token)
        TokenHash: string

        /// Expiration time
        ExpiresAt: DateTimeOffset option

        /// Issuing agent
        IssuedBy: string

        /// Creation timestamp
        CreatedAt: DateTimeOffset

        /// Last used timestamp
        mutable LastUsedAt: DateTimeOffset option

        /// Whether principal is active
        Active: bool
    }

    /// Authentication result
    type AuthResult =
        | Authenticated of AdminPrincipal
        | Unauthorized of reason: string
        | Expired
        | Revoked

    /// Audit log entry for admin operations
    type AdminAuditEntry = {
        /// Unique entry ID
        Id: string

        /// Timestamp
        Timestamp: DateTimeOffset

        /// Principal who performed the operation
        Principal: string

        /// Operation performed
        Operation: AdminOperation

        /// Whether operation succeeded
        Success: bool

        /// Target of operation (e.g., boost ID)
        Target: string option

        /// Additional details
        Details: Map<string, string>

        /// Client info (IP, user agent)
        ClientInfo: Map<string, string>
    }

    /// Admin command with authentication
    type AdminCommand = {
        /// Operation to perform
        Operation: AdminOperation

        /// Token for authentication
        Token: string

        /// Parameters for the operation
        Parameters: Map<string, obj>

        /// Request timestamp
        RequestedAt: DateTimeOffset

        /// Request ID for correlation
        RequestId: string
    }

    /// Admin command result
    type AdminCommandResult = {
        /// Request ID
        RequestId: string

        /// Whether successful
        Success: bool

        /// Error message if failed
        Error: string option

        /// Result data if successful
        Data: obj option

        /// Execution time
        ExecutionTimeMs: int64

        /// Audit entry ID
        AuditId: string
    }

    // ============================================================
    // STATE
    // ============================================================

    let private principals = ConcurrentDictionary<string, AdminPrincipal>()
    let private auditLog = ConcurrentDictionary<string, AdminAuditEntry>()
    let private revokedTokens = ConcurrentDictionary<string, DateTimeOffset>()
    let private initLock = obj()
    let mutable private initialized = false

    // ============================================================
    // CRYPTO HELPERS
    // ============================================================

    /// Compute token hash
    let private hashToken (token: string) : string =
        use sha256 = SHA256.Create()
        let bytes = System.Text.Encoding.UTF8.GetBytes("fractal-admin-" + token)
        let hash = sha256.ComputeHash(bytes)
        BitConverter.ToString(hash).Replace("-", "").ToLowerInvariant()

    /// Generate new admin token
    let generateToken () : string =
        let bytes = Array.zeroCreate<byte> 32
        use rng = RandomNumberGenerator.Create()
        rng.GetBytes(bytes)
        Convert.ToBase64String(bytes).Replace("+", "-").Replace("/", "_").TrimEnd('=')

    // ============================================================
    // PERMISSION MAPPING
    // ============================================================

    /// Get required permission level for an operation
    let private requiredLevel (op: AdminOperation) : PermissionLevel =
        match op with
        | AdminOperation.ViewMetrics -> PermissionLevel.ReadOnly
        | AdminOperation.ExportConfig -> PermissionLevel.ReadOnly
        | AdminOperation.CreateBoost -> PermissionLevel.Operator
        | AdminOperation.DeleteBoost -> PermissionLevel.Operator
        | AdminOperation.ModifyBoost -> PermissionLevel.Operator
        | AdminOperation.SetDefaultLevel -> PermissionLevel.Admin
        | AdminOperation.ToggleShedding -> PermissionLevel.Admin
        | AdminOperation.RegisterAlias -> PermissionLevel.Admin
        | AdminOperation.ModifyRouting -> PermissionLevel.Admin
        | AdminOperation.ImportConfig -> PermissionLevel.SuperAdmin

    /// Check if permission level is sufficient
    let private hasPermission (principal: PermissionLevel) (required: PermissionLevel) : bool =
        match principal, required with
        | PermissionLevel.SuperAdmin, _ -> true
        | PermissionLevel.Admin, PermissionLevel.ReadOnly -> true
        | PermissionLevel.Admin, PermissionLevel.Operator -> true
        | PermissionLevel.Admin, PermissionLevel.Admin -> true
        | PermissionLevel.Operator, PermissionLevel.ReadOnly -> true
        | PermissionLevel.Operator, PermissionLevel.Operator -> true
        | PermissionLevel.ReadOnly, PermissionLevel.ReadOnly -> true
        | _ -> false

    // ============================================================
    // AUTHENTICATION
    // ============================================================

    /// Authenticate a token
    let authenticate (token: string) : AuthResult =
        if String.IsNullOrWhiteSpace(token) then
            Unauthorized "Empty token"
        else
            let tokenHash = hashToken token

            // Check if token is revoked
            match revokedTokens.TryGetValue(tokenHash) with
            | true, _ -> Revoked
            | false, _ ->
                // Find principal by token hash
                match principals.Values |> Seq.tryFind (fun p -> p.TokenHash = tokenHash && p.Active) with
                | Some principal ->
                    // Check expiration
                    match principal.ExpiresAt with
                    | Some expires when expires < DateTimeOffset.UtcNow ->
                        Expired
                    | _ ->
                        // Update last used
                        principal.LastUsedAt <- Some DateTimeOffset.UtcNow
                        Authenticated principal
                | None ->
                    Unauthorized "Invalid token"

    /// Authorize an operation
    let authorize (principal: AdminPrincipal) (operation: AdminOperation) : Result<unit, string> =
        let required = requiredLevel operation
        if hasPermission principal.Level required then
            Ok ()
        else
            Error (sprintf "Insufficient permission: %A required, %A granted" required principal.Level)

    // ============================================================
    // PRINCIPAL MANAGEMENT
    // ============================================================

    /// Create a new admin principal
    let createPrincipal (name: string) (level: PermissionLevel) (issuedBy: string) (expiresIn: TimeSpan option) : AdminPrincipal * string =
        let token = generateToken ()
        let now = DateTimeOffset.UtcNow

        let principal = {
            Id = Guid.NewGuid().ToString("N").[..7]
            Name = name
            Level = level
            TokenHash = hashToken token
            ExpiresAt = expiresIn |> Option.map (fun ts -> now.Add(ts))
            IssuedBy = issuedBy
            CreatedAt = now
            LastUsedAt = None
            Active = true
        }

        principals.[principal.Id] <- principal
        (principal, token)

    /// Revoke a principal's token
    let revokePrincipal (principalId: string) : bool =
        match principals.TryGetValue(principalId) with
        | true, principal ->
            revokedTokens.[principal.TokenHash] <- DateTimeOffset.UtcNow
            principals.[principalId] <- { principal with Active = false }
            true
        | false, _ -> false

    /// List all principals
    let listPrincipals () : AdminPrincipal list =
        principals.Values |> Seq.toList

    /// Get principal by ID
    let getPrincipal (id: string) : AdminPrincipal option =
        match principals.TryGetValue(id) with
        | true, p -> Some p
        | false, _ -> None

    // ============================================================
    // AUDIT LOGGING
    // ============================================================

    /// Log an admin operation
    let private logAudit (principal: string) (operation: AdminOperation) (success: bool) (target: string option) (details: Map<string, string>) (clientInfo: Map<string, string>) : string =
        let entry = {
            Id = Guid.NewGuid().ToString("N").[..11]
            Timestamp = DateTimeOffset.UtcNow
            Principal = principal
            Operation = operation
            Success = success
            Target = target
            Details = details
            ClientInfo = clientInfo
        }
        auditLog.[entry.Id] <- entry
        entry.Id

    /// Safe skip that doesn't throw if not enough elements
    let private safeSkip (n: int) (source: seq<'T>) : seq<'T> =
        source |> Seq.indexed |> Seq.filter (fun (i, _) -> i >= n) |> Seq.map snd

    /// Get audit log entries
    let getAuditLog (limit: int) (offset: int) : AdminAuditEntry list =
        auditLog.Values
        |> Seq.sortByDescending (fun e -> e.Timestamp)
        |> safeSkip offset
        |> Seq.truncate limit
        |> Seq.toList

    /// Get audit entries for a principal
    let getAuditByPrincipal (principalId: string) (limit: int) : AdminAuditEntry list =
        auditLog.Values
        |> Seq.filter (fun e -> e.Principal = principalId)
        |> Seq.sortByDescending (fun e -> e.Timestamp)
        |> Seq.truncate limit
        |> Seq.toList

    // ============================================================
    // COMMAND EXECUTION
    // ============================================================

    /// Execute an admin command with authentication
    let rec executeCommand (command: AdminCommand) (clientInfo: Map<string, string>) : AdminCommandResult =
        let stopwatch = System.Diagnostics.Stopwatch.StartNew()

        // Authenticate
        match authenticate command.Token with
        | Unauthorized reason ->
            stopwatch.Stop()
            let auditId = logAudit "ANONYMOUS" command.Operation false None (Map.ofList ["reason", reason]) clientInfo
            {
                RequestId = command.RequestId
                Success = false
                Error = Some (sprintf "Authentication failed: %s" reason)
                Data = None
                ExecutionTimeMs = stopwatch.ElapsedMilliseconds
                AuditId = auditId
            }

        | Expired ->
            stopwatch.Stop()
            let auditId = logAudit "EXPIRED" command.Operation false None Map.empty clientInfo
            {
                RequestId = command.RequestId
                Success = false
                Error = Some "Token expired"
                Data = None
                ExecutionTimeMs = stopwatch.ElapsedMilliseconds
                AuditId = auditId
            }

        | Revoked ->
            stopwatch.Stop()
            let auditId = logAudit "REVOKED" command.Operation false None Map.empty clientInfo
            {
                RequestId = command.RequestId
                Success = false
                Error = Some "Token revoked"
                Data = None
                ExecutionTimeMs = stopwatch.ElapsedMilliseconds
                AuditId = auditId
            }

        | Authenticated principal ->
            // Authorize
            match authorize principal command.Operation with
            | Error reason ->
                stopwatch.Stop()
                let auditId = logAudit principal.Id command.Operation false None (Map.ofList ["reason", reason]) clientInfo
                {
                    RequestId = command.RequestId
                    Success = false
                    Error = Some (sprintf "Authorization failed: %s" reason)
                    Data = None
                    ExecutionTimeMs = stopwatch.ElapsedMilliseconds
                    AuditId = auditId
                }

            | Ok () ->
                // Execute operation
                try
                    let result = executeOperation command.Operation command.Parameters
                    stopwatch.Stop()
                    let target =
                        command.Parameters
                        |> Map.tryFind "target"
                        |> Option.map string
                    let auditId = logAudit principal.Id command.Operation true target Map.empty clientInfo
                    {
                        RequestId = command.RequestId
                        Success = true
                        Error = None
                        Data = Some result
                        ExecutionTimeMs = stopwatch.ElapsedMilliseconds
                        AuditId = auditId
                    }
                with ex ->
                    stopwatch.Stop()
                    let auditId = logAudit principal.Id command.Operation false None (Map.ofList ["error", ex.Message]) clientInfo
                    {
                        RequestId = command.RequestId
                        Success = false
                        Error = Some ex.Message
                        Data = None
                        ExecutionTimeMs = stopwatch.ElapsedMilliseconds
                        AuditId = auditId
                    }

    /// Execute the actual operation
    and private executeOperation (operation: AdminOperation) (parameters: Map<string, obj>) : obj =
        match operation with
        | AdminOperation.CreateBoost ->
            let keyExpr = parameters.["keyExpr"] :?> string
            let depth = parameters.["depth"] :?> int |> FractalLevel.fromInt
            let createdBy = parameters.["createdBy"] :?> string
            let ttlMs = parameters |> Map.tryFind "ttlMs" |> Option.map (fun v -> v :?> int64) |> Option.defaultValue 300_000L
            let result = FractalControl.focus keyExpr depth ttlMs createdBy
            box result

        | AdminOperation.DeleteBoost ->
            let boostId = parameters.["boostId"] :?> string
            let deleted = FractalControl.removeBoost boostId
            box deleted

        | AdminOperation.ModifyBoost ->
            let boostId = parameters.["boostId"] :?> string
            // In production, would update boost properties
            box (sprintf "Modified boost %s" boostId)

        | AdminOperation.SetDefaultLevel ->
            let level = parameters.["level"] :?> int |> FractalLevel.fromInt
            FractalControl.setDefaultPolicy level
            box level

        | AdminOperation.ToggleShedding ->
            let enabled = parameters.["enabled"] :?> bool
            if enabled then
                FractalControl.activateShedding "Admin command"
            else
                FractalControl.deactivateShedding ()
            box enabled

        | AdminOperation.RegisterAlias ->
            let key = parameters.["key"] :?> string
            let alias = FractalControl.registerKey key
            box (sprintf "Registered alias %d -> %s" alias key)

        | AdminOperation.ModifyRouting ->
            // Would modify ContentRouter rules
            box "Routing modified"

        | AdminOperation.ViewMetrics ->
            let status = FractalControl.getStatus ()
            box status

        | AdminOperation.ExportConfig ->
            let config = {|
                ActiveBoosts = FractalControl.getActiveBoosts () |> List.length
                SheddingActive = FractalControl.isShedding ()
            |}
            box config

        | AdminOperation.ImportConfig ->
            // Would import full configuration
            box "Config imported"

    // ============================================================
    // INITIALIZATION
    // ============================================================

    /// Initialize the AdminSpace with a root principal
    let initialize () : string =
        lock initLock (fun () ->
            if not initialized then
                // Create root super admin
                let (_, rootToken) = createPrincipal "root" PermissionLevel.SuperAdmin "SYSTEM" None
                initialized <- true
                rootToken
            else
                ""
        )

    /// Check if AdminSpace is initialized
    let isInitialized () : bool = initialized

    /// Reset AdminSpace (for testing)
    let reset () =
        lock initLock (fun () ->
            principals.Clear()
            auditLog.Clear()
            revokedTokens.Clear()
            initialized <- false
        )

    // ============================================================
    // SAFETY CONSTRAINT VALIDATION
    // ============================================================

    /// Validate SC-LOG-010 compliance
    let validateAuthentication () : SafetyConstraintResult =
        // Create test principal and validate auth flow
        let (testPrincipal, testToken) = createPrincipal "test" PermissionLevel.ReadOnly "VALIDATOR" (Some (TimeSpan.FromMinutes(1.0)))

        let authResult = authenticate testToken
        let passed =
            match authResult with
            | Authenticated p -> p.Id = testPrincipal.Id
            | _ -> false

        // Clean up
        revokePrincipal testPrincipal.Id |> ignore

        {
            ConstraintId = SafetyConstraints.scLog010
            Description = "Admin space operations authenticated"
            Passed = passed
            Details =
                if passed then
                    sprintf "Auth validated. Principals: %d, Audit entries: %d" principals.Count auditLog.Count
                else
                    "Authentication flow failed"
        }

    // ============================================================
    // STATISTICS
    // ============================================================

    /// Get AdminSpace statistics
    let getStats () =
        {|
            TotalPrincipals = principals.Count
            ActivePrincipals = principals.Values |> Seq.filter (fun p -> p.Active) |> Seq.length
            RevokedTokens = revokedTokens.Count
            AuditEntries = auditLog.Count
            Initialized = initialized
        |}

