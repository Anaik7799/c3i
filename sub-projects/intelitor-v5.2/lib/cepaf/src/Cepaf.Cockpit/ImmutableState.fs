namespace Cepaf.Cockpit

open System
open System.Security.Cryptography
open System.Text

/// =============================================================================
/// IMMUTABLE STATE - Cryptographically-Signed Append-Only State Register
/// =============================================================================
///
/// WHAT: Implements cryptographically-signed append-only blocks for Prajna state.
/// WHY: SC-PRAJNA-003 requires all state changes via Immutable Register.
///
/// ## Architecture
///
/// ```
///   State Mutation  -->  Sign (Ed25519)  -->  Hash (SHA3-256)  -->  Append
///         |                    |                    |                  |
///         |              Signature            Chain Hash           DuckDB
///         |                                        |
///         +----------------------------------------+---> Immutable History
/// ```
///
/// ## Hash Chain
///
/// Each block contains:
/// - Content (state change data)
/// - Previous block hash
/// - Timestamp
/// - Ed25519 signature
/// - Protocol version
///
/// ```
/// Block_n = {
///   content: StateChange,
///   prev_hash: SHA3-256(Block_n-1),
///   timestamp: DateTime,
///   signature: Ed25519(content || prev_hash || timestamp),
///   version: "21.1.0"
/// }
/// ```
///
/// STAMP Constraints:
///   - SC-PRAJNA-003: State changes via Immutable Register
///   - SC-REG-001: All state changes via append-only register
///   - SC-REG-002: Hash chain MUST be unbroken
///   - SC-REG-003: All blocks MUST be Ed25519 signed
///   - SC-REG-004: Blocks are immutable - no UPDATE
///
/// AOR Rules:
///   - AOR-PRAJNA-003: State mutations MUST be logged to Immutable Register
///   - AOR-REG-001: Append-Only Mandate - ALL state mutations via immutable register
///   - AOR-REG-002: Chain Verification - Verify hash chain integrity on startup
///
/// Document Control:
///   | Field | Value |
///   |-------|-------|
///   | Version | 21.1.0 |
///   | Created | 2026-01-01 |
///   | Author | Cybernetic Architect |
///   | STAMP | SC-REG-001, SC-REG-002, SC-REG-003 |
///
/// =============================================================================
module ImmutableState =

    // =========================================================================
    // TYPE DEFINITIONS
    // =========================================================================

    /// Protocol version for block format compatibility
    let private protocolVersion = "21.1.0"

    /// State change types
    type StateChangeType =
        | ConfigChange
        | MetricUpdate
        | AlertCreation
        | AlertAcknowledgment
        | CommandExecution
        | HolonStateChange
        | GoalEvaluation
        | GuardianDecision

    /// State change payload
    type StateChange = {
        ChangeType: StateChangeType
        Module: string
        Key: string
        OldValue: string option
        NewValue: string
        Metadata: Map<string, string>
    }

    /// Immutable block in the chain
    type Block = {
        Index: int64
        Content: StateChange
        ContentHash: string
        PrevHash: string
        Timestamp: DateTimeOffset
        Signature: string
        ProtocolVersion: string
    }

    /// Chain integrity result
    type IntegrityResult =
        | Valid
        | BrokenChain of int64 * string
        | MissingSignature of int64
        | InvalidSignature of int64
        | CorruptedBlock of int64 * string

    /// Register state
    type RegisterState = {
        Blocks: Block list
        LastIndex: int64
        LastHash: string
        CreatedAt: DateTimeOffset
        LastUpdated: DateTimeOffset
    }

    // =========================================================================
    // CRYPTOGRAPHIC FUNCTIONS
    // =========================================================================

    /// Compute SHA3-256 hash (using SHA256 as stand-in for F# compatibility)
    let private computeHash (data: byte[]) : string =
        use sha256 = SHA256.Create()
        let hash = sha256.ComputeHash(data)
        BitConverter.ToString(hash).Replace("-", "").ToLower()

    /// Compute hash from string data
    let private hashString (data: string) : string =
        computeHash (Encoding.UTF8.GetBytes(data))

    /// Generate Ed25519-style signature (simplified - production would use proper Ed25519)
    let private signData (data: byte[]) (privateKey: byte[]) : string =
        // In production, use proper Ed25519 signing
        use hmac = new HMACSHA512(privateKey)
        let signature = hmac.ComputeHash(data)
        BitConverter.ToString(signature).Replace("-", "").ToLower().Substring(0, 128)

    /// Verify Ed25519-style signature
    let private verifySignature (data: byte[]) (signature: string) (publicKey: byte[]) : bool =
        // In production, use proper Ed25519 verification
        let expected = signData data publicKey
        signature = expected

    /// Generate a deterministic key pair for demo (production would use secure key generation)
    let private getKeyPair () =
        let seed = Encoding.UTF8.GetBytes("indrajaal_prajna_register_key_seed_v21.1.0")
        use sha512 = SHA512.Create()
        let key = sha512.ComputeHash(seed)
        (key, key) // In production, derive public key from private key properly

    // =========================================================================
    // BLOCK OPERATIONS
    // =========================================================================

    /// Serialize state change to string for hashing
    let private serializeChange (change: StateChange) : string =
        sprintf "%A|%s|%s|%s|%s|%s"
            change.ChangeType
            change.Module
            change.Key
            (change.OldValue |> Option.defaultValue "")
            change.NewValue
            (change.Metadata |> Map.toList |> List.map (fun (k, v) -> sprintf "%s=%s" k v) |> String.concat ",")

    /// Compute content hash for a block
    let private computeContentHash (change: StateChange) (prevHash: string) (timestamp: DateTimeOffset) : string =
        let data = sprintf "%s|%s|%s" (serializeChange change) prevHash (timestamp.ToString("o"))
        hashString data

    /// Create a new block (SC-REG-003: All blocks signed)
    let private createBlock (index: int64) (change: StateChange) (prevHash: string) : Block =
        let timestamp = DateTimeOffset.UtcNow
        let contentHash = computeContentHash change prevHash timestamp

        // Sign the block content
        let (privateKey, _) = getKeyPair ()
        let dataToSign = sprintf "%d|%s|%s|%s" index contentHash prevHash (timestamp.ToString("o"))
        let signature = signData (Encoding.UTF8.GetBytes(dataToSign)) privateKey

        {
            Index = index
            Content = change
            ContentHash = contentHash
            PrevHash = prevHash
            Timestamp = timestamp
            Signature = signature
            ProtocolVersion = protocolVersion
        }

    /// Verify a single block's integrity
    let private verifyBlock (block: Block) (expectedPrevHash: string option) : IntegrityResult =
        // Check previous hash matches
        match expectedPrevHash with
        | Some expected when block.PrevHash <> expected ->
            BrokenChain (block.Index, sprintf "Expected prev_hash %s, got %s" expected block.PrevHash)
        | _ ->
            // Verify content hash
            let computedHash = computeContentHash block.Content block.PrevHash block.Timestamp
            if computedHash <> block.ContentHash then
                CorruptedBlock (block.Index, "Content hash mismatch")
            else
                // Verify signature
                let (_, publicKey) = getKeyPair ()
                let dataToSign = sprintf "%d|%s|%s|%s" block.Index block.ContentHash block.PrevHash (block.Timestamp.ToString("o"))
                if not (verifySignature (Encoding.UTF8.GetBytes(dataToSign)) block.Signature publicKey) then
                    InvalidSignature block.Index
                else
                    Valid

    // =========================================================================
    // REGISTER OPERATIONS
    // =========================================================================

    /// Create a new empty register
    let createRegister () : RegisterState =
        let genesisHash = hashString "indrajaal_genesis_block_v21.1.0"
        {
            Blocks = []
            LastIndex = -1L
            LastHash = genesisHash
            CreatedAt = DateTimeOffset.UtcNow
            LastUpdated = DateTimeOffset.UtcNow
        }

    /// Record a state change to the register (SC-REG-001: Append-only)
    let record (change: StateChange) (register: RegisterState) : RegisterState =
        let newIndex = register.LastIndex + 1L
        let block = createBlock newIndex change register.LastHash

        // Log telemetry
        printfn "[ImmutableState] Block %d recorded: %A %s.%s"
            newIndex change.ChangeType change.Module change.Key

        {
            register with
                Blocks = register.Blocks @ [block]
                LastIndex = newIndex
                LastHash = block.ContentHash
                LastUpdated = DateTimeOffset.UtcNow
        }

    /// Verify chain integrity (SC-REG-002: Hash chain MUST be unbroken)
    let verifyChain (register: RegisterState) : IntegrityResult =
        let genesisHash = hashString "indrajaal_genesis_block_v21.1.0"

        let rec verifyBlocks (blocks: Block list) (expectedPrevHash: string) : IntegrityResult =
            match blocks with
            | [] -> Valid
            | block :: rest ->
                match verifyBlock block (Some expectedPrevHash) with
                | Valid -> verifyBlocks rest block.ContentHash
                | error -> error

        verifyBlocks register.Blocks genesisHash

    /// Get block by index
    let getBlock (index: int64) (register: RegisterState) : Block option =
        register.Blocks |> List.tryFind (fun b -> b.Index = index)

    /// Get blocks by change type
    let getBlocksByType (changeType: StateChangeType) (register: RegisterState) : Block list =
        register.Blocks |> List.filter (fun b -> b.Content.ChangeType = changeType)

    /// Get blocks in time range
    let getBlocksInRange (start: DateTimeOffset) (endTime: DateTimeOffset) (register: RegisterState) : Block list =
        register.Blocks |> List.filter (fun b -> b.Timestamp >= start && b.Timestamp <= endTime)

    /// Compute Merkle root for state verification (SC-REG-012)
    let computeMerkleRoot (register: RegisterState) : string =
        match register.Blocks with
        | [] -> hashString "empty_register"
        | blocks ->
            let hashes = blocks |> List.map (fun b -> b.ContentHash)
            let rec merkle (hashes: string list) : string =
                match hashes with
                | [single] -> single
                | _ ->
                    let pairs = hashes |> List.chunkBySize 2
                    let newLevel =
                        pairs |> List.map (fun pair ->
                            match pair with
                            | [a; b] -> hashString (a + b)
                            | [a] -> hashString (a + a) // Duplicate if odd
                            | _ -> failwith "Invalid pair"
                        )
                    merkle newLevel
            merkle hashes

    // =========================================================================
    // CONVENIENCE FUNCTIONS
    // =========================================================================

    /// Record a configuration change
    let recordConfig (moduleName: string) (key: string) (oldValue: string option) (newValue: string) (register: RegisterState) : RegisterState =
        record {
            ChangeType = ConfigChange
            Module = moduleName
            Key = key
            OldValue = oldValue
            NewValue = newValue
            Metadata = Map.empty
        } register

    /// Record a Guardian decision
    let recordGuardianDecision (action: string) (decision: string) (reason: string) (register: RegisterState) : RegisterState =
        record {
            ChangeType = GuardianDecision
            Module = "Guardian"
            Key = action
            OldValue = None
            NewValue = decision
            Metadata = Map.ofList [("reason", reason)]
        } register

    /// Record a command execution
    let recordCommandExecution (command: string) (target: string) (result: string) (register: RegisterState) : RegisterState =
        record {
            ChangeType = CommandExecution
            Module = "Orchestrator"
            Key = command
            OldValue = None
            NewValue = result
            Metadata = Map.ofList [("target", target)]
        } register

    /// Get chain summary
    let summary (register: RegisterState) =
        sprintf "Register: %d blocks, last updated %s, integrity: %A"
            (List.length register.Blocks)
            (register.LastUpdated.ToString("yyyy-MM-dd HH:mm:ss"))
            (verifyChain register)
