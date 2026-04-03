module Cepaf.Knowledge.FractalLogger

open System
open System.Diagnostics
open System.Threading

type LogLevel = Info | Warn | Error | Perf

type LogEntry = {
    Timestamp: DateTime
    Level: LogLevel
    ThreadId: int
    Context: string
    Message: string
    Duration: TimeSpan option
}

type FractalLogger() =
    let lockObj = obj()
    
    let color level = 
        match level with
        | Info -> ConsoleColor.Cyan
        | Warn -> ConsoleColor.Yellow
        | Error -> ConsoleColor.Red
        | Perf -> ConsoleColor.Green

    member this.Log(level: LogLevel, context: string, message: string, ?duration: TimeSpan) =
        lock lockObj (fun () ->
            Console.ForegroundColor <- color level
            let timeStr = DateTime.Now.ToString("HH:mm:ss.fff")
            let durStr = match duration with Some d -> sprintf " [%0.2fms]" d.TotalMilliseconds | None -> ""
            printfn "[%s] T%02d | %-20s | %s%s" timeStr Thread.CurrentThread.ManagedThreadId context message durStr
            Console.ResetColor()
        )

    member this.MeasureAsync(context: string, operationName: string, action: unit -> Async<'T>) =
        async {
            this.Log(Info, context, sprintf "START: %s" operationName)
            let sw = Stopwatch.StartNew()
            try
                let! result = action()
                sw.Stop()
                this.Log(Perf, context, sprintf "DONE: %s" operationName, sw.Elapsed)
                return result
            with ex ->
                sw.Stop()
                this.Log(Error, context, sprintf "FAIL: %s - %s" operationName ex.Message, sw.Elapsed)
                return raise ex
        }
