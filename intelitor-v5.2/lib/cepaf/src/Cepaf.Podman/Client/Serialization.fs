namespace Cepaf.Podman.Client

open System
open System.Text.Json
open System.Text.Json.Serialization
open Cepaf.Podman.Domain

/// JSON serialization helpers for Podman API
module Serialization =

    // ========================================================================
    // JSON Options
    // ========================================================================

    /// Default JSON serializer options
    let jsonOptions =
        let options = JsonSerializerOptions()
        options.PropertyNamingPolicy <- JsonNamingPolicy.CamelCase
        options.PropertyNameCaseInsensitive <- true
        options.DefaultIgnoreCondition <- JsonIgnoreCondition.WhenWritingNull
        options.WriteIndented <- false
        options

    /// JSON options for reading (more permissive)
    let readOptions =
        let options = JsonSerializerOptions()
        options.PropertyNameCaseInsensitive <- true
        options.AllowTrailingCommas <- true
        options.ReadCommentHandling <- JsonCommentHandling.Skip
        options

    // ========================================================================
    // Helper Functions
    // ========================================================================

    /// Safely get string property from JSON element
    let tryGetString (name: string) (element: JsonElement) : string option =
        match element.TryGetProperty(name) with
        | true, prop when prop.ValueKind = JsonValueKind.String -> Some (prop.GetString())
        | _ -> None

    /// Get string property with default value
    let getString (name: string) (defaultValue: string) (element: JsonElement) : string =
        tryGetString name element |> Option.defaultValue defaultValue

    /// Safely get int property from JSON element
    let tryGetInt (name: string) (element: JsonElement) : int option =
        match element.TryGetProperty(name) with
        | true, prop when prop.ValueKind = JsonValueKind.Number -> Some (prop.GetInt32())
        | _ -> None

    /// Get int property with default value
    let getInt (name: string) (defaultValue: int) (element: JsonElement) : int =
        tryGetInt name element |> Option.defaultValue defaultValue

    /// Safely get int64 property
    let tryGetInt64 (name: string) (element: JsonElement) : int64 option =
        match element.TryGetProperty(name) with
        | true, prop when prop.ValueKind = JsonValueKind.Number -> Some (prop.GetInt64())
        | _ -> None

    /// Get int64 with default
    let getInt64 (name: string) (defaultValue: int64) (element: JsonElement) : int64 =
        tryGetInt64 name element |> Option.defaultValue defaultValue

    /// Safely get bool property
    let tryGetBool (name: string) (element: JsonElement) : bool option =
        match element.TryGetProperty(name) with
        | true, prop when prop.ValueKind = JsonValueKind.True -> Some true
        | true, prop when prop.ValueKind = JsonValueKind.False -> Some false
        | _ -> None

    /// Get bool with default
    let getBool (name: string) (defaultValue: bool) (element: JsonElement) : bool =
        tryGetBool name element |> Option.defaultValue defaultValue

    /// Get array property as list
    let getArray (name: string) (element: JsonElement) : JsonElement list =
        match element.TryGetProperty(name) with
        | true, prop when prop.ValueKind = JsonValueKind.Array ->
            [ for item in prop.EnumerateArray() -> item ]
        | _ -> []

    /// Get string array property
    let getStringArray (name: string) (element: JsonElement) : string list =
        getArray name element
        |> List.choose (fun e ->
            if e.ValueKind = JsonValueKind.String then Some (e.GetString())
            else None)

    /// Get object property as map
    let getStringMap (name: string) (element: JsonElement) : Map<string, string> =
        match element.TryGetProperty(name) with
        | true, prop when prop.ValueKind = JsonValueKind.Object ->
            [ for p in prop.EnumerateObject() ->
                (p.Name, if p.Value.ValueKind = JsonValueKind.String then p.Value.GetString() else p.Value.GetRawText())
            ] |> Map.ofList
        | _ -> Map.empty

    /// Parse DateTimeOffset from Unix timestamp
    let parseUnixTimestamp (seconds: int64) : DateTimeOffset =
        DateTimeOffset.FromUnixTimeSeconds(seconds)

    /// Parse DateTimeOffset from ISO string
    let parseDateTimeOffset (s: string) : DateTimeOffset option =
        match DateTimeOffset.TryParse(s) with
        | true, dt -> Some dt
        | false, _ -> None

    // ========================================================================
    // Container Parsing
    // ========================================================================

    /// Parse port mapping from JSON
    /// Podman uses snake_case (container_port) and camelCase (containerPort) interchangeably
    let parsePortMapping (element: JsonElement) : PortMapping =
        // Try both naming conventions
        let containerPort =
            tryGetInt "container_port" element
            |> Option.orElse (tryGetInt "containerPort" element)
            |> Option.defaultValue 0
        let hostPort =
            tryGetInt "host_port" element
            |> Option.orElse (tryGetInt "hostPort" element)
        let hostIP =
            tryGetString "host_ip" element
            |> Option.orElse (tryGetString "hostIP" element)
        let protocol =
            tryGetString "protocol" element
            |> Option.defaultValue "tcp"
        let range =
            tryGetInt "range" element
        {
            ContainerPort = uint16 containerPort
            HostPort =
                match hostPort with
                | Some p when p > 0 -> Some (uint16 p)
                | _ -> None
            HostIP = hostIP
            Protocol = PortProtocol.parse protocol
            Range =
                match range with
                | Some r when r > 1 -> Some (uint16 r)
                | _ -> None
        }

    /// Parse mount from JSON
    /// Podman uses varying cases for field names
    let parseMount (element: JsonElement) : Mount =
        let mountType =
            tryGetString "Type" element
            |> Option.orElse (tryGetString "type" element)
            |> Option.defaultValue "bind"
        let source =
            tryGetString "Source" element
            |> Option.orElse (tryGetString "source" element)
            |> Option.defaultValue ""
        let target =
            tryGetString "Destination" element
            |> Option.orElse (tryGetString "destination" element)
            |> Option.orElse (tryGetString "Target" element)
            |> Option.orElse (tryGetString "target" element)
            |> Option.defaultValue ""
        let readOnly =
            // RW=true means NOT read-only
            match tryGetBool "RW" element with
            | Some rw -> not rw
            | None ->
                tryGetBool "ReadOnly" element
                |> Option.orElse (tryGetBool "read_only" element)
                |> Option.defaultValue false
        {
            Type = MountType.parse mountType
            Source = source
            Target = target
            ReadOnly = readOnly
            Options = getStringArray "Options" element
        }

    /// Parse container state from JSON
    let parseContainerState (element: JsonElement) : ContainerStateDetail =
        let statusStr = getString "Status" "unknown" element
        {
            Status = ContainerStatus.parse statusStr
            Running = getBool "Running" false element
            Paused = getBool "Paused" false element
            Restarting = getBool "Restarting" false element
            OOMKilled = getBool "OOMKilled" false element
            Dead = getBool "Dead" false element
            Pid = getInt "Pid" 0 element
            ExitCode = getInt "ExitCode" 0 element
            Error = tryGetString "Error" element
            StartedAt = tryGetString "StartedAt" element |> Option.bind parseDateTimeOffset
            FinishedAt = tryGetString "FinishedAt" element |> Option.bind parseDateTimeOffset
            Health = None // Parsed separately if present
        }

    /// Parse container summary from list response
    /// Note: Podman list API returns simpler format than inspect
    let parseContainerSummary (element: JsonElement) : ContainerSummary =
        let names =
            getStringArray "Names" element
            |> List.map (fun n -> if n.StartsWith("/") then n.Substring(1) else n)

        // Podman list returns Mounts as string array, not object array
        let mounts =
            match element.TryGetProperty("Mounts") with
            | true, prop when prop.ValueKind = JsonValueKind.Array ->
                [ for item in prop.EnumerateArray() do
                    match item.ValueKind with
                    | JsonValueKind.String ->
                        // Simple string mount path
                        yield { Type = MountType.Bind; Source = item.GetString(); Target = item.GetString(); ReadOnly = false; Options = [] }
                    | JsonValueKind.Object ->
                        // Full mount object
                        yield parseMount item
                    | _ -> () ]
            | _ -> []

        // Parse ports - can be array of objects or null
        let ports =
            match element.TryGetProperty("Ports") with
            | true, prop when prop.ValueKind = JsonValueKind.Array ->
                [ for item in prop.EnumerateArray() do
                    if item.ValueKind = JsonValueKind.Object then
                        yield parsePortMapping item ]
            | _ -> []

        {
            Id = getString "Id" "" element
            Names = names
            Image = getString "Image" "" element
            ImageID = getString "ImageID" "" element
            Command = getString "Command" "" element
            Created = getInt64 "Created" 0L element |> parseUnixTimestamp
            State = ContainerStatus.parse (getString "State" "unknown" element)
            Status = getString "Status" "" element
            Ports = ports
            Labels = getStringMap "Labels" element
            Mounts = mounts
            Networks = getStringArray "Networks" element
        }

    /// Parse container inspect response
    let parseContainerInspect (element: JsonElement) : ContainerInspect =
        let stateElement =
            match element.TryGetProperty("State") with
            | true, s -> s
            | false, _ -> element
        {
            Id = getString "Id" "" element
            Created = tryGetString "Created" element |> Option.bind parseDateTimeOffset |> Option.defaultValue DateTimeOffset.MinValue
            Path = getString "Path" "" element
            Args = getStringArray "Args" element
            State = parseContainerState stateElement
            Image = getString "Image" "" element
            ImageName = getString "ImageName" "" element
            Name = getString "Name" "" element |> fun n -> if n.StartsWith("/") then n.Substring(1) else n
            RestartCount = getInt "RestartCount" 0 element
            Platform = getString "Platform" "linux" element
            MountLabel = getString "MountLabel" "" element
            ProcessLabel = getString "ProcessLabel" "" element
            Mounts = getArray "Mounts" element |> List.map parseMount
            Labels =
                match element.TryGetProperty("Config") with
                | true, config -> getStringMap "Labels" config
                | false, _ -> Map.empty
            Env =
                match element.TryGetProperty("Config") with
                | true, config ->
                    getStringArray "Env" config
                    |> List.choose (fun s ->
                        match s.IndexOf('=') with
                        | -1 -> None
                        | i -> Some (s.Substring(0, i), s.Substring(i + 1)))
                    |> Map.ofList
                | false, _ -> Map.empty
        }

    /// Parse container list response
    let parseContainerList (json: string) : PodmanResult<ContainerSummary list> =
        try
            let doc = JsonDocument.Parse(json)
            let containers =
                [ for item in doc.RootElement.EnumerateArray() ->
                    parseContainerSummary item ]
            Ok containers
        with ex ->
            Error (PodmanError.JsonParseError ex.Message)

    // ========================================================================
    // Pod Parsing
    // ========================================================================

    /// Parse pod container info
    let parsePodContainerInfo (element: JsonElement) : PodContainerInfo =
        {
            Id = getString "Id" "" element
            Name = getString "Name" "" element
            Status = ContainerStatus.parse (getString "State" "unknown" element)
        }

    /// Parse pod summary
    let parsePodSummary (element: JsonElement) : PodSummary =
        {
            Id = getString "Id" "" element
            Name = getString "Name" "" element
            Status = PodStatus.parse (getString "Status" "unknown" element)
            Created = tryGetString "Created" element |> Option.bind parseDateTimeOffset |> Option.defaultValue DateTimeOffset.MinValue
            Labels = getStringMap "Labels" element
            Containers = getArray "Containers" element |> List.map parsePodContainerInfo
            InfraId = tryGetString "InfraId" element
        }

    /// Parse pod list response
    let parsePodList (json: string) : PodmanResult<PodSummary list> =
        try
            let doc = JsonDocument.Parse(json)
            let pods =
                [ for item in doc.RootElement.EnumerateArray() ->
                    parsePodSummary item ]
            Ok pods
        with ex ->
            Error (PodmanError.JsonParseError ex.Message)

    // ========================================================================
    // Image Parsing
    // ========================================================================

    /// Parse image summary
    let parseImageSummary (element: JsonElement) : ImageSummary =
        {
            Id = getString "Id" "" element
            RepoTags = getStringArray "RepoTags" element
            RepoDigests = getStringArray "RepoDigests" element
            Created = getInt64 "Created" 0L element |> parseUnixTimestamp
            Size = getInt64 "Size" 0L element
            VirtualSize = getInt64 "VirtualSize" 0L element
            Labels = getStringMap "Labels" element
            Containers = getInt "Containers" 0 element
        }

    /// Parse image list response
    let parseImageList (json: string) : PodmanResult<ImageSummary list> =
        try
            let doc = JsonDocument.Parse(json)
            let images =
                [ for item in doc.RootElement.EnumerateArray() ->
                    parseImageSummary item ]
            Ok images
        with ex ->
            Error (PodmanError.JsonParseError ex.Message)

    // ========================================================================
    // Volume Parsing
    // ========================================================================

    /// Parse volume
    let parseVolume (element: JsonElement) : Volume =
        {
            Name = getString "Name" "" element
            Driver = VolumeDriver.parse (getString "Driver" "local" element)
            Mountpoint = getString "Mountpoint" "" element
            CreatedAt = tryGetString "CreatedAt" element |> Option.bind parseDateTimeOffset |> Option.defaultValue DateTimeOffset.MinValue
            Labels = getStringMap "Labels" element
            Options = getStringMap "Options" element
            Scope = getString "Scope" "local" element
        }

    /// Parse volume list response
    let parseVolumeList (json: string) : PodmanResult<Volume list> =
        try
            let doc = JsonDocument.Parse(json)
            let volumes =
                [ for item in doc.RootElement.EnumerateArray() ->
                    parseVolume item ]
            Ok volumes
        with ex ->
            Error (PodmanError.JsonParseError ex.Message)

    // ========================================================================
    // Network Parsing
    // ========================================================================

    /// Parse subnet
    let parseSubnet (element: JsonElement) : Subnet =
        {
            Subnet = getString "subnet" "" element
            Gateway = tryGetString "gateway" element
        }

    /// Parse network
    let parseNetwork (element: JsonElement) : Network =
        {
            Name = getString "name" "" element
            Id = getString "id" "" element
            Driver = NetworkDriver.parse (getString "driver" "bridge" element)
            Created = tryGetString "created" element |> Option.bind parseDateTimeOffset |> Option.defaultValue DateTimeOffset.MinValue
            Subnets = getArray "subnets" element |> List.map parseSubnet
            Internal = getBool "internal" false element
            DnsEnabled = getBool "dns_enabled" true element
            Labels = getStringMap "labels" element
            Options = getStringMap "options" element
        }

    /// Parse network list response
    let parseNetworkList (json: string) : PodmanResult<Network list> =
        try
            let doc = JsonDocument.Parse(json)
            let networks =
                [ for item in doc.RootElement.EnumerateArray() ->
                    parseNetwork item ]
            Ok networks
        with ex ->
            Error (PodmanError.JsonParseError ex.Message)

    // ========================================================================
    // Event Parsing
    // ========================================================================

    /// Parse event actor
    let parseEventActor (element: JsonElement) : EventActor =
        {
            ID = getString "ID" "" element
            Attributes = getStringMap "Attributes" element
        }

    /// Parse event
    let parseEvent (element: JsonElement) : PodmanEvent =
        {
            Type = EventType.parse (getString "Type" "unknown" element)
            Action = getString "Action" "" element
            Actor =
                match element.TryGetProperty("Actor") with
                | true, a -> parseEventActor a
                | false, _ -> EventActor.empty
            Time = getInt64 "time" 0L element
            TimeNano = getInt64 "timeNano" 0L element
            Status = tryGetString "status" element
        }

    /// Parse event from JSON string
    let parseEventString (json: string) : PodmanResult<PodmanEvent> =
        try
            let doc = JsonDocument.Parse(json)
            Ok (parseEvent doc.RootElement)
        with ex ->
            Error (PodmanError.JsonParseError ex.Message)

    // ========================================================================
    // Create Response Parsing
    // ========================================================================

    /// Parse create response (container/pod/volume/network)
    let parseCreateResponse (json: string) : PodmanResult<string> =
        try
            let doc = JsonDocument.Parse(json)
            let id =
                tryGetString "Id" doc.RootElement
                |> Option.orElse (tryGetString "id" doc.RootElement)
                |> Option.orElse (tryGetString "ID" doc.RootElement)
                |> Option.defaultValue ""
            if String.IsNullOrEmpty(id) then
                Error (PodmanError.JsonParseError "No ID in create response")
            else
                Ok id
        with ex ->
            Error (PodmanError.JsonParseError ex.Message)

    // ========================================================================
    // Spec Serialization
    // ========================================================================

    /// Convert TimeSpan to nanoseconds
    let toNanoseconds (ts: TimeSpan) : int64 =
        int64 ts.TotalMilliseconds * 1000000L

    /// Serialize container spec to JSON
    let serializeContainerSpec (spec: ContainerSpec) : string =
        use stream = new System.IO.MemoryStream()
        use writer = new Utf8JsonWriter(stream)

        writer.WriteStartObject()

        writer.WriteString("image", spec.Image)

        match spec.Name with
        | Some name -> writer.WriteString("name", name)
        | None -> ()

        match spec.Command with
        | Some cmd ->
            writer.WriteStartArray("command")
            for c in cmd do writer.WriteStringValue(c)
            writer.WriteEndArray()
        | None -> ()

        match spec.Entrypoint with
        | Some ep ->
            writer.WriteStartArray("entrypoint")
            for e in ep do writer.WriteStringValue(e)
            writer.WriteEndArray()
        | None -> ()

        match spec.WorkDir with
        | Some wd -> writer.WriteString("work_dir", wd)
        | None -> ()

        if not spec.Env.IsEmpty then
            writer.WriteStartObject("env")
            for kv in spec.Env do
                writer.WriteString(kv.Key, kv.Value)
            writer.WriteEndObject()

        // Port mappings
        if not spec.PortMappings.IsEmpty then
            writer.WriteStartArray("portmappings")
            for port in spec.PortMappings do
                writer.WriteStartObject()
                writer.WriteNumber("container_port", int port.ContainerPort)
                match port.HostPort with
                | Some hp -> writer.WriteNumber("host_port", int hp)
                | None -> ()
                match port.HostIP with
                | Some ip -> writer.WriteString("host_ip", ip)
                | None -> ()
                writer.WriteString("protocol", PortProtocol.toString port.Protocol)
                writer.WriteEndObject()
            writer.WriteEndArray()

        // Mounts
        if not spec.Mounts.IsEmpty then
            writer.WriteStartArray("mounts")
            for mount in spec.Mounts do
                writer.WriteStartObject()
                writer.WriteString("type", MountType.toString mount.Type)
                writer.WriteString("source", mount.Source)
                writer.WriteString("destination", mount.Target)
                if mount.ReadOnly then
                    writer.WriteBoolean("read_only", true)
                writer.WriteEndObject()
            writer.WriteEndArray()

        // Resource limits
        match spec.Resources with
        | Some res ->
            writer.WriteStartObject("resource_limits")
            match res.Memory with
            | Some mem ->
                writer.WriteStartObject("memory")
                match mem.Limit with
                | Some limit -> writer.WriteNumber("limit", limit)
                | None -> ()
                match mem.Reservation with
                | Some res -> writer.WriteNumber("reservation", res)
                | None -> ()
                writer.WriteEndObject()
            | None -> ()
            match res.Cpu with
            | Some cpu ->
                writer.WriteStartObject("cpu")
                match cpu.Shares with
                | Some shares -> writer.WriteNumber("shares", shares)
                | None -> ()
                match cpu.Quota with
                | Some quota -> writer.WriteNumber("quota", quota)
                | None -> ()
                writer.WriteEndObject()
            | None -> ()
            match res.PidsLimit with
            | Some limit ->
                writer.WriteStartObject("pids")
                writer.WriteNumber("limit", limit)
                writer.WriteEndObject()
            | None -> ()
            writer.WriteEndObject()
        | None -> ()

        // Health check
        match spec.HealthCheck with
        | Some hc ->
            writer.WriteStartObject("healthconfig")
            writer.WriteStartArray("test")
            for t in HealthCheckTest.toStringList hc.Test do
                writer.WriteStringValue(t)
            writer.WriteEndArray()
            match hc.Interval with
            | Some i -> writer.WriteNumber("interval", toNanoseconds i)
            | None -> ()
            match hc.Timeout with
            | Some t -> writer.WriteNumber("timeout", toNanoseconds t)
            | None -> ()
            match hc.StartPeriod with
            | Some sp -> writer.WriteNumber("startperiod", toNanoseconds sp)
            | None -> ()
            match hc.Retries with
            | Some r -> writer.WriteNumber("retries", r)
            | None -> ()
            writer.WriteEndObject()
        | None -> ()

        // Restart policy
        match spec.RestartPolicy with
        | Some rp ->
            writer.WriteString("restart_policy", RestartPolicyType.toString rp.Policy)
            match rp.MaxRetries with
            | Some retries -> writer.WriteNumber("restart_tries", retries)
            | None -> ()
        | None -> ()

        // Stop timeout
        match spec.StopTimeout with
        | Some timeout -> writer.WriteNumber("stop_timeout", timeout)
        | None -> ()

        // Auto-remove
        if spec.Remove then
            writer.WriteBoolean("remove", true)

        // Labels
        if not spec.Labels.IsEmpty then
            writer.WriteStartObject("labels")
            for kv in spec.Labels do
                writer.WriteString(kv.Key, kv.Value)
            writer.WriteEndObject()

        // Terminal/TTY
        if spec.Terminal then
            writer.WriteBoolean("terminal", true)

        writer.WriteEndObject()
        writer.Flush()

        System.Text.Encoding.UTF8.GetString(stream.ToArray())

    /// Serialize pod spec to JSON
    let serializePodSpec (spec: PodSpec) : string =
        use stream = new System.IO.MemoryStream()
        use writer = new Utf8JsonWriter(stream)

        writer.WriteStartObject()

        match spec.Name with
        | Some name -> writer.WriteString("name", name)
        | None -> ()

        match spec.Hostname with
        | Some hostname -> writer.WriteString("hostname", hostname)
        | None -> ()

        if spec.NoInfra then
            writer.WriteBoolean("no_infra", true)

        match spec.InfraImage with
        | Some image -> writer.WriteString("infra_image", image)
        | None -> ()

        // Port mappings
        if not spec.PortMappings.IsEmpty then
            writer.WriteStartArray("portmappings")
            for port in spec.PortMappings do
                writer.WriteStartObject()
                writer.WriteNumber("container_port", int port.ContainerPort)
                match port.HostPort with
                | Some hp -> writer.WriteNumber("host_port", int hp)
                | None -> ()
                writer.WriteString("protocol", PortProtocol.toString port.Protocol)
                writer.WriteEndObject()
            writer.WriteEndArray()

        // Labels
        if not spec.Labels.IsEmpty then
            writer.WriteStartObject("labels")
            for kv in spec.Labels do
                writer.WriteString(kv.Key, kv.Value)
            writer.WriteEndObject()

        writer.WriteEndObject()
        writer.Flush()

        System.Text.Encoding.UTF8.GetString(stream.ToArray())

    /// Serialize volume spec to JSON
    let serializeVolumeSpec (spec: VolumeSpec) : string =
        use stream = new System.IO.MemoryStream()
        use writer = new Utf8JsonWriter(stream)

        writer.WriteStartObject()
        writer.WriteString("Name", spec.Name)
        writer.WriteString("Driver", VolumeDriver.toString spec.Driver)

        if not spec.Labels.IsEmpty then
            writer.WriteStartObject("Labels")
            for kv in spec.Labels do
                writer.WriteString(kv.Key, kv.Value)
            writer.WriteEndObject()

        if not spec.Options.IsEmpty then
            writer.WriteStartObject("Options")
            for kv in spec.Options do
                writer.WriteString(kv.Key, kv.Value)
            writer.WriteEndObject()

        writer.WriteEndObject()
        writer.Flush()

        System.Text.Encoding.UTF8.GetString(stream.ToArray())

    /// Serialize network spec to JSON
    let serializeNetworkSpec (spec: NetworkSpec) : string =
        use stream = new System.IO.MemoryStream()
        use writer = new Utf8JsonWriter(stream)

        writer.WriteStartObject()
        writer.WriteString("name", spec.Name)
        writer.WriteString("driver", NetworkDriver.toString spec.Driver)
        writer.WriteBoolean("internal", spec.Internal)
        writer.WriteBoolean("dns_enabled", spec.DnsEnabled)

        if not spec.Subnets.IsEmpty then
            writer.WriteStartArray("subnets")
            for subnet in spec.Subnets do
                writer.WriteStartObject()
                writer.WriteString("subnet", subnet.Subnet)
                match subnet.Gateway with
                | Some gw -> writer.WriteString("gateway", gw)
                | None -> ()
                writer.WriteEndObject()
            writer.WriteEndArray()

        if not spec.Labels.IsEmpty then
            writer.WriteStartObject("labels")
            for kv in spec.Labels do
                writer.WriteString(kv.Key, kv.Value)
            writer.WriteEndObject()

        writer.WriteEndObject()
        writer.Flush()

        System.Text.Encoding.UTF8.GetString(stream.ToArray())
