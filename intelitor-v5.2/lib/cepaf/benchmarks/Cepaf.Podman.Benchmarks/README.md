# Cepaf.Podman Benchmarks

Performance benchmark suite for the Cepaf.Podman F# library using BenchmarkDotNet.

## Overview

This benchmark suite measures the performance characteristics of key operations in Cepaf.Podman:

- **JSON Parsing**: Parsing container, image, volume, and network list responses from the Podman API
- **Compose Parsing**: Parsing podman-compose/docker-compose YAML files
- **Serialization**: Serializing container, pod, network, and volume specs to JSON
- **Health Probes**: In-memory health check result processing and status classification

## Requirements

- .NET 8.0 SDK
- Built Cepaf.Podman library

## Running Benchmarks

### Quick Start

```bash
# Navigate to benchmark directory
cd lib/cepaf/benchmarks/Cepaf.Podman.Benchmarks

# Restore dependencies
dotnet restore

# Run all benchmarks (Release mode required for accurate results)
dotnet run -c Release
```

### Running Specific Benchmark Categories

```bash
# JSON Parsing benchmarks
dotnet run -c Release -- --json

# Compose file parsing benchmarks
dotnet run -c Release -- --compose

# Serialization benchmarks
dotnet run -c Release -- --serialization

# Health probe benchmarks
dotnet run -c Release -- --health

# All benchmarks
dotnet run -c Release -- --all
```

### Help

```bash
dotnet run -c Release -- --help
```

## Benchmark Categories

### 1. JSON Parsing Benchmarks (`JsonParsingBenchmarks.fs`)

Measures the performance of parsing Podman API JSON responses:

| Benchmark | Description |
|-----------|-------------|
| ParseContainerList_1 | Parse JSON with 1 container |
| ParseContainerList_10 | Parse JSON with 10 containers |
| ParseContainerList_50 | Parse JSON with 50 containers |
| ParseContainerList_100 | Parse JSON with 100 containers (baseline) |
| ParseImageList_* | Image list parsing with varying counts |
| ParseVolumeList_* | Volume list parsing |
| ParseNetworkList_* | Network list parsing |

### 2. Compose Parsing Benchmarks (`ComposeParseBenchmarks.fs`)

Measures YAML parsing performance for compose files:

| Benchmark | Description |
|-----------|-------------|
| ParseSimpleCompose | Parse 2-service compose file |
| ParseComplexCompose_5 | Parse 5-service compose file |
| ParseComplexCompose_10 | Parse 10-service compose file (baseline) |
| ParseComplexCompose_20 | Parse 20-service compose file |
| ParseDuration_* | Duration string parsing (30s, 5m, 2h, 500ms) |
| ParseMemory_* | Memory string parsing (512M, 2G, 1024K) |
| ParsePort_* | Port string parsing |
| ParseVolume_* | Volume string parsing |
| GetDeploymentOrder_* | Topological sort for service dependencies |

### 3. Serialization Benchmarks (`SerializationBenchmarks.fs`)

Measures JSON serialization performance:

| Benchmark | Description |
|-----------|-------------|
| SerializeSimpleContainerSpec | Simple container spec to JSON |
| SerializeComplexContainerSpec | Complex container spec with all options (baseline) |
| SerializeSimplePodSpec | Simple pod spec to JSON |
| SerializeComplexPodSpec | Complex pod spec to JSON |
| SerializeNetworkSpec | Network spec to JSON |
| SerializeVolumeSpec | Volume spec to JSON |
| *StatusParse | Type parsing benchmarks |

### 4. Health Probe Benchmarks (`HealthProbeBenchmarks.fs`)

Measures in-memory health check operations:

| Benchmark | Description |
|-----------|-------------|
| CreateDefaultProbeConfig | Create default probe configuration |
| ConfigureProbeWithOptions | Configure probe with custom options |
| FilterHealthyFrom100 | Filter healthy containers from 100 results |
| FilterUnhealthyFrom100 | Filter unhealthy containers (baseline) |
| ClassifyAllResultsByStatus | Classify 100 results by health status |
| BuildResultMapFrom* | Build container result maps |
| DetectStatusChanges | Detect status changes between result sets |

## Output

Benchmark results are generated in multiple formats:

- **Console**: Real-time progress and summary
- **Markdown**: GitHub-flavored markdown report (`BenchmarkDotNet.Artifacts/*.md`)
- **JSON**: Machine-readable results (`BenchmarkDotNet.Artifacts/*.json`)
- **HTML**: Interactive HTML report (`BenchmarkDotNet.Artifacts/*.html`)

## Interpreting Results

### Key Metrics

- **Mean**: Average execution time
- **Error**: Half of the 99.9% confidence interval
- **StdDev**: Standard deviation of measurements
- **Gen0/Gen1/Gen2**: Garbage collection counts per 1000 operations
- **Allocated**: Memory allocated per operation
- **Ratio**: Performance relative to baseline benchmark

### Example Output

```
|                     Method |      Mean |    Error |   StdDev | Ratio |   Gen0 |   Gen1 | Allocated |
|--------------------------- |----------:|---------:|---------:|------:|-------:|-------:|----------:|
| ParseContainerList_1       |  12.34 us | 0.123 us | 0.115 us |  0.10 | 1.2345 |      - |   5.12 KB |
| ParseContainerList_10      |  45.67 us | 0.456 us | 0.427 us |  0.38 | 4.5678 |      - |  18.45 KB |
| ParseContainerList_50      |  98.76 us | 0.987 us | 0.923 us |  0.82 | 9.8765 | 0.1234 |  45.23 KB |
| ParseContainerList_100     | 120.45 us | 1.204 us | 1.127 us |  1.00 | 12.345 | 0.2345 |  78.90 KB |
```

## Configuration

The benchmarks use the following BenchmarkDotNet configuration:

- **Runtime**: .NET 8.0
- **Diagnosers**: Memory diagnoser (tracks allocations and GC)
- **Exporters**: JSON, Markdown (GitHub), HTML
- **Statistics**: All statistical columns including median, P95, etc.

## Adding New Benchmarks

1. Create a new benchmark class with `[<MemoryDiagnoser>]` and `[<SimpleJob(RuntimeMoniker.Net90)>]` attributes
2. Add `[<GlobalSetup>]` method to prepare test data
3. Add benchmark methods with `[<Benchmark>]` attribute
4. Mark one benchmark as `Baseline = true` for ratio comparison
5. Add the file to the project's `<Compile>` items in order

## Performance Guidelines

When reviewing results, consider these targets:

| Operation | Target | Notes |
|-----------|--------|-------|
| Container list parse (100) | < 200us | Main API response parsing |
| Compose file parse (10 svc) | < 500us | YAML is slower than JSON |
| Container spec serialize | < 50us | Used for every create operation |
| Health status classification | < 1us | Must be fast for polling |

## Troubleshooting

### Benchmarks too slow

- Ensure running in Release configuration (`-c Release`)
- Close other applications to reduce interference
- Consider running fewer iterations for development

### Memory issues

- Large test data (100+ containers) may require more heap
- GC pressure is normal for parsing operations

### Results vary significantly

- Run multiple times and compare medians
- Check for background processes
- Ensure CPU governor is set to performance mode
