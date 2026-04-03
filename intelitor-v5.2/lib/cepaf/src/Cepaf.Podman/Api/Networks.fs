namespace Cepaf.Podman.Api

open System
open System.Text.Json
open Cepaf.Podman.Domain
open Cepaf.Podman.Client

/// Network management operations
module Networks =

    // ========================================================================
    // List Operations
    // ========================================================================

    /// List networks
    let list (client: PodmanClient) : AsyncPodmanResult<Network list> = async {
        let! result = HttpClient.getRaw client "/networks/json"
        return result |> Result.bind Serialization.parseNetworkList
    }

    /// Check if network exists
    let exists (client: PodmanClient) (name: string) : AsyncPodmanResult<bool> = async {
        let! result = HttpClient.getRaw client (sprintf "/networks/%s/exists" (HttpClient.urlEncode name))
        match result with
        | Ok _ -> return Ok true
        | Error (PodmanError.NotFound _) -> return Ok false
        | Error e -> return Error e
    }

    // ========================================================================
    // Inspect Operations
    // ========================================================================

    /// Inspect network
    let inspect (client: PodmanClient) (name: string) : AsyncPodmanResult<Network> = async {
        let! result = HttpClient.getRaw client (sprintf "/networks/%s/json" (HttpClient.urlEncode name))
        return result |> Result.bind (fun json ->
            try
                let doc = JsonDocument.Parse(json)
                Ok (Serialization.parseNetwork doc.RootElement)
            with ex ->
                Error (PodmanError.JsonParseError ex.Message)
        )
    }

    // ========================================================================
    // Lifecycle Operations
    // ========================================================================

    /// Create network
    let create (client: PodmanClient) (spec: NetworkSpec) : AsyncPodmanResult<Network> = async {
        let json = Serialization.serializeNetworkSpec spec
        let! result = HttpClient.postJson client "/networks/create" json
        return result |> Result.bind (fun responseJson ->
            try
                let doc = JsonDocument.Parse(responseJson)
                Ok (Serialization.parseNetwork doc.RootElement)
            with ex ->
                Error (PodmanError.JsonParseError ex.Message)
        )
    }

    /// Create network with name only
    let createNamed (client: PodmanClient) (name: string) : AsyncPodmanResult<Network> =
        let spec = NetworkSpec.create name
        create client spec

    /// Remove network
    let remove (client: PodmanClient) (name: string) (force: bool) : AsyncPodmanResult<unit> = async {
        let query = sprintf "?force=%b" force
        return! HttpClient.delete client (sprintf "/networks/%s%s" (HttpClient.urlEncode name) query)
    }

    /// Prune unused networks
    let prune (client: PodmanClient) : AsyncPodmanResult<string list> = async {
        let! result = HttpClient.postEmpty client "/networks/prune"
        return result |> Result.bind (fun json ->
            try
                let doc = JsonDocument.Parse(json)
                Ok (Serialization.getStringArray "NetworksDeleted" doc.RootElement)
            with ex ->
                Error (PodmanError.JsonParseError ex.Message)
        )
    }

    // ========================================================================
    // Connect/Disconnect Operations
    // ========================================================================

    /// Connect options
    type ConnectOptions = {
        Container: string
        Aliases: string list
        IPv4Address: string option
        IPv6Address: string option
    }

    module ConnectOptions =
        let create container = {
            Container = container
            Aliases = []
            IPv4Address = None
            IPv6Address = None
        }

        let withAlias alias opts = { opts with Aliases = alias :: opts.Aliases }
        let withIPv4 ip opts = { opts with IPv4Address = Some ip }
        let withIPv6 ip opts = { opts with IPv6Address = Some ip }

    /// Connect container to network
    let connect (client: PodmanClient) (networkName: string) (options: ConnectOptions) : AsyncPodmanResult<unit> = async {
        let aliasesJson =
            if options.Aliases.IsEmpty then ""
            else sprintf ",\"Aliases\":[%s]" (options.Aliases |> List.map (sprintf "\"%s\"") |> String.concat ",")

        let ipv4Json =
            match options.IPv4Address with
            | Some ip -> sprintf ",\"StaticIPs\":[\"%s\"]" ip
            | None -> ""

        let json = sprintf "{\"Container\":\"%s\"%s%s}" options.Container aliasesJson ipv4Json

        let! result = HttpClient.postJson client (sprintf "/networks/%s/connect" (HttpClient.urlEncode networkName)) json
        return result |> Result.map ignore
    }

    /// Connect container by name only
    let connectContainer (client: PodmanClient) (networkName: string) (containerName: string) : AsyncPodmanResult<unit> =
        connect client networkName (ConnectOptions.create containerName)

    /// Disconnect container from network
    let disconnect (client: PodmanClient) (networkName: string) (containerName: string) (force: bool) : AsyncPodmanResult<unit> = async {
        let json = sprintf "{\"Container\":\"%s\",\"Force\":%b}" containerName force
        let! result = HttpClient.postJson client (sprintf "/networks/%s/disconnect" (HttpClient.urlEncode networkName)) json
        return result |> Result.map ignore
    }

    // ========================================================================
    // Update Operations
    // ========================================================================

    /// Update network (limited support in Podman)
    let update (client: PodmanClient) (name: string) (labels: Map<string, string>) : AsyncPodmanResult<unit> = async {
        // Note: Podman has limited network update support
        // This is a placeholder that would need API support verification
        return Error (PodmanError.InternalError "Network update not fully supported - recreate network instead")
    }

    // ========================================================================
    // Convenience Operations
    // ========================================================================

    /// Find network by name
    let findByName (client: PodmanClient) (name: string) : AsyncPodmanResult<Network option> = async {
        let! result = list client
        return result |> Result.map (fun networks ->
            networks |> List.tryFind (fun n -> n.Name = name)
        )
    }

    /// Ensure network exists, create if not
    let ensureExists (client: PodmanClient) (name: string) : AsyncPodmanResult<Network> = async {
        let! existsResult = exists client name
        match existsResult with
        | Error e -> return Error e
        | Ok true -> return! inspect client name
        | Ok false -> return! createNamed client name
    }

    /// Create bridge network
    let createBridge (client: PodmanClient) (name: string) (subnet: string option) : AsyncPodmanResult<Network> =
        let spec =
            NetworkSpec.create name
            |> NetworkSpec.withDriver NetworkDriver.Bridge
            |> fun s ->
                match subnet with
                | Some sub -> NetworkSpec.withSubnet sub None s
                | Option.None -> s
        create client spec

    /// Create macvlan network
    let createMacvlan (client: PodmanClient) (name: string) (parent: string) (subnet: string) : AsyncPodmanResult<Network> =
        let spec =
            NetworkSpec.create name
            |> NetworkSpec.withDriver NetworkDriver.Macvlan
            |> NetworkSpec.withSubnet subnet None
            |> fun s -> { s with Options = Map.ofList [("parent", parent)] }
        create client spec

    /// Remove network if exists
    let removeIfExists (client: PodmanClient) (name: string) : AsyncPodmanResult<unit> = async {
        let! existsResult = exists client name
        match existsResult with
        | Error e -> return Error e
        | Ok false -> return Ok ()
        | Ok true -> return! remove client name true
    }

    /// List networks with label filter
    let listWithLabel (client: PodmanClient) (label: string) : AsyncPodmanResult<Network list> = async {
        let query = sprintf "?filters={\"label\":[\"%s\"]}" (HttpClient.urlEncode label)
        let! result = HttpClient.getRaw client (sprintf "/networks/json%s" query)
        return result |> Result.bind Serialization.parseNetworkList
    }

    /// Get all network names
    let listNames (client: PodmanClient) : AsyncPodmanResult<string list> = async {
        let! result = list client
        return result |> Result.map (List.map (fun n -> n.Name))
    }

    // ========================================================================
    // Network Info
    // ========================================================================

    /// Network statistics
    type NetworkStats = {
        Name: string
        Created: DateTimeOffset
        Driver: string
        Internal: bool
        DnsEnabled: bool
    }

    /// Get network statistics
    let getStats (client: PodmanClient) (name: string) : AsyncPodmanResult<NetworkStats> = async {
        let! result = inspect client name
        return result |> Result.map (fun n -> {
            Name = n.Name
            Created = n.Created
            Driver = NetworkDriver.toString n.Driver
            Internal = n.Internal
            DnsEnabled = n.DnsEnabled
        })
    }

    /// Get default network
    let getDefault (client: PodmanClient) : AsyncPodmanResult<Network option> = async {
        let! result = list client
        return result |> Result.map (fun networks ->
            networks |> List.tryFind (fun n -> n.Name = "podman" || n.Name = "bridge")
        )
    }

