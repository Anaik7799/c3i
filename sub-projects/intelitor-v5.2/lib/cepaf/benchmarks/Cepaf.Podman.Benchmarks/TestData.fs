namespace Cepaf.Podman.Benchmarks

open System
open Cepaf.Podman.Domain

/// Test data generators for benchmarks
module TestData =

    // ========================================================================
    // Container JSON Test Data
    // ========================================================================

    /// Generate a single container JSON object
    let generateContainerJson (index: int) =
        sprintf """{
            "Id": "abc123def456789%06d",
            "Names": ["/container_%d"],
            "Image": "localhost/indrajaal-app:v5.2.%d",
            "ImageID": "sha256:abc123def456789%06d0123456789abcdef0123456789abcdef0123456789abcdef",
            "Command": "mix phx.server --port 400%d",
            "Created": %d,
            "State": "%s",
            "Status": "Up %d hours",
            "Ports": [
                {"container_port": 4000, "host_port": %d, "protocol": "tcp"},
                {"container_port": 9568, "host_port": %d, "protocol": "tcp"}
            ],
            "Labels": {
                "io.containers.autoupdate": "registry",
                "org.opencontainers.image.title": "indrajaal-app",
                "com.cepaf.service": "service-%d",
                "com.cepaf.version": "5.2.%d"
            },
            "Mounts": [
                {"Type": "bind", "Source": "/data/config_%d", "Destination": "/app/config", "RW": true},
                {"Type": "volume", "Source": "data_vol_%d", "Destination": "/app/data", "RW": true}
            ],
            "Networks": ["indrajaal_network", "monitoring_network"]
        }"""
            index index index index
            (index % 10)
            (1700000000L + int64 index)
            (if index % 4 = 0 then "running" elif index % 4 = 1 then "created" elif index % 4 = 2 then "exited" else "paused")
            (index % 24 + 1)
            (4000 + index) (9568 + index)
            index index index index

    /// Generate container list JSON with specified count
    let generateContainerListJson (count: int) : string =
        let containers =
            [ for i in 0 .. count - 1 -> generateContainerJson i ]
            |> String.concat ",\n"
        sprintf "[%s]" containers

    // ========================================================================
    // Image JSON Test Data
    // ========================================================================

    /// Generate a single image JSON object
    let generateImageJson (index: int) =
        sprintf """{
            "Id": "sha256:img%06d0123456789abcdef0123456789abcdef0123456789abcdef0123456789ab",
            "RepoTags": ["localhost/image_%d:latest", "localhost/image_%d:v1.0.%d"],
            "RepoDigests": ["localhost/image_%d@sha256:digest%06d0123456789abcdef"],
            "Created": %d,
            "Size": %d,
            "VirtualSize": %d,
            "Labels": {
                "maintainer": "team@example.com",
                "org.opencontainers.image.version": "1.0.%d",
                "org.opencontainers.image.title": "image_%d"
            },
            "Containers": %d
        }"""
            index index index index index index
            (1700000000L + int64 index)
            (100000000L + int64 (index * 50000000))
            (150000000L + int64 (index * 75000000))
            index index
            (index % 5)

    /// Generate image list JSON with specified count
    let generateImageListJson (count: int) : string =
        let images =
            [ for i in 0 .. count - 1 -> generateImageJson i ]
            |> String.concat ",\n"
        sprintf "[%s]" images

    // ========================================================================
    // Volume JSON Test Data
    // ========================================================================

    /// Generate a single volume JSON object
    let generateVolumeJson (index: int) =
        sprintf """{
            "Name": "volume_%d",
            "Driver": "local",
            "Mountpoint": "/var/lib/containers/storage/volumes/volume_%d/_data",
            "CreatedAt": "2024-12-23T10:00:00.%06dZ",
            "Labels": {
                "com.cepaf.app": "indrajaal",
                "com.cepaf.volume.type": "data"
            },
            "Options": {
                "device": "tmpfs",
                "o": "size=100m,uid=1000"
            },
            "Scope": "local"
        }"""
            index index index

    /// Generate volume list JSON
    let generateVolumeListJson (count: int) : string =
        let volumes =
            [ for i in 0 .. count - 1 -> generateVolumeJson i ]
            |> String.concat ",\n"
        sprintf "[%s]" volumes

    // ========================================================================
    // Network JSON Test Data
    // ========================================================================

    /// Generate a single network JSON object
    let generateNetworkJson (index: int) =
        sprintf """{
            "name": "network_%d",
            "id": "net%06d0123456789abcdef",
            "driver": "%s",
            "created": "2024-12-23T10:00:00.%06dZ",
            "subnets": [
                {"subnet": "10.%d.0.0/16", "gateway": "10.%d.0.1"}
            ],
            "internal": %s,
            "dns_enabled": true,
            "labels": {
                "com.cepaf.network.type": "app"
            },
            "options": {}
        }"""
            index index
            (if index % 3 = 0 then "bridge" elif index % 3 = 1 then "macvlan" else "host")
            index
            (index % 256) (index % 256)
            (if index % 2 = 0 then "false" else "true")

    /// Generate network list JSON
    let generateNetworkListJson (count: int) : string =
        let networks =
            [ for i in 0 .. count - 1 -> generateNetworkJson i ]
            |> String.concat ",\n"
        sprintf "[%s]" networks

    // ========================================================================
    // Compose File Test Data
    // ========================================================================

    /// Generate a simple compose file YAML
    let generateSimpleComposeYaml () = """
version: '3.8'

services:
  app:
    image: localhost/indrajaal-app:latest
    ports:
      - "4000:4000"
    volumes:
      - ./data:/app/data
    depends_on:
      - db
    restart: unless-stopped

  db:
    image: postgres:17
    ports:
      - "5433:5432"
    volumes:
      - db_data:/var/lib/postgresql/data
    environment:
      POSTGRES_PASSWORD: secret
    restart: always

volumes:
  db_data:
"""

    /// Generate a complex compose file YAML with multiple services
    let generateComplexComposeYaml (serviceCount: int) =
        let services =
            [ for i in 0 .. serviceCount - 1 ->
                sprintf """  service_%d:
    image: localhost/service_%d:latest
    ports:
      - "%d:%d"
      - "%d:%d/udp"
    volumes:
      - ./config_%d:/app/config:ro
      - data_%d:/app/data
    depends_on:%s
    restart: unless-stopped
    labels:
      com.cepaf.service: "service_%d"
      com.cepaf.version: "1.0.%d"
    cap_add:
      - SYS_PTRACE
    cap_drop:
      - NET_ADMIN
    security_opt:
      - no-new-privileges:true
"""
                    i i
                    (4000 + i) (4000 + i)
                    (9000 + i) (9000 + i)
                    i i
                    (if i > 0 then sprintf "\n      - service_%d" (i - 1) else "")
                    i i
            ]
            |> String.concat "\n"

        let volumes =
            [ for i in 0 .. serviceCount - 1 -> sprintf "  data_%d:" i ]
            |> String.concat "\n"

        sprintf """version: '3.8'

services:
%s

networks:
  default:
    driver: bridge

volumes:
%s
        """ services volumes

    // ========================================================================
    // Container Spec Test Data
    // ========================================================================

    /// Create a simple container spec
    let createSimpleContainerSpec () =
        ContainerSpec.create "localhost/indrajaal-app:latest"
        |> ContainerSpec.withName "test-container"
        |> ContainerSpec.withPort 4000us 4000us
        |> ContainerSpec.withEnv "MIX_ENV" "prod"
        |> ContainerSpec.withLabel "app" "indrajaal"

    /// Create a complex container spec with many options
    let createComplexContainerSpec () =
        let healthCheck = {
            Test = HealthCheckTest.Cmd ["curl"; "-f"; "http://localhost:4000/health"]
            Interval = Some (TimeSpan.FromSeconds(30.0))
            Timeout = Some (TimeSpan.FromSeconds(10.0))
            StartPeriod = Some (TimeSpan.FromSeconds(60.0))
            StartInterval = None
            Retries = Some 3
        }

        let resources = {
            Memory = Some { Limit = Some (512L * 1024L * 1024L); Reservation = Some (256L * 1024L * 1024L); Swap = None; Swappiness = None; DisableOOMKiller = None }
            Cpu = Some { Shares = Some 1024UL; Quota = Some 100000L; Period = None; Cpus = None; Mems = None }
            PidsLimit = Some 100L
        }

        ContainerSpec.create "localhost/indrajaal-app:latest"
        |> ContainerSpec.withName "complex-container"
        |> ContainerSpec.withCommand ["mix"; "phx.server"]
        |> ContainerSpec.withEntrypoint ["/app/entrypoint.sh"]
        |> ContainerSpec.withWorkDir "/app"
        |> ContainerSpec.withPort 4000us 4000us
        |> ContainerSpec.withPort 9568us 9568us
        |> ContainerSpec.withEnv "MIX_ENV" "prod"
        |> ContainerSpec.withEnv "SECRET_KEY_BASE" "very-long-secret-key-base-value"
        |> ContainerSpec.withEnv "DATABASE_URL" "ecto://postgres:secret@db:5432/indrajaal_prod"
        |> ContainerSpec.withEnv "PHX_HOST" "localhost"
        |> ContainerSpec.withLabel "app" "indrajaal"
        |> ContainerSpec.withLabel "version" "5.2.0"
        |> ContainerSpec.withLabel "maintainer" "team@example.com"
        |> ContainerSpec.withMount (Mount.createBind "/data/config" "/app/config" |> Mount.withReadOnly)
        |> ContainerSpec.withVolume "app_data" "/app/data"
        |> ContainerSpec.withHealthCheck healthCheck
        |> ContainerSpec.withResources resources
        |> ContainerSpec.withRestartPolicy RestartPolicy.always
        |> ContainerSpec.withStopTimeout 30

    // ========================================================================
    // Pod Spec Test Data
    // ========================================================================

    /// Create a simple pod spec
    let createSimplePodSpec () =
        PodSpec.create ()
        |> PodSpec.withName "test-pod"
        |> PodSpec.withHostname "test-pod-host"
        |> PodSpec.withPort 4000us 4000us

    /// Create a complex pod spec
    let createComplexPodSpec () =
        let createPort hostPort containerPort =
            { ContainerPort = containerPort; HostPort = Some hostPort; HostIP = None; Protocol = PortProtocol.TCP; Range = None }

        { PodSpec.create () with
            Name = Some "complex-pod"
            Hostname = Some "complex-pod-host"
            PortMappings = [
                createPort 4000us 4000us
                createPort 4001us 4001us
                createPort 9568us 9568us
            ]
            Labels = Map.ofList [
                ("app", "indrajaal")
                ("environment", "production")
                ("version", "5.2.0")
            ]
        }

    // ========================================================================
    // Network/Volume Spec Test Data
    // ========================================================================

    /// Create a network spec
    let createNetworkSpec () =
        NetworkSpec.create "test-network"
        |> NetworkSpec.withDriver NetworkDriver.Bridge
        |> NetworkSpec.withSubnet "10.89.0.0/16" (Some "10.89.0.1")

    /// Create a volume spec
    let createVolumeSpec () =
        VolumeSpec.create "test-volume"
        |> VolumeSpec.withDriver VolumeDriver.Local
        |> VolumeSpec.withLabel "app" "indrajaal"
        |> VolumeSpec.withOption "device" "tmpfs"
