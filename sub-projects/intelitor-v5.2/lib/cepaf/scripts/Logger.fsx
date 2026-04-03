// Logger.fsx - Quadplex Logging Module
// Version: 1.0.0
// Context: Shared Sensory Fabric

namespace Cepaf.Scripts

open System
open System.IO

module Logger = 
    let logPath = "logs/fractal_execution.log"
    
    let private ensureLogDir () = 
        let dir = Path.GetDirectoryName(logPath)
        if not (Directory.Exists(dir)) then Directory.CreateDirectory(dir) |> ignore

    let log level context message = 
        ensureLogDir()
        let timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff")
        let entry = sprintf "[%s] [%s] [%s] %s" timestamp level context message
        
        // File Output (Persistent Memory)
        try File.AppendAllText(logPath, entry + "\n") with _ -> ()

        // Console Output (Immediate Awareness)
        let color = 
            match level with
            | "INFO" -> ConsoleColor.Cyan
            | "SUCCESS" -> ConsoleColor.Green
            | "WARN" -> ConsoleColor.Yellow
            | "FAIL" -> ConsoleColor.Red
            | _ -> ConsoleColor.White
        
        Console.ForegroundColor <- color
        printfn "%s" entry
        Console.ResetColor()

    let info ctx msg = log "INFO" ctx msg
    let success ctx msg = log "SUCCESS" ctx msg
    let warn ctx msg = log "WARN" ctx msg
    let fail ctx msg = log "FAIL" ctx msg
