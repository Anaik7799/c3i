namespace Indrajaal.Cortex

open System
open System.Threading
open System.Threading.Tasks
open Microsoft.Extensions.Hosting
open Microsoft.Extensions.Logging
open Cepaf.Knowledge.OpenRouter

// --- TYPE DEFINITIONS ---

type CortexState = {
    Sequence: int64
    LastPulse: DateTime
}

type CortexMsg =
    | Pulse of DateTime
    | Analyze of string
    | Stop

// --- WORKER IMPLEMENTATION ---

type CortexWorker(logger: ILogger<CortexWorker>, 
                  governor: MetabolicGovernor, 
                  vectorLogger: ILogger<VectorStore>,
                  bucketLogger: ILogger<TokenBucket>) =
    inherit BackgroundService()

    // KMS LOGGING
    let logToKms level msg =
        try
            let file = "/workspace/data/kms/fractal_execution.log" 
            let timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff")
            let entry = sprintf "[%s] [%s] [CORTEX] %s" timestamp level msg
            System.IO.File.AppendAllText(file, entry + "\n")
        with _ -> ()

    // Instantiate Organs with correct dependencies
    let hippocampus = VectorStore(vectorLogger)
    let throttle = TokenBucket(100, 10, Some bucketLogger) // Capacity 100, 10 per sec, with Logging
    let visualCortex = TopologyEngine()
    
    // BRAIN: OpenRouter Client (Option Type for Safety)
    let apiKey = Environment.GetEnvironmentVariable("OPENROUTER_API_KEY")
    let openRouter : Option<OpenRouterClient> = 
        if String.IsNullOrEmpty(apiKey) then 
            logger.LogWarning("⚠️ OpenRouter Key Missing. Using Lobotomy Mode.")
            None 
        else 
            let config = {
                ApiKey = apiKey
                BaseUrl = "https://openrouter.ai/api/v1/"
                DefaultModel = "google/gemini-2.0-flash-exp"
            }
            Some (new OpenRouterClient(config))

    let agent = MailboxProcessor.Start(fun inbox ->
        let rec loop state = async {
            // METABOLIC CHECK (Governance)
            let currentThrottle = MetabolicGovernor.ThrottleFactor
            if currentThrottle > 0.0 then
                let delay = int (currentThrottle * 1000.0)
                do! Async.Sleep(delay)

            let! msg = inbox.Receive()
            match msg with
            | Pulse ts ->
                let logMsg = sprintf "Cortex Pulse: %A | Topology: %s | SIL-6: Zero-Trust NIF Active" ts (visualCortex.Snapshot())
                logger.LogInformation(logMsg)
                logToKms "INFO" logMsg
                return! loop { state with Sequence = state.Sequence + 1L; LastPulse = ts }
            
            | Analyze prompt ->
                // ENERGY CHECK (Upgrade 4)
                if throttle.Consume(10) then
                    let logMsg = sprintf "Analyzing: %s" prompt
                    logger.LogInformation(logMsg)
                    logToKms "INFO" logMsg
                    
                    // RECALL CONTEXT (Upgrade 1)
                    let! previousMatch = hippocampus.Recall(prompt)
                    match previousMatch with
                    | Some match' -> 
                        let hitMsg = sprintf "Context Recalled: %s" match'.Content
                        logger.LogInformation(hitMsg)
                        logToKms "INFO" hitMsg
                    | None -> ()

                    // COGNITION (Upgrade 3)
                    match openRouter with
                    | Some client ->
                        try
                            let! response = client.CompleteAsync(prompt, "google/gemini-2.0-flash-exp") |> Async.AwaitTask
                            let thought = sprintf "🧠 AI Thought: %s" response
                            logger.LogInformation(thought)
                            logToKms "AI" thought
                            
                            // MEMORIZE THOUGHT
                            let! _ = hippocampus.Store(response, Map.empty)
                            ()
                        with ex ->
                            logger.LogError(ex, "AI Failure")
                            logToKms "ERROR" (sprintf "AI Failure: %s" ex.Message)
                    | None -> ()

                    // STORE INPUT (Learning)
                    let! _ = hippocampus.Store(prompt, Map.empty)
                    ()
                else
                    let warnMsg = "Throttled: Insufficient Compute Credits."
                    logger.LogWarning(warnMsg)
                    logToKms "WARN" warnMsg
                
                return! loop state

            | Stop ->
                let stopMsg = "Cortex Hibernating."
                logger.LogInformation(stopMsg)
                logToKms "INFO" stopMsg
                return ()
        }
        loop { Sequence = 0L; LastPulse = DateTime.MinValue }
    )

    override this.ExecuteAsync(stoppingToken: CancellationToken) =
        // Start Governor (fire and forget task)
        governor.StartMonitoring(stoppingToken) |> ignore
        
        task {
            while not stoppingToken.IsCancellationRequested do
                agent.Post(Pulse DateTime.UtcNow)
                do! Task.Delay(1000, stoppingToken)
        } :> Task
