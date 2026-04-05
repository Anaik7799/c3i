{ pkgs, lib, config, inputs, ... }:

{
  # Indrajaal v5.2 - SOPv5.11 Cybernetic Framework
  # Clean development environment with practical commands

  env = {
    # Patient Mode (MANDATORY)
    NO_TIMEOUT = "true";
    PATIENT_MODE = "enabled";
    INFINITE_PATIENCE = "true";
    ELIXIR_ERL_OPTIONS = "+S 16:16 +SDio 16";
    MIX_OS_DEPS_COMPILE_PARTITION_COUNT = "8";

    # Container settings
    PODMAN_ROOTLESS = "true";
    CONTAINER_REGISTRY = "localhost";

    # Editor Substrate (SC-SYS-003: Helix Migration for Stability)
    EDITOR = "hx";
    GIT_EDITOR = "hx";

    # Database
    POSTGRES_USER = "postgres";
    POSTGRES_PASSWORD = "postgres";
    DATABASE_URL = "ecto://postgres:postgres@localhost:5433/indrajaal_dev";

    # Logging
    LOG_DIRECTORY = "./data/tmp";

    # FoundationSupervisor Health Port (SC-CPU-GOV-008)
    # Ports 4000-4010 reserved for 16-container SIL-6 mesh
    HEALTH_PORT = "4051";

    # CEPAF / Infrastructure
    PROJECT_ROOT = "/home/an/dev/ver/c3i";

    # Planning System Access Control (SC-TODO-001 to SC-TODO-008)
    # CRITICAL: PROJECT_TODOLIST.md MUST ONLY be accessed via F# Planning CLI
    PLANNING_CLI_AUTHORITATIVE = "true";
    PLANNING_DIRECT_ACCESS_BLOCKED = "true";
    PLANNING_AUDIT_ENABLED = "true";

    # Orchestration Coordination (SC-ORCH-001 to SC-ORCH-015)
    ORCHESTRATION_ENABLED = "true";
    ORCHESTRATION_GUARDIAN_REQUIRED = "true";

    # Writable NPM prefix for JetBrains/Remote (SC-SYS-004)
    NPM_CONFIG_PREFIX = "/home/an/.npm-global";

    # Intercept mkdir calls in /nix/store to prevent EACCES (SC-SYS-006)
    LD_PRELOAD = "/home/an/.npm-global/lib/libnix_eacces_fix.so";

    # E2E Browser Testing (SC-COV-008)
    # Toggles: google-chrome-stable | google-chrome-unstable | chromium
    WALLABY_CHROME_PATH = "google-chrome-unstable";
  };

  packages = with pkgs; [
    git
    podman
    podman-compose
    rebar3
    elixir_1_19
    erlang_28
    nodejs_20
    postgresql_17
    redis
    helix
    curl
    jq
    which
    zig
    dart
    flutter332
    dotnet-sdk_10
    rustc
    cargo
    rust-analyzer
    clippy
    rustfmt
    direnv
    pkgs.linuxHeaders
    # Biomorphic Holon State Storage (SC-HOLON-001)
    sqlite
    duckdb
    # E2E Browser Testing — Wallaby + Chrome (SC-COV-008)
    chromium
    chromedriver
    google-chrome
    inputs.browser-previews.packages.${pkgs.system}.google-chrome-dev
    # Language Servers for Claude Code LSP Plugin
    elixir-ls                          # Elixir LSP
    erlang-language-platform           # Erlang LSP
    gleam                              # Gleam LSP (built-in)
    fsautocomplete                     # F# LSP
    csharp-ls                          # C# LSP (lightweight)
    pyright                            # Python LSP (fast type checker)
    sqls                               # SQL LSP (PostgreSQL, SQLite, MySQL)
    # Additional Language Servers (SC-LSP-001)
    nodePackages.yaml-language-server  # YAML LSP (OpenAPI, K8s, etc.)
    haskellPackages.Agda               # Agda proof assistant (with agda-mode)
    graphviz                           # DOT graph language tools
    # Nix Language Support (SC-LSP-002)
    nil                                # Nix LSP (modern, incremental)
    nixpkgs-fmt                        # Nix formatter
    nix-tree                           # Dependency tree visualization
    # Google Cloud SDK (gcloud CLI)
    google-cloud-sdk                   # gcloud, gsutil, bq
    rclone                             # Google Drive FUSE mount
    # gRPC/Protobuf Support (SC-LSP-003)
    buf                                # Buf CLI for protobuf (includes LSP)
    protobuf                           # Protocol Buffers compiler
    grpcurl                            # gRPC CLI tool
    # Wolfram/Mathematica Support (SC-LSP-004)
    # wolfram-engine                   # Commercial - requires license
    # Note: Free alternative: pip install lsp-server-wolfram
    # Zenoh Configuration (SC-LSP-005)
    # Zenoh uses JSON5 config files - use jsonnet LSP or JSON with relaxed parsing
    # Note: Quint LSP via `npx @informalsystems/quint-language-server`
  ];

  languages.elixir = {
    enable = true;
    package = pkgs.elixir_1_19;
  };
  languages.gleam.enable = true;
  languages.dart.enable = true;
  languages.dotnet = {
    enable = true;
    package = pkgs.dotnet-sdk_10;
  };
  languages.rust.enable = true;
  languages.python.enable = true;
  languages.nix.enable = true;  # Nix language support with nil LSP

  dotenv.enable = true;

  services.postgres = {
    enable = false;
    port = 5433;
    initialDatabases = [{ name = "indrajaal_dev"; }];
    initialScript = ''
      CREATE USER indrajaal WITH PASSWORD 'indrajaal';
      ALTER DATABASE indrajaal_dev OWNER TO indrajaal;
      GRANT ALL PRIVILEGES ON DATABASE indrajaal_dev TO indrajaal;
    '';
  };

  services.redis.enable = false;

  # ============================================
  # INDRAJAAL APP COMMANDS
  # ============================================

  scripts.app.exec = ''
    echo "🚀 Starting Indrajaal Phoenix server..."
    mix phx.server
  '';

  scripts.app-start.exec = ''
    echo "🐳 Starting dev containers + Phoenix..."
    elixir scripts/env/dev-start.exs && mix phx.server
  '';

  scripts.app-iex.exec = ''
    echo "🔧 Starting Phoenix with IEx..."
    iex -S mix phx.server
  '';

  scripts.app-gleam.exec = ''
    echo "🚀 Starting Indrajaal Gleam Web server (Mist + Lustre)..."
    cd lib/indrajaal_gleam_web && gleam run
  '';

  # ============================================
  # COMPILATION & QUALITY (CPU Governed — SC-CPU-GOV-001)
  # All compile/test commands use adaptive parallelism via cpu-governor.sh
  # ============================================

  # SC-METRICS-003 + SC-CPU-GOV-001: Adaptive schedulers for compilation
  scripts.compile.exec = ''
    source scripts/cpu-governor.sh
    echo "[CPU-GOV] Compiling with adaptive parallelism (SC-CPU-GOV-001, SC-ENV-COMPILE)..."
    governed_compile "$@"
  '';

  scripts.compile-strict.exec = ''
    source scripts/cpu-governor.sh
    echo "[CPU-GOV] Strict compilation with adaptive parallelism..."
    cpu_wait_if_high && adaptive_env
    nice -n "$GOVERNOR_NICE" env \
    NO_TIMEOUT=true PATIENT_MODE=enabled \
    SKIP_ZENOH_NIF=0 WALLABY_ENABLED=true \
    ELIXIR_ERL_OPTIONS="$ELIXIR_ERL_OPTIONS" \
    MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8 \
    mix compile --warnings-as-errors --jobs "$MIX_JOBS" 2>&1 | tee -a ./data/tmp/1-compile.log
  '';

  scripts.compile-profile.exec = ''
    source scripts/cpu-governor.sh
    echo "[CPU-GOV] Profiled compilation with adaptive parallelism..."
    cpu_wait_if_high && adaptive_env
    mkdir -p ./data/metrics
    nice -n "$GOVERNOR_NICE" env \
      NO_TIMEOUT=true PATIENT_MODE=enabled \
      SKIP_ZENOH_NIF=0 WALLABY_ENABLED=true \
      ELIXIR_ERL_OPTIONS="$ELIXIR_ERL_OPTIONS" \
      MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8 \
      mix compile --profile time --jobs "$MIX_JOBS" 2>&1 | tee ./data/metrics/compile-profile-$(date +%Y%m%d-%H%M%S).log
    echo ""
    echo "Top 20 slowest files (by wait time):"
    grep -E "^\[profile\]" ./data/metrics/compile-profile-*.log 2>/dev/null | sort -t'+' -k2 -n -r | head -20
  '';

  scripts.compile-xref.exec = ''
    echo "📈 Dependency graph analysis (SC-METRICS-002)..."
    mix xref graph --format stats --label compile-connected
    echo ""
    echo "🔄 Checking for cycles..."
    mix xref graph --format cycles
  '';

  scripts.quality.exec = ''
    echo "✅ Running quality checks..."
    mix format --check-formatted && mix credo --strict && echo "Quality OK"
  '';

  scripts.quality-full.exec = ''
    echo "🔍 Full quality pipeline..."
    mix format --check-formatted && \
    mix credo --strict && \
    mix dialyzer && \
    mix sobelow --exit && \
    echo "✅ All quality gates passed"
  '';

  # ============================================
  # TESTING
  # ============================================

  # SC-METRICS-003 + SC-CPU-GOV-002: Governed test with adaptive parallelism
  scripts.test.exec = ''
    source scripts/cpu-governor.sh
    echo "[CPU-GOV] Running tests with adaptive parallelism (SC-CPU-GOV-002)..."
    governed_test "$@"
  '';

  scripts.test-cover.exec = ''
    source scripts/cpu-governor.sh
    echo "[CPU-GOV] Running tests with coverage + adaptive parallelism..."
    cpu_wait_if_high && adaptive_env
    nice -n "$GOVERNOR_NICE" env \
      SKIP_ZENOH_NIF=0 \
      WALLABY_ENABLED=true \
      NO_TIMEOUT=true \
      PATIENT_MODE=enabled \
      HEALTH_PORT=4051 \
      ELIXIR_ERL_OPTIONS="$ELIXIR_ERL_OPTIONS" \
      POSTGRES_USER="''${POSTGRES_USER:-postgres}" \
      POSTGRES_PASSWORD="''${POSTGRES_PASSWORD:-postgres}" \
      DATABASE_URL="''${DATABASE_URL:-ecto://postgres:postgres@localhost:5433/indrajaal_test}" \
      MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8 \
      MIX_ENV=test mix test --cover
  '';

  # Wallaby E2E Browser Tests (SC-COV-008 + SC-CPU-GOV-002)
  scripts.test-e2e.exec = ''
    source scripts/cpu-governor.sh
    echo "[CPU-GOV] Running Wallaby E2E tests with adaptive parallelism..."
    governed_wallaby "$@"
  '';

  # ============================================
  # CPU GOVERNOR (SC-CPU-GOV-001 to SC-CPU-GOV-010)
  # Adaptive parallelism with 85% hard limit
  # Uses /proc/stat differential (NOT load average)
  # ============================================

  scripts.governed-compile.exec = ''
    source scripts/cpu-governor.sh && governed_compile "$@"
  '';

  scripts.governed-test.exec = ''
    source scripts/cpu-governor.sh && governed_test "$@"
  '';

  scripts.governed-wallaby.exec = ''
    source scripts/cpu-governor.sh && governed_wallaby "$@"
  '';

  scripts.governed-exec.exec = ''
    source scripts/cpu-governor.sh && governed_exec "$@"
  '';

  scripts.cpu-status.exec = ''
    source scripts/cpu-governor.sh && cpu_governor_status
  '';

  # SIL-6 Mesh Test Suite (SC-CPU-GOV-002)
  scripts.test-sil6.exec = ''
    source scripts/cpu-governor.sh
    echo "[CPU-GOV] Running SIL-6 mesh test suite with adaptive parallelism..."
    cpu_wait_if_high && adaptive_env
    nice -n "$GOVERNOR_NICE" env \
      SKIP_ZENOH_NIF=0 \
      WALLABY_ENABLED=true \
      NO_TIMEOUT=true \
      PATIENT_MODE=enabled \
      HEALTH_PORT=4051 \
      ELIXIR_ERL_OPTIONS="$ELIXIR_ERL_OPTIONS" \
      POSTGRES_USER="''${POSTGRES_USER:-postgres}" \
      POSTGRES_PASSWORD="''${POSTGRES_PASSWORD:-postgres}" \
      DATABASE_URL="''${DATABASE_URL:-ecto://postgres:postgres@localhost:5433/indrajaal_test}" \
      MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8 \
      MIX_ENV=test mix test test/sil6/ --trace "$@"
  '';

  # SIL-6 with containers (SC-CPU-GOV-002)
  scripts.test-sil6-live.exec = ''
    source scripts/cpu-governor.sh
    echo "[CPU-GOV] Running SIL-6 live test suite with adaptive parallelism..."
    cpu_wait_if_high && adaptive_env
    nice -n "$GOVERNOR_NICE" env \
      SKIP_ZENOH_NIF=0 \
      WALLABY_ENABLED=true \
      NO_TIMEOUT=true \
      PATIENT_MODE=enabled \
      HEALTH_PORT=4051 \
      ELIXIR_ERL_OPTIONS="$ELIXIR_ERL_OPTIONS" \
      POSTGRES_USER="''${POSTGRES_USER:-postgres}" \
      POSTGRES_PASSWORD="''${POSTGRES_PASSWORD:-postgres}" \
      DATABASE_URL="''${DATABASE_URL:-ecto://postgres:postgres@localhost:5433/indrajaal_test}" \
      MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8 \
      MIX_ENV=test mix test test/sil6/ --trace --include requires_containers "$@"
  '';

  # ============================================
  # CEPAF / F# COCKPIT
  # ============================================

  scripts.cockpitf.exec = ''
    CMD="''${1:-deploy}"
    dotnet fsi lib/cepaf/scripts/CockpitOperations.fsx "$CMD"
  '';

  scripts.cepaf-build.exec = ''
    echo "🔨 Building CEPAF F# projects..."
    cd lib/cepaf && dotnet build
  '';

  scripts.constraint-sync.exec = ''
    DLL="lib/cepaf/src/Cepaf.ConstraintSync/bin/Release/net10.0/constraint-sync.dll"
    if [ ! -f "$DLL" ]; then
      echo "Building constraint-sync binary..."
      dotnet build lib/cepaf/src/Cepaf.ConstraintSync/Cepaf.ConstraintSync.fsproj -c Release -v q
    fi
    dotnet exec "$DLL" "$@"
  '';

  scripts.cepaf-test.exec = ''
    echo "🧪 Running F# Expecto tests (SC-FFI-001: LD_LIBRARY_PATH set)..."
    FILTER="''${1:-}"
    if [ -n "$FILTER" ]; then
      echo "  Filter: --filter-test-list $FILTER"
      dotnet run --project lib/cepaf/test/Cepaf.Tests/Cepaf.Tests.fsproj -- --filter-test-list "$FILTER" --summary
    else
      dotnet run --project lib/cepaf/test/Cepaf.Tests/Cepaf.Tests.fsproj -- --summary
    fi
  '';

  scripts.zenoh-ffi-build.exec = ''
    echo "🦀 Building Zenoh FFI native library (zenoh 1.7 + csbindgen 1.9)..."
    cargo build --release -p zenoh_ffi
    echo "✓ Built: target/release/libzenoh_ffi.so"
    nm -D target/release/libzenoh_ffi.so | grep zenoh_ffi_ | wc -l | xargs -I{} echo "  {} FFI symbols exported"
  '';

  # ============================================
  # RUST TOOLS (lib/rust/ workspace)
  # SC-ZMOF-001, SC-MUDA-001, SC-UIGT-001
  # ============================================

  scripts.sa-regression.exec = ''
    echo "🦀 C3I Browser Regression Suite (Ratatui TUI)..."
    cargo run --release --manifest-path lib/rust/Cargo.toml -p c3i_browser_regression -- "$@"
  '';

  scripts.sa-fmea-gen.exec = ''
    echo "🦀 Generating FMEA/STAMP directives (9 fractal layers)..."
    cargo run --release --manifest-path lib/rust/Cargo.toml -p c3i_swarm_generator -- "$@"
  '';

  scripts.sa-agui-catalog.exec = ''
    echo "🦀 Generating AG-UI idea catalog (200 ideas, 10 categories)..."
    cargo run --release --manifest-path lib/rust/Cargo.toml -p c3i_agui_ideas -- "$@"
  '';

  scripts.rust-check.exec = ''
    echo "🦀 Checking Rust crates (lib/rust workspace)..."
    cargo clippy --manifest-path lib/rust/Cargo.toml --workspace -- -D warnings
    cargo test --manifest-path lib/rust/Cargo.toml --workspace
    echo "✓ All Rust crates: clippy clean + tests pass"
  '';

  # ============================================
  # STANDALONE ENVIRONMENT (SIL-6 Certified F# CLI)
  # SC-SIL6-001 to SC-SIL6-015, SC-CTRL-003
  # Uses compiled F# modules for robustness
  # ============================================

  scripts.sa-up.exec = ''
    echo "🚀 SIL-6 EXECUTION: Wave-Based Mesh Boot (SC-SIL6-009)..."
    dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- mesh up
  '';

  scripts.sa-down.exec = ''
    echo "🛑 SIL-6 EXECUTION: Graceful Shutdown with Dying Gasp (SC-SIL6-007)..."
    dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- mesh down
  '';

  scripts.sa-status.exec = ''
    echo "📊 SIL-6 STATUS: Digital Twin + Quorum Report..."
    dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- mesh status
  '';

  scripts.sa-health.exec = ''
    echo "💊 SIL-6 HEALTH: Quorum Voting + FPPS Consensus (SC-SIL6-011)..."
    dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- mesh health
  '';

  scripts.sa-scour.exec = ''
    echo "🧹 SIL-6 Preflight: Port Substrate Isolation..."
    dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- mesh scour
  '';

  scripts.sa-clean.exec = ''
    echo "🧹 SIL-6 Deep Clean: Shutdown + Volume Prune..."
    dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- mesh clean
  '';

  scripts.sa-resurrect.exec = ''
    echo "🐣 SIL-6 RESURRECTION: One-Command System Recovery (SC-EMR-065)..."
    dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- mesh resurrect
  '';

  scripts.sa-sanitize-treesitter.exec = ''
    echo "🧹 [SUBSTRATE] Sanitizing Tree-sitter cache..."
    bash scripts/substrate/sanitize_treesitter.sh
  '';

  scripts.sa-security.exec = ''
    echo "🛡️ SIL-6 SECURITY AUDIT: Swarm-wide Vulnerability Scan..."
    dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- mesh security
  '';

  scripts.sa-nuclear.exec = ''
    echo "☢️ SIL-6 NUCLEAR RESET: Obliterating all persistent state..."
    dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- mesh nuclear
  '';

  scripts.sa-logs.exec = ''
    SERVICE="''${1:-indrajaal-ex-app-1}"
    echo "📜 SIL-6 LOGS: Streaming $SERVICE..."
    dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- mesh logs "$SERVICE"
  '';

  scripts.sa-emergency.exec = ''
    echo "🚨 SIL-6 EMERGENCY: Immediate Stop < 5s (SC-EMR-057)..."
    dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- mesh emergency
  '';

  scripts.sa-verify.exec = ''
    echo "✅ SIL-6 VERIFY: 5-Order Effects Verification..."
    dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- mesh verify
  '';

  scripts.sa-monitor.exec = ''
    echo "📡 SIL-6 COCKPIT: F# TUI Monitor (NASA-STD-3000 Dark Cockpit)..."
    dotnet run --project lib/cepaf/src/Cepaf.Cockpit.CLI/Cepaf.Cockpit.CLI.fsproj -- monitor
  '';

  scripts.sa-dashboard.exec = ''
    echo "📊 SIL-6 DASHBOARD: Real-time Mesh View..."
    dotnet run --project lib/cepaf/src/Cepaf.Cockpit.CLI/Cepaf.Cockpit.CLI.fsproj -- monitor
  '';

  # Cockpit CLI quick commands (non-TUI)
  scripts.cockpit.exec = ''
    CMD="''${1:-status}"
    shift 2>/dev/null || true
    dotnet run --project lib/cepaf/src/Cepaf.Cockpit.CLI/Cepaf.Cockpit.CLI.fsproj -- "$CMD" "$@"
  '';

  scripts.sa-ux.exec = ''
    echo "🎨 Running UX/UI evaluation..."
    dotnet fsi lib/cepaf/scripts/CockpitUXEvaluator.fsx
  '';

  scripts.sa-orchestrate.exec = ''
    MODE="''${1:-swarm}"
    echo "🎯 Running RuntimeTestOrchestrator (mode: $MODE)..."
    dotnet fsi lib/cepaf/scripts/RuntimeTestOrchestrator.fsx --mode "$MODE"
  '';

  # ============================================
  # UNIFIED CHECKPOINT REGISTRY (UCR)
  # SC-UCR-001 to SC-UCR-015, AOR-UCR-001 to AOR-UCR-010
  # 4-Phase: File/KMS/Git → CRIU → Chandy-Lamport → Multiverse
  # ============================================

  scripts.sa-checkpoint.exec = ''
    PHASE="''${1:-full}"
    echo "📦 UCR CHECKPOINT: Phase $PHASE (SC-UCR-001)..."
    dotnet fsi scripts/infrastructure/mesh-checkpoint-unified.fsx --phase "$PHASE"
  '';

  scripts.sa-checkpoint-verify.exec = ''
    echo "✅ UCR VERIFY: 46-test verification suite (SC-UCR-007)..."
    dotnet fsi scripts/infrastructure/mesh-checkpoint-verify.fsx
  '';

  scripts.sa-checkpoint-restore.exec = ''
    ARCHIVE="''${1:-latest}"
    echo "🔄 UCR RESTORE: $ARCHIVE (SC-UCR-015)..."
    dotnet fsi scripts/infrastructure/mesh-checkpoint-unified.fsx --restore "$ARCHIVE"
  '';

  scripts.sa-checkpoint-list.exec = ''
    echo "📋 UCR LIST: Available checkpoints..."
    ls -la data/checkpoints/ 2>/dev/null || echo "No checkpoints found in data/checkpoints/"
  '';

  # ============================================
  # SIL-6 FULL MESH (Biomorphic Fractal Holon)
  # SC-SIL6-001, SC-MESH-001, SC-SYNC-001, SC-ZENOH-001
  # ============================================

  scripts.sa-mesh.exec = ''
    CMD="''${1:-boot}"
    echo "🧬 SIL-6 BIOMORPHIC MESH: $CMD (SC-SIL6-001)..."
    dotnet fsi lib/cepaf/scripts/SIL6MeshOrchestrator.fsx "$CMD" "''${@:2}"
  '';

  scripts.sa-mesh-boot.exec = ''
    echo "🚀 SIL-6 MESH BOOT: Full biomorphic sequence..."
    dotnet fsi lib/cepaf/scripts/SIL6MeshOrchestrator.fsx boot
  '';

  scripts.sa-mesh-status.exec = ''
    echo "📊 SIL-6 MESH STATUS: Digital twin + quorum + Zenoh..."
    dotnet fsi lib/cepaf/scripts/SIL6MeshOrchestrator.fsx status
  '';

  scripts.sa-mesh-test.exec = ''
    TYPE="''${1:-all}"
    echo "🧪 SIL-6 MESH TEST: $TYPE..."
    dotnet fsi lib/cepaf/scripts/SIL6MeshOrchestrator.fsx test "$TYPE"
  '';

  scripts.sa-test-obs.exec = ''
    echo "🔭 OBSERVABILITY TEST: Verifying OTEL + Prometheus + Grafana + Loki..."
    dotnet fsi lib/cepaf/scripts/SIL6MeshOrchestrator.fsx test obs
  '';

  scripts.sa-test-cc.exec = ''
    echo "🔄 CHANGE CONTROL TEST: Checkpoint + restore capability..."
    dotnet fsi lib/cepaf/scripts/SIL6MeshOrchestrator.fsx test cc
  '';

  scripts.sa-test-mv.exec = ''
    echo "🌌 MULTIVERSE TEST: Shadow universe forking..."
    dotnet fsi lib/cepaf/scripts/SIL6MeshOrchestrator.fsx test mv
  '';

  scripts.sa-mesh-checkpoint.exec = ''
    NAME="''${1:-manual}"
    echo "📦 MESH CHECKPOINT: Creating $NAME via SIL6MeshOrchestrator..."
    dotnet fsi lib/cepaf/scripts/SIL6MeshOrchestrator.fsx checkpoint "$NAME"
  '';

  scripts.sa-restore.exec = ''
    NAME="''${1:-}"
    if [ -z "$NAME" ]; then
      echo "📋 Available checkpoints:"
      ls -1 data/checkpoints/ 2>/dev/null || echo "No checkpoints found"
    else
      echo "🔄 RESTORE: Restoring $NAME..."
      dotnet fsi lib/cepaf/scripts/SIL6MeshOrchestrator.fsx restore "$NAME"
    fi
  '';

  scripts.sa-fork.exec = ''
    NAME="''${1:-shadow}"
    echo "🌌 FORK: Creating shadow universe $NAME..."
    dotnet fsi lib/cepaf/scripts/SIL6MeshOrchestrator.fsx fork "$NAME"
  '';

  scripts.sa-test-zenoh.exec = ''
    echo "🌐 ZENOH TEST: Router + Telemetry verification..."
    dotnet fsi lib/cepaf/scripts/SIL6MeshOrchestrator.fsx test zenoh
  '';

  scripts.sa-test-agents.exec = ''
    echo "🤖 ZENOH AGENTS TEST: Container monitoring + control..."
    dotnet fsi lib/cepaf/scripts/SIL6MeshOrchestrator.fsx test agents
  '';

  scripts.sa-bdd-smoke.exec = ''
    echo "🧪 BDD SMOKE TESTS: SIL-6 Biomorphic Mesh Verification"
    echo "  15 Containers | 7 Tiers | 5 Boot Phases"
    echo "  STAMP: SC-GA-004, SC-ZTEST-001..008, SC-MESH-001..010"
    echo ""
    dotnet fsi lib/cepaf/scripts/SIL6MeshBDDSmokeTests.fsx
  '';

  # ============================================
  # PHASE 8: CHECKPOINT/RESTORE COMMANDS (SC-MESH-007, SC-UCR-015)
  # ============================================

  scripts.sa-checkpoint-legacy.exec = ''
    NAME="''${1:-}"
    echo "📦 STATE CHECKPOINT: Phase 8 (SC-MESH-007, SC-UCR-015)"
    if [ -n "$NAME" ]; then
      dotnet fsi lib/cepaf/scripts/EnhancedSwarmOrchestrator.fsx -- checkpoint "$NAME"
    else
      dotnet fsi lib/cepaf/scripts/EnhancedSwarmOrchestrator.fsx -- checkpoint
    fi
  '';

  # ============================================
  # ZENOH TEST MESSAGING SUBSCRIPTIONS (SC-ZTEST-001 to SC-ZTEST-011)
  # Phase 8: Real-time test feedback via Zenoh pub/sub
  # Replaces log-based verification with checkpoint messages
  # ============================================

  scripts.zenoh-boot-sub.exec = ''
    echo "📡 ZENOH BOOT SUBSCRIBER: Listening for boot checkpoints (CP-BOOT-01 to CP-BOOT-10)..."
    echo "  Topics: indrajaal/boot/**"
    echo "  Checkpoints: preflight, foundation, mesh, cognitive, app, homeostasis"
    echo "  Press Ctrl+C to stop"
    echo ""
    # Try zenoh-sub if available, fallback to curl polling
    if command -v zenohd &> /dev/null; then
      zenoh-sub -k "indrajaal/boot/**"
    else
      echo "ℹ️  zenoh-sub not available, using HTTP polling..."
      while true; do
        curl -s "http://localhost:8000/key/indrajaal/boot/**" 2>/dev/null || echo "Waiting for Zenoh..."
        sleep 2
      done
    fi
  '';

  scripts.zenoh-test-sub.exec = ''
    echo "📡 ZENOH TEST SUBSCRIBER: Listening for test checkpoints (CP-TEST-01 to CP-TEST-08)..."
    echo "  Topics: indrajaal/test/**"
    echo "  Events: suite/start, compile, module, case, coverage, summary"
    echo "  Press Ctrl+C to stop"
    echo ""
    if command -v zenohd &> /dev/null; then
      zenoh-sub -k "indrajaal/test/**"
    else
      echo "ℹ️  zenoh-sub not available, using HTTP polling..."
      while true; do
        curl -s "http://localhost:8000/key/indrajaal/test/**" 2>/dev/null || echo "Waiting for Zenoh..."
        sleep 2
      done
    fi
  '';

  scripts.zenoh-smoke-sub.exec = ''
    echo "📡 ZENOH SMOKE SUBSCRIBER: Listening for smoke test checkpoints (CP-SMOKE-01 to CP-SMOKE-08)..."
    echo "  Topics: indrajaal/smoke/**"
    echo "  Categories: api, db, zenoh, perf, security, resilience"
    echo "  Press Ctrl+C to stop"
    echo ""
    if command -v zenohd &> /dev/null; then
      zenoh-sub -k "indrajaal/smoke/**"
    else
      echo "ℹ️  zenoh-sub not available, using HTTP polling..."
      while true; do
        curl -s "http://localhost:8000/key/indrajaal/smoke/**" 2>/dev/null || echo "Waiting for Zenoh..."
        sleep 2
      done
    fi
  '';

  scripts.zenoh-all-sub.exec = ''
    echo "📡 ZENOH ALL SUBSCRIBER: Listening for all Indrajaal messages..."
    echo "  Topics: indrajaal/**"
    echo "  Includes: boot, test, smoke, container, mesh, orchestrator"
    echo "  Press Ctrl+C to stop"
    echo ""
    if command -v zenohd &> /dev/null; then
      zenoh-sub -k "indrajaal/**"
    else
      echo "ℹ️  zenoh-sub not available, using HTTP polling..."
      while true; do
        curl -s "http://localhost:8000/key/indrajaal/**" 2>/dev/null || echo "Waiting for Zenoh..."
        sleep 2
      done
    fi
  '';

  scripts.test-orchestrate.exec = ''
    echo "🎼 TEST ORCHESTRATE: Running tests with Zenoh orchestration..."
    echo "  SC-ZTEST-005: Orchestrator aggregate update < 100ms"
    echo "  Subscribe to: indrajaal/test/**, indrajaal/smoke/**"
    echo ""
    # Enable Zenoh NIF and run tests with orchestration
    SKIP_ZENOH_NIF=0 \
    WALLABY_ENABLED=true \
    NO_TIMEOUT=true \
    PATIENT_MODE=enabled \
    ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" \
    MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8 \
    POSTGRES_USER=postgres \
    POSTGRES_PASSWORD=postgres \
    DATABASE_URL="ecto://postgres:postgres@localhost:5433/indrajaal_test" \
    MIX_ENV=test mix test --formatter Indrajaal.Testing.ZenohTestFormatter
  '';

  scripts.sa-agents.exec = ''
    echo "🤖 ZENOH CONTAINER AGENTS: Monitoring all containers..."
    dotnet fsi lib/cepaf/scripts/SIL6MeshOrchestrator.fsx agents
  '';

  scripts.sa-control.exec = ''
    CONTAINER="''${1:-indrajaal-ex-app-1}"
    CMD="''${2:-status}"
    echo "🎮 CONTROL: $CONTAINER → $CMD"
    dotnet fsi lib/cepaf/scripts/SIL6MeshOrchestrator.fsx control "$CONTAINER" "$CMD"
  '';

  # ============================================
  # ENHANCED SWARM ORCHESTRATOR (15-Container Mesh)
  # SC-OPT-001 to SC-OPT-008, SC-MATH-001 to SC-MATH-005
  # Mathematical foundations: CPM, DFA, RCPSP, Graph Theory
  # ============================================

  scripts.sa-swarm-up.exec = ''
    echo "🚀 SWARM BOOT: Full 15-container mesh with 2oo3 quorum..."
    echo "  Wave 1: DB Foundation"
    echo "  Wave 2: Observability + Zenoh 2oo3"
    echo "  Wave 3: Cognitive Plane (Bridge + Cortex)"
    echo "  Wave 4: Application Seed"
    echo "  Wave 5: HA + Satellites"
    dotnet fsi lib/cepaf/scripts/EnhancedSwarmOrchestrator.fsx boot
  '';

  scripts.sa-swarm-down.exec = ''
    echo "🛑 SWARM SHUTDOWN: Graceful with checkpointing..."
    dotnet fsi lib/cepaf/scripts/EnhancedSwarmOrchestrator.fsx down
  '';

  scripts.sa-swarm-status.exec = ''
    echo "📊 SWARM STATUS: 15 containers + quorum + biomorphic health..."
    dotnet fsi lib/cepaf/scripts/EnhancedSwarmOrchestrator.fsx status
  '';

  scripts.sa-swarm-quorum.exec = ''
    echo "🗳️ ZENOH QUORUM: 2oo3 verification with early exit..."
    dotnet fsi lib/cepaf/scripts/EnhancedSwarmOrchestrator.fsx quorum
  '';

  scripts.sa-swarm-bio.exec = ''
    echo "🧬 BIOMORPHIC HEALTH: Sentinel + PatternHunter + SymbioticDefense..."
    dotnet fsi lib/cepaf/scripts/EnhancedSwarmOrchestrator.fsx bio
  '';

  scripts.sa-swarm-dag.exec = ''
    echo "📈 CONTAINER DAG: Topological sort with generations..."
    dotnet fsi lib/cepaf/scripts/EnhancedSwarmOrchestrator.fsx dag
  '';

  scripts.sa-swarm-cpm.exec = ''
    echo "⏱️ CRITICAL PATH: CPM analysis for boot optimization..."
    dotnet fsi lib/cepaf/scripts/EnhancedSwarmOrchestrator.fsx cpm
  '';

  scripts.sa-swarm-rca.exec = ''
    FAILURE="''${1:-Unknown failure}"
    echo "🔍 7-LEVEL RCA: Root cause analysis for '$FAILURE'..."
    dotnet fsi lib/cepaf/scripts/EnhancedSwarmOrchestrator.fsx rca "$FAILURE"
  '';

  scripts.sa-swarm-verify.exec = ''
    echo "✅ SWARM VERIFY: Full 100+ smoke test suite..."
    dotnet fsi lib/cepaf/scripts/EnhancedSwarmOrchestrator.fsx verify
  '';

  # ============================================
  # PHASE 7: BOOT OPTIMIZATION & CONFIGURATION SYNC
  # SC-OPT-001 to SC-OPT-008, SC-PHICS-001 to SC-PHICS-006
  # Precompiled images, wave parallelization, config drift detection
  # ============================================

  scripts.sa-build-precompiled.exec = ''
    echo "🔨 PHASE 7: Building precompiled image (SC-OPT-005)..."
    bash scripts/build-precompiled-image.sh "$@"
  '';

  scripts.sa-parallel-boot.exec = ''
    echo "⚡ PHASE 7: Wave-based parallel boot (SC-OPT-002)..."
    dotnet fsi lib/cepaf/scripts/EnhancedSwarmOrchestrator.fsx parallel-boot
  '';

  scripts.sa-config-sync.exec = ''
    echo "🔄 PHASE 7: Syncing F#/Elixir configs (SC-OPT-007)..."
    dotnet fsi lib/cepaf/scripts/ConfigurationSynchronizer.fsx sync
  '';

  scripts.sa-config-drift.exec = ''
    echo "🔍 PHASE 7: Checking config drift (SC-OPT-008)..."
    dotnet fsi lib/cepaf/scripts/ConfigurationSynchronizer.fsx drift
  '';

  scripts.sa-compose-gen.exec = ''
    echo "📝 PHASE 7: Generating compose files from config..."
    dotnet fsi lib/cepaf/scripts/ConfigurationSynchronizer.fsx generate
  '';

  scripts.sa-phics-status.exec = ''
    echo "📡 PHICS: Checking device status (SC-PHICS-001)..."
    dotnet fsi lib/cepaf/scripts/PhicsMonitor.fsx status
  '';

  scripts.sa-phics-test.exec = ''
    echo "⚡ PHICS: Testing latency (SC-PHICS-003 <50ms)..."
    dotnet fsi lib/cepaf/scripts/PhicsMonitor.fsx test
  '';

  # ============================================
  # DATABASE
  # ============================================

  scripts.db-setup.exec = ''
    echo "🗄️ Setting up database..."
    mix ecto.setup
  '';

  scripts.db-reset.exec = ''
    echo "🔄 Resetting database..."
    mix ecto.reset
  '';

  scripts.db-migrate.exec = ''
    echo "📦 Running migrations..."
    mix ecto.migrate
  '';

  scripts.db-console.exec = ''
    echo "🔧 Opening database console..."
    PGPASSWORD=postgres psql -h localhost -p 5433 -U postgres -d indrajaal_dev
  '';

  # ============================================
  # TODO & PROJECT MANAGEMENT
  # ============================================

  scripts.todo.exec = ''
    # Updated to use F# Planning CLI (Sprint 45 migration)
    dotnet run --project lib/cepaf/src/Cepaf.Planning.CLI -- status
  '';

  # Rust Planning Daemon (sa-plan-daemon) — replaces F# Cepaf.Planning.CLI
  # SC-CACHE-001, AOR-CHG-001
  scripts.sa-plan.exec = ''
    cd sub-projects/intelitor-v5.2
    ./target/release/sa-plan-daemon "$@"
  '';

  # ============================================
  # CHAYA DIGITAL TWIN (SC-CHAYA-001 to SC-CHAYA-003)
  # Standalone operation with full task management
  # ============================================

  scripts.chaya.exec = ''
    CMD="''${1:-status}"
    dotnet run --project lib/cepaf/src/Cepaf.Planning.CLI -- chaya "$CMD" "''${@:2}"
  '';

  scripts.chaya-status.exec = ''
    dotnet run --project lib/cepaf/src/Cepaf.Planning.CLI -- chaya status
  '';

  scripts.chaya-tasks.exec = ''
    STATUS="''${1:-}"
    if [ -z "$STATUS" ]; then
      dotnet run --project lib/cepaf/src/Cepaf.Planning.CLI -- chaya list
    else
      dotnet run --project lib/cepaf/src/Cepaf.Planning.CLI -- chaya list "$STATUS"
    fi
  '';

  scripts.chaya-add.exec = ''
    TITLE="''${1:-}"
    PRIORITY="''${2:-P3}"
    if [ -z "$TITLE" ]; then
      echo "Usage: chaya-add <title> [priority]"
      echo "  Priority: P0, P1, P2, P3 (default: P3)"
    else
      dotnet run --project lib/cepaf/src/Cepaf.Planning.CLI -- chaya add "$TITLE" "$PRIORITY"
    fi
  '';

  scripts.chaya-update.exec = ''
    if [ "$#" -lt 2 ]; then
      echo "Usage: chaya-update <task-id> <status>"
      echo "  Status: todo, in_progress, done, blocked"
    else
      dotnet run --project lib/cepaf/src/Cepaf.Planning.CLI -- chaya update "$1" "$2"
    fi
  '';

  scripts.chaya-ooda.exec = ''
    dotnet run --project lib/cepaf/src/Cepaf.Planning.CLI -- chaya ooda
  '';

  scripts.chaya-mesh.exec = ''
    dotnet run --project lib/cepaf/src/Cepaf.Planning.CLI -- chaya mesh
  '';

  scripts.chaya-sync.exec = ''
    dotnet run --project lib/cepaf/src/Cepaf.Planning.CLI -- chaya sync
  '';

  # ============================================
  # ORCHESTRATION (SC-ORCH-001 to SC-ORCH-015)
  # Cortex-Prajna-Smriti-CEPAF-Planning-Chaya Coordination
  # ============================================

  scripts.sa-orch.exec = ''
    CMD="''${1:-status}"
    echo "🔄 ORCHESTRATION: $CMD (SC-ORCH-001)..."
    dotnet run --project lib/cepaf/src/Cepaf.Planning.CLI -- orch "$CMD" "''${@:2}"
  '';

  scripts.sa-orch-status.exec = ''
    echo "📊 ORCHESTRATION STATUS: Service health and coordination..."
    dotnet run --project lib/cepaf/src/Cepaf.Planning.CLI -- orch status
  '';

  scripts.sa-orch-init.exec = ''
    echo "🚀 ORCHESTRATION INIT: Initializing all services..."
    dotnet run --project lib/cepaf/src/Cepaf.Planning.CLI -- orch init
  '';

  scripts.sa-orch-ooda.exec = ''
    echo "🔄 OODA CYCLE: Observe-Orient-Decide-Act coordination..."
    dotnet run --project lib/cepaf/src/Cepaf.Planning.CLI -- orch ooda
  '';

  scripts.sa-orch-health.exec = ''
    echo "💊 SERVICE HEALTH: All 7 services health check..."
    dotnet run --project lib/cepaf/src/Cepaf.Planning.CLI -- orch health
  '';

  scripts.envelope.exec = ''
    echo "📊 Generating Capability Envelope Dashboard..."
    mix capability.envelope "$@"
  '';

  scripts.envelope-json.exec = ''
    mix capability.envelope --json
  '';

  scripts.envelope-journal.exec = ''
    echo "📝 Saving capability envelope to journal..."
    mix capability.envelope --journal
  '';

  # Claude Code with Multi-Language LSP
  # Languages: Elixir, Erlang, Gleam, F#, C#, Rust, Python, Bash/Zsh, SQL
  scripts.claude.exec = ''
    /home/an/.claude/local/claude "$@"
  '';

  # ============================================
  # SMRITI KNOWLEDGE MANAGEMENT SYSTEM
  # SC-SMRITI-040, SC-SMRITI-050
  # ============================================

  scripts.smriti-status.exec = ''
    dotnet fsi lib/cepaf/scripts/SmritiIngestorCLI.fsx status
  '';

  scripts.smriti-ingest.exec = ''
    dotnet fsi lib/cepaf/scripts/SmritiIngestorCLI.fsx ingest "$@"
  '';

  scripts.smriti-search.exec = ''
    dotnet fsi lib/cepaf/scripts/SmritiIngestorCLI.fsx search "$@"
  '';

  scripts.smriti-verify.exec = ''
    dotnet fsi lib/cepaf/scripts/SmritiIntegrationVerifier.fsx
  '';

  scripts.smriti-export.exec = ''
    elixir -e "Indrajaal.KMS.Panspermia.Exporter.export(:json, \"export/smriti\")"
  '';

  scripts.smriti-immortality.exec = ''
    elixir -e "Indrajaal.KMS.Immortality.Protocol.execute() |> IO.inspect()"
  '';
  scripts.smriti-immortality.description = "Execute immortality protocol";

  scripts.smriti-federation.exec = ''
    elixir -e "Indrajaal.Smriti.Federation.Protocol.sync_all() |> IO.inspect()"
  '';
  scripts.smriti-federation.description = "Sync with federation peers";

  # ============================================
  # QUICK REFERENCE
  # ============================================

  scripts.help.exec = ''
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║              INDRAJAAL v5.2 - COMMAND REFERENCE                  ║"
    echo "╠══════════════════════════════════════════════════════════════════╣"
    echo "║  INDRAJAAL APP                                                   ║"
    echo "║    app              Start Phoenix server                         ║"
    echo "║    app-start        Start containers + Phoenix                   ║"
    echo "║    app-iex          Start Phoenix with IEx console               ║"
    echo "║                                                                  ║"
    echo "║  COMPILATION & QUALITY                                           ║"
    echo "║    compile          Compile with Patient Mode                    ║"
    echo "║    compile-strict   Compile with warnings as errors              ║"
    echo "║    quality          Format + Credo checks                        ║"
    echo "║    quality-full     Full pipeline (+ Dialyzer + Sobelow)         ║"
    echo "║                                                                  ║"
    echo "║  TESTING                                                         ║"
    echo "║    test [args]      Run tests with Patient Mode                  ║"
    echo "║    test-cover       Run tests with coverage report               ║"
    echo "║    test-sil6        Run SIL-6 mesh test suite (test/sil6/)     ║"
    echo "║    test-sil6-live   SIL-6 tests with live containers           ║"
    echo "║                                                                  ║"
    echo "║  STANDALONE ENV (sa-*) - SIL-6 Certified F# CLI                   ║"
    echo "║    sa-up            Wave-based mesh boot (SC-SIL6-009)           ║"
    echo "║    sa-down          Graceful shutdown with dying gasp            ║"
    echo "║    sa-status        Digital Twin + quorum report                 ║"
    echo "║    sa-health        Quorum voting + FPPS consensus               ║"
    echo "║    sa-scour         Port substrate isolation                     ║"
    echo "║    sa-clean         Shutdown + volume prune                      ║"
    echo "║    sa-logs [svc]    Stream logs (default: indrajaal-ex-app-1)     ║"
    echo "║    sa-emergency     Immediate stop < 5s (SC-EMR-057)             ║"
    echo "║    sa-verify        5-order effects verification                 ║"
    echo "║    sa-monitor       F# TUI Cockpit (NASA-STD-3000 Dark Cockpit)    ║"
    echo "║    cockpit [cmd]    Cockpit CLI: status|health|nodes|alarms     ║"
    echo "║    sa-ux            Run UX/UI evaluation                         ║"
    echo "║    sa-orchestrate   Run test orchestrator                        ║"
    echo "║                                                                  ║"
    echo "║  SIL-6 FULL MESH (Biomorphic Fractal Holon)                       ║"
    echo "║    sa-mesh [cmd]    SIL-6 mesh: boot|down|status|test           ║"
    echo "║    sa-mesh-boot     Full biomorphic boot sequence               ║"
    echo "║    sa-mesh-status   Digital twin + quorum + Zenoh status        ║"
    echo "║    sa-mesh-test     Run all system tests                        ║"
    echo "║    sa-test-obs      Test observability stack                    ║"
    echo "║    sa-test-cc       Test change control capability              ║"
    echo "║    sa-test-mv       Test multiverse forking                     ║"
    echo "║    sa-bdd-smoke     BDD smoke tests for 15-container mesh       ║"
    echo "║    sa-checkpoint    Create state checkpoint                     ║"
    echo "║    sa-restore       Restore from checkpoint                     ║"
    echo "║    sa-fork          Fork shadow universe                        ║"
    echo "║                                                                  ║"
    echo "║  ZENOH TEST MESSAGING (SC-ZTEST-001 to SC-ZTEST-011)            ║"
    echo "║    zenoh-boot-sub   Subscribe to boot checkpoints (CP-BOOT-*)   ║"
    echo "║    zenoh-test-sub   Subscribe to test checkpoints (CP-TEST-*)   ║"
    echo "║    zenoh-smoke-sub  Subscribe to smoke checkpoints (CP-SMOKE-*) ║"
    echo "║    zenoh-all-sub    Subscribe to all Indrajaal Zenoh messages   ║"
    echo "║    test-orchestrate Run tests with Zenoh orchestration          ║"
    echo "║                                                                  ║"
    echo "║  ENHANCED SWARM (15-Container with 2oo3 Quorum)                  ║"
    echo "║    sa-swarm-up      Boot full 15-container swarm (7 tiers)    ║"
    echo "║    sa-swarm-down    Graceful shutdown with checkpointing        ║"
    echo "║    sa-swarm-status  Swarm status + quorum + biomorphic          ║"
    echo "║    sa-swarm-quorum  2oo3 Zenoh quorum verification              ║"
    echo "║    sa-swarm-bio     Biomorphic health check                     ║"
    echo "║    sa-swarm-dag     Container DAG visualization                 ║"
    echo "║    sa-swarm-cpm     Critical path analysis                      ║"
    echo "║    sa-swarm-rca     7-level root cause analysis                 ║"
    echo "║    sa-swarm-verify  Full 100+ smoke test suite                  ║"
    echo "║                                                                  ║"
    echo "║  PHASE 7: BOOT OPTIMIZATION & CONFIG SYNC                        ║"
    echo "║    sa-build-precompiled  Build precompiled BEAM image           ║"
    echo "║    sa-parallel-boot      Wave-based parallel boot optimization  ║"
    echo "║    sa-config-sync        Sync F#/Elixir configurations          ║"
    echo "║    sa-config-drift       Check configuration drift              ║"
    echo "║    sa-compose-gen        Generate compose files from config     ║"
    echo "║    sa-phics-status       PHICS device status check              ║"
    echo "║    sa-phics-test         PHICS latency test (<50ms)             ║"
    echo "║                                                                  ║"
    echo "║  CEPAF / F# COCKPIT                                              ║"
    echo "║    cockpitf [cmd]   F# Cockpit (deploy|status|test|cleanup)      ║"
    echo "║    cepaf-build      Build F# projects                            ║"
    echo "║    cepaf-test [grp] Run F# Expecto tests (optional group filter) ║"
    echo "║    constraint-sync  Constraint sync engine (SC/AOR census+FMEA)   ║"
    echo "║    zenoh-ffi-build  Build Zenoh FFI native library (Rust)        ║"
    echo "║                                                                  ║"
    echo "║  DATABASE                                                        ║"
    echo "║    db-setup         Setup database                               ║"
    echo "║    db-reset         Reset database                               ║"
    echo "║    db-migrate       Run migrations                               ║"
    echo "║    db-console       Open psql console                            ║"
    echo "║                                                                  ║"
    echo "║  PLANNING & TASK MANAGEMENT (Sprint 45 Migration)                 ║"
    echo "║    todo             Show project tasks (F# Planning System)      ║"
    echo "║    sa-plan [cmd]    Planning CLI (status|add|update|list)        ║"
    echo "║                                                                  ║"
    echo "║  CHAYA DIGITAL TWIN (SC-CHAYA-001 to SC-CHAYA-003)               ║"
    echo "║    chaya [cmd]      Chaya CLI (status|list|add|update|ooda|mesh) ║"
    echo "║    chaya-status     Show Chaya status and health                 ║"
    echo "║    chaya-tasks      List tasks (optional: status filter)         ║"
    echo "║    chaya-add        Add task: chaya-add <title> [priority]       ║"
    echo "║    chaya-update     Update: chaya-update <id> <status>           ║"
    echo "║    chaya-ooda       Run OODA cycle (<100ms per SC-OODA-001)      ║"
    echo "║    chaya-mesh       Show mesh topology and distribution          ║"
    echo "║    chaya-sync       Sync with PROJECT_TODOLIST.md                ║"
    echo "║                                                                  ║"
    echo "║  ORCHESTRATION (SC-ORCH-001 to SC-ORCH-015)                      ║"
    echo "║    sa-orch [cmd]    Orchestration: status|init|ooda|health      ║"
    echo "║    sa-orch-status   Service health and coordination             ║"
    echo "║    sa-orch-init     Initialize all 7 services                    ║"
    echo "║    sa-orch-ooda     Run OODA cycle coordination                 ║"
    echo "║    sa-orch-health   All services health check                    ║"
    echo "║                                                                  ║"
    echo "║  REPORTING                                                       ║"
    echo "║    envelope         Capability envelope dashboard                ║"
    echo "║    envelope-json    Export envelope as JSON                      ║"
    echo "║    envelope-journal Save envelope to journal                     ║"
    echo "║                                                                  ║"
    echo "║  CPU GOVERNOR (SC-CPU-GOV-001, 85% hard limit)                    ║"
    echo "║    governed-compile  CPU-safe compilation (adaptive parallelism) ║"
    echo "║    governed-test     CPU-safe test execution (HEALTH_PORT=4051) ║"
    echo "║    governed-wallaby  CPU-safe Wallaby E2E (Chrome, port 4050)   ║"
    echo "║    governed-exec     CPU-safe arbitrary command                  ║"
    echo "║    cpu-status        CPU governor dashboard                     ║"
    echo "║                                                                  ║"
    echo "║  RUST TOOLS (lib/rust/ workspace, SC-ZMOF-001)                    ║"
    echo "║    sa-regression    Browser regression TUI (--headless --url)   ║"
    echo "║    sa-fmea-gen      Generate FMEA/STAMP directives (--format)  ║"
    echo "║    sa-agui-catalog  Generate AG-UI idea catalog (--format)     ║"
    echo "║    rust-check       Clippy + tests for all Rust crates         ║"
    echo "║                                                                  ║"
    echo "║  OTHER                                                           ║"
    echo "║    help             Show this help                               ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "  Prajna Cockpit:  http://localhost:4000/prajna"
    echo "  AI Copilot:      http://localhost:4000/prajna/copilot"
    echo "  Grafana:         http://localhost:3000 (admin/indrajaal)"
    echo ""
  '';

  enterShell = ''
    # FORCE PRIORITIZATION of writable global npm packages (SC-SYS-004)
    export PATH="/home/an/.npm-global/bin:$PATH"
    export NPM_CONFIG_PREFIX="/home/an/.npm-global"

    # Zenoh FFI native library path (SC-FFI-001)
    # Required for F# tests that load libzenoh_ffi.so via DllImport
    export LD_LIBRARY_PATH="$PWD/target/release:''${LD_LIBRARY_PATH:-}"

    # GPU Terminal Detection (Bash/Zsh + oh-my-* compatible)
    # Supports: oh-my-zsh, oh-my-bash, Powerlevel10k, Starship, etc.
    _gpu_terminal=false

    # Check COLORTERM (most reliable for truecolor)
    case "$COLORTERM" in
      truecolor|24bit) _gpu_terminal=true ;;
    esac

    # Check TERM
    case "$TERM" in
      *-256color|*-direct|xterm-kitty|alacritty*|tmux-256color|screen-256color) _gpu_terminal=true ;;
    esac

    # oh-my-zsh / oh-my-bash detection (these frameworks assume color support)
    [ -n "$ZSH" ] && _gpu_terminal=true                    # oh-my-zsh
    [ -n "$OSH" ] && _gpu_terminal=true                    # oh-my-bash
    [ -n "$ZSH_VERSION" ] && [ -n "$TERM" ] && _gpu_terminal=true  # zsh with any TERM
    [ -n "$BASH_VERSION" ] && [ "$TERM" != "dumb" ] && _gpu_terminal=true  # bash non-dumb

    # Powerlevel10k / Starship / other prompts
    [ -n "$POWERLEVEL9K_LEFT_PROMPT_ELEMENTS" ] && _gpu_terminal=true
    [ -n "$STARSHIP_SESSION_KEY" ] && _gpu_terminal=true
    [ -n "$SPACESHIP_VERSION" ] && _gpu_terminal=true

    # Check terminal-specific env vars
    [ -n "$KITTY_WINDOW_ID" ] && _gpu_terminal=true
    [ -n "$ALACRITTY_LOG" ] && _gpu_terminal=true
    [ -n "$ALACRITTY_SOCKET" ] && _gpu_terminal=true
    [ -n "$WEZTERM_PANE" ] && _gpu_terminal=true
    [ "$TERM_PROGRAM" = "WezTerm" ] && _gpu_terminal=true
    [ "$TERM_PROGRAM" = "iTerm.app" ] && _gpu_terminal=true
    [ "$TERM_PROGRAM" = "Apple_Terminal" ] && _gpu_terminal=true
    [ "$TERM_PROGRAM" = "vscode" ] && _gpu_terminal=true
    [ "$TERM_PROGRAM" = "Hyper" ] && _gpu_terminal=true
    [ -n "$KONSOLE_VERSION" ] && _gpu_terminal=true
    [ -n "$GNOME_TERMINAL_SCREEN" ] && _gpu_terminal=true
    [ -n "$VTE_VERSION" ] && _gpu_terminal=true            # GTK terminals (Tilix, etc.)
    [ -n "$WT_SESSION" ] && _gpu_terminal=true             # Windows Terminal
    [ -n "$TMUX" ] && _gpu_terminal=true                   # tmux
    [ -n "$ZELLIJ" ] && _gpu_terminal=true                 # Zellij

    if [ "$_gpu_terminal" = true ]; then
      # 24-bit True Color (GPU terminals)
      RED='\033[38;2;255;82;82m'
      LRED='\033[38;2;255;138;128m'
      CYAN='\033[38;2;0;229;255m'
      LCYAN='\033[38;2;132;255;255m'
      GOLD='\033[38;2;255;193;7m'
      LGOLD='\033[38;2;255;215;64m'
      GREEN='\033[38;2;105;240;174m'
      LGREEN='\033[38;2;185;246;202m'
      YELLOW='\033[38;2;255;245;157m'
      MAGENTA='\033[38;2;234;128;252m'
      WHITE='\033[38;2;255;255;255m'
      DIM='\033[2m'
      BOLD='\033[1m'
      NC='\033[0m'
    else
      # Fallback: Green monochrome
      RED='\033[0;32m'
      LRED='\033[1;32m'
      CYAN='\033[0;32m'
      LCYAN='\033[1;32m'
      GOLD='\033[0;32m'
      LGOLD='\033[1;32m'
      GREEN='\033[0;32m'
      LGREEN='\033[1;32m'
      YELLOW='\033[1;32m'
      MAGENTA='\033[0;32m'
      WHITE='\033[1;32m'
      DIM='\033[2m'
      BOLD='\033[1m'
      NC='\033[0m'
    fi

    echo ""
    echo -e "    ''${GOLD}●''${NC}''${DIM}╮''${NC}       ''${DIM}╭''${NC}''${GOLD}●''${NC}"
    echo -e "     ''${DIM}╰╮''${NC} ''${DIM}╭─╮''${NC} ''${DIM}╭╯''${NC}"
    echo -e "  ''${GOLD}●''${NC}''${DIM}───''${NC}''${CYAN}◉''${NC}''${DIM}─┤''${NC}''${LRED}''${BOLD}◈''${NC}''${DIM}├─''${NC}''${CYAN}◉''${NC}''${DIM}───''${NC}''${GOLD}●''${NC}   ''${WHITE}''${BOLD}INDRAJAAL''${NC}"
    echo -e "     ''${DIM}╭╯''${NC} ''${DIM}╰─╯''${NC} ''${DIM}╰╮''${NC}       ''${DIM}इन्द्रजाल''${NC}"
    echo -e "    ''${GOLD}●''${NC}''${DIM}╯''${NC}       ''${DIM}╰''${NC}''${GOLD}●''${NC}       ''${GREEN}v20.0.0''${NC} ''${DIM}Biomorphic Fractal Holon''${NC}"
    echo ""
    echo -e "  ''${DIM}Elixir''${NC} ''${LGREEN}$(elixir -v 2>/dev/null | head -1 | cut -d' ' -f2)''${NC}  ''${DIM}.NET''${NC} ''${LGREEN}$(dotnet --version 2>/dev/null)''${NC}  ''${DIM}Podman''${NC} ''${LGREEN}$(podman -v 2>/dev/null | cut -d' ' -f3)''${NC}  ''${DIM}Editor''${NC} ''${LGREEN}Helix (hx)''${NC}"
    echo ""
    echo -e "  ''${YELLOW}help''${NC} ''${DIM}│''${NC} ''${YELLOW}sa-up''${NC} ''${DIM}│''${NC} ''${YELLOW}compile''${NC} ''${DIM}│''${NC} ''${YELLOW}test''${NC} ''${DIM}│''${NC} ''${YELLOW}app''${NC} ''${DIM}│''${NC} ''${YELLOW}quality''${NC}"
    echo ""
    echo -e "  ''${RED}◈''${NC} ''${DIM}Patient Mode''${NC}   ''${CYAN}◉''${NC} ''${DIM}Zero-Defect''${NC}   ''${GOLD}●''${NC} ''${DIM}50 Agents''${NC}"
    echo ""
  '';

  cachix.enable = false;
}
