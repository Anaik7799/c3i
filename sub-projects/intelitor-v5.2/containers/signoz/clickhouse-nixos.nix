{ pkgs ? import <nixpkgs> {} }:

let
  # Pre-built configuration files
  signozConfig = pkgs.writeText "signoz.xml" ''
    <clickhouse>
        <logger>
            <level>information</level>
            <log>/var/log/clickhouse-server/clickhouse-server.log</log>
            <errorlog>/var/log/clickhouse-server/clickhouse-server.err.log</errorlog>
            <size>1000M</size>
            <count>10</count>
        </logger>

        <listen_host>::</listen_host>
        <http_port>8123</http_port>
        <tcp_port>9000</tcp_port>

        <!-- Skip validation for user-level settings (we put them in users.xml) -->
        <skip_check_for_incorrect_settings>1</skip_check_for_incorrect_settings>

        <!-- Data path for ClickHouse -->
        <path>/var/lib/clickhouse/</path>

        <!-- Enable query log for monitoring -->
        <query_log>
            <database>system</database>
            <table>query_log</table>
            <partition_by>toYYYYMM(event_date)</partition_by>
            <flush_interval_milliseconds>7500</flush_interval_milliseconds>
        </query_log>
    </clickhouse>
  '';

  usersConfig = pkgs.writeText "signoz-users.xml" ''
    <clickhouse>
        <users>
            <signoz>
                <password from_env="CLICKHOUSE_PASSWORD"/>
                <networks>
                    <ip>::/0</ip>
                </networks>
                <profile>default</profile>
                <quota>default</quota>
                <!-- STAMP: User-level resource limits -->
                <max_memory_usage>5368709120</max_memory_usage> <!-- 5GB per query -->
                <max_execution_time>300</max_execution_time> <!-- 5 minute timeout -->
            </signoz>
        </users>

        <profiles>
            <default>
                <!-- STAMP: Resource limits to prevent OOM (UCA1) -->
                <max_memory_usage>7516192768</max_memory_usage>
                <max_memory_usage_for_all_queries>6442450944</max_memory_usage_for_all_queries>
                <!-- STAMP: Query complexity limits (SC3) -->
                <max_query_size>1048576</max_query_size>
                <max_ast_depth>1000</max_ast_depth>
                <max_ast_elements>50000</max_ast_elements>
                <max_expanded_ast_elements>500000</max_expanded_ast_elements>
                <!-- STAMP: Default query limits for safety -->
                <max_execution_time>60</max_execution_time>
                <max_rows_to_read>1000000000</max_rows_to_read>
                <max_bytes_to_read>107374182400</max_bytes_to_read>
                <max_rows_to_group_by>1000000</max_rows_to_group_by>
                <group_by_overflow_mode>throw</group_by_overflow_mode>
            </default>
        </profiles>
    </clickhouse>
  '';

  healthCheckScript = pkgs.writeShellScriptBin "health-check.sh" ''
    ${pkgs.clickhouse}/bin/clickhouse-client --query "SELECT 1" >/dev/null 2>&1
  '';

in pkgs.dockerTools.buildLayeredImage {
  name = "localhost/signoz-clickhouse";
  tag = "latest";

  contents = with pkgs; [
    clickhouse
    bash
    coreutils
    curl
    gnugrep
    gawk
    netcat-gnu
    healthCheckScript
    # TDG: Additional packages determined by tests
  ];

  # extraCommands runs without requiring KVM (unlike runAsRoot)
  extraCommands = ''
    # Create necessary directories
    mkdir -p var/lib/clickhouse
    mkdir -p var/log/clickhouse-server
    mkdir -p etc/clickhouse-server/config.d
    mkdir -p etc/clickhouse-server/users.d
    mkdir -p usr/local/bin

    # STAMP: Apply safety constraints for data directories (SC1, SC3)
    chmod 700 var/lib/clickhouse
    chmod 755 var/log/clickhouse-server

    # Copy configuration files
    cp ${signozConfig} etc/clickhouse-server/config.d/signoz.xml
    cp ${usersConfig} etc/clickhouse-server/users.d/signoz.xml

    # Create symlink for health check
    ln -sf ${healthCheckScript}/bin/health-check.sh usr/local/bin/health-check.sh
  '';
  
  config = {
    Cmd = [ "${pkgs.clickhouse}/bin/clickhouse-server" "--config-file=/etc/clickhouse-server/config.xml" ];
    
    WorkingDir = "/var/lib/clickhouse";
    
    User = "clickhouse";
    
    ExposedPorts = {
      "8123/tcp" = {};  # HTTP interface
      "9000/tcp" = {};  # Native protocol
      "9005/tcp" = {};  # Interserver HTTP
      "9009/tcp" = {};  # Interserver native protocol
    };
    
    Volumes = {
      "/var/lib/clickhouse" = {};
      "/var/log/clickhouse-server" = {};
    };
    
    Env = [
      "CLICKHOUSE_DB=signoz"
      "CLICKHOUSE_USER=signoz"
      "CLICKHOUSE_DEFAULT_ACCESS_MANAGEMENT=1"
    ];
    
    # GDE: Health check for goal monitoring
    # Note: Durations must be in nanoseconds for podman compatibility
    Healthcheck = {
      Test = ["CMD" "/usr/local/bin/health-check.sh"];
      Interval = 30000000000;  # 30s in nanoseconds
      Timeout = 5000000000;    # 5s in nanoseconds
      Retries = 3;
      StartPeriod = 40000000000;  # 40s in nanoseconds
    };
    
    Labels = {
      "org.opencontainers.image.source" = "https://github.com/SigNoz/signoz";
      "org.opencontainers.image.description" = "ClickHouse for SigNoz - TDG/STAMP validated";
      "org.opencontainers.image.version" = pkgs.clickhouse.version;
      "indrajaal.component" = "observability";
      "indrajaal.subsystem" = "clickhouse";
    };
  };
}