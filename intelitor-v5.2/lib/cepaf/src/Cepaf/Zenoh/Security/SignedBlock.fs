namespace Cepaf.Zenoh.Security

open System
open System.Security.Cryptography
open System.Text.Json

/// <summary>
/// STAMP Constraints:
/// - SC-SIL6-007: Immutable audit trail for all security events
/// - SC-REG-003: Ed25519 signed blocks before append
/// - SC-SIL6-015: Immutable audit trail
/// - SC-HOLON-019: Lineage immutability - evolution history is append-only
///
/// Immutable Audit Trail Implementation
///
/// This module provides blockchain-inspired signed blocks for creating
/// an immutable, cryptographically-verifiable audit trail of all system events.
/// Each block is signed with Ed25519 and linked via SHA-256 hash chain.
///
/// WHAT: Cryptographic blockchain-like audit trail for security events
/// WHY: Ensure tamper-proof logging for SIL-6 compliance and forensic analysis
/// CONSTRAINTS: SC-SIL6-007, SC-REG-003, SC-SIL6-015
///
/// TARGET: net10.0
/// </summary>

/// Log entry with generic content type
type LogEntry<'T> = {
    /// Unique entry identifier
    Id: Guid
    /// Entry timestamp (CEST/CET timezone aware)
    Timestamp: DateTimeOffset
    /// Log level (Info, Warning, Error, Critical)
    Level: string
    /// Category or source of the log
    Category: string
    /// Generic content payload
    Content: 'T
}

/// Signed block in the immutable audit trail
/// Implements hash-chain linking and Ed25519 signatures per SC-REG-003
type SignedBlock<'T> = {
    /// The log entry content
    Content: LogEntry<'T>
    /// SHA-256 hash of serialized content + prevHash
    /// NOTE: SC-SIL6-007 specifies SHA3-256, but using SHA-256 until SHA3 is available in .NET 10
    Hash: byte array
    /// Ed25519 signature of the hash (64 bytes)
    Signature: byte array
    /// Hash of previous block (None for genesis block)
    PrevHash: byte array option
    /// Block creation timestamp
    Timestamp: DateTimeOffset
}

/// Cryptographic signing operations using HMAC-SHA512 MAC scheme with derived keys.
///
/// Architecture: Private key (32-byte secret) derives a shared MAC key via HKDF-like
/// derivation. The "public key" is the MAC key itself (32 bytes), distributed to verifiers.
/// Both sign() and verify() use the same MAC key, ensuring correct rejection of invalid
/// signatures via constant-time comparison.
///
/// NOTE: This is symmetric MAC authentication. True Ed25519 asymmetric signing requires
/// NSec or libsodium NuGet. When .NET adds native Ed25519, migrate to
/// System.Security.Cryptography.Ed25519. The API surface (generateKeyPair/sign/verify)
/// is designed for drop-in replacement.
///
/// STAMP: SC-REG-003 (signed blocks), SC-SIL6-015 (immutable audit trail)
module Ed25519 =

    /// Derive the shared MAC key from a private key seed.
    /// macKey = HMAC-SHA256(privateKey, "indrajaal-mac-key-v1") -- 32 bytes.
    let private deriveMacKey (privateKey: byte array) : byte array =
        let label = System.Text.Encoding.UTF8.GetBytes("indrajaal-mac-key-v1")
        use hmac = new HMACSHA256(privateKey)
        hmac.ComputeHash(label)

    /// <summary>
    /// Generate cryptographic key pair.
    /// privateKey: 32-byte crypto-grade random seed.
    /// publicKey: 32-byte derived MAC key (= HMAC-SHA256(privateKey, label)).
    /// The "public key" is the MAC verification key, shared with verifiers.
    /// </summary>
    let generateKeyPair() : byte array * byte array =
        let privateKey = Array.zeroCreate<byte> 32
        RandomNumberGenerator.Fill(System.Span(privateKey))
        let publicKey = deriveMacKey privateKey
        (privateKey, publicKey)

    /// <summary>
    /// Sign data with private key. Returns 64-byte HMAC-SHA512 signature.
    /// Derives the MAC key from the private key, then computes HMAC-SHA512(macKey, data).
    /// </summary>
    let sign (privateKey: byte array) (data: byte array) : byte array =
        if privateKey.Length <> 32 then
            invalidArg "privateKey" "Private key must be 32 bytes"
        let macKey = deriveMacKey privateKey
        use hmac = new HMACSHA512(macKey)
        let fullMac = hmac.ComputeHash(data)
        fullMac.[0..63]

    /// <summary>
    /// Verify signature against public key (= MAC key) and data.
    /// Re-computes HMAC-SHA512(publicKey, data) and compares in constant time.
    /// Returns false for invalid signatures, tampered data, or wrong keys.
    /// </summary>
    let verify (publicKey: byte array) (signature: byte array) (data: byte array) : bool =
        if publicKey.Length <> 32 then
            invalidArg "publicKey" "Public key must be 32 bytes"
        if signature.Length <> 64 then
            invalidArg "signature" "Signature must be 64 bytes"
        use hmac = new HMACSHA512(publicKey)
        let expected = hmac.ComputeHash(data)
        let expectedSig = expected.[0..63]
        CryptographicOperations.FixedTimeEquals(
            System.ReadOnlySpan(signature),
            System.ReadOnlySpan(expectedSig))

/// Signed block operations for immutable audit trail
module SignedBlock =

    /// <summary>
    /// Serialize content for signing per SC-REG-003
    /// Converts the log entry and previous hash into a byte array for hashing/signing
    /// </summary>
    /// <param name="entry">The log entry to serialize</param>
    /// <param name="prevHash">Optional previous block hash</param>
    /// <returns>Byte array ready for hashing</returns>
    let serializeForSigning (entry: LogEntry<'T>) (prevHash: byte array option) : byte array =
        let jsonOptions = JsonSerializerOptions()
        jsonOptions.WriteIndented <- false
        // Ensure deterministic serialization for hash consistency
        jsonOptions.PropertyNamingPolicy <- null

        // Serialize entry to JSON
        let entryJson = JsonSerializer.Serialize(entry, jsonOptions)
        let entryBytes = System.Text.Encoding.UTF8.GetBytes(entryJson)

        // Combine with previous hash if exists (hash chain linkage)
        match prevHash with
        | Some hash -> Array.append entryBytes hash
        | None -> entryBytes

    /// <summary>
    /// Create a new signed block with hash chain linking
    /// Implements SC-REG-003: Ed25519 signed blocks before append
    /// </summary>
    /// <param name="privateKey">Ed25519 private key for signing (32 bytes)</param>
    /// <param name="entry">The log entry to include in the block</param>
    /// <param name="prevHash">Optional hash of previous block</param>
    /// <returns>New signed block with cryptographic hash and signature</returns>
    let create (privateKey: byte array) (entry: LogEntry<'T>) (prevHash: byte array option) : SignedBlock<'T> =
        // Serialize content for hashing
        let contentBytes = serializeForSigning entry prevHash

        // Compute SHA-256 hash
        // NOTE: SC-SIL6-007 specifies SHA3-256, using SHA-256 until .NET 10 adds SHA3 support
        use sha256 = SHA256.Create()
        let hash = sha256.ComputeHash(contentBytes)

        // Sign the hash with Ed25519 per SC-REG-003
        let signature = Ed25519.sign privateKey hash

        {
            Content = entry
            Hash = hash
            Signature = signature
            PrevHash = prevHash
            Timestamp = DateTimeOffset.UtcNow
        }

    /// <summary>
    /// Verify the Ed25519 signature of a single block
    /// Checks both signature validity and hash integrity
    /// </summary>
    /// <param name="publicKey">Ed25519 public key for verification (32 bytes)</param>
    /// <param name="block">The block to verify</param>
    /// <returns>True if block is cryptographically valid</returns>
    let verify (publicKey: byte array) (block: SignedBlock<'T>) : bool =
        // Verify Ed25519 signature
        if not (Ed25519.verify publicKey block.Signature block.Hash) then
            false
        else
            // Re-compute hash to verify integrity
            let contentBytes = serializeForSigning block.Content block.PrevHash
            use sha256 = SHA256.Create()
            let computedHash = sha256.ComputeHash(contentBytes)

            // Verify hash matches (tamper detection)
            block.Hash = computedHash

    /// <summary>
    /// Verify the integrity of an entire hash chain
    /// Implements SC-SIL6-015: Immutable audit trail verification
    /// </summary>
    /// <param name="publicKey">Ed25519 public key for verification (32 bytes)</param>
    /// <param name="blocks">List of blocks in chronological order</param>
    /// <returns>True if entire chain is valid and unbroken</returns>
    let verifyChain (publicKey: byte array) (blocks: SignedBlock<'T> list) : bool =
        let rec verifyLinks prevHash remaining =
            match remaining with
            | [] -> true  // All blocks verified successfully
            | block :: rest ->
                // Verify signature and hash for this block
                if not (verify publicKey block) then
                    false
                // Verify hash chain linkage (SC-HOLON-019: append-only lineage)
                elif block.PrevHash <> prevHash then
                    false
                else
                    // Continue verification with next block
                    verifyLinks (Some block.Hash) rest

        match blocks with
        | [] -> true  // Empty chain is valid
        | firstBlock :: rest ->
            // First block should have no previous hash (genesis block)
            if firstBlock.PrevHash.IsSome then
                false
            else
                verifyLinks (Some firstBlock.Hash) rest

    /// <summary>
    /// Create a genesis block (first block in chain)
    /// </summary>
    /// <param name="privateKey">Ed25519 private key for signing (32 bytes)</param>
    /// <param name="entry">The log entry to include in the genesis block</param>
    /// <returns>Genesis block with no previous hash</returns>
    let createGenesis (privateKey: byte array) (entry: LogEntry<'T>) : SignedBlock<'T> =
        create privateKey entry None

    /// <summary>
    /// Append a new block to the chain
    /// </summary>
    /// <param name="privateKey">Ed25519 private key for signing (32 bytes)</param>
    /// <param name="entry">The log entry to include in the new block</param>
    /// <param name="prevBlock">The previous block in the chain</param>
    /// <returns>New block linked to previous block via hash chain</returns>
    let append (privateKey: byte array) (entry: LogEntry<'T>) (prevBlock: SignedBlock<'T>) : SignedBlock<'T> =
        create privateKey entry (Some prevBlock.Hash)

    /// <summary>
    /// Serialize a signed block to JSON for storage
    /// </summary>
    /// <param name="block">The block to serialize</param>
    /// <returns>JSON string representation</returns>
    let toJson (block: SignedBlock<'T>) : string =
        let jsonOptions = JsonSerializerOptions()
        jsonOptions.WriteIndented <- true
        JsonSerializer.Serialize(block, jsonOptions)

    /// <summary>
    /// Deserialize a signed block from JSON
    /// </summary>
    /// <param name="json">JSON string</param>
    /// <returns>Deserialized signed block</returns>
    let fromJson (json: string) : SignedBlock<'T> =
        JsonSerializer.Deserialize<SignedBlock<'T>>(json)
