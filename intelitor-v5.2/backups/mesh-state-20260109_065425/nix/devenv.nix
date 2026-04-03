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

    # Database
    POSTGRES_USER = "postgres";
    POSTGRES_PASSWORD = "postgres";
    DATABASE_URL = "ecto://postgres:postgres@localhost:5433/indrajaal_dev";

    # Logging
    LOG_DIRECTORY = "./data/tmp";

    # CEPAF / Infrastructure
    PROJECT_ROOT = "/home/an/dev/ver/intelitor-v5.2";
  };

  packages = with pkgs; [
    git
    podman
    podman-compose
    elixir_1_19
    erlang_28
    nodejs_20
    postgresql_17
    redis
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
    # Language Servers for Claude Code LSP Plugin
    elixir-ls                          # Elixir LSP
    erlang-language-platform           # Erlang LSP
    gleam                              # Gleam LSP (built-in)
    fsautocomplete                     # F# LSP
    csharp-ls                          # C# LSP (lightweight)
    pyright                            # Python LSP (fast type checker)
    nodePackages.bash-language-server  # Bash/Zsh LSP
    sqls                               # SQL LSP (PostgreSQL, SQLite, MySQL)
    # Additional Language Servers (SC-LSP-001)
    nodePackages.yaml-language-server  # YAML LSP (OpenAPI, K8s, etc.)
    haskellPackages.Agda               # Agda proof assistant (with agda-mode)
    graphviz                           # DOT graph language tools
    # Nix Language Support (SC-LSP-002)
    nil                                # Nix LSP (modern, incremental)
    nixpkgs-fmt                        # Nix formatter
    nix-tree                           # Dependency tree visualization
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

  # ============================================
  # COMPILATION & QUALITY
  # ============================================

  # SC-METRICS-003: MANDATORY 16 schedulers for ALL compilation
  scripts.compile.exec = ''
    echo "⚡ Compiling with Patient Mode + 16 schedulers (SC-METRICS-003)..."
    NO_TIMEOUT=true PATIENT_MODE=enabled \
    ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" \
    MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8 \
    mix compile 2>&1 | tee -a ./data/tmp/1-compile.log
  '';

  scripts.compile-strict.exec = ''
    echo "🔒 Strict compilation (warnings as errors, 16 schedulers)..."
    NO_TIMEOUT=true PATIENT_MODE=enabled \
    ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" \
    MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8 \
    mix compile --warnings-as-errors 2>&1 | tee -a ./data/tmp/1-compile.log
  '';

  scripts.compile-profile.exec = ''
    echo "📊 Profiled compilation with timing metrics (SC-METRICS-001)..."
    mkdir -p ./data/metrics
    NO_TIMEOUT=true PATIENT_MODE=enabled \
    ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" \
    MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8 \
    mix compile --profile time 2>&1 | tee ./data/metrics/compile-profile-$(date +%Y%m%d-%H%M%S).log
    echo ""
    echo "🔍 Top 20 slowest files (by wait time):"
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

  # SC-METRICS-003: MANDATORY 16 schedulers for ALL test compilation
  scripts.test.exec = ''
    echo "🧪 Running tests (SC-TEST-NIF-001: Zenoh NIF ACTIVE, SC-METRICS-003: 16 schedulers)..."
    SKIP_ZENOH_NIF=0 \
    POSTGRES_USER=postgres \
    POSTGRES_PASSWORD=postgres \
    DATABASE_URL="ecto://postgres:postgres@localhost:5433/indrajaal_test" \
    NO_TIMEOUT=true \
    PATIENT_MODE=enabled \
    ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" \
    MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8 \
    MIX_ENV=test mix test "$@"
  '';

  scripts.test-cover.exec = ''
    echo "📊 Running tests with coverage (SC-TEST-NIF-001: Zenoh NIF ACTIVE, SC-METRICS-003: 16 schedulers)..."
    SKIP_ZENOH_NIF=0 \
    POSTGRES_USER=postgres \
    POSTGRES_PASSWORD=postgres \
    DATABASE_URL="ecto://postgres:postgres@localhost:5433/indrajaal_test" \
    NO_TIMEOUT=true \
    PATIENT_MODE=enabled \
    ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" \
    MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8 \
    MIX_ENV=test mix test --cover
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

  scripts.sa-logs.exec = ''
    SERVICE="''${1:-indrajaal-app-prod}"
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
    echo "📡 SIL-6 MONITOR: Biomorphic Dashboard..."
    dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- mesh dashboard
  '';

  scripts.sa-dashboard.exec = ''
    echo "📊 SIL-6 DASHBOARD: Real-time Mesh View..."
    dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- mesh dashboard
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
    mix todo.status
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
    echo "║                                                                  ║"
    echo "║  STANDALONE ENV (sa-*) - SIL-6 Certified F# CLI                   ║"
    echo "║    sa-up            Wave-based mesh boot (SC-SIL6-009)           ║"
    echo "║    sa-down          Graceful shutdown with dying gasp            ║"
    echo "║    sa-status        Digital Twin + quorum report                 ║"
    echo "║    sa-health        Quorum voting + FPPS consensus               ║"
    echo "║    sa-scour         Port substrate isolation                     ║"
    echo "║    sa-clean         Shutdown + volume prune                      ║"
    echo "║    sa-logs [svc]    Stream logs (default: indrajaal-app-prod)    ║"
    echo "║    sa-emergency     Immediate stop < 5s (SC-EMR-057)             ║"
    echo "║    sa-verify        5-order effects verification                 ║"
    echo "║    sa-monitor       Biomorphic dashboard                         ║"
    echo "║    sa-ux            Run UX/UI evaluation                         ║"
    echo "║    sa-orchestrate   Run test orchestrator                        ║"
    echo "║                                                                  ║"
    echo "║  CEPAF / F# COCKPIT                                              ║"
    echo "║    cockpitf [cmd]   F# Cockpit (deploy|status|test|cleanup)      ║"
    echo "║    cepaf-build      Build F# projects                            ║"
    echo "║                                                                  ║"
    echo "║  DATABASE                                                        ║"
    echo "║    db-setup         Setup database                               ║"
    echo "║    db-reset         Reset database                               ║"
    echo "║    db-migrate       Run migrations                               ║"
    echo "║    db-console       Open psql console                            ║"
    echo "║                                                                  ║"
    echo "║  REPORTING & TRACKING                                             ║"
    echo "║    envelope         Capability envelope dashboard                ║"
    echo "║    envelope-json    Export envelope as JSON                      ║"
    echo "║    envelope-journal Save envelope to journal                     ║"
    echo "║    todo             Show project tasks                           ║"
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
    echo -e "  ''${DIM}Elixir''${NC} ''${LGREEN}$(elixir -v 2>/dev/null | head -1 | cut -d' ' -f2)''${NC}  ''${DIM}.NET''${NC} ''${LGREEN}$(dotnet --version 2>/dev/null)''${NC}  ''${DIM}Podman''${NC} ''${LGREEN}$(podman -v 2>/dev/null | cut -d' ' -f3)''${NC}"
    echo ""
    echo -e "  ''${YELLOW}help''${NC} ''${DIM}│''${NC} ''${YELLOW}sa-up''${NC} ''${DIM}│''${NC} ''${YELLOW}compile''${NC} ''${DIM}│''${NC} ''${YELLOW}test''${NC} ''${DIM}│''${NC} ''${YELLOW}app''${NC} ''${DIM}│''${NC} ''${YELLOW}quality''${NC}"
    echo ""
    echo -e "  ''${RED}◈''${NC} ''${DIM}Patient Mode''${NC}   ''${CYAN}◉''${NC} ''${DIM}Zero-Defect''${NC}   ''${GOLD}●''${NC} ''${DIM}50 Agents''${NC}"
    echo ""
  '';

  cachix.enable = false;
}
