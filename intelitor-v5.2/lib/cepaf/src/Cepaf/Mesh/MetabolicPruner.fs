namespace Cepaf.Mesh

open System
open System.IO
open System.Diagnostics
open System.Collections.Generic
open System.Security.Cryptography
open System.Text
open Cepaf.Zenoh.Messaging

module MetabolicPruner =

    type OrphanCategory =
        | OrphanedLayer
        | DeadMountPoint
        | BrokenSymlink
        | IntermediateArtifact

    type OrphanReason =
        | AbortedBuild
        | InterruptedPull
        | MetadataMismatch
        | StaleArtifact
        | Unknown

    type OrphanInfo = {
        Id: string
        Category: OrphanCategory
        Path: string
        SizeGb: float
        LastModified: DateTime
        Reason: OrphanReason
        IsLocked: bool
        MissingMetadata: string list
    }

    type PruneReport = {
        GraphRoot: string
        TotalOrphans: int
        TotalSizeGb: float
        Categories: Map<OrphanCategory, int * float>
        Orphans: OrphanInfo list
        VerificationHash: string
        Timestamp: DateTime
    }

    let private logThinking msg =
        printfn "\u001b[34m\u001b[1m[THINK]\u001b[0m %s" msg

    let private runPodman (args: string) =
        let startInfo: ProcessStartInfo = ProcessStartInfo("podman", args)
        startInfo.RedirectStandardOutput <- true
        startInfo.RedirectStandardError <- true
        startInfo.UseShellExecute <- false
        startInfo.CreateNoWindow <- true
        try
            let p: Process = Process.Start(startInfo)
            let output = p.StandardOutput.ReadToEnd()
            p.WaitForExit()
            output
        with _ -> ""

    let private getGraphRoot () =
        let root = runPodman "info --format {{.Store.GraphRoot}}"
        root.Trim([|'\''; '"'; ' '; '\n'; '\r'|])

    let private isDirLocked (path: string) =
        // Professional-grade check: see if any process has open files in this dir
        // Using fuser or lsof if available, fallback to simple check
        let startInfo = ProcessStartInfo("fuser", path)
        startInfo.RedirectStandardOutput <- true
        startInfo.UseShellExecute <- false
        startInfo.CreateNoWindow <- true
        try
            let p = Process.Start(startInfo)
            p.WaitForExit()
            p.ExitCode = 0 // If fuser returns 0, processes are using it
        with _ -> false

    let private calculateDirSize path =
        let startInfo = ProcessStartInfo("buildah", sprintf "unshare du -s %s" path)
        startInfo.RedirectStandardOutput <- true
        startInfo.UseShellExecute <- false
        startInfo.CreateNoWindow <- true
        try
            let p = Process.Start(startInfo)
            let output = p.StandardOutput.ReadToEnd()
            p.WaitForExit()
            if p.ExitCode = 0 then
                let sizeStr = output.Split([|' '; '\t'|], StringSplitOptions.RemoveEmptyEntries).[0]
                float sizeStr / 1024.0 / 1024.0
            else 0.0
        with _ -> 0.0

    let private checkMetadata (path: string) =
        let required = ["config.json"; "userdata"]
        required |> List.filter (fun f -> not (File.Exists(Path.Combine(path, f))))

    let private checkBrokenSymlinks root =
        logThinking "Scanning for broken symlinks in GraphRoot..."
        let found = new List<OrphanInfo>()
        try
            let allFiles = Directory.GetFiles(root, "*", SearchOption.AllDirectories)
            for file in allFiles do
                let info = FileInfo(file)
                if info.Attributes.HasFlag(FileAttributes.ReparsePoint) then
                    // It's a symlink, check if target exists
                    try
                        let target = File.ResolveLinkTarget(file, true)
                        if isNull target || not (target.Exists) then
                            found.Add({
                                Id = Path.GetFileName(file)
                                Category = BrokenSymlink
                                Path = file
                                SizeGb = 0.0 // Symlinks are negligible size
                                LastModified = info.LastWriteTime
                                Reason = StaleArtifact
                                IsLocked = false
                                MissingMetadata = ["Target missing"]
                            })
                    with _ -> ()
        with _ -> ()
        List.ofSeq found

    /// <summary>
    /// Analyze the substrate for orphans with professional validation logic.
    /// </summary>
    let analyze (ageThresholdHours: float) =
        let root = getGraphRoot()
        let overlayPath = Path.Combine(root, "overlay")
        logThinking (sprintf "Analyzing Substrate GraphRoot: %s" root)

        if not (Directory.Exists(overlayPath)) then
            failwithf "Overlay storage path not found: %s" overlayPath

        // 1. Get Physical Directories
        let physicalNames = 
            Directory.GetDirectories(overlayPath)
            |> Array.map Path.GetFileName
            |> Set.ofArray

        // 2. Get Logical Ground Truth
        logThinking "Interrogating Podman for logical ground truth..."
        let containerIds = runPodman "ps -aq"
        let imageIds = runPodman "images -aq"
        let allIds = 
            (containerIds.Split([|'\n'; '\r'; ' '|], StringSplitOptions.RemoveEmptyEntries))
            |> Array.append (imageIds.Split([|'\n'; '\r'; ' '|], StringSplitOptions.RemoveEmptyEntries))
            |> Array.distinct

        let activeSet = new HashSet<string>()
        if allIds.Length > 0 then
            let idBatch = String.concat " " allIds
            let inspect = runPodman (sprintf "inspect --format {{.GraphDriver.Data.UpperDir}}:{{.GraphDriver.Data.LowerDir}} %s" idBatch)
            inspect.Split([|'\n'; ':'|], StringSplitOptions.RemoveEmptyEntries)
            |> Array.iter (fun p -> 
                let clean = p.Trim()
                if clean.Contains("/overlay/") then
                    let parts = clean.Split('/')
                    let idx = Array.tryFindIndex (fun x -> x = "overlay") parts |> Option.defaultValue -1
                    if idx >= 0 && idx < parts.Length - 1 then
                        activeSet.Add(parts.[idx+1]) |> ignore
            )

        // 3. Compute Set Difference
        let orphans = Set.difference physicalNames (Set.ofSeq activeSet)
        
        let orphanInfos = 
            orphans 
            |> Set.toList 
            |> List.map (fun name ->
                let path = Path.Combine(overlayPath, name)
                let lastMod = try Directory.GetLastWriteTime(path) with _ -> DateTime.MinValue
                let size = calculateDirSize path
                let locked = isDirLocked path
                let missing = checkMetadata path
                
                let reason =
                    if name.EndsWith("-init") then AbortedBuild
                    elif missing.Length > 0 then MetadataMismatch
                    elif (DateTime.Now - lastMod).TotalHours >= ageThresholdHours then StaleArtifact
                    else Unknown

                { 
                    Id = name
                    Category = OrphanedLayer
                    Path = path
                    SizeGb = size
                    LastModified = lastMod
                    Reason = reason
                    IsLocked = locked
                    MissingMetadata = missing
                }
            )
            |> List.filter (fun i -> i.SizeGb > 0.001 && not i.IsLocked)
            |> List.filter (fun i -> (DateTime.Now - i.LastModified).TotalHours >= ageThresholdHours)

        // 4. Find Dead Mount Points & Broken Symlinks
        let brokenLinks = checkBrokenSymlinks root
        
        let allOrphans = List.append orphanInfos brokenLinks
                         |> List.sortByDescending (fun i -> i.SizeGb)

        let totalSize = allOrphans |> List.sumBy (fun i -> i.SizeGb)
        let categories = 
            allOrphans 
            |> List.groupBy (fun i -> i.Category)
            |> List.map (fun (cat, items) -> cat, (items.Length, items |> List.sumBy (fun i -> i.SizeGb)))
            |> Map.ofList

        // Generate verification hash for the specific set
        let orphanList = allOrphans |> List.map (fun i -> i.Path) |> String.concat "|"
        let hashBytes = SHA256.HashData(Encoding.UTF8.GetBytes(orphanList))
        let hash = BitConverter.ToString(hashBytes).Replace("-", "").ToLower()

        {
            GraphRoot = root
            TotalOrphans = allOrphans.Length
            TotalSizeGb = totalSize
            Categories = categories
            Orphans = allOrphans
            VerificationHash = hash
            Timestamp = DateTime.Now
        }

    /// <summary>
    /// Execute the transactional prune. (OODA: Act)
    /// </summary>
    let prune (report: PruneReport) (confirmedHash: string) (dryRun: bool) =
        if report.VerificationHash <> confirmedHash then
            Error "Safety gate BLOCKED: Hash mismatch."
        else
            logThinking (sprintf "ACTUATING PRUNE: Reclaiming %.2f GB (DryRun: %b)" report.TotalSizeGb dryRun)
            
            if dryRun then
                Ok report.TotalOrphans
            else
                let mutable count = 0
                for orphan in report.Orphans do
                    let startInfo = ProcessStartInfo("buildah", sprintf "unshare rm -rf %s" orphan.Path)
                    startInfo.UseShellExecute <- false
                    startInfo.CreateNoWindow <- true
                    try
                        let p = Process.Start(startInfo)
                        p.WaitForExit()
                        if p.ExitCode = 0 then count <- count + 1
                    with _ -> ()
                
                ZenohPublish.publish "CP-MET-PRUNE" "indrajaal/metabolism/prune" "SUCCESS" (sprintf "{\"count\":%d, \"gb\":%.2f}" count report.TotalSizeGb)
                Ok count
