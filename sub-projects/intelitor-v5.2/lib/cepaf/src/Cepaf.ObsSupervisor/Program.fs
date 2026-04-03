namespace Cepaf.ObsSupervisor

open System
open System.Diagnostics
open System.Threading
open System.Threading.Tasks

module ProcessManager =
    type ServiceInfo = {
        Name: string
        Command: string
        Args: string
    }

    type ProcessState =
        | Stopped
        | Running of Process * ServiceInfo
        | Crashed of int * DateTime * ServiceInfo

    type Msg =
        | StartService of string * string * string
        | ProcessExited of string * int
        | StopAll

    let private maxRestarts = 5
    let private restartCounts = System.Collections.Concurrent.ConcurrentDictionary<string, int>()

    let createSupervisor () =
        MailboxProcessor.Start(fun inbox ->
            let rec loop (services: Map<string, ProcessState>) = async {
                let! msg = inbox.Receive()
                match msg with
                | StartService (name, cmd, args) ->
                    printfn "[Supervisor] Starting service: %s (%s %s)" name cmd args
                    let psi = ProcessStartInfo(cmd, args)
                    psi.UseShellExecute <- false
                    psi.RedirectStandardOutput <- true
                    psi.RedirectStandardError <- true

                    let info = { Name = name; Command = cmd; Args = args }

                    try
                        let p = new Process(StartInfo = psi)
                        p.EnableRaisingEvents <- true
                        p.Exited.Add(fun _ ->
                            inbox.Post(ProcessExited(name, p.ExitCode)))

                        p.OutputDataReceived.Add(fun evtArgs ->
                            if evtArgs.Data <> null then printfn "[%s] %s" name evtArgs.Data)
                        p.ErrorDataReceived.Add(fun evtArgs ->
                            if evtArgs.Data <> null then eprintfn "[%s|ERR] %s" name evtArgs.Data)

                        if p.Start() then
                            p.BeginOutputReadLine()
                            p.BeginErrorReadLine()
                            restartCounts.AddOrUpdate(name, 0, fun _ _ -> 0) |> ignore
                            printfn "[Supervisor] Service %s started (PID %d)" name p.Id
                            return! loop (services.Add(name, Running(p, info)))
                        else
                            printfn "[Supervisor] Failed to start %s" name
                            return! loop services
                    with ex ->
                        eprintfn "[Supervisor] Exception starting %s: %s" name ex.Message
                        return! loop services

                | ProcessExited (name, exitCode) ->
                    printfn "[Supervisor] Service %s exited with code %d" name exitCode
                    match services.TryFind(name) with
                    | Some (Running(_, info)) | Some (Crashed(_, _, info)) ->
                        let count = restartCounts.AddOrUpdate(name, 1, fun _ c -> c + 1)
                        if count <= maxRestarts then
                            let delay = min (count * 2000) 10000
                            printfn "[Supervisor] Scheduling restart %d/%d for %s in %dms..." count maxRestarts name delay
                            async {
                                do! Async.Sleep delay
                                inbox.Post(StartService(info.Name, info.Command, info.Args))
                            } |> Async.Start
                            return! loop (services.Add(name, Crashed(exitCode, DateTime.UtcNow, info)))
                        else
                            eprintfn "[Supervisor] Service %s exceeded max restarts (%d). Giving up." name maxRestarts
                            return! loop (services.Add(name, Crashed(exitCode, DateTime.UtcNow, info)))
                    | _ ->
                        eprintfn "[Supervisor] ProcessExited for unknown service: %s" name
                        return! loop services

                | StopAll ->
                    printfn "[Supervisor] Stopping all services..."
                    services |> Map.iter (fun name state ->
                        match state with
                        | Running (p, _) ->
                            printfn "[Supervisor] Killing %s (PID %d)" name p.Id
                            try p.Kill() with | _ -> ()
                        | _ -> ()
                    )
                    return! loop services
            }
            loop Map.empty
        )

module Program =
    [<EntryPoint>]
    let main argv =
        printfn "============================================"
        printfn "  Cepaf.ObsSupervisor v1.1.0"
        printfn "  SIL-6 Observability Process Manager"
        printfn "============================================"

        let supervisor = ProcessManager.createSupervisor()

        // Zenoh FFI placeholder
        printfn "[Zenoh] Initializing native Zenoh FFI..."

        // Signal handling
        let cts = new CancellationTokenSource()
        Console.CancelKeyPress.Add(fun e ->
            e.Cancel <- true
            printfn "[Supervisor] Received SIGINT/SIGTERM. Shutting down gracefully..."
            supervisor.Post(ProcessManager.StopAll)
            Thread.Sleep(2000)
            cts.Cancel()
        )

        // Start Observability Services
        // Prometheus: config at /app/config/prometheus/prometheus.yml
        supervisor.Post(ProcessManager.StartService(
            "Prometheus", "prometheus",
            "--config.file=/app/config/prometheus/prometheus.yml --storage.tsdb.path=/prometheus --web.listen-address=0.0.0.0:9090 --web.enable-lifecycle"))

        // Grafana: homepath from GF_PATHS_HOME env var, with NixOS auto-detection fallback
        let grafanaHome =
            match Environment.GetEnvironmentVariable("GF_PATHS_HOME") with
            | null | "" ->
                // NixOS containers install grafana via nix-env; resolve the actual Nix store path
                let nixProfilePath = "/root/.nix-profile/share/grafana"
                if IO.Directory.Exists(nixProfilePath) then nixProfilePath
                else "/usr/share/grafana"  // traditional Linux fallback
            | path -> path
        supervisor.Post(ProcessManager.StartService(
            "Grafana", "grafana-server",
            sprintf "--config=/app/config/grafana/grafana.ini --homepath=%s" grafanaHome))

        // OTEL Collector: config at /app/config/otel-collector/config.yaml
        supervisor.Post(ProcessManager.StartService(
            "OTEL", "otelcol",
            "--config=file:/app/config/otel-collector/config.yaml"))

        printfn "[Supervisor] All services queued for startup. Press Ctrl+C to exit."

        try
            Task.Delay(-1, cts.Token).Wait()
        with
        | :? AggregateException -> ()

        0
