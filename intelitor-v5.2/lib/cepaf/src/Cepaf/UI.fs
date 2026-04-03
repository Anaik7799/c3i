namespace Cepaf.Phases

open System
open System.Threading
open Serilog
open PuppeteerSharp
open Cepaf

module UI =
    let run (config: CepaConfig) (cts: CancellationToken) =
        async {
            Log.Information("--- Phase 5: UI Verification (Puppeteer) ---")
            try
                use browserFetcher = new BrowserFetcher()
                Log.Information("Checking for browser...")
                let! _ = browserFetcher.DownloadAsync() |> Async.AwaitTask
                
                let options = LaunchOptions(Headless = true)
                Log.Information("Launching browser...")
                let! browser = Puppeteer.LaunchAsync(options) |> Async.AwaitTask
                
                try
                    let! page = browser.NewPageAsync() |> Async.AwaitTask
                    Log.Information("Navigating to http://localhost:4000 ...")
                    let! _ = page.GotoAsync("http://localhost:4000") |> Async.AwaitTask
                    
                    let! title = page.GetTitleAsync() |> Async.AwaitTask
                    Log.Information("Page title: {Title}", title)
                    
                    if title.Contains("Indrajaal") then
                        Log.Information("UI Verification Passed.")
                        return Ok ()
                    else
                        Log.Warning("Page title does not match. Found: {Title}", title)
                        return Error (ValidationFailed("UI", "Title mismatch"))
                finally
                    let! _ = browser.CloseAsync() |> Async.AwaitTask
                    ()
            with ex ->
                Log.Error(ex, "Puppeteer verification failed.")
                return Error (InfrastructureError("Puppeteer", ex.Message))
        }
