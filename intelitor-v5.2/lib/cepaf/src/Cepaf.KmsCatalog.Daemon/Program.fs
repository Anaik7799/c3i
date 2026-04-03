namespace Cepaf.KmsCatalog.Daemon

open System
open Microsoft.Extensions.DependencyInjection
open Microsoft.Extensions.Hosting

module Program =
    [<EntryPoint>]
    let main args =
        let host =
            Host.CreateDefaultBuilder(args)
                .ConfigureServices(fun hostContext services ->
                    services.AddHostedService<Worker>() |> ignore
                )
                .Build()

        host.Run()
        0
