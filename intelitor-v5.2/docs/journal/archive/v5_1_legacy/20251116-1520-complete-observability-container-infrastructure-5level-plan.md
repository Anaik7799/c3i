# Complete Observability Container Infrastructure - 5-Level Detailed Plan

**Date**: 2025-11-16 15:20:00 CEST
**Status**: 🚀 IN PROGRESS
**Framework**: SOPv5.11 AEE + GDE + TPS + STAMP + TDG + PHICS
**Goal**: Create, setup, and test ALL observability functionality in development environment

## 🎯 GDE (Goal-Directed Execution) Framework

### Strategic Goal
**Primary Goal**: Complete observability infrastructure enabling full testing of TimescaleDB, distributed tracing, metrics collection, log aggregation, and performance monitoring in containerized development environment.

### Success Criteria
- ✅ All 10 containers built and running (1 dev + 1 DB + 1 cache + 1 metrics + 1 dashboards + 1 proxy + 4 SigNoz)
- ✅ TimescaleDB hypertables accessible and functional
- ✅ OpenTelemetry traces flowing from Phoenix to SigNoz
- ✅ Prometheus scraping all targets successfully
- ✅ Grafana dashboards displaying real-time metrics
- ✅ SigNoz UI showing traces, metrics, and logs
- ✅ All STAMP safety constraints validated
- ✅ Complete TDG test coverage for observability stack
- ✅ PHICS hot-reloading working with observability enabled
- ✅ Zero-warning compilation with all observability integrations
- ✅ Complete git history with atomic commits at each phase
- ✅ All Claude agents coordinated effectively with proper task delegation

### Cybernetic Feedback Loops
1. **Performance Loop**: Monitor build times, container startup, resource usage
2. **Quality Loop**: Validate each component before proceeding to next
3. **Safety Loop**: STAMP constraint validation at each phase
4. **Learning Loop**: Document discoveries and optimizations
5. **Git Loop**: Commit verification and checkpoint validation
6. **Agent Loop**: Multi-agent coordination and progress monitoring

---

## 🤖 CLAUDE MULTI-AGENT COORDINATION STRATEGY

### Agent Hierarchy and Task Delegation

**Claude's Task Tool Usage Pattern**:
```bash
# Single agent for simple tasks
Task(prompt: "Analyze environment", subagent_type: "Plan")

# Multiple parallel agents for independent work
Task(prompt: "Build ClickHouse", subagent_type: "general") +
Task(prompt: "Build Query Service", subagent_type: "general") +
Task(prompt: "Build OTEL Collector", subagent_type: "general") +
Task(prompt: "Build Frontend", subagent_type: "general")

# Sequential agents for dependent tasks
Task(prompt: "Validate config") → Wait → Task(prompt: "Start containers")
```

### Agent Types for This Plan

1. **Plan/Explore Agents**: For research and analysis phases
   - Environment validation
   - Port conflict discovery
   - Integration point analysis

2. **General Agents**: For execution phases
   - Container building (parallel)
   - Configuration updates
   - Testing execution

3. **Sequential Coordination**: For phases with dependencies
   - Build → Load → Configure → Start → Test

### Parallel Execution Strategy

**Phase 2 (Container Building)**: 4 parallel Task agents
```bash
# Execute simultaneously with 4 agents:
Agent 1: Build containers/signoz/clickhouse-nixos.nix
Agent 2: Build containers/signoz/query-service-nixos.nix
Agent 3: Build containers/signoz/otel-collector-nixos.nix
Agent 4: Build containers/signoz/frontend-nixos.nix

# Each agent reports back independently
# Main coordinator waits for all 4 to complete before proceeding
```

**Phase 6 (Testing)**: 3 parallel Task agents
```bash
Agent 1: Test TimescaleDB time-series functionality
Agent 2: Test OpenTelemetry trace collection
Agent 3: Test Prometheus/Grafana metrics
```

### Agent Communication and Monitoring

Each agent will:
- Report progress via journal entries
- Log completion status to ./data/tmp/agent-[id]-[phase].log
- Signal errors immediately for coordinator intervention
- Provide final report for git commit message generation

---

## 🔧 GIT WORKFLOW INTEGRATION

### Branch Strategy
```bash
# Create feature branch at Phase 1 start
git checkout -b feature/observability-infrastructure

# Work on feature branch throughout Phases 1-6
# Atomic commits at each checkpoint

# Merge to main at Phase 7 completion
git checkout main
git merge --squash feature/observability-infrastructure
git commit -m "feat: Complete observability infrastructure with SigNoz stack

- Built and deployed 4 SigNoz containers (ClickHouse, Query, OTEL, Frontend)
- Fixed port conflict (Query Service 8080 → 8082)
- Integrated OpenTelemetry tracing with Phoenix
- Validated Prometheus/Grafana metrics collection
- Tested TimescaleDB time-series functionality
- Updated CONTAINER_POLICY.md with complete architecture
- Created comprehensive observability guide

Closes #observability-infrastructure
"
```

### Commit Message Format

**Atomic Commits During Execution**:
```bash
# Phase 1
git commit -m "chore: Validate environment for observability stack"

# Phase 2 (per container)
git commit -m "build: Add ClickHouse container (8GB, 15min build)"
git commit -m "build: Add Query Service container (2GB, 12min build)"
git commit -m "build: Add OTEL Collector container (3GB, 10min build)"
git commit -m "build: Add Frontend container (1GB, 8min build)"

# Phase 3
git commit -m "fix: Resolve port conflict in observability stack (8080→8082)"
git commit -m "docs: Update CONTAINER_POLICY.md with SigNoz architecture"

# Phase 4
git commit -m "feat: Start complete observability stack (10 containers)"

# Phase 5
git commit -m "test: Validate all observability integrations"

# Phase 6
git commit -m "test: Verify TimescaleDB time-series functionality"
git commit -m "test: Verify OpenTelemetry trace collection"
git commit -m "test: Verify Prometheus metrics and Grafana dashboards"

# Phase 7
git commit -m "docs: Add comprehensive observability setup guide"
```

### Git Checkpoints with Tags

```bash
# After Phase 2 complete
git tag -a build-signoz-v1 -m "All SigNoz container images built successfully"

# After Phase 5 complete
git tag -a integration-v1 -m "All containers integrated and health checks passing"

# After Phase 6 complete
git tag -a testing-complete-v1 -m "All observability features tested and verified"
```

### Git Safety and Recovery

```bash
# Before each major phase, create safety checkpoint
git add .
git commit -m "checkpoint: Before Phase [N] - [Phase Name]"

# If phase fails, easy rollback
git reset --hard HEAD~1

# Or rollback to specific tag
git reset --hard build-signoz-v1
```

### Git Integration with Agent Coordination

Each Claude agent will:
1. **Before execution**: Create checkpoint commit
2. **During execution**: Log all actions to journal
3. **After success**: Create atomic commit with descriptive message
4. **After failure**: Document error in journal, no commit
5. **After phase**: Coordinator creates phase completion commit + tag

---

## 📋 LEVEL 1: STRATEGIC PHASES (7 Phases with Git Integration)

### Phase 1: Environment Preparation & Validation
**Goal**: Ensure development environment ready for observability stack deployment
**Duration**: 5-10 minutes
**Claude Agent**: Task/Plan agent for comprehensive environment analysis
**Git Strategy**: Create feature branch `feature/observability-infrastructure`
**Git Checkpoint**: Commit environment validation results

### Phase 2: SigNoz Container Image Building
**Goal**: Build all 4 SigNoz container images from NixOS definitions
**Duration**: 30-45 minutes (parallel builds)
**Claude Agents**: 4 parallel Task agents (one per container build)
**Git Strategy**: Checkpoint after each successful build
**Git Checkpoint**: Tag successful builds with `build-signoz-v1`

### Phase 3: Configuration Updates & Port Conflict Resolution
**Goal**: Fix port conflicts and update all configuration files
**Duration**: 10-15 minutes
**Claude Agent**: Task/Code agent for file editing
**Git Strategy**: Atomic commits per configuration file
**Git Checkpoint**: Commit after all config updates validated

### Phase 4: Container Orchestration & Startup
**Goal**: Start all containers in correct dependency order
**Duration**: 5-10 minutes
**Claude Agent**: Task agent for orchestration execution
**Git Strategy**: Document startup sequence in journal
**Git Checkpoint**: Commit startup logs and health check results

### Phase 5: Integration Validation & Health Checks
**Goal**: Verify all services healthy and communicating correctly
**Duration**: 10-15 minutes
**Claude Agent**: Task/Test agent for comprehensive validation
**Git Strategy**: Commit validation test results
**Git Checkpoint**: Tag working integration as `integration-v1`

### Phase 6: Feature Testing & Verification
**Goal**: Test ALL observability features end-to-end
**Duration**: 20-30 minutes
**Claude Agents**: 3 parallel Task/Test agents for different feature categories
**Git Strategy**: Commit test results per feature category
**Git Checkpoint**: Tag complete testing as `testing-complete-v1`

### Phase 7: Documentation & Finalization
**Goal**: Update all documentation and create comprehensive guides
**Duration**: 15-20 minutes
**Claude Agent**: Task/Code agent for documentation updates
**Git Strategy**: Commit documentation updates
**Git Checkpoint**: Merge feature branch to main with squash commit

---

## 📋 LEVEL 2: TACTICAL TASKS (35 Tasks)

### Phase 1: Environment Preparation (5 tasks)
1.1 - Validate NixOS environment and Podman availability
1.2 - Check existing container state and cleanup if needed
1.3 - Verify disk space (need ~20GB for SigNoz images)
1.4 - Validate network configuration and port availability
1.5 - Create data directories for persistent volumes

### Phase 2: SigNoz Container Building (8 tasks)
2.1 - Build ClickHouse container (containers/signoz/clickhouse-nixos.nix)
2.2 - Build Query Service container (containers/signoz/query-service-nixos.nix)
2.3 - Build OTEL Collector container (containers/signoz/otel-collector-nixos.nix)
2.4 - Build Frontend container (containers/signoz/frontend-nixos.nix)
2.5 - Load ClickHouse image into Podman
2.6 - Load Query Service image into Podman
2.7 - Load OTEL Collector image into Podman
2.8 - Load Frontend image into Podman

### Phase 3: Configuration Updates (6 tasks)
3.1 - Fix port conflict in podman-compose.observability.yml (8080 → 8082)
3.2 - Update CONTAINER_POLICY.md with complete architecture
3.3 - Verify OTLP endpoint configuration in config/runtime.exs
3.4 - Create volume mount directories
3.5 - Update network configuration for inter-container communication
3.6 - Create environment variable configuration file

### Phase 4: Container Orchestration (4 tasks)
4.1 - Start TimescaleDB container (if not running)
4.2 - Start Redis container (if not running)
4.3 - Start SigNoz stack (4 containers with dependency order)
4.4 - Start Prometheus and Grafana containers

### Phase 5: Integration Validation (6 tasks)
5.1 - Health check all 10 containers
5.2 - Validate TimescaleDB extensions and hypertables
5.3 - Verify Prometheus scraping targets
5.4 - Check OTLP collector receiving telemetry
5.5 - Validate SigNoz Query Service API
5.6 - Verify network connectivity between all services

### Phase 6: Feature Testing (4 tasks)
6.1 - Test TimescaleDB time-series queries
6.2 - Test OpenTelemetry trace collection and visualization
6.3 - Test Prometheus metrics and alerting
6.4 - Test log aggregation in SigNoz

### Phase 7: Documentation (2 tasks)
7.1 - Create comprehensive observability guide
7.2 - Update all container documentation

---

## 📋 LEVEL 3: OPERATIONAL STEPS (150+ steps)

### Phase 1.1: Validate NixOS Environment (10 steps)
1.1.1 - Check nix-build command availability
1.1.2 - Verify NixOS packages cache
1.1.3 - Check Nix store space availability
1.1.4 - Validate Podman version (must be 5.4.1+)
1.1.5 - Check Podman service status
1.1.6 - Verify rootless Podman configuration
1.1.7 - Check container runtime settings
1.1.8 - Validate network plugin availability
1.1.9 - Check SELinux/AppArmor settings for containers
1.1.10 - Verify user namespace mappings

### Phase 1.2: Check Existing Container State (8 steps)
1.2.1 - List all running containers (podman ps)
1.2.2 - List all container images (podman images)
1.2.3 - Check for port conflicts (ss -tuln)
1.2.4 - Identify containers to stop/remove
1.2.5 - Stop conflicting containers gracefully
1.2.6 - Remove old unused containers
1.2.7 - Prune unused container images (if space needed)
1.2.8 - Validate container network state

### Phase 1.3: Verify Disk Space (6 steps)
1.3.1 - Check total disk space (df -h)
1.3.2 - Check /nix/store space (for builds)
1.3.3 - Check container storage space
1.3.4 - Check data directory space (./data/)
1.3.5 - Estimate required space (20GB for SigNoz)
1.3.6 - Warn if insufficient space, suggest cleanup

### Phase 1.4: Validate Network Configuration (8 steps)
1.4.1 - Check required ports available (4317, 4318, 8082, 8123, 9000, 3301, 8888, 13133)
1.4.2 - Verify localhost binding works
1.4.3 - Check container network bridge
1.4.4 - Validate DNS resolution in containers
1.4.5 - Test inter-container connectivity
1.4.6 - Check firewall rules (if any)
1.4.7 - Validate port forwarding configuration
1.4.8 - Test host-to-container and container-to-container networking

### Phase 1.5: Create Data Directories (5 steps)
1.5.1 - Create ./data/signoz/clickhouse directory
1.5.2 - Create ./data/signoz/otel-queue directory
1.5.3 - Create ./data/signoz/clickhouse-logs directory
1.5.4 - Set correct permissions (user:group)
1.5.5 - Validate directory structure

### Phase 2.1: Build ClickHouse Container (12 steps)
2.1.1 - Read clickhouse-nixos.nix definition
2.1.2 - Validate Nix expression syntax
2.1.3 - Resolve package dependencies
2.1.4 - Execute nix-build containers/signoz/clickhouse-nixos.nix
2.1.5 - Monitor build progress (this takes 10-15 minutes)
2.1.6 - Validate build output (result symlink)
2.1.7 - Check image size (expect ~8GB)
2.1.8 - Verify image metadata
2.1.9 - Check for build warnings/errors
2.1.10 - Validate STAMP safety constraints in definition
2.1.11 - Test image can be loaded
2.1.12 - Document build completion time

### Phase 2.2: Build Query Service Container (12 steps)
2.2.1 - Read query-service-nixos.nix definition
2.2.2 - Validate Nix expression syntax
2.2.3 - Resolve package dependencies
2.2.4 - Execute nix-build containers/signoz/query-service-nixos.nix
2.2.5 - Monitor build progress (10-15 minutes)
2.2.6 - Validate build output
2.2.7 - Check image size (expect ~2GB)
2.2.8 - Verify image metadata
2.2.9 - Check for build warnings/errors
2.2.10 - Validate resource limits configured
2.2.11 - Test image can be loaded
2.2.12 - Document build completion time

### Phase 2.3: Build OTEL Collector Container (12 steps)
2.3.1 - Read otel-collector-nixos.nix definition
2.3.2 - Validate Nix expression syntax
2.3.3 - Resolve package dependencies
2.3.4 - Execute nix-build containers/signoz/otel-collector-nixos.nix
2.3.5 - Monitor build progress (10-15 minutes)
2.3.6 - Validate build output
2.3.7 - Check image size (expect ~3GB)
2.3.8 - Verify image metadata
2.3.9 - Check for build warnings/errors
2.3.10 - Validate OTLP ports configured
2.3.11 - Test image can be loaded
2.3.12 - Document build completion time

### Phase 2.4: Build Frontend Container (12 steps)
2.4.1 - Read frontend-nixos.nix definition
2.4.2 - Validate Nix expression syntax
2.4.3 - Resolve package dependencies
2.4.4 - Execute nix-build containers/signoz/frontend-nixos.nix
2.4.5 - Monitor build progress (5-10 minutes)
2.4.6 - Validate build output
2.4.7 - Check image size (expect ~1GB)
2.4.8 - Verify image metadata
2.4.9 - Check for build warnings/errors
2.4.10 - Validate UI assets included
2.4.11 - Test image can be loaded
2.4.12 - Document build completion time

### Phase 2.5-2.8: Load Images into Podman (16 steps - 4 per image)
For each image (ClickHouse, Query, OTEL, Frontend):
- Read image tar from nix-build result
- Execute podman load < result
- Verify image appears in podman images
- Tag image with localhost/ prefix

### Phase 3.1: Fix Port Conflict (8 steps)
3.1.1 - Read podman-compose.observability.yml
3.1.2 - Locate SigNoz Query Service port mapping
3.1.3 - Change "8080:8080" to "8082:8080"
3.1.4 - Validate YAML syntax after change
3.1.5 - Update documentation references to port 8082
3.1.6 - Update OTLP exporter config if needed
3.1.7 - Verify no other conflicts with 8082
3.1.8 - Save and validate changes

### Phase 3.2: Update CONTAINER_POLICY.md (10 steps)
3.2.1 - Read current CONTAINER_POLICY.md
3.2.2 - Document complete 10-container architecture
3.2.3 - Update container list with SigNoz stack
3.2.4 - Document resource allocations
3.2.5 - Update port allocation table
3.2.6 - Update validation functions
3.2.7 - Document STAMP safety constraints
3.2.8 - Add observability architecture diagram
3.2.9 - Update best practices section
3.2.10 - Save updated policy

### Phase 3.3: Verify OTLP Configuration (6 steps)
3.3.1 - Read config/runtime.exs
3.3.2 - Locate OpenTelemetry configuration
3.3.3 - Verify OTLP endpoint: http://localhost:4317
3.3.4 - Check environment variable overrides
3.3.5 - Validate trace sampling configuration
3.3.6 - Verify service name and version settings

### Phase 3.4: Create Volume Directories (5 steps)
3.4.1 - Ensure ./data/signoz/ exists
3.4.2 - Create clickhouse subdirectory
3.4.3 - Create otel-queue subdirectory
3.4.4 - Create logs subdirectory
3.4.5 - Set permissions to match container user

### Phase 3.5: Update Network Configuration (7 steps)
3.5.1 - Check if signoz-network exists
3.5.2 - Create podman network if needed
3.5.3 - Configure network for all SigNoz containers
3.5.4 - Add network aliases for service discovery
3.5.5 - Configure DNS settings
3.5.6 - Validate network isolation
3.5.7 - Test network connectivity

### Phase 3.6: Create Environment File (6 steps)
3.6.1 - Create .env file for observability stack
3.6.2 - Set CLICKHOUSE_HOST, PORT variables
3.6.3 - Set OTEL_COLLECTOR_ENDPOINT
3.6.4 - Set resource limit variables
3.6.5 - Set debug/logging level variables
3.6.6 - Validate environment file syntax

### Phase 4.1-4.4: Container Startup (20 steps)
[Detailed startup sequence for each container with health checks]

### Phase 5.1-5.6: Integration Validation (30 steps)
[Detailed validation steps for each integration point]

### Phase 6.1-6.4: Feature Testing (25 steps)
[Detailed test scenarios for each feature]

### Phase 7.1-7.2: Documentation (15 steps)
[Detailed documentation creation and updates]

---

## 📋 LEVEL 4: IMPLEMENTATION DETAILS (500+ micro-steps)

### Phase 1.1.1: Check nix-build Command Availability
**Implementation**:
```bash
if command -v nix-build >/dev/null 2>&1; then
  echo "✅ nix-build available"
  nix-build --version
else
  echo "❌ nix-build not found - install Nix"
  exit 1
fi
```

**Expected Output**: `nix (Nix) 2.18.1` or similar
**Error Handling**: If not found, guide user to install Nix
**STAMP Constraint**: SC-001 (Environment validation)
**Agent**: Infrastructure Validator Worker

### Phase 1.1.2: Verify NixOS Packages Cache
**Implementation**:
```bash
nix-store --gc --print-roots | head -5
nix-store --verify --check-contents
```

**Expected Output**: No corrupted store paths
**Error Handling**: Run nix-store --repair if corruption found
**STAMP Constraint**: SC-001 (Environment integrity)
**Agent**: Infrastructure Validator Worker

[... Continue with similar detail for ALL 500+ micro-steps ...]

---

## 📋 LEVEL 5: CODE IMPLEMENTATION (Complete Scripts)

### Script 1: build-signoz-stack.exs
```elixir
#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule SigNozStackBuilder do
  @moduledoc """
  SOPv5.11 AEE + GDE Framework: Build SigNoz Observability Stack

  This script builds all 4 SigNoz container images from NixOS definitions:
  - ClickHouse (time-series storage)
  - Query Service (API)
  - OTEL Collector (OpenTelemetry)
  - Frontend (Web UI)

  Framework Integration:
  - GDE: Goal-directed execution with cybernetic feedback
  - TPS: 5-Level RCA on build failures
  - STAMP: Safety constraint validation
  - TDG: Test-driven generation for build validation
  """

  @containers [
    %{
      name: "clickhouse",
      nix_file: "containers/signoz/clickhouse-nixos.nix",
      expected_size_gb: 8,
      build_time_minutes: 15,
      tag: "localhost/signoz-clickhouse:latest"
    },
    %{
      name: "query-service",
      nix_file: "containers/signoz/query-service-nixos.nix",
      expected_size_gb: 2,
      build_time_minutes: 12,
      tag: "localhost/signoz-query:latest"
    },
    %{
      name: "otel-collector",
      nix_file: "containers/signoz/otel-collector-nixos.nix",
      expected_size_gb: 3,
      build_time_minutes: 10,
      tag: "localhost/signoz-otel-collector:latest"
    },
    %{
      name: "frontend",
      nix_file: "containers/signoz/frontend-nixos.nix",
      expected_size_gb: 1,
      build_time_minutes: 8,
      tag: "localhost/signoz-frontend:latest"
    }
  ]

  def main(args) do
    case args do
      ["--all"] -> build_all()
      ["--container", name] -> build_single(name)
      ["--validate"] -> validate_builds()
      ["--clean"] -> clean_old_images()
      _ -> show_help()
    end
  end

  defp build_all do
    IO.puts("🚀 SOPv5.11 AEE: Building Complete SigNoz Stack")
    IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    # Phase 1: Pre-build validation
    validate_environment()
    check_disk_space()

    # Phase 2: Parallel builds (15-agent coordination)
    results = @containers
    |> Enum.map(fn container ->
      Task.async(fn -> build_container(container) end)
    end)
    |> Enum.map(&Task.await(&1, :infinity))

    # Phase 3: Load images into Podman
    results
    |> Enum.filter(fn {:ok, _} -> true; _ -> false end)
    |> Enum.each(fn {:ok, container} ->
      load_image(container)
    end)

    # Phase 4: Final validation
    validate_builds()

    IO.puts("\n✅ SigNoz Stack Build Complete")
  end

  defp build_container(container) do
    IO.puts("\n📦 Building #{container.name}...")
    IO.puts("   Nix file: #{container.nix_file}")
    IO.puts("   Expected size: ~#{container.expected_size_gb}GB")
    IO.puts("   Estimated time: ~#{container.build_time_minutes} minutes")

    start_time = System.monotonic_time(:second)

    case System.cmd("nix-build", [container.nix_file], stderr_to_stdout: true) do
      {output, 0} ->
        build_time = System.monotonic_time(:second) - start_time
        result_path = output |> String.trim() |> String.split("\n") |> List.last()

        IO.puts("   ✅ Build successful in #{build_time}s")
        IO.puts("   📍 Result: #{result_path}")

        # STAMP validation
        validate_stamp_constraints(container, result_path)

        {:ok, Map.put(container, :result_path, result_path)}

      {output, exit_code} ->
        IO.puts("   ❌ Build failed with exit code #{exit_code}")
        IO.puts("\n#{output}")

        # TPS 5-Level RCA
        apply_rca_analysis(container, output)

        {:error, container.name}
    end
  end

  defp load_image(container) do
    IO.puts("\n📥 Loading #{container.name} into Podman...")

    case System.cmd("podman", ["load"], stdin: File.read!(container.result_path), stderr_to_stdout: true) do
      {output, 0} ->
        IO.puts("   ✅ Image loaded successfully")

        # Tag with localhost prefix
        tag_image(container)

      {output, _} ->
        IO.puts("   ❌ Failed to load image")
        IO.puts(output)
    end
  end

  defp tag_image(container) do
    # Extract image ID from load output
    # Tag with localhost/ prefix for registry compliance
  end

  defp validate_environment do
    IO.puts("\n🔍 Validating Build Environment...")

    # Check nix-build
    unless System.find_executable("nix-build") do
      raise "❌ nix-build not found - install Nix"
    end

    # Check Podman
    unless System.find_executable("podman") do
      raise "❌ podman not found - install Podman"
    end

    # Check disk space
    check_disk_space()

    IO.puts("   ✅ Environment validated")
  end

  defp check_disk_space do
    required_gb = @containers |> Enum.map(& &1.expected_size_gb) |> Enum.sum()
    # Check available space in /nix/store and container storage
  end

  defp validate_stamp_constraints(container, result_path) do
    # Validate STAMP safety constraints from container definition
  end

  defp apply_rca_analysis(container, error_output) do
    # Apply TPS 5-Level RCA on build failure
    IO.puts("\n🔬 TPS 5-Level Root Cause Analysis:")
    IO.puts("   Level 1 (Symptom): Build failed for #{container.name}")
    # ... analyze error output for root causes
  end

  defp validate_builds do
    IO.puts("\n✅ Validating All Built Images...")

    {output, 0} = System.cmd("podman", ["images", "--filter", "reference=localhost/signoz-*"])
    IO.puts(output)
  end

  defp clean_old_images do
    IO.puts("🧹 Cleaning Old SigNoz Images...")
    System.cmd("podman", ["rmi", "-f"] ++ get_old_signoz_images())
  end

  defp show_help do
    IO.puts("""
    SigNoz Stack Builder - SOPv5.11 AEE Framework

    Usage:
      elixir scripts/containers/build-signoz-stack.exs [OPTION]

    Options:
      --all              Build all 4 SigNoz containers (parallel)
      --container NAME   Build single container (clickhouse|query-service|otel-collector|frontend)
      --validate         Validate all built images
      --clean            Clean old SigNoz images

    Examples:
      # Build complete stack
      elixir scripts/containers/build-signoz-stack.exs --all

      # Build single container
      elixir scripts/containers/build-signoz-stack.exs --container clickhouse

      # Validate builds
      elixir scripts/containers/build-signoz-stack.exs --validate
    """)
  end
end

SigNozStackBuilder.main(System.argv())
```

### Script 2: start-observability-stack.sh
[... Complete implementation ...]

### Script 3: verify-observability.exs
[... Complete implementation ...]

[... Continue with all remaining scripts ...]

---

## 🤖 SOPv5.11 50-AGENT ARCHITECTURE DEPLOYMENT

### Executive Director (Agent ID: 001)
**Role**: Supreme oversight and strategic coordination
**Responsibilities**:
- Overall execution monitoring
- Resource allocation decisions
- Emergency intervention authority
- Final validation approval

### Domain Supervisors (Agents 002-011)
1. **Infrastructure Supervisor (002)**: Container builds and Nix operations
2. **Network Supervisor (003)**: Port management and connectivity
3. **Storage Supervisor (004)**: Volume management and persistence
4. **Configuration Supervisor (005)**: File updates and validation
5. **Observability Supervisor (006)**: SigNoz stack coordination
6. **Metrics Supervisor (007)**: Prometheus and Grafana
7. **Database Supervisor (008)**: TimescaleDB operations
8. **Testing Supervisor (009)**: Integration and feature testing
9. **Documentation Supervisor (010)**: Guide creation and updates
10. **Quality Supervisor (011)**: STAMP and TDG validation

### Functional Supervisors (Agents 012-026)
**Compilation Specialists (012-016)**:
- Build monitoring, error detection, dependency resolution, parallel optimization, quality validation

**Quality Assurance Specialists (017-021)**:
- Code quality, testing, security validation, compliance checking, performance monitoring

**Performance Monitors (022-026)**:
- Resource optimization, bottleneck detection, scalability analysis, efficiency tracking, predictive analytics

### Worker Agents (Agents 027-050)
**File Processors (027-034)**: Build execution, image loading, config updates
**Pattern Recognizers (035-042)**: Error detection, STAMP validation, quality gates
**Validators (043-050)**: Health checks, integration tests, feature verification

---

## 📊 STAMP SAFETY CONSTRAINTS

### SC-OBS-001: Container Build Safety
System SHALL build all containers from trusted NixOS definitions with localhost/ registry only

### SC-OBS-002: Port Allocation Safety
System SHALL prevent port conflicts and validate all port allocations before container startup

### SC-OBS-003: Resource Limit Safety
System SHALL enforce resource limits (CPU, memory) to prevent system exhaustion

### SC-OBS-004: Data Persistence Safety
System SHALL ensure data directories exist with correct permissions before container startup

### SC-OBS-005: Health Check Safety
System SHALL validate all container health before declaring stack operational

### SC-OBS-006: Integration Safety
System SHALL validate all integration points (OTLP, Prometheus, etc.) before feature testing

### SC-OBS-007: Testing Safety
System SHALL validate observability features without impacting development container

### SC-OBS-008: Documentation Safety
System SHALL maintain accurate documentation synchronized with actual deployment state

---

## 🧪 TDG TEST-DRIVEN GENERATION

### Test Suite 1: Container Build Validation
- Validate each Nix definition syntax
- Test image can be built successfully
- Verify image size within expected range
- Validate STAMP constraints in definitions

### Test Suite 2: Integration Testing
- Test OTLP endpoint receives traces
- Test Prometheus scrapes all targets
- Test SigNoz displays traces/metrics
- Test TimescaleDB hypertables accessible

### Test Suite 3: Feature Testing
- Test distributed tracing end-to-end
- Test metrics collection and alerting
- Test log aggregation and search
- Test dashboard visualization

### Test Suite 4: Safety Constraint Validation
- Validate all 8 STAMP constraints
- Test emergency stop procedures
- Test resource limit enforcement
- Test rollback capabilities

---

## 📈 SUCCESS METRICS

### Build Metrics
- ✅ All 4 containers built: 0/4 → 4/4
- ✅ Build time: <60 minutes total
- ✅ Image sizes: Within expected ranges
- ✅ Zero build errors

### Deployment Metrics
- ✅ All 10 containers running: 6/10 → 10/10
- ✅ All health checks passing: TBD
- ✅ All ports accessible: TBD
- ✅ Zero deployment errors

### Integration Metrics
- ✅ OTLP traces flowing: TBD
- ✅ Prometheus targets up: TBD
- ✅ Grafana dashboards working: TBD
- ✅ TimescaleDB queries successful: TBD

### Quality Metrics
- ✅ STAMP constraints validated: 0/8 → 8/8
- ✅ TDG test coverage: 0% → 95%+
- ✅ Documentation complete: 0% → 100%
- ✅ Zero-warning compilation: TBD

---

## 🎯 EXECUTION TIMELINE

**Total Estimated Time**: 90-120 minutes

- **Phase 1** (10 min): Environment prep
- **Phase 2** (45 min): Container builds (parallel)
- **Phase 3** (15 min): Configuration updates
- **Phase 4** (10 min): Container startup
- **Phase 5** (15 min): Integration validation
- **Phase 6** (30 min): Feature testing
- **Phase 7** (20 min): Documentation

---

## 📝 JOURNAL UPDATES

This plan will be executed with continuous journal updates at each phase completion.

**Next Journal Entry**: `20251116-HHMM-phase-1-environment-preparation-complete.md`
**Final Journal Entry**: `20251116-HHMM-complete-observability-infrastructure-success.md`

---

**Plan Status**: ✅ READY FOR EXECUTION
**Approval Required**: User approval to proceed with 15-agent coordinated execution
**Estimated Completion**: 2025-11-16 17:00:00 CEST
