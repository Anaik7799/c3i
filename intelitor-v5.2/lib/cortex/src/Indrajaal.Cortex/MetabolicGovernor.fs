namespace Indrajaal.Cortex

open System
open System.IO
open System.Threading
open System.Threading.Tasks
open Microsoft.Extensions.Logging

type MetabolicState = {
    CurrentLoad: float
    ThrottleFactor: float // 0.0 (No throttle) to 1.0 (Full stop)
    IsCritical: bool
}

type MetabolicGovernor(logger: ILogger<MetabolicGovernor>) =
    
    // Volatile state for lock-free read access
    static let mutable currentThrottle = 0.0
    static let mutable isCritical = false

    // Linux-specific CPU read
    let getLinuxCpuUsage () =
        try
            if File.Exists("/proc/stat") then
                let lines = File.ReadAllLines("/proc/stat")
                let parts = lines.[0].Split(' ', StringSplitOptions.RemoveEmptyEntries)
                // user, nice, system, idle
                let user = float parts.[1]
                let nice = float parts.[2]
                let system = float parts.[3]
                let idle = float parts.[4]
                let total = user + nice + system + idle
                (total, idle)
            else
                (0.0, 0.0)
        with _ -> (0.0, 0.0)

    // Public API
    static member ThrottleFactor = currentThrottle
    static member IsCritical = isCritical

    member this.StartMonitoring(cancellationToken: CancellationToken) =
        // Start the async loop as a Task
        Async.StartAsTask(this.MonitorLoop(cancellationToken))

    member private this.MonitorLoop(ct: CancellationToken) = async {
        logger.LogInformation("🛡️ Metabolic Governor: INITIALIZED (Target < 75% Load)")
        
        let mutable prevTotal = 0.0
        let mutable prevIdle = 0.0
        
        // Initial reading
        let (t1, i1) = getLinuxCpuUsage()
        prevTotal <- t1
        prevIdle <- i1

        while not ct.IsCancellationRequested do
            do! Async.Sleep(1000) // 1s sampling rate

            let (currTotal, currIdle) = getLinuxCpuUsage()
            
            let deltaTotal = currTotal - prevTotal
            let deltaIdle = currIdle - prevIdle
            
            if deltaTotal > 0.0 then
                let cpuUsage = 1.0 - (deltaIdle / deltaTotal)
                let usagePercent = cpuUsage * 100.0

                // GOVERNOR LOGIC
                if usagePercent > 75.0 then
                    // Overload: Increase throttling
                    isCritical <- true
                    currentThrottle <- min 1.0 (currentThrottle + 0.1)
                    logger.LogWarning("🔥 METABOLIC ALERT: System Load {Load:F1}% > 75%. Throttling to {Throttle:F1}", usagePercent, currentThrottle)
                
                elif usagePercent < 60.0 then
                    // Recovery: Decrease throttling
                    isCritical <- false
                    currentThrottle <- max 0.0 (currentThrottle - 0.05)
                    if currentThrottle > 0.0 then
                        logger.LogInformation("❄️ Cooling Down: Load {Load:F1}%. Reducing Throttle to {Throttle:F1}", usagePercent, currentThrottle)
                
                else
                    // Hysteresis Zone (60-75%): Hold steady
                    ()

            prevTotal <- currTotal
            prevIdle <- currIdle
    }