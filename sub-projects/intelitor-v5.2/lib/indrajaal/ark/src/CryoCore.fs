namespace Indrajaal.Ark

open System
open System.IO
open System.IO.Compression
open System.Formats.Tar // Requires .NET 7+
open Indrajaal.Ark.Domain

module CryoCore =

    // Safety: Exclude volatile/dangerous directories
    let private exclusionList =
        [ ".git"; "_build"; "deps"; ".elixir_ls"; "priv/static"; ".env"; "node_modules" ]
        |> Set.ofList

    let private isSafe (path: string) =
        let normalized = path.Replace("\\", "/")
        exclusionList |> Set.exists (fun ex -> normalized.Contains(ex)) |> not

    /// Compresses a directory into a memory stream (GZipped Tarball)
    let preserve (sourceDir: string) : Result<byte[]> =
        try
            use memoryStream = new MemoryStream()
            
            // Scope for GZip to ensure flush
            do
                use gzip = new GZipStream(memoryStream, CompressionLevel.Optimal, true)
                // Scope for TarWriter
                do
                    use tar = new TarWriter(gzip)
                    
                    let files = 
                        Directory.GetFiles(sourceDir, "*.*", SearchOption.AllDirectories)
                        |> Array.filter isSafe

                    for file in files do
                        let relPath = Path.GetRelativePath(sourceDir, file)
                        try 
                            tar.WriteEntry(file, relPath)
                        with e -> 
                            Console.ForegroundColor <- ConsoleColor.Yellow
                            printfn $"[WARN] Skipped locked file: {relPath}"
                            Console.ResetColor()
            
            Success (memoryStream.ToArray())
        with e ->
            Failure $"Preservation failed: {e.Message}"

    /// Decompresses bytes back to a directory
    let rehydrate (data: byte[]) (targetDir: string) : Result<unit> =
        try
            if Directory.Exists(targetDir) then Directory.Delete(targetDir, true)
            Directory.CreateDirectory(targetDir) |> ignore

            use memoryStream = new MemoryStream(data)
            use gzip = new GZipStream(memoryStream, CompressionMode.Decompress)
            use tar = new TarReader(gzip)
            
            let mutable entry = tar.GetNextEntry()
            while entry <> null do
                entry.ExtractToFile(Path.Combine(targetDir, entry.Name), true)
                entry <- tar.GetNextEntry()
            
            Success ()
        with e ->
            Failure $"Rehydration failed: {e.Message}"
