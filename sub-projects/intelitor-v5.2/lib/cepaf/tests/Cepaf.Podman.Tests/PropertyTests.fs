module Cepaf.Podman.Tests.PropertyTests

open System
open FsCheck
open FsCheck.FSharp
open Cepaf.Podman.Domain

// ============================================================================
// Custom Generators
// ============================================================================

/// Generate valid container names (lowercase alphanumeric with hyphens)
let containerNameGen =
    gen {
        let! prefix = Gen.elements ["indrajaal"; "app"; "db"; "cache"; "web"; "api"]
        let! suffix = Gen.choose (1, 9999)
        return sprintf "%s-%d" prefix suffix
    }

/// Generate valid image references
let imageRefGen =
    gen {
        let! name = Gen.elements ["app"; "db"; "redis"; "nginx"; "postgres"]
        let! tag = Gen.elements ["latest"; "v1.0"; "v2.0"; "alpine"; "slim"]
        return sprintf "localhost/%s:%s" name tag
    }

/// Generate port numbers (valid range)
let portGen = Gen.choose (1, 65535) |> Gen.map uint16

/// Generate valid environment variable names
let envKeyGen =
    gen {
        let! prefix = Gen.elements ["APP"; "DB"; "REDIS"; "LOG"; "DEBUG"; "ENV"]
        let! suffix = Gen.elements ["_HOST"; "_PORT"; "_USER"; "_PASS"; "_LEVEL"; ""]
        return prefix + suffix
    }

/// Generate mount paths
let pathGen =
    gen {
        let! dir = Gen.elements ["/data"; "/var/lib"; "/home/user"; "/tmp"; "/opt"]
        let! subdir = Gen.elements ["app"; "db"; "logs"; "cache"; "config"]
        return sprintf "%s/%s" dir subdir
    }

// ============================================================================
// Arbitrary Instances
// ============================================================================

type Generators =
    static member PortProtocol() =
        Arb.fromGen (Gen.elements [PortProtocol.TCP; PortProtocol.UDP; PortProtocol.SCTP])

    static member MountType() =
        Arb.fromGen (Gen.elements [MountType.Bind; MountType.Volume; MountType.Tmpfs; MountType.Image; MountType.Devpts])

    static member ContainerStatus() =
        Arb.fromGen (Gen.oneof [
            Gen.constant ContainerStatus.Created
            Gen.constant ContainerStatus.Running
            Gen.constant ContainerStatus.Paused
            Gen.constant ContainerStatus.Restarting
            Gen.constant ContainerStatus.Removing
            Gen.choose (0, 255) |> Gen.map ContainerStatus.Exited
            Gen.elements ["killed"; "oom"] |> Gen.map ContainerStatus.Dead
            Gen.elements ["custom"; "other"] |> Gen.map ContainerStatus.Unknown
        ])

    static member RestartPolicyType() =
        Arb.fromGen (Gen.elements [
            RestartPolicyType.No
            RestartPolicyType.Always
            RestartPolicyType.OnFailure
            RestartPolicyType.UnlessStopped
        ])

    static member NetworkDriver() =
        Arb.fromGen (Gen.elements [
            NetworkDriver.Bridge
            NetworkDriver.Host
            NetworkDriver.None
            NetworkDriver.Macvlan
            NetworkDriver.Ipvlan
        ])

    static member VolumeDriver() =
        Arb.fromGen (Gen.elements [VolumeDriver.Local; VolumeDriver.Custom "nfs"])

    static member HealthStatus() =
        Arb.fromGen (Gen.oneof [
            Gen.constant HealthStatus.Healthy
            Gen.constant HealthStatus.Starting
            Gen.constant HealthStatus.NoHealthcheck
            Gen.choose (1, 10) |> Gen.map HealthStatus.Unhealthy
            Gen.elements ["unknown"; "pending"] |> Gen.map HealthStatus.Unknown
        ])

// ============================================================================
// Property Tests Module
// ============================================================================

module Properties =

    // ------------------------------------------------------------------------
    // PortProtocol Properties
    // ------------------------------------------------------------------------

    let ``PortProtocol parse-toString roundtrip`` (protocol: PortProtocol) =
        let str = PortProtocol.toString protocol
        let parsed = PortProtocol.parse str
        parsed = protocol

    let ``PortProtocol parse is case insensitive`` () =
        PortProtocol.parse "TCP" = PortProtocol.TCP &&
        PortProtocol.parse "tcp" = PortProtocol.TCP &&
        PortProtocol.parse "Tcp" = PortProtocol.TCP

    let ``PortProtocol unknown defaults to TCP`` () =
        PortProtocol.parse "invalid" = PortProtocol.TCP &&
        PortProtocol.parse "" = PortProtocol.TCP

    // ------------------------------------------------------------------------
    // MountType Properties
    // ------------------------------------------------------------------------

    let ``MountType parse-toString roundtrip`` (mountType: MountType) =
        let str = MountType.toString mountType
        let parsed = MountType.parse str
        parsed = mountType

    let ``MountType parse is case insensitive`` () =
        MountType.parse "BIND" = MountType.Bind &&
        MountType.parse "bind" = MountType.Bind &&
        MountType.parse "Bind" = MountType.Bind

    // ------------------------------------------------------------------------
    // ContainerStatus Properties
    // ------------------------------------------------------------------------

    let ``ContainerStatus parse handles common states`` () =
        ContainerStatus.parse "running" = ContainerStatus.Running &&
        ContainerStatus.parse "created" = ContainerStatus.Created &&
        ContainerStatus.parse "paused" = ContainerStatus.Paused &&
        ContainerStatus.parse "exited" = ContainerStatus.Exited 0 &&
        ContainerStatus.parse "dead" = ContainerStatus.Dead "unknown"

    let ``ContainerStatus parse unknown returns Unknown`` () =
        match ContainerStatus.parse "custom-state" with
        | ContainerStatus.Unknown _ -> true
        | _ -> false

    // ------------------------------------------------------------------------
    // RestartPolicy Properties
    // ------------------------------------------------------------------------

    let ``RestartPolicyType toString produces valid strings`` (policy: RestartPolicyType) =
        let str = RestartPolicyType.toString policy
        str.Length > 0

    let ``RestartPolicy module functions create correct types`` () =
        let always = RestartPolicy.always
        let onFailure = RestartPolicy.onFailure 5
        let unlessStopped = RestartPolicy.unlessStopped
        let no = RestartPolicy.no
        always.Policy = RestartPolicyType.Always &&
        onFailure.Policy = RestartPolicyType.OnFailure &&
        onFailure.MaxRetries = Some 5 &&
        unlessStopped.Policy = RestartPolicyType.UnlessStopped &&
        no.Policy = RestartPolicyType.No

    // ------------------------------------------------------------------------
    // NetworkDriver Properties
    // ------------------------------------------------------------------------

    let ``NetworkDriver parse-toString roundtrip`` (driver: NetworkDriver) =
        let str = NetworkDriver.toString driver
        let parsed = NetworkDriver.parse str
        parsed = driver

    let ``NetworkDriver parse handles common drivers`` () =
        NetworkDriver.parse "bridge" = NetworkDriver.Bridge &&
        NetworkDriver.parse "host" = NetworkDriver.Host &&
        NetworkDriver.parse "none" = NetworkDriver.None &&
        NetworkDriver.parse "macvlan" = NetworkDriver.Macvlan

    // ------------------------------------------------------------------------
    // VolumeDriver Properties
    // ------------------------------------------------------------------------

    let ``VolumeDriver parse-toString roundtrip`` (driver: VolumeDriver) =
        let str = VolumeDriver.toString driver
        let parsed = VolumeDriver.parse str
        parsed = driver

    let ``VolumeDriver local is default`` () =
        VolumeDriver.parse "local" = VolumeDriver.Local &&
        VolumeDriver.parse "" = VolumeDriver.Local

    // ------------------------------------------------------------------------
    // HealthStatus Properties
    // ------------------------------------------------------------------------

    let ``HealthStatus parse handles common states`` () =
        HealthStatus.parse "healthy" = HealthStatus.Healthy &&
        HealthStatus.parse "starting" = HealthStatus.Starting &&
        HealthStatus.parse "none" = HealthStatus.NoHealthcheck

    // ------------------------------------------------------------------------
    // Mount Properties
    // ------------------------------------------------------------------------

    let ``Mount createBind creates bind mount`` () =
        let mount = Mount.createBind "/src/path" "/dst/path"
        mount.Type = MountType.Bind &&
        mount.Source = "/src/path" &&
        mount.Target = "/dst/path" &&
        mount.ReadOnly = false

    let ``Mount createVolume creates volume mount`` () =
        let mount = Mount.createVolume "myvolume" "/data"
        mount.Type = MountType.Volume &&
        mount.Source = "myvolume" &&
        mount.Target = "/data"

    let ``Mount withReadOnly sets read-only flag`` () =
        let mount = Mount.createBind "/src" "/dst" |> Mount.withReadOnly
        mount.ReadOnly = true

    // ------------------------------------------------------------------------
    // PortMapping Properties
    // ------------------------------------------------------------------------

    let ``PortMapping create with valid port`` () =
        let mapping = PortMapping.create 80us
        mapping.ContainerPort = 80us &&
        mapping.HostPort = None &&
        mapping.Protocol = PortProtocol.TCP

    let ``PortMapping withHostPort sets host port`` () =
        let mapping = PortMapping.create 80us |> PortMapping.withHostPort 8080us
        mapping.ContainerPort = 80us &&
        mapping.HostPort = Some 8080us

    let ``PortMapping withProtocol changes protocol`` (protocol: PortProtocol) =
        let mapping = PortMapping.create 80us |> PortMapping.withProtocol protocol
        mapping.Protocol = protocol

    // ------------------------------------------------------------------------
    // ContainerSpec Builder Properties
    // ------------------------------------------------------------------------

    let ``ContainerSpec create sets image`` () =
        let spec = ContainerSpec.create "localhost/myapp:v1"
        spec.Image = "localhost/myapp:v1"

    let ``ContainerSpec withName sets name`` () =
        let spec = ContainerSpec.create "localhost/myapp:v1" |> ContainerSpec.withName "test-container"
        spec.Name = Some "test-container"

    let ``ContainerSpec withEnv adds environment variable`` () =
        let spec =
            ContainerSpec.create "localhost/myapp:v1"
            |> ContainerSpec.withEnv "KEY1" "value1"
            |> ContainerSpec.withEnv "KEY2" "value2"
        spec.Env.ContainsKey "KEY1" && spec.Env.["KEY1"] = "value1" &&
        spec.Env.ContainsKey "KEY2" && spec.Env.["KEY2"] = "value2"

    let ``ContainerSpec withPort adds port mapping`` () =
        // Note: withPort signature is (hostPort, containerPort)
        let spec = ContainerSpec.create "localhost/myapp:v1" |> ContainerSpec.withPort 8080us 80us
        spec.PortMappings.Length = 1 &&
        spec.PortMappings.[0].ContainerPort = 80us &&
        spec.PortMappings.[0].HostPort = Some 8080us

    let ``ContainerSpec withMemoryLimit sets memory`` () =
        let limit = 512L * 1024L * 1024L // 512MB
        let spec = ContainerSpec.create "localhost/myapp:v1" |> ContainerSpec.withMemoryLimit limit
        match spec.Resources with
        | Some res ->
            match res.Memory with
            | Some mem -> mem.Limit = Some limit
            | None -> false
        | None -> false

    let ``ContainerSpec withRestartAlways sets restart policy`` () =
        let spec = ContainerSpec.create "localhost/myapp:v1" |> ContainerSpec.withRestartAlways
        match spec.RestartPolicy with
        | Some rp -> rp.Policy = RestartPolicyType.Always
        | None -> false

    let ``ContainerSpec withHealthCheck sets health check`` () =
        let hc = HealthCheckConfig.create (HealthCheckTest.Cmd ["curl"; "-f"; "http://localhost/health"])
        let spec = ContainerSpec.create "localhost/myapp:v1" |> ContainerSpec.withHealthCheck hc
        match spec.HealthCheck with
        | Some hc ->
            match hc.Test with
            | HealthCheckTest.Cmd c -> c = ["curl"; "-f"; "http://localhost/health"]
            | _ -> false
        | None -> false

    // ------------------------------------------------------------------------
    // PodSpec Builder Properties
    // ------------------------------------------------------------------------

    let ``PodSpec create initializes empty spec`` () =
        let spec = PodSpec.create ()
        spec.Name.IsNone &&
        spec.PortMappings.IsEmpty &&
        spec.Labels.IsEmpty

    let ``PodSpec withName sets name`` () =
        let spec = PodSpec.create () |> PodSpec.withName "test-pod"
        spec.Name = Some "test-pod"

    // ------------------------------------------------------------------------
    // Safety Constraint Properties
    // ------------------------------------------------------------------------

    let ``Localhost images pass validation`` () =
        // Only localhost/ prefix is valid per SC-CNT-010
        let images = [
            "localhost/app:v1"
            "localhost/db:latest"
            "localhost/myapp:tag"
        ]
        images |> List.forall (fun img ->
            let spec = ContainerSpec.create img
            match Cepaf.Podman.Safety.Constraints.validateContainerSpec spec with
            | Cepaf.Podman.Safety.Constraints.Valid -> true
            | Cepaf.Podman.Safety.Constraints.Invalid vs ->
                // Should have no critical violations for localhost/ images
                // May have warnings for missing health check, resources, etc.
                not (vs |> List.exists (fun v -> v.Severity = Cepaf.Podman.Safety.Constraints.Critical))
        )

    let ``External images fail validation with critical`` () =
        let images = [
            "docker.io/nginx:latest"
            "gcr.io/myproject/app:v1"
            "nginx:latest"
        ]
        images |> List.forall (fun img ->
            let spec = ContainerSpec.create img
            match Cepaf.Podman.Safety.Constraints.validateContainerSpec spec with
            | Cepaf.Podman.Safety.Constraints.Valid -> false
            | Cepaf.Podman.Safety.Constraints.Invalid vs ->
                vs |> List.exists (fun v -> v.Severity = Cepaf.Podman.Safety.Constraints.Critical)
        )

// ============================================================================
// Test Runner
// ============================================================================

let private config =
    Config.QuickThrowOnFailure
        .WithMaxTest(100)
        .WithArbitrary([typeof<Generators>])

type PropertyTestResult = {
    Name: string
    Passed: bool
    Message: string
}

let runPropertyTests () =
    printfn ""
    printfn "=== PROPERTY-BASED TESTS (FsCheck) ==="
    printfn ""

    let mutable passed = 0
    let mutable failed = 0

    let runTest name prop =
        try
            Check.One(config, prop)
            printfn "  [PASS] %s" name
            passed <- passed + 1
            true
        with ex ->
            printfn "  [FAIL] %s: %s" name ex.Message
            failed <- failed + 1
            false

    let runSimpleTest name (test: unit -> bool) =
        try
            if test() then
                printfn "  [PASS] %s" name
                passed <- passed + 1
                true
            else
                printfn "  [FAIL] %s: returned false" name
                failed <- failed + 1
                false
        with ex ->
            printfn "  [FAIL] %s: %s" name ex.Message
            failed <- failed + 1
            false

    // Protocol tests
    printfn "--- Protocol & Type Parsing ---"
    runTest "PortProtocol roundtrip" Properties.``PortProtocol parse-toString roundtrip`` |> ignore
    runSimpleTest "PortProtocol case insensitive" Properties.``PortProtocol parse is case insensitive`` |> ignore
    runSimpleTest "PortProtocol unknown defaults" Properties.``PortProtocol unknown defaults to TCP`` |> ignore

    // MountType tests
    printfn ""
    printfn "--- MountType ---"
    runTest "MountType roundtrip" Properties.``MountType parse-toString roundtrip`` |> ignore
    runSimpleTest "MountType case insensitive" Properties.``MountType parse is case insensitive`` |> ignore

    // ContainerStatus tests
    printfn ""
    printfn "--- ContainerStatus ---"
    runSimpleTest "ContainerStatus common states" Properties.``ContainerStatus parse handles common states`` |> ignore
    runSimpleTest "ContainerStatus unknown" Properties.``ContainerStatus parse unknown returns Unknown`` |> ignore

    // RestartPolicy tests
    printfn ""
    printfn "--- RestartPolicy ---"
    runTest "RestartPolicyType toString" Properties.``RestartPolicyType toString produces valid strings`` |> ignore
    runSimpleTest "RestartPolicy module functions" Properties.``RestartPolicy module functions create correct types`` |> ignore

    // NetworkDriver tests
    printfn ""
    printfn "--- NetworkDriver ---"
    runTest "NetworkDriver roundtrip" Properties.``NetworkDriver parse-toString roundtrip`` |> ignore
    runSimpleTest "NetworkDriver common drivers" Properties.``NetworkDriver parse handles common drivers`` |> ignore

    // VolumeDriver tests
    printfn ""
    printfn "--- VolumeDriver ---"
    runTest "VolumeDriver roundtrip" Properties.``VolumeDriver parse-toString roundtrip`` |> ignore
    runSimpleTest "VolumeDriver local default" Properties.``VolumeDriver local is default`` |> ignore

    // HealthStatus tests
    printfn ""
    printfn "--- HealthStatus ---"
    runSimpleTest "HealthStatus common states" Properties.``HealthStatus parse handles common states`` |> ignore

    // Mount tests
    printfn ""
    printfn "--- Mount ---"
    runSimpleTest "Mount createBind" Properties.``Mount createBind creates bind mount`` |> ignore
    runSimpleTest "Mount createVolume" Properties.``Mount createVolume creates volume mount`` |> ignore
    runSimpleTest "Mount withReadOnly" Properties.``Mount withReadOnly sets read-only flag`` |> ignore

    // PortMapping tests
    printfn ""
    printfn "--- PortMapping ---"
    runSimpleTest "PortMapping create" Properties.``PortMapping create with valid port`` |> ignore
    runSimpleTest "PortMapping withHostPort" Properties.``PortMapping withHostPort sets host port`` |> ignore
    runTest "PortMapping withProtocol" Properties.``PortMapping withProtocol changes protocol`` |> ignore

    // ContainerSpec tests
    printfn ""
    printfn "--- ContainerSpec Builder ---"
    runSimpleTest "ContainerSpec create" Properties.``ContainerSpec create sets image`` |> ignore
    runSimpleTest "ContainerSpec withName" Properties.``ContainerSpec withName sets name`` |> ignore
    runSimpleTest "ContainerSpec withEnv" Properties.``ContainerSpec withEnv adds environment variable`` |> ignore
    runSimpleTest "ContainerSpec withPort" Properties.``ContainerSpec withPort adds port mapping`` |> ignore
    runSimpleTest "ContainerSpec withMemoryLimit" Properties.``ContainerSpec withMemoryLimit sets memory`` |> ignore
    runSimpleTest "ContainerSpec withRestartAlways" Properties.``ContainerSpec withRestartAlways sets restart policy`` |> ignore
    runSimpleTest "ContainerSpec withHealthCheck" Properties.``ContainerSpec withHealthCheck sets health check`` |> ignore

    // PodSpec tests
    printfn ""
    printfn "--- PodSpec Builder ---"
    runSimpleTest "PodSpec create" Properties.``PodSpec create initializes empty spec`` |> ignore
    runSimpleTest "PodSpec withName" Properties.``PodSpec withName sets name`` |> ignore

    // Safety tests
    printfn ""
    printfn "--- Safety Constraints ---"
    runSimpleTest "Localhost images valid" Properties.``Localhost images pass validation`` |> ignore
    runSimpleTest "External images fail" Properties.``External images fail validation with critical`` |> ignore

    printfn ""
    printfn "--- Property Test Summary ---"
    printfn "  Passed: %d" passed
    printfn "  Failed: %d" failed
    printfn ""

    (passed, failed)
