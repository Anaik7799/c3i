namespace Cepaf.Bridge

/// Entry point for the Cepaf Bridge server
module Program =

    [<EntryPoint>]
    let main args =
        // Handle --help
        if args |> Array.contains "--help" || args |> Array.contains "-h" then
            printfn """
Cepaf Bridge - Elixir-F# Interop Server for Podman Container Management

Usage:
  cepaf-bridge              Start the JSON-RPC server (reads from stdin)
  cepaf-bridge --help       Show this help message
  cepaf-bridge --version    Show version information

The bridge server communicates via JSON-RPC 2.0 over stdio.
It maintains a persistent connection to the Podman socket and
handles container lifecycle operations with STAMP safety validation.

Methods:
  system.ping               Check connectivity
  system.info               Get system information
  system.version            Get version info

  container.list            List containers
  container.inspect         Get container details
  container.create          Create a new container
  container.start           Start a container
  container.stop            Stop a container
  container.remove          Remove a container
  container.logs            Get container logs
  container.exists          Check if container exists
  container.findByName      Find container by name

  health.check              Run health check on container
  health.summary            Get health summary of all containers
  health.liveness           Check if container is alive
  health.readiness          Check if container is ready
  health.allHealthy         Check if all containers are healthy
  health.unhealthy          Get list of unhealthy containers

  safety.validateSpec       Validate container specification
  safety.validateImage      Validate image reference (SC-CNT-010)
  safety.validateRootless   Validate rootless mode (SC-CNT-012)
  safety.validateContainerHealth  Validate container health
  safety.validateAll        Validate all running containers

  emergency.stop            Force stop container (SC-EMR-057)
  emergency.remove          Force remove container (SC-EMR-060)
  emergency.stopAll         Stop all managed containers

Environment:
  UID                       User ID for rootless socket detection

Example:
  echo '{"jsonrpc":"2.0","id":"1","method":"system.ping"}' | cepaf-bridge
"""
            0

        // Handle --version
        elif args |> Array.contains "--version" || args |> Array.contains "-v" then
            printfn "cepaf-bridge 1.0.0"
            printfn "Cepaf.Podman Integration Bridge"
            printfn "Copyright (c) 2025 CEPAF Team"
            0

        // Run server
        else
            Server.start()
