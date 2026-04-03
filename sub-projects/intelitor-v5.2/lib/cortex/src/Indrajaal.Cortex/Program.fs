namespace Indrajaal.Cortex

open System
open System.Collections.Generic
open System.Linq
open System.Threading.Tasks
open Microsoft.Extensions.DependencyInjection
open Microsoft.Extensions.Hosting

module Program =

    [<EntryPoint>]
    let main args =
        let builder = Host.CreateApplicationBuilder(args)
        
        // Register Governor
        builder.Services.AddSingleton<MetabolicGovernor>() |> ignore
        
        builder.Services.AddHostedService<CortexWorker>() |> ignore

        builder.Build().Run()

        0 // exit code