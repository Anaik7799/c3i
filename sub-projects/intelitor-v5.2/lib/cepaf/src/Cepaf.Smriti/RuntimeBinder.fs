namespace Cepaf.Smriti

#nowarn "3261" // Suppress nullness warnings for Process/JsonElement interop

open System.Diagnostics
open System.Text.Json
open Microsoft.Data.Sqlite

// Run 4: Runtime Hardening - Binding Reality to Metadata

module RuntimeBinder =

    // Basic container info from Podman inspect
    type ContainerInfo = {
        Id: string
        Image: string
        State: string
        Labels: Map<string, string>
    }

    /// Query Podman for running containers via CLI
    /// SC-CNT-009: NixOS/Podman only. SC-CNT-012: Rootless.
    let private getPodmanContainers () : ContainerInfo list =
        try
            let psi = ProcessStartInfo("podman", "ps --format json --no-trunc")
            psi.RedirectStandardOutput <- true
            psi.RedirectStandardError <- true
            psi.UseShellExecute <- false
            psi.CreateNoWindow <- true

            use proc = Process.Start(psi)
            let output = proc.StandardOutput.ReadToEnd()
            proc.WaitForExit(5000) |> ignore

            if proc.ExitCode <> 0 || System.String.IsNullOrWhiteSpace(output) then
                []
            else
                // Parse JSON array of container objects
                use doc = JsonDocument.Parse(output)
                doc.RootElement.EnumerateArray()
                |> Seq.map (fun el ->
                    let labels =
                        match el.TryGetProperty("Labels") with
                        | true, labelsEl when labelsEl.ValueKind = JsonValueKind.Object ->
                            labelsEl.EnumerateObject()
                            |> Seq.map (fun p -> p.Name, p.Value.GetString())
                            |> Map.ofSeq
                        | _ -> Map.empty
                    {
                        Id = match el.TryGetProperty("Id") with true, v -> v.GetString() | _ -> ""
                        Image = match el.TryGetProperty("Image") with true, v -> v.GetString() | _ -> ""
                        State = match el.TryGetProperty("State") with true, v -> v.GetString() | _ -> "unknown"
                        Labels = labels
                    })
                |> Seq.toList
        with _ex ->
            printfn "[Runtime] Podman not available or query failed"
            []

    let private updateHolonRuntime (conn: SqliteConnection) (holonId: string) (status: string) =
        use cmd = conn.CreateCommand()
        cmd.CommandText <- """
            UPDATE holons 
            SET vital_signs = json_patch(vital_signs, @patch)
            WHERE fqun = @id
        """
        let patch = sprintf """{"runtime_status": "%s"}""" status
        cmd.Parameters.AddWithValue("@id", holonId) |> ignore
        cmd.Parameters.AddWithValue("@patch", patch) |> ignore
        cmd.ExecuteNonQuery() |> ignore

    let sync (connString: string) =
        let containers = getPodmanContainers()
        use conn = new SqliteConnection(connString)
        conn.Open()

        for c in containers do
            // Check for Backstage annotation on container
            // label: backstage.io/entity-id
            match c.Labels.TryFind "backstage.io/entity-id" with
            | Some entityId -> 
                printfn "[Runtime] Linking Container %s to Entity %s" c.Id entityId
                updateHolonRuntime conn entityId c.State
            | None -> ()