namespace Cepaf.Bridge

open System
open System.Text.Json
open Cepaf.Podman.Client
open Cepaf.Bridge.Protocol
open Cepaf.Bridge.Commands

/// Main server logic for JSON-RPC over stdio
module Server =

    /// Dispatch a method call to the appropriate handler
    let dispatch (client: PodmanClient) (request: JsonRpc.Request) : Async<string> =
        let id = request.Id
        let params' = request.Params

        match request.Method with
        // System commands
        | "system.ping" -> System.handlePing client id
        | "system.info" -> System.handleInfo client id
        | "system.version" -> System.handleVersion client id

        // Container commands
        | "container.list" -> Container.handleList client id params'
        | "container.inspect" -> Container.handleInspect client id params'
        | "container.create" -> Container.handleCreate client id params'
        | "container.start" -> Container.handleStart client id params'
        | "container.stop" -> Container.handleStop client id params'
        | "container.remove" -> Container.handleRemove client id params'
        | "container.logs" -> Container.handleLogs client id params'
        | "container.exists" -> Container.handleExists client id params'
        | "container.findByName" -> Container.handleFindByName client id params'

        // Health commands
        | "health.check" -> Health.handleCheck client id params'
        | "health.summary" -> Health.handleSummary client id params'
        | "health.liveness" -> Health.handleLiveness client id params'
        | "health.readiness" -> Health.handleReadiness client id params'
        | "health.allHealthy" -> Health.handleAllHealthy client id params'
        | "health.unhealthy" -> Health.handleUnhealthy client id params'

        // Safety commands
        | "safety.validateSpec" -> Safety.handleValidateSpec client id params'
        | "safety.validateImage" -> Safety.handleValidateImage client id params'
        | "safety.validateRootless" -> Safety.handleValidateRootless client id params'
        | "safety.validateContainerHealth" -> Safety.handleValidateContainerHealth client id params'
        | "safety.validateAll" -> Safety.handleValidateAll client id params'

        // Emergency commands
        | "emergency.stop" -> Safety.handleEmergencyStop client id params'
        | "emergency.remove" -> Safety.handleEmergencyRemove client id params'
        | "emergency.stopAll" -> Safety.handleEmergencyStopAll client id params'

        // Guardian commands (SC-NEURO-001: AI output gatekeeper)
        | "guardian.status" -> Safety.handleGuardianStatus client id params'
        | "guardian.validateProposal" -> Safety.handleGuardianValidate client id params'

        // Shadow Mode commands (SC-SHADOW-001)
        | "shadow.status" -> Safety.handleShadowStatus client id params'

        // Training GYM commands (RL data capture)
        | "gym.stats" -> Safety.handleTrainingGymStats client id params'
        | "gym.recordEpisode" -> Safety.handleRecordEpisode client id params'

        // GDE Pipeline commands (Goal-Directed Evolution)
        | "gde.status" -> Safety.handleGDEStatus client id params'
        | "gde.executeCycle" -> Safety.handleGDEExecuteCycle client id params'
        | "gde.validateProposal" -> Safety.handleGDEValidateProposal client id params'

        // OpenRouter telemetry commands
        | "openrouter.usage" -> Safety.handleOpenRouterUsage client id params'
        | "openrouter.recordCall" -> Safety.handleOpenRouterRecordCall client id params'

        // Fractal Logging commands (5-Level Controllable Logging)
        | "fractal.status" -> Safety.handleFractalStatus client id params'
        | "fractal.shouldLog" -> Safety.handleFractalShouldLog client id params'
        | "fractal.focus" -> Safety.handleFractalFocus client id params'
        | "fractal.removeBoost" -> Safety.handleFractalRemoveBoost client id params'
        | "fractal.getActiveBoosts" -> Safety.handleFractalGetActiveBoosts client id params'
        | "fractal.setPolicy" -> Safety.handleFractalSetPolicy client id params'
        | "fractal.activateShedding" -> Safety.handleFractalActivateShedding client id params'
        | "fractal.deactivateShedding" -> Safety.handleFractalDeactivateShedding client id params'
        | "fractal.emit" -> Safety.handleFractalEmit client id params'

        // Unknown method
        | method' ->
            async { return JsonRpc.methodNotFoundResponse id method' }

    /// Process a single line of input
    let processLine (client: PodmanClient) (line: string) : Async<string> = async {
        if String.IsNullOrWhiteSpace(line) then
            return ""
        else
            match JsonRpc.parseRequest line with
            | Error e ->
                return JsonRpc.parseErrorResponse e
            | Ok request ->
                try
                    return! dispatch client request
                with ex ->
                    return JsonRpc.internalErrorResponse request.Id ex.Message
    }

    /// Run the server loop reading from stdin, writing to stdout
    let run (client: PodmanClient) : Async<unit> = async {
        // Write ready signal
        Console.Error.WriteLine("[cepaf-bridge] Server started, waiting for commands...")

        let mutable running = true
        while running do
            let line = Console.ReadLine()
            if isNull line then
                // EOF - exit gracefully
                running <- false
            else
                let! response = processLine client line
                if not (String.IsNullOrEmpty(response)) then
                    Console.WriteLine(response)
                    Console.Out.Flush()
    }

    /// Create client and run server
    let start () : int =
        match HttpClient.createDefault() with
        | Error e ->
            Console.Error.WriteLine(sprintf "[cepaf-bridge] Failed to create client: %s" (Cepaf.Podman.Domain.PodmanError.toMessage e))
            1
        | Ok client ->
            try
                run client |> Async.RunSynchronously
                HttpClient.dispose client
                0
            with ex ->
                Console.Error.WriteLine(sprintf "[cepaf-bridge] Fatal error: %s" ex.Message)
                HttpClient.dispose client
                1
