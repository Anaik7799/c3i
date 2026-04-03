namespace Cepaf.Smriti

open System.Text.Json
open System.Text.Json.Serialization

// Helper to configure JSON serialization for F# types
// System.Text.Json doesn't support F# unions out of the box until .NET 9+ with specific flags 
// or custom converters. Since we are on net10.0 preview, we might have better support 
// but explicit configuration is safer for cross-platform.

module JsonHelper =
    
    let options = 
        let opt = JsonSerializerOptions()
        // Allow F# Union serialization as strings/objects if possible, 
        // or we need a specific converter library like FSharp.SystemTextJson
        // For now, let's use a simple string converter strategy if needed
        opt

    // In a real project, we'd add FSharp.SystemTextJson
    // For this prototype, we'll strip the union cases manually or define a DTO
    
    // We will define DTOs in HolonMapper to avoid union serialization issues directly.
