// =============================================================================
// ZenohSerialization.fs - Type-Safe Serialization for Zenoh Messages
// =============================================================================
// STAMP: SC-MSG-002, SC-SER-001, SC-SER-002
// AOR: AOR-ZENOH-004
// Criticality: Level 1 (CRITICAL) - Data Integrity
// =============================================================================
// Provides JSON serialization with:
// - Snake_case naming for Elixir/Phoenix compatibility
// - F# discriminated union support
// - Option type handling
// - Error-safe serialization with Result types
// =============================================================================

namespace Cepaf.Zenoh.Core

open System
open System.Text
open System.Text.Json
open System.Text.Json.Serialization

/// Snake_case naming policy for Elixir/Phoenix compatibility
type SnakeCaseNamingPolicy() =
    inherit JsonNamingPolicy()

    override _.ConvertName(name: string) =
        if String.IsNullOrEmpty(name) then name
        else
            let sb = StringBuilder()
            for i = 0 to name.Length - 1 do
                let c = name.[i]
                if i > 0 && Char.IsUpper(c) then
                    sb.Append('_') |> ignore
                    sb.Append(Char.ToLowerInvariant(c)) |> ignore
                else
                    sb.Append(Char.ToLowerInvariant(c)) |> ignore
            sb.ToString()

/// JSON serialization options and utilities
module ZenohJson =

    /// Default serialization options for Zenoh messages
    /// - Snake_case naming for Elixir compatibility
    /// - Null handling for Option types
    /// - Compact output (no indentation)
    let options =
        let opts = JsonSerializerOptions()
        opts.PropertyNamingPolicy <- SnakeCaseNamingPolicy()
        opts.DefaultIgnoreCondition <- JsonIgnoreCondition.WhenWritingNull
        opts.WriteIndented <- false
        opts.PropertyNameCaseInsensitive <- true

        // Add F# specific converters
        opts.Converters.Add(JsonFSharpConverter(
            JsonUnionEncoding.AdjacentTag |||
            JsonUnionEncoding.NamedFields |||
            JsonUnionEncoding.UnwrapRecordCases,
            unionTagName = "type",
            unionFieldsName = "data"
        ))

        opts

    /// Pretty-printed options for debugging
    let prettyOptions =
        let opts = JsonSerializerOptions(options)
        opts.WriteIndented <- true
        opts

    /// Serialize to JSON string
    let serializeString<'T> (value: 'T) : string =
        JsonSerializer.Serialize(value, options)

    /// Serialize to JSON string (pretty-printed)
    let serializePretty<'T> (value: 'T) : string =
        JsonSerializer.Serialize(value, prettyOptions)

    /// Deserialize from JSON string
    let deserializeString<'T> (json: string) : 'T =
        JsonSerializer.Deserialize<'T>(json, options)

/// Type-safe serialization functions with error handling
module ZenohSerializer =

    /// Serialize value to UTF-8 bytes (SC-SER-001)
    let serialize<'T> (value: 'T) : ZenohResult<byte[]> =
        try
            let bytes = JsonSerializer.SerializeToUtf8Bytes(value, ZenohJson.options)
            Ok bytes
        with ex ->
            Error (ZenohError.SerializationError(typeof<'T>.Name, ex.Message))

    /// Deserialize from UTF-8 bytes (SC-SER-002)
    let deserialize<'T> (bytes: byte[]) : ZenohResult<'T> =
        try
            let span = ReadOnlySpan(bytes)
            let value = JsonSerializer.Deserialize<'T>(span, ZenohJson.options)
            Ok value
        with ex ->
            Error (ZenohError.DeserializationError(typeof<'T>.Name, ex.Message))

    /// Serialize to string (for debugging/logging)
    let serializeToString<'T> (value: 'T) : ZenohResult<string> =
        try
            Ok (ZenohJson.serializeString value)
        with ex ->
            Error (ZenohError.SerializationError(typeof<'T>.Name, ex.Message))

    /// Deserialize from string
    let deserializeFromString<'T> (json: string) : ZenohResult<'T> =
        try
            Ok (ZenohJson.deserializeString<'T> json)
        with ex ->
            Error (ZenohError.DeserializationError(typeof<'T>.Name, ex.Message))

    /// Try to deserialize, returning None on failure
    let tryDeserialize<'T> (bytes: byte[]) : 'T option =
        match deserialize<'T> bytes with
        | Ok value -> Some value
        | Error _ -> None

    /// Serialize with size validation
    let serializeWithLimit<'T> (maxBytes: int) (value: 'T) : ZenohResult<byte[]> =
        match serialize value with
        | Ok bytes when bytes.Length <= maxBytes -> Ok bytes
        | Ok bytes ->
            Error (ZenohError.SerializationError(
                typeof<'T>.Name,
                sprintf "Serialized size %d exceeds limit %d" bytes.Length maxBytes))
        | Error e -> Error e

/// Binary encoding utilities for efficient payload handling
module BinaryEncoding =

    /// Encode string to UTF-8 bytes
    let encodeString (s: string) : byte[] =
        Encoding.UTF8.GetBytes(s)

    /// Decode UTF-8 bytes to string
    let decodeString (bytes: byte[]) : string =
        Encoding.UTF8.GetString(bytes)

    /// Encode int64 to big-endian bytes
    let encodeInt64 (value: int64) : byte[] =
        let bytes = BitConverter.GetBytes(value)
        if BitConverter.IsLittleEndian then
            Array.Reverse(bytes)
        bytes

    /// Decode big-endian bytes to int64
    let decodeInt64 (bytes: byte[]) : int64 =
        let arr = Array.copy bytes
        if BitConverter.IsLittleEndian then
            Array.Reverse(arr)
        BitConverter.ToInt64(arr, 0)

    /// Encode Guid to bytes
    let encodeGuid (guid: Guid) : byte[] =
        guid.ToByteArray()

    /// Decode bytes to Guid
    let decodeGuid (bytes: byte[]) : Guid =
        Guid(bytes)

    /// Calculate simple checksum
    let checksum (bytes: byte[]) : uint32 =
        let mutable sum = 0u
        for b in bytes do
            sum <- sum + uint32 b
        sum

/// Message framing for length-prefixed protocols
module MessageFraming =

    /// Frame a message with length prefix (4-byte big-endian)
    let frame (payload: byte[]) : byte[] =
        let length = BitConverter.GetBytes(uint32 payload.Length)
        if BitConverter.IsLittleEndian then
            Array.Reverse(length)
        Array.concat [length; payload]

    /// Unframe a length-prefixed message
    let unframe (data: byte[]) : (byte[] * byte[]) option =
        if data.Length < 4 then None
        else
            let lengthBytes = data.[0..3]
            if BitConverter.IsLittleEndian then
                Array.Reverse(lengthBytes)
            let length = int (BitConverter.ToUInt32(lengthBytes, 0))

            if data.Length < 4 + length then None
            else
                let payload = data.[4..3+length]
                let remaining = data.[4+length..]
                Some (payload, remaining)

/// Schema versioning support for message evolution
module SchemaVersion =

    /// Current schema version
    let [<Literal>] CurrentVersion = "1.0.0"

    /// Supported versions for backwards compatibility
    let supportedVersions = ["1.0.0"]

    /// Check if a version is supported
    let isSupported (version: string) =
        List.contains version supportedVersions

    /// Compare versions (semantic versioning)
    let compare (v1: string) (v2: string) : int =
        let parse (v: string) =
            v.Split('.')
            |> Array.map (fun s -> Int32.TryParse(s) |> function | true, n -> n | _ -> 0)

        let parts1 = parse v1
        let parts2 = parse v2

        let rec loop i =
            if i >= 3 then 0
            else
                let p1 = if i < parts1.Length then parts1.[i] else 0
                let p2 = if i < parts2.Length then parts2.[i] else 0
                if p1 < p2 then -1
                elif p1 > p2 then 1
                else loop (i + 1)

        loop 0

    /// Check if v1 is compatible with v2 (same major version)
    let isCompatible (v1: string) (v2: string) : bool =
        let major1 = v1.Split('.').[0]
        let major2 = v2.Split('.').[0]
        major1 = major2
