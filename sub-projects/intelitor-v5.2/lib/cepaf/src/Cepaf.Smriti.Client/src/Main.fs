/// Z-KMS Client Main - Application Entry Point
///
/// Initializes and starts the Elmish application.
module Cepaf.Smriti.Client.Main

open Elmish
open Elmish.React
open Cepaf.Smriti.Client.App

/// Program entry point
[<EntryPoint>]
let main _ =
    Program.mkProgram init update view
    |> Program.withReactSynchronous "root"
#if DEBUG
    |> Program.withConsoleTrace
#endif
    |> Program.run

    0
