# 🚨 **5-LEVEL COMPREHENSIVE PLAN: NixOS Container Setup & Verification** ✅ **COMPLETE INFRASTRUCTURE**

**Date**: 2025-09-10 15:29:00 CEST  
**Status**: 🔬 COMPREHENSIVE 5-LEVEL PLANNING DOCUMENT  
**Framework**: SOPv5.1 + TPS + STAMP + TDG + GDE + PHICS + Container-Only  
**Agent**: Container Infrastructure Planning Coordinator  
**Scope**: Complete NixOS container infrastructure for Indrajaal Security Monitoring System

---

## 🎯 **LEVEL 1: SYMPTOMS & OBSERVABLE REQUIREMENTS**

### **1.1 Current State Issues**
1. **Container Registry Violation**: Current container `indrajaal-dev-app` using `docker.io/nixos/nix:latest` instead of localhost registry
2. **SSL Certificate Failures**: Erlang/Elixir cannot find SSL certificates in containers
3. **Missing Unified Setup**: No single orchestration script for all containers
4. **Incomplete Validation**: Missing comprehensive test framework
5. **Documentation Fragmentation**: Container docs scattered across multiple locations
6. **PHICS Integration Gaps**: Hot-reloading not validated across container boundaries

### **1.2 Required End State**
1. **6 Production Containers Running**:
   - `indrajaal-timescaledb-demo` (PostgreSQL 17 + TimescaleDB)
   - `indrajaal-redis-demo` (Redis 7 Cache)
   - `indrajaal-app-demo` (Elixir/Phoenix Application)
   - `indrajaal-prometheus-demo` (Metrics Collection)
   - `indrajaal-grafana-demo` (Dashboard Visualization)
   - `indrajaal-nginx-demo` (Load Balancer/Reverse Proxy)

2. **All Containers NixOS-Based**: Zero tolerance for Alpine/Ubuntu/other distributions
3. **Local Registry Only**: All images with `localhost/` prefix
4. **SSL Certificates Working**: No `:no_cacerts_found` errors
5. **PHICS Hot-Reloading**: File changes reflected in containers
6. **Complete Automation**: Setup without manual intervention
7. **Comprehensive Documentation**: All procedures documented and validated

### **1.3 Observable Success Metrics**
- Container health checks: 100% passing
- SSL certificate validation: `public_key:cacerts_get()` returns certificates
- Registry compliance: 0 external registry pulls
- PHICS validation: <50ms file sync latency
- Test coverage: 86+ validation checks passing
- Documentation: Complete setup guide with troubleshooting

---

## 🔍 **LEVEL 2: SURFACE CAUSES & IMMEDIATE ACTIONS**

### **2.1 Technical Root Causes**
1. **SSL Certificate Path Mismatch**:
   - Erlang expects: `/etc/ssl/certs/ca-bundle.crt`
   - NixOS provides: `/nix/store/*/ca-bundle.crt`
   - Solution: Multi-path symlink strategy

2. **Container Image Sources**:
   - Current: Mixed sources (docker.io, Alpine-based)
   - Required: Pure NixOS images only
   - Solution: Build all images from NixOS base

3. **Missing Orchestration**:
   - Current: Manual container startup
   - Required: Automated dependency-based startup
   - Solution: Master orchestration script

### **2.2 Immediate Action Items**

#### **Phase 2.1: Environment Cleanup (15 minutes)**
```bash
# Remove violating containers
podman rm -f indrajaal-dev-app

# Clean up images
podman rmi docker.io/nixos/nix:latest

# Create proper network
podman network create indrajaal-app --subnet 172.29.0.0/24

# Setup logging directory
mkdir -p ./data/tmp
```

#### **Phase 2.2: Documentation Organization (10 minutes)**
```bash
# Move 5-level analysis to containers folder
mv docs/journal/20250910-1351-comprehensive-nixos-container-setup-5level-analysis.md \
   docs/containers/

# Create documentation structure
mkdir -p docs/containers/setup
mkdir -p docs/containers/validation
mkdir -p docs/containers/troubleshooting
```

#### **Phase 2.3: Initial Validation Scripts (20 minutes)**
Create basic validation to ensure prerequisites:
- `scripts/containers/prerequisite_validator.exs`
- `scripts/containers/registry_enforcer.exs`
- `scripts/containers/network_validator.exs`

---

## 🏗️ **LEVEL 3: SYSTEM BEHAVIOR & ARCHITECTURE**

### **3.1 Container Architecture Design**

#### **3.1.1 Network Architecture**
```yaml
Network: indrajaal-app (bridge)
Subnet: 172.29.0.0/24
Gateway: 172.29.0.1

Container IPs:
- PostgreSQL: 172.29.0.10
- Redis: 172.29.0.11
- Application: 172.29.0.20
- Prometheus: 172.29.0.30
- Grafana: 172.29.0.31
- Nginx: 172.29.0.40
```

#### **3.1.2 Dependency Graph**
```
[PostgreSQL] ─┐
              ├─> [Application] ─> [Nginx] ─> External
[Redis] ──────┘         │
                        ├─> [Prometheus] ─> [Grafana]
```

#### **3.1.3 Volume Mounts**
```yaml
PostgreSQL:
  - ./data/timescaledb:/var/lib/postgresql/data:z
  - ./priv/repo/migrations:/docker-entrypoint-initdb.d:ro
  
Redis:
  - ./data/redis:/data:z
  
Application:
  - .:/workspace:z  # PHICS hot-reloading
  - ./data/tmp:/var/log/claude:z
  
Prometheus:
  - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml:ro
  - ./data/prometheus:/prometheus:z
  
Grafana:
  - ./monitoring/grafana:/etc/grafana/provisioning:ro
  - ./data/grafana:/var/lib/grafana:z
  
Nginx:
  - ./containers/nginx/nginx.conf:/etc/nginx/nginx.conf:ro
  - ./containers/nginx/sites:/etc/nginx/sites-enabled:ro
```

### **3.2 NixOS Container Definitions**

#### **3.2.1 Base NixOS Container Template**
```nix
{ pkgs ? import <nixpkgs> {} }:

pkgs.dockerTools.buildLayeredImage {
  name = "localhost/indrajaal-${service}";
  tag = "nixos-devenv";
  
  contents = with pkgs; [
    # Base system
    bashInteractive
    coreutils
    cacert  # CRITICAL: SSL certificates
    
    # Service-specific packages
    ${servicePackages}
  ];
  
  config = {
    Env = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "NIX_SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "PHICS_ENABLED=true"
      "SOPV51_COMPLIANT=true"
    ];
    
    WorkingDir = "/workspace";
    
    ExposedPorts = {
      "${port}/tcp" = {};
    };
  };
  
  # SSL certificate fix
  runAsRoot = ''
    mkdir -p /etc/ssl/certs /etc/pki/tls/certs
    ln -sf ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt /etc/ssl/certs/ca-bundle.crt
    ln -sf ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt /etc/pki/tls/certs/ca-bundle.crt
    ln -sf ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt /etc/ssl/cert.pem
    ln -sf ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt /etc/ssl/certs/ca-certificates.crt
  '';
}
```

### **3.3 SSL Certificate Resolution Strategy**

#### **3.3.1 Multi-Path Certificate Solution**
```elixir
defmodule SSLCertificateResolver do
  @certificate_paths [
    "/etc/ssl/certs/ca-bundle.crt",
    "/etc/pki/tls/certs/ca-bundle.crt",
    "/etc/ssl/cert.pem",
    "/etc/ssl/certs/ca-certificates.crt"
  ]
  
  def setup_certificates(container_name) do
    # Find Nix store CA bundle
    ca_bundle = find_nix_ca_bundle(container_name)
    
    # Create all standard paths
    Enum.each(@certificate_paths, fn path ->
      create_symlink(container_name, ca_bundle, path)
    end)
    
    # Validate accessibility
    validate_certificates(container_name)
  end
end
```

### **3.4 PHICS Hot-Reloading Architecture**

#### **3.4.1 Bidirectional File Sync**
```elixir
defmodule PHICSIntegration do
  @watch_paths [
    "lib/**/*.ex",
    "lib/**/*.exs",
    "assets/**/*",
    "priv/static/**/*"
  ]
  
  def setup_hot_reloading(container_name) do
    # Mount workspace with proper permissions
    mount_workspace(container_name)
    
    # Configure file watchers
    configure_watchers(container_name)
    
    # Enable Phoenix code reloader
    enable_code_reloader(container_name)
    
    # Validate hot-reloading
    test_hot_reload(container_name)
  end
end
```

---

## 🔧 **LEVEL 4: CONFIGURATION & IMPLEMENTATION**

### **4.1 Master Container Setup Script**

#### **4.1.1 Complete Orchestration Script Structure**
```elixir
defmodule MasterNixOSContainerSetup do
  @moduledoc """
  Master NixOS Container Setup Orchestrator
  Implements complete container infrastructure based on 5-level analysis
  """
  
  require Logger
  
  @containers [
    %{name: "timescaledb", port: 5433, priority: 1},
    %{name: "redis", port: 6379, priority: 1},
    %{name: "app", ports: [4000, 4001], priority: 2},
    %{name: "prometheus", port: 9090, priority: 3},
    %{name: "grafana", port: 3000, priority: 3},
    %{name: "nginx", ports: [8080, 8443], priority: 3}
  ]
  
  def main(args) do
    Logger.info("🚀 Starting Master NixOS Container Setup")
    
    with :ok <- Phase1.validate_prerequisites(),
         :ok <- Phase2.cleanup_environment(),
         :ok <- Phase3.build_nixos_images(),
         :ok <- Phase4.setup_ssl_certificates(),
         :ok <- Phase5.start_container_orchestration(),
         :ok <- Phase6.validate_phics_integration(),
         :ok <- Phase7.run_comprehensive_tests(),
         :ok <- Phase8.generate_documentation() do
      Logger.info("✅ Container setup completed successfully")
      :ok
    else
      {:error, reason} -> handle_error(reason)
    end
  end
end
```

#### **4.1.2 Phase Implementation Details**

**Phase 1: Prerequisites Validation**
```elixir
defmodule Phase1 do
  def validate_prerequisites do
    checks = [
      check_podman_version(),
      check_nix_installation(),
      check_devenv_setup(),
      check_directory_structure(),
      check_network_availability()
    ]
    
    case Enum.find(checks, &match?({:error, _}, &1)) do
      nil -> :ok
      error -> error
    end
  end
end
```

**Phase 2: Environment Cleanup**
```elixir
defmodule Phase2 do
  def cleanup_environment do
    # Remove violating containers
    remove_non_compliant_containers()
    
    # Clean registry references
    cleanup_external_registries()
    
    # Setup proper network
    create_container_network()
    
    # Prepare directories
    setup_directory_structure()
  end
end
```

**Phase 3: Build NixOS Images**
```elixir
defmodule Phase3 do
  def build_nixos_images do
    @containers
    |> Enum.map(&build_container_image/1)
    |> validate_all_builds()
  end
  
  defp build_container_image(container) do
    nix_file = "containers/#{container.name}-nixos.nix"
    image_tag = "localhost/indrajaal-#{container.name}-demo:nixos-devenv"
    
    case System.cmd("nix-build", [nix_file, "-o", "result"]) do
      {_, 0} -> load_to_podman(image_tag)
      error -> {:error, error}
    end
  end
end
```

### **4.2 Container-Specific Configurations**

#### **4.2.1 PostgreSQL + TimescaleDB Configuration**
```nix
# containers/timescaledb-nixos.nix
{ pkgs ? import <nixpkgs> {} }:

pkgs.dockerTools.buildLayeredImage {
  name = "localhost/indrajaal-timescaledb-demo";
  tag = "nixos-devenv";
  
  contents = with pkgs; [
    postgresql_17
    timescaledb
    postgresqlPackages.pg_cron
    postgresqlPackages.pgvector
    cacert
    bashInteractive
  ];
  
  config = {
    Env = [
      "POSTGRES_DB=indrajaal_demo"
      "POSTGRES_USER=postgres"
      "POSTGRES_PASSWORD=postgres"
      "PGPORT=5433"
      "TIMESCALEDB_TELEMETRY=off"
      "TS_TUNE_MEMORY=2GB"
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
    ];
    
    ExposedPorts = {
      "5433/tcp" = {};
    };
    
    Volumes = {
      "/var/lib/postgresql/data" = {};
    };
  };
  
  runAsRoot = ''
    # SSL certificate setup
    ${sslCertificateSetup}
    
    # TimescaleDB initialization
    mkdir -p /docker-entrypoint-initdb.d
    echo "CREATE EXTENSION IF NOT EXISTS timescaledb;" > /docker-entrypoint-initdb.d/00-timescaledb.sql
  '';
}
```

#### **4.2.2 Elixir/Phoenix Application Configuration**
```nix
# containers/app-nixos.nix
{ pkgs ? import <nixpkgs> {} }:

let
  gitInfo = {
    commit = builtins.readFile ./git-commit;
    branch = builtins.readFile ./git-branch;
  };
in
pkgs.dockerTools.buildLayeredImage {
  name = "localhost/indrajaal-app-demo";
  tag = "dialyzer-enabled";
  
  contents = with pkgs; [
    elixir_1_18
    erlang_27
    nodejs_20
    git
    gnugrep
    inotify-tools  # For PHICS hot-reloading
    cacert
    bashInteractive
  ];
  
  config = {
    Env = [
      "MIX_ENV=dev"
      "PHX_SERVER=true"
      "PHICS_ENABLED=true"
      "PHICS_WATCH_ENABLED=true"
      "DATABASE_URL=ecto://postgres:postgres@timescaledb:5433/indrajaal_demo"
      "REDIS_URL=redis://redis:6379"
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "GIT_COMMIT=${gitInfo.commit}"
      "GIT_BRANCH=${gitInfo.branch}"
    ];
    
    WorkingDir = "/workspace";
    
    ExposedPorts = {
      "4000/tcp" = {};
      "4001/tcp" = {};
    };
    
    Cmd = [ "mix" "phx.server" ];
  };
  
  runAsRoot = ''
    # SSL certificate setup
    ${sslCertificateSetup}
    
    # PHICS setup
    mkdir -p /workspace
    chmod 755 /workspace
  '';
}
```

### **4.3 Testing Framework Implementation**

#### **4.3.1 STAMP Safety Constraint Tests**
```elixir
# test/stamp/container_safety_constraints_test.exs
defmodule ContainerSafetyConstraintsTest do
  use ExUnit.Case
  use PropCheck
  
  @safety_constraints [
    "SC-CNT-001: All containers MUST use localhost registry",
    "SC-CNT-002: SSL certificates MUST be accessible",
    "SC-CNT-003: PHICS hot-reloading MUST work",
    "SC-CNT-004: Health checks MUST pass before dependencies",
    "SC-CNT-005: Logs MUST be centralized in ./data/tmp"
  ]
  
  describe "SC-CNT-001: Registry Compliance" do
    test "all containers use localhost registry" do
      containers = get_running_containers()
      
      Enum.each(containers, fn container ->
        assert String.starts_with?(container.image, "localhost/"),
               "Container #{container.name} violates SC-CNT-001"
      end)
    end
  end
  
  describe "SC-CNT-002: SSL Certificate Access" do
    property "certificates accessible in all containers" do
      forall container <- container_generator() do
        result = check_ssl_certificates(container)
        result != :no_cacerts_found
      end
    end
  end
end
```

#### **4.3.2 TDG Container Creation Tests**
```elixir
# test/tdg/container_creation_test.exs
defmodule TDG.ContainerCreationTest do
  use ExUnit.Case
  
  # Tests written BEFORE implementation
  describe "container creation process" do
    test "validates NixOS base images" do
      images = list_container_images()
      
      Enum.each(images, fn image ->
        assert is_nixos_based?(image),
               "Image #{image} is not NixOS-based"
      end)
    end
    
    test "builds images with localhost registry" do
      result = build_all_images()
      
      assert {:ok, images} = result
      assert length(images) == 6
      
      Enum.each(images, fn image ->
        assert String.starts_with?(image, "localhost/")
      end)
    end
    
    test "configures SSL certificates correctly" do
      containers = start_test_containers()
      
      Enum.each(containers, fn container ->
        assert {:ok, _certs} = validate_ssl_in_container(container)
      end)
    end
  end
end
```

### **4.4 Validation Scripts**

#### **4.4.1 Container Readiness Validator**
```elixir
# scripts/containers/container_readiness_validator.exs
defmodule ContainerReadinessValidator do
  @required_containers [
    "indrajaal-timescaledb-demo",
    "indrajaal-redis-demo",
    "indrajaal-app-demo",
    "indrajaal-prometheus-demo",
    "indrajaal-grafana-demo",
    "indrajaal-nginx-demo"
  ]
  
  def validate_all do
    validations = [
      validate_containers_running(),
      validate_health_checks(),
      validate_network_connectivity(),
      validate_service_endpoints(),
      validate_ssl_certificates(),
      validate_phics_integration()
    ]
    
    generate_report(validations)
  end
end
```

---

## 📋 **LEVEL 5: ROOT DESIGN & STRATEGIC IMPLEMENTATION**

### **5.1 Strategic Architecture Decisions**

#### **5.1.1 NixOS-Only Container Strategy**
**Decision**: Use exclusively NixOS-based containers
**Rationale**:
- **Reproducibility**: Nix guarantees identical environments
- **Security**: Minimal attack surface with declarative configuration
- **Integration**: Native integration with DevEnv and Nix tooling
- **Compliance**: Meets enterprise requirements for supply chain security

**Implementation**:
- All container definitions in Nix expressions
- No Dockerfile/Containerfile usage
- Podman for OCI compliance without Docker daemon

#### **5.1.2 Local Registry Enforcement**
**Decision**: All images MUST use `localhost/` prefix
**Rationale**:
- **Security**: Prevents supply chain attacks
- **Air-Gap Capability**: Can operate without internet
- **Compliance**: Meets regulatory requirements
- **Control**: Complete control over image sources

**Implementation**:
- Registry validator script with pre-commit hooks
- Automated compliance checking in CI/CD
- Policy enforcement in podman configuration

#### **5.1.3 SSL Certificate Multi-Path Strategy**
**Decision**: Create symlinks to multiple standard certificate paths
**Rationale**:
- **Compatibility**: Different tools expect different paths
- **Erlang/OTP**: Has hardcoded certificate paths
- **Flexibility**: Works across different environments

**Implementation**:
- Symlink creation in container build process
- Runtime validation of certificate accessibility
- Fallback mechanisms for certificate discovery

### **5.2 Complete Implementation Timeline**

#### **5.2.1 Day 1: Foundation (4 hours)**
1. **Hour 1**: Environment cleanup and documentation organization
2. **Hour 2**: Create NixOS container definitions for all 6 containers
3. **Hour 3**: Implement SSL certificate resolution
4. **Hour 4**: Create master setup script framework

#### **5.2.2 Day 2: Implementation (4 hours)**
1. **Hour 1**: Build and test all container images
2. **Hour 2**: Implement container orchestration
3. **Hour 3**: Setup PHICS hot-reloading
4. **Hour 4**: Create validation scripts

#### **5.2.3 Day 3: Testing & Documentation (4 hours)**
1. **Hour 1**: Implement STAMP safety constraint tests
2. **Hour 2**: Create TDG container creation tests
3. **Hour 3**: Run comprehensive validation
4. **Hour 4**: Update all documentation

### **5.3 Risk Mitigation Strategies**

#### **5.3.1 Technical Risks**
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| SSL certificate issues persist | Medium | High | Multi-path strategy with validation |
| Container build failures | Low | High | Incremental build with validation |
| Network connectivity issues | Low | Medium | Comprehensive network testing |
| PHICS integration failures | Medium | Medium | Fallback to manual reload |

#### **5.3.2 Process Risks**
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Documentation gaps | Low | Medium | Comprehensive documentation plan |
| Testing coverage insufficient | Low | High | TDG methodology enforcement |
| Manual intervention required | Medium | Medium | Automation with error recovery |

### **5.4 Quality Assurance Framework**

#### **5.4.1 Testing Pyramid**
```
         /\
        /  \  E2E Tests (10%)
       /    \  - Full system validation
      /------\
     /        \ Integration Tests (30%)
    /          \ - Container interaction
   /            \ - Service communication
  /--------------\
 /                \ Unit Tests (60%)
/                  \ - Individual components
--------------------  - Utility functions
```

#### **5.4.2 Validation Checkpoints**
1. **Pre-Build Validation**:
   - Environment prerequisites
   - Directory structure
   - Network availability

2. **Build-Time Validation**:
   - Image creation success
   - Registry compliance
   - Size optimization

3. **Runtime Validation**:
   - Container health
   - Service connectivity
   - Performance metrics

4. **Post-Setup Validation**:
   - Complete system test
   - Documentation accuracy
   - Recovery procedures

### **5.5 Documentation Deliverables**

#### **5.5.1 Primary Documentation**
1. **Setup Guide** (`docs/containers/NIXOS_CONTAINER_SETUP_GUIDE.md`):
   - Complete setup procedures
   - Step-by-step instructions
   - Troubleshooting guide

2. **Architecture Document** (`docs/containers/CONTAINER_ARCHITECTURE.md`):
   - System design
   - Component interactions
   - Network topology

3. **Validation Framework** (`docs/containers/VALIDATION_FRAMEWORK.md`):
   - Test procedures
   - Success criteria
   - Compliance checking

#### **5.5.2 Operational Documentation**
1. **Emergency Procedures** (`docs/containers/EMERGENCY_PROCEDURES.md`):
   - Recovery procedures
   - Rollback strategies
   - Contact information

2. **Maintenance Guide** (`docs/containers/MAINTENANCE_GUIDE.md`):
   - Update procedures
   - Backup strategies
   - Performance tuning

### **5.6 Success Metrics & KPIs**

#### **5.6.1 Technical Metrics**
- **Container Uptime**: >99.9%
- **SSL Success Rate**: 100%
- **Registry Compliance**: 100%
- **Test Coverage**: >90%
- **Setup Time**: <30 minutes
- **Recovery Time**: <5 minutes

#### **5.6.2 Process Metrics**
- **Documentation Completeness**: 100%
- **Automation Level**: >95%
- **Manual Interventions**: 0
- **Error Recovery Rate**: 100%
- **Validation Pass Rate**: 100%

### **5.7 Final Deliverables Checklist**

#### **Scripts (11 files)**
- [ ] `scripts/containers/master_nixos_container_setup.exs`
- [ ] `scripts/containers/nixos_ssl_resolver.exs`
- [ ] `scripts/containers/container_readiness_validator.exs`
- [ ] `scripts/containers/registry_compliance_validator.exs`
- [ ] `scripts/containers/phics_integration_validator.exs`
- [ ] `scripts/containers/prerequisite_validator.exs`
- [ ] `scripts/containers/network_validator.exs`
- [ ] `scripts/containers/health_check_monitor.exs`
- [ ] `scripts/containers/emergency_recovery.exs`
- [ ] `scripts/containers/performance_baseline.exs`
- [ ] `scripts/containers/backup_restore.exs`

#### **Container Definitions (6 files)**
- [ ] `containers/timescaledb-nixos.nix`
- [ ] `containers/redis-nixos.nix`
- [ ] `containers/app-nixos.nix`
- [ ] `containers/prometheus-nixos.nix`
- [ ] `containers/grafana-nixos.nix`
- [ ] `containers/nginx-nixos.nix`

#### **Test Files (4 files)**
- [ ] `test/stamp/container_safety_constraints_test.exs`
- [ ] `test/tdg/container_creation_test.exs`
- [ ] `test/property/container_properties_test.exs`
- [ ] `test/containers/comprehensive_container_test.exs`

#### **Documentation (8 files)**
- [ ] Move `20250910-1351-comprehensive-nixos-container-setup-5level-analysis.md` to `docs/containers/`
- [ ] Update `docs/containers/COMPREHENSIVE_CONTAINER_ARCHITECTURE.md`
- [ ] Update `docs/containers/COMPLETE_CONTAINER_REBUILD_GUIDE.md`
- [ ] Update `docs/containers/nixos-container-ssl-setup-complete.md`
- [ ] Update `docs/containers/VALIDATION_FRAMEWORK_COMPLETE.md`
- [ ] Create `docs/containers/NIXOS_CONTAINER_SETUP_GUIDE.md`
- [ ] Create `docs/containers/EMERGENCY_PROCEDURES.md`
- [ ] Update `CLAUDE.md` with container procedures

### **5.8 Implementation Commands Summary**

```bash
# Complete setup in one command
elixir scripts/containers/master_nixos_container_setup.exs --complete

# Individual phases
elixir scripts/containers/master_nixos_container_setup.exs --phase prerequisites
elixir scripts/containers/master_nixos_container_setup.exs --phase cleanup
elixir scripts/containers/master_nixos_container_setup.exs --phase build
elixir scripts/containers/master_nixos_container_setup.exs --phase ssl
elixir scripts/containers/master_nixos_container_setup.exs --phase orchestration
elixir scripts/containers/master_nixos_container_setup.exs --phase phics
elixir scripts/containers/master_nixos_container_setup.exs --phase validation
elixir scripts/containers/master_nixos_container_setup.exs --phase documentation

# Validation only
elixir scripts/containers/container_readiness_validator.exs --comprehensive

# Emergency recovery
elixir scripts/containers/emergency_recovery.exs --full-recovery
```

---

## 🎯 **CONCLUSION**

This 5-level comprehensive plan provides a complete blueprint for implementing a production-ready NixOS container infrastructure for the Indrajaal Security Monitoring System. The plan addresses all identified issues from the symptom level through to strategic design decisions, ensuring:

1. **100% NixOS Compliance**: All containers based on NixOS
2. **Complete SSL Resolution**: Multi-path certificate strategy
3. **Full Automation**: Setup without manual intervention
4. **Comprehensive Validation**: 86+ validation checks
5. **Enterprise Documentation**: Complete operational guides
6. **PHICS Integration**: Hot-reloading across container boundaries
7. **Local Registry Only**: Security through isolation

**Estimated Total Implementation Time**: 12 hours (3 days × 4 hours)

**Critical Success Factors**:
- Strict adherence to NixOS-only policy
- Complete implementation of SSL certificate solution
- Comprehensive testing at each phase
- Full documentation updates
- Zero manual intervention in final setup

This plan incorporates all findings from the 5-level analysis document and provides a systematic approach to achieving a fully verified, production-ready container infrastructure.