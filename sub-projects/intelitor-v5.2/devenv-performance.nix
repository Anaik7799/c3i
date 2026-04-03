{ pkgs, ... }:
{
  # Enhanced performance testing environment with LXC container support
  packages = with pkgs; [
    # Core Elixir/Erlang stack
    elixir_1_17
    erlang_27
    
    # Database tools
    postgresql_17
    
    # Container management
    lxd
    lxc
    
    # Load testing tools
    artillery
    wrk
    hey
    siege
    httpie
    
    # Performance monitoring
    htop
    iotop
    nethogs
    bandwhich
    sysstat
    perf-tools
    
    # Analysis and debugging
    flamegraph
    valgrind
    gdb
    strace
    
    # Network tools
    netcat
    nmap
    tcpdump
    wireshark-cli
    
    # Development essentials
    git
    curl
    jq
    yq-go
    vim
    tmux
    
    # Container inspection
    dive
    ctop
    
    # Benchmarking
    sysbench
    stress-ng
    
    # Observability
    prometheus
    grafana
    
    # File system tools
    ncdu
    tree
    fd
    ripgrep
  ];

  # Enable language support
  languages.elixir.enable = true;
  languages.javascript.enable = true;
  languages.python.enable = true;
  languages.nix.enable = true;

  # Services for development
  services.postgres = {
    enable = true;
    package = pkgs.postgresql_17;
    port = 5433;  # Non-conflicting port
    initialDatabases = [
      { name = "intelitor_dev"; }
      { name = "intelitor_test"; }
    ];
    settings = {
      max_connections = 200;
      shared_buffers = "256MB";
      effective_cache_size = "1GB";
      work_mem = "16MB";
      maintenance_work_mem = "128MB";
    };
  };

  services.redis = {
    enable = true;
    port = 6380;  # Non-conflicting port
  };

  # Custom scripts for performance testing
  scripts = {
    # LXC Environment Management
    lxc-setup.exec = ''
      echo "🚀 Setting up LXC performance testing environment..."
      elixir scripts/performance/setup_lxc_environment.exs --setup
    '';

    lxc-status.exec = ''
      echo "📊 LXC Environment Status:"
      elixir scripts/performance/setup_lxc_environment.exs --status
    '';

    lxc-start.exec = ''
      echo "▶️ Starting all LXC containers..."
      elixir scripts/performance/setup_lxc_environment.exs --start
    '';

    lxc-stop.exec = ''
      echo "⏹️ Stopping all LXC containers..."
      elixir scripts/performance/setup_lxc_environment.exs --stop
    '';

    lxc-teardown.exec = ''
      echo "🗑️ Tearing down LXC environment..."
      read -p "Are you sure? This will destroy all containers! (y/N): " confirm
      if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        elixir scripts/performance/setup_lxc_environment.exs --teardown
      else
        echo "Cancelled."
      fi
    '';

    # Application Setup
    perf-setup.exec = ''
      echo "🏗️ Setting up Intelitor for performance testing..."
      
      # Ensure dependencies
      mix deps.get
      
      # Database setup
      mix ecto.create
      mix ecto.migrate
      
      # Generate performance test data
      echo "📊 Generating performance test data..."
      mix performance.setup_data --tenants 50 --users_per_tenant 100 --devices_per_tenant 200
      
      echo "✅ Performance setup complete!"
    '';

    # Performance Testing
    perf-baseline.exec = ''
      echo "📈 Running baseline performance tests..."
      mix performance.baseline
    '';

    perf-load.exec = ''
      echo "🚛 Running load tests..."
      mix performance.load_test
    '';

    perf-stress.exec = ''
      echo "💪 Running stress tests..."
      mix performance.stress_test
    '';

    perf-endurance.exec = ''
      echo "🏃 Running endurance tests..."
      mix performance.endurance_test
    '';

    perf-full.exec = ''
      echo "🎯 Running full performance test suite..."
      
      echo "1️⃣ Baseline tests..."
      mix performance.baseline
      
      echo "2️⃣ Load tests..."
      mix performance.load_test
      
      echo "3️⃣ Stress tests..."
      mix performance.stress_test
      
      echo "4️⃣ Endurance tests..."
      mix performance.endurance_test
      
      echo "5️⃣ Generating comprehensive report..."
      mix performance.generate_report
      
      echo "✅ Full performance testing complete!"
    '';

    # Load Testing Tools
    artillery-test.exec = ''
      echo "🎯 Running Artillery load test..."
      artillery run scripts/performance/artillery-config.yml --output /tmp/artillery-report.json
      artillery report /tmp/artillery-report.json --output artillery-report.html
      echo "📊 Report generated: artillery-report.html"
    '';

    wrk-test.exec = ''
      echo "⚡ Running wrk load test..."
      wrk -t12 -c400 -d30s --latency http://10.200.0.10:4000/api/v1/alarms
    '';

    elixir-load.exec = ''
      echo "💎 Running custom Elixir load test..."
      elixir scripts/performance/elixir_load_tester.ex
    '';

    # Monitoring
    perf-monitor.exec = ''
      echo "📊 Starting performance monitoring dashboard..."
      
      # Start dashboard in background
      mix compile.dashboard --refresh 5 &
      DASHBOARD_PID=$!
      
      # Start htop for system monitoring
      htop &
      HTOP_PID=$!
      
      echo "🎮 Monitoring started!"
      echo "  - Dashboard refreshing every 5 seconds"
      echo "  - System monitor (htop) running"
      echo "  - Press Ctrl+C to stop all monitoring"
      
      # Wait for user interrupt
      trap "kill $DASHBOARD_PID $HTOP_PID 2>/dev/null; exit" INT
      wait
    '';

    # Container Application Deployment
    deploy-app.exec = ''
      echo "🚢 Deploying Intelitor to containers..."
      
      # Build release
      MIX_ENV=prod mix release
      
      # Deploy to primary app container
      echo "📦 Deploying to primary app server..."
      lxc file push _build/prod/rel/intelitor/ intelitor-app-primary/opt/ -r
      lxc exec intelitor-app-primary -- systemctl restart intelitor-primary
      
      # Deploy to secondary app container  
      echo "📦 Deploying to secondary app server..."
      lxc file push _build/prod/rel/intelitor/ intelitor-app-secondary/opt/ -r
      lxc exec intelitor-app-secondary -- systemctl restart intelitor-secondary
      
      echo "✅ Deployment complete!"
    '';

    # Database Operations
    db-setup.exec = ''
      echo "🗄️ Setting up databases in containers..."
      
      # Setup primary database
      lxc exec intelitor-db-perf -- su postgres -c "createdb intelitor_prod"
      
      # Run migrations
      MIX_ENV=prod DATABASE_URL=postgres://postgres@10.200.0.5:5432/intelitor_prod mix ecto.migrate
      
      echo "✅ Database setup complete!"
    '';

    # Health Checks
    health-check.exec = ''
      echo "🏥 Performing health checks..."
      
      echo "📡 Checking container connectivity..."
      
      # Check database
      if nc -z 10.200.0.5 5432; then
        echo "  ✅ Database (10.200.0.5:5432) - OK"
      else
        echo "  ❌ Database (10.200.0.5:5432) - FAILED"
      fi
      
      # Check app servers
      if curl -s http://10.200.0.10:4000/health >/dev/null; then
        echo "  ✅ App Primary (10.200.0.10:4000) - OK"
      else
        echo "  ❌ App Primary (10.200.0.10:4000) - FAILED"
      fi
      
      if curl -s http://10.200.0.11:4010/health >/dev/null; then
        echo "  ✅ App Secondary (10.200.0.11:4010) - OK"
      else
        echo "  ❌ App Secondary (10.200.0.11:4010) - FAILED"
      fi
      
      # Check monitoring
      if curl -s http://10.200.0.30:3000 >/dev/null; then
        echo "  ✅ Grafana (10.200.0.30:3000) - OK"
      else
        echo "  ❌ Grafana (10.200.0.30:3000) - FAILED"
      fi
      
      if curl -s http://10.200.0.30:9090 >/dev/null; then
        echo "  ✅ Prometheus (10.200.0.30:9090) - OK"
      else
        echo "  ❌ Prometheus (10.200.0.30:9090) - FAILED"
      fi
      
      # Check storage
      if curl -s http://10.200.0.40:9000/minio/health/live >/dev/null; then
        echo "  ✅ MinIO (10.200.0.40:9000) - OK"
      else
        echo "  ❌ MinIO (10.200.0.40:9000) - FAILED"
      fi
    '';

    # Log Collection
    collect-logs.exec = ''
      echo "📝 Collecting logs from all containers..."
      
      mkdir -p logs/containers
      
      # Collect from each container
      for container in intelitor-db-perf intelitor-app-primary intelitor-app-secondary intelitor-load-gen intelitor-monitoring intelitor-storage; do
        echo "  📄 Collecting logs from $container..."
        lxc exec $container -- journalctl --no-pager -n 1000 > logs/containers/$container.log 2>/dev/null || echo "    ⚠️  Failed to collect logs from $container"
      done
      
      # Collect LXC host logs
      journalctl --no-pager -u snap.lxd.daemon -n 500 > logs/containers/lxd-host.log 2>/dev/null || echo "    ⚠️  Failed to collect LXD logs"
      
      echo "✅ Logs collected in logs/containers/"
    '';

    # Performance Analysis
    analyze-performance.exec = ''
      echo "🔍 Analyzing performance data..."
      
      # Generate performance report
      mix performance.generate_report
      
      # Analyze container resource usage
      echo "📊 Container Resource Analysis:"
      for container in intelitor-db-perf intelitor-app-primary intelitor-app-secondary intelitor-load-gen intelitor-monitoring intelitor-storage; do
        echo "  🔧 $container:"
        lxc info $container | grep -E "(Memory|CPU|Disk)" || echo "    ⚠️  No resource data available"
      done
      
      # Check for bottlenecks
      echo "🚨 Bottleneck Analysis:"
      echo "  (This would contain automated bottleneck detection)"
      
      echo "✅ Performance analysis complete!"
    '';
  };

  # Environment variables for performance testing
  env = {
    # Database connections
    DATABASE_URL = "postgres://postgres@localhost:5433/intelitor_dev";
    TEST_DATABASE_URL = "postgres://postgres@localhost:5433/intelitor_test";
    
    # Container network
    CONTAINER_NETWORK = "10.200.0.0/24";
    
    # Performance testing settings
    PERFORMANCE_TEST_DURATION = "600";  # 10 minutes default
    PERFORMANCE_TEST_USERS = "100";
    PERFORMANCE_TEST_TARGET = "http://10.200.0.10:4000";
    
    # Monitoring
    PROMETHEUS_URL = "http://10.200.0.30:9090";
    GRAFANA_URL = "http://10.200.0.30:3000";
    
    # Load testing
    ARTILLERY_TARGET = "http://10.200.0.10:4000";
    WRK_THREADS = "12";
    WRK_CONNECTIONS = "400";
    
    # Resource limits
    MAX_MEMORY_MB = "32768";  # 32GB total
    MAX_CPU_CORES = "32";
  };

  # Shell configuration
  enterShell = ''
    echo "🏗️  Intelitor LXC Performance Testing Environment"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo ""
    echo "🚀 LXC Container Management:"
    echo "  lxc-setup     - Setup all LXC containers with NixOS"
    echo "  lxc-status    - Show container status and health"
    echo "  lxc-start     - Start all containers"
    echo "  lxc-stop      - Stop all containers" 
    echo "  lxc-teardown  - Destroy all containers (careful!)"
    echo ""
    echo "🏗️  Application Setup:"
    echo "  perf-setup    - Setup Intelitor with test data"
    echo "  deploy-app    - Deploy to containers"
    echo "  db-setup      - Setup production databases"
    echo "  health-check  - Check all services"
    echo ""
    echo "🧪 Performance Testing:"
    echo "  perf-baseline - Run baseline tests"
    echo "  perf-load     - Run load tests"
    echo "  perf-stress   - Run stress tests"
    echo "  perf-endurance- Run endurance tests"
    echo "  perf-full     - Run complete test suite"
    echo ""
    echo "⚡ Load Testing Tools:"
    echo "  artillery-test- Artillery HTTP load testing"
    echo "  wrk-test      - wrk HTTP benchmarking"
    echo "  elixir-load   - Custom Elixir load testing"
    echo ""
    echo "📊 Monitoring & Analysis:"
    echo "  perf-monitor  - Start monitoring dashboard"
    echo "  collect-logs  - Collect logs from all containers"
    echo "  analyze-performance - Generate performance analysis"
    echo ""
    echo "🔗 Service URLs (after setup):"
    echo "  App Primary:   http://10.200.0.10:4000"
    echo "  App Secondary: http://10.200.0.11:4010"
    echo "  Database:      postgresql://postgres@10.200.0.5:5432"
    echo "  Grafana:       http://10.200.0.30:3000 (admin/perftest123)"
    echo "  Prometheus:    http://10.200.0.30:9090"
    echo "  MinIO:         http://10.200.0.40:9000 (admin/perftest123)"
    echo ""
    echo "⚠️  First time setup: run 'lxc-setup' to create containers"
    echo ""
    
    # Show current LXC status if available
    if command -v lxc >/dev/null 2>&1; then
      echo "📊 Current Container Status:"
      lxc list 2>/dev/null | grep intelitor || echo "  No Intelitor containers found"
      echo ""
    fi
  '';

  # Pre-commit hooks for performance testing
  pre-commit.hooks = {
    # Ensure performance tests don't regress
    performance-check = {
      enable = true;
      entry = "mix performance.regression_test";
      language = "system";
      files = "\\.(ex|exs)$";
      pass_filenames = false;
    };
    
    # Check container configurations
    lxc-config-check = {
      enable = true;
      entry = "scripts/performance/validate_lxc_configs.sh";
      language = "system";
      files = "scripts/performance/.*\\.exs$";
      pass_filenames = false;
    };
  };
}