# CEPAF Compose Generator

**Version**: 21.3.0-SIL6
**Date**: 2026-01-18

## Overview

The ComposeGenerator module provides deterministic generation of `podman-compose.yml` files from centralized configuration. This ensures **single source of truth** for all container orchestration.

## STAMP Compliance

| ID | Constraint | Implementation |
|----|------------|----------------|
| SC-CONSOL-004 | Generated files MUST be deterministic | Sorted output, no randomness |
| SC-CONFIG-001 | All configuration from single source | MeshConfig.fs |
| SC-CONFIG-002 | NO magic values in generated files | All values from config |
| SC-MESH-001 | Support all 15 SIL-6 containers | Full container support |
| SC-BOOT-009 | Wave-based dependency ordering | Wave field in ContainerSpec |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    COMPOSE GENERATOR                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  MeshConfig.fs (Single Source of Truth)                     │
│       │                                                      │
│       ├── NetworkConfig (Ports, IPs, Hostnames)             │
│       ├── ContainerConfig (Images, Resources, Health)       │
│       ├── EnvironmentConfig (Env vars, URLs)                │
│       └── VolumeConfig (Named volumes, Paths)               │
│                                                              │
│  ComposeGenerator.fs                                         │
│       │                                                      │
│       ├── ComposeTypes (ContainerSpec, NetworkSpec, etc.)   │
│       ├── YamlGen (YAML formatting utilities)               │
│       ├── NetworkGen (Network YAML generation)              │
│       ├── VolumeGen (Volume YAML generation)                │
│       ├── ServiceGen (Service YAML generation)              │
│       └── MeshConfigBuilder (Pre-built configurations)      │
│                                                              │
│  Output: podman-compose.yml                                  │
│       ├── networks:                                          │
│       ├── volumes:                                           │
│       └── services: (sorted by wave, then name)             │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Type System

### Core Types

```fsharp
type ContainerSpec = {
    Name: string                    // Container name
    Hostname: string                // Network hostname
    Image: string                   // Container image
    Networks: NetworkAttachment list
    Environment: Map<string, string>
    Ports: PortMapping list
    Volumes: VolumeMount list
    HealthCheck: HealthCheck option
    Resources: Resources option
    DependsOn: Dependency list
    Restart: string
    Labels: Map<string, string>
    Wave: int                       // Boot wave (1-5)
}

type NetworkSpec = {
    Name: string
    Driver: string                  // "bridge"
    Internal: bool
    Subnet: string option
    Gateway: string option
}

type VolumeSpec = {
    Name: string
    Driver: string                  // "local"
    Labels: Map<string, string>
}

type MeshConfig = {
    Version: string                 // "3.8"
    Networks: NetworkSpec list
    Volumes: VolumeSpec list
    Services: ContainerSpec list
}
```

## API Reference

### Core Functions

```fsharp
/// Generate complete podman-compose.yml from config
val generateFromConfig : MeshConfig -> string

/// Validate generated YAML against config
val validateCompose : string -> MeshConfig -> Result<unit, ValidationError list>

/// Generate single service YAML
val generateService : ContainerSpec -> string

/// Generate network YAML
val generateNetwork : NetworkSpec -> string

/// Generate volume YAML
val generateVolume : VolumeSpec -> string
```

### Builder Functions

```fsharp
/// Create database container spec
val createDbContainer : unit -> ContainerSpec

/// Create observability container spec
val createObsContainer : unit -> ContainerSpec

/// Create Zenoh router container spec (1-3)
val createZenohRouter : int -> ContainerSpec

/// Create application container spec (1-3)
val createAppContainer : int -> ContainerSpec

/// Create complete SIL-6 full mesh configuration
val createSil6FullMesh : unit -> MeshConfig
```

## Usage Examples

### 1. Generate SIL-6 Full Mesh

```fsharp
open Cepaf.Config.ComposeGenerator
open Cepaf.Config.MeshConfigBuilder

// Create configuration
let config = createSil6FullMesh ()

// Generate YAML
let yaml = generateFromConfig config

// Validate
match validateCompose yaml config with
| Ok () -> printfn "✓ Valid"
| Error errors -> errors |> List.iter (printfn "%A")

// Save to file
System.IO.File.WriteAllText("podman-compose.yml", yaml)
```

### 2. Custom Configuration

```fsharp
open Cepaf.Config.ComposeTypes

let customConfig = {
    Version = "3.8"
    Networks = [
        {
            Name = "my-network"
            Driver = "bridge"
            Internal = false
            Subnet = Some "172.30.0.0/16"
            Gateway = Some "172.30.0.1"
        }
    ]
    Volumes = [
        { Name = "my-data"; Driver = "local"; Labels = Map.empty }
    ]
    Services = [
        {
            Name = "my-service"
            Hostname = "my-service"
            Image = "localhost/my-image:latest"
            Networks = [
                { Name = "my-network"; IpAddress = Some "172.30.0.10" }
            ]
            Environment = Map.ofList [("KEY", "value")]
            Ports = [{ Host = 8080; Container = 80; Protocol = "tcp" }]
            Volumes = []
            HealthCheck = None
            Resources = None
            DependsOn = []
            Restart = "unless-stopped"
            Labels = Map.empty
            Wave = 1
        }
    ]
}

let yaml = generateFromConfig customConfig
```

### 3. CLI Usage

```bash
# Generate SIL-6 full mesh
dotnet fsi lib/cepaf/scripts/generate_compose.fsx --mesh sil6

# Generate with validation
dotnet fsi lib/cepaf/scripts/generate_compose.fsx --mesh sil6 --validate

# Generate to custom output
dotnet fsi lib/cepaf/scripts/generate_compose.fsx \
    --mesh sil6 \
    --output custom.yml \
    --verbose

# Run demo
dotnet fsi lib/cepaf/scripts/demo_compose_generator.fsx
```

## Supported Containers (14 Total)

### Wave 1: Infrastructure (2 containers)
- `indrajaal-db-prod` - PostgreSQL 17 + TimescaleDB
- `indrajaal-obs-prod` - OTEL + Prometheus + Grafana + Loki

### Wave 2: Zenoh Control Plane (3 containers)
- `zenoh-router-1` - Primary router (7447)
- `zenoh-router-2` - Secondary router (7448)
- `zenoh-router-3` - Tertiary router (7449)

### Wave 3: Application Nodes (3 containers)
- `indrajaal-ex-app-1` - Seed node (4000)
- `indrajaal-ex-app-2` - HA node 2 (4003)
- `indrajaal-ex-app-3` - HA node 3 (4005)

### Wave 4: Cognitive Plane (2 containers)
- `cepaf-bridge` - F# CEPAF bridge (9876)
- `indrajaal-cortex` - F# Cortex AI brain (9877)

### Wave 5: Satellite Plane (2 containers)
- `indrajaal-ml-runner-1` - FLAME ML runner
- `indrajaal-ml-runner-2` - FLAME ML runner

### Additional Services (2 containers)
- `indrajaal-chaya` - Digital Twin (4002)
- Additional app nodes as needed

## Wave-Based Boot Ordering

Services are organized into waves for ordered startup:

```
Wave 1 (Infrastructure):
  └─> Database, Observability

Wave 2 (Control Plane):
  └─> Zenoh Routers (depends on Wave 1)

Wave 3 (Application):
  └─> App Nodes (depends on Wave 1 + Wave 2)

Wave 4 (Cognitive):
  └─> CEPAF Bridge, Cortex (depends on Wave 3)

Wave 5 (Satellite):
  └─> ML Runners (depends on Wave 4)
```

## Validation

The generator performs comprehensive validation:

### Port Uniqueness
- Ensures no port conflicts across services
- Reports duplicate port assignments

### Dependency Validation
- Verifies all `depends_on` services exist
- Detects circular dependencies

### Network Validation
- Ensures all referenced networks are defined
- Validates IP address assignments

### Volume Validation
- Ensures all referenced volumes are defined
- Validates mount configurations

## YAML Generation Rules

1. **Deterministic Output**: Services sorted by wave, then name
2. **Proper Indentation**: 2 spaces per level
3. **Quote Special Values**: Auto-quote strings with `:`  or `#`
4. **Comment Waves**: Each service annotated with wave number
5. **Sorted Maps**: Environment variables and labels sorted by key
6. **Sorted Lists**: Ports sorted by host port

## Integration with Existing Systems

### MeshConfig.fs Integration
- All port numbers from `NetworkConfig.Ports`
- All IP addresses from `NetworkConfig.IpAddresses`
- All hostnames from `NetworkConfig.Hostnames`
- All images from `ContainerConfig.Images`
- All resources from `ContainerConfig.Resources`
- All health checks from `ContainerConfig.HealthChecks`

### Backward Compatibility
- Generates YAML compatible with existing compose files
- Preserves all existing functionality
- Can replace manual compose files

## Testing

```bash
# Run demo (shows all features)
dotnet fsi lib/cepaf/scripts/demo_compose_generator.fsx

# Generate and validate
dotnet fsi lib/cepaf/scripts/generate_compose.fsx --mesh sil6 --validate --verbose

# Verify against existing
diff lib/cepaf/artifacts/podman-compose-sil6-full-mesh.yml \
     lib/cepaf/artifacts/generated-sil6-full-mesh.yml
```

## Benefits

1. **Single Source of Truth**: All configuration in `MeshConfig.fs`
2. **No Magic Values**: All values come from centralized config
3. **Type Safety**: F# type system prevents errors
4. **Deterministic**: Same config always produces same YAML
5. **Validated**: Built-in validation catches errors early
6. **Extensible**: Easy to add new containers or networks
7. **Maintainable**: Change config once, regenerate all files

## Future Enhancements

- [ ] Support for secrets management
- [ ] Support for Docker Swarm mode
- [ ] Support for Kubernetes YAML generation
- [ ] Support for terraform/tofu generation
- [ ] Support for health check customization per environment
- [ ] Support for resource limit profiles (dev/staging/prod)

## Related Documents

- `MeshConfig.fs` - Centralized configuration
- `CLAUDE.md` - System specification
- `.claude/rules/fsharp-sil6-mesh.md` - Mesh orchestration rules
- `docs/architecture/HOLON_FOUNDERS_DIRECTIVE.md` - Supreme covenant

## Change History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2026-01-18 | Claude Opus 4.5 | Initial implementation |
