# ClickHouse for SigNoz - SOPv5.11 Compliant Container
# Built from localhost base image for CONTAINER_POLICY.md compliance
# Generated: 2025-11-17 07:30 CEST

FROM localhost/indrajaal-sopv51-base:nixos-25.05-latest

# STAMP: Apply safety constraints for directories (SC1, SC3)
RUN mkdir -p /var/lib/clickhouse /var/log/clickhouse-server \
    /etc/clickhouse-server/config.d /etc/clickhouse-server/users.d && \
    chmod 700 /var/lib/clickhouse && \
    chmod 755 /var/log/clickhouse-server

# Install ClickHouse from NixOS packages
RUN nix-env -iA nixpkgs.clickhouse

# Configure ClickHouse for SigNoz with STAMP resource limits
RUN cat > /etc/clickhouse-server/config.d/signoz.xml << 'EOF'
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

    <!-- STAMP: Resource limits to prevent OOM (UCA1) -->
    <max_memory_usage>7516192768</max_memory_usage> <!-- 7GB -->
    <max_memory_usage_for_all_queries>6442450944</max_memory_usage_for_all_queries> <!-- 6GB -->

    <!-- STAMP: Query complexity limits (SC3) -->
    <max_query_size>1048576</max_query_size>
    <max_ast_depth>1000</max_ast_depth>
    <max_ast_elements>50000</max_ast_elements>
    <max_expanded_ast_elements>500000</max_expanded_ast_elements>

    <!-- Storage policies -->
    <storage_configuration>
        <disks>
            <default>
                <path>/var/lib/clickhouse/</path>
                <!-- STAMP: Disk space limit (SC3) -->
                <keep_free_space_bytes>10737418240</keep_free_space_bytes> <!-- 10GB free -->
            </default>
        </disks>
    </storage_configuration>

    <!-- Enable query log for monitoring -->
    <query_log>
        <database>system</database>
        <table>query_log</table>
        <partition_by>toYYYYMM(event_date)</partition_by>
        <flush_interval_milliseconds>7500</flush_interval_milliseconds>
    </query_log>
</clickhouse>
EOF

# User configuration with safety constraints
RUN cat > /etc/clickhouse-server/users.d/signoz.xml << 'EOF'
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
            <!-- STAMP: Default query limits for safety -->
            <max_execution_time>60</max_execution_time>
            <max_rows_to_read>1000000000</max_rows_to_read>
            <max_bytes_to_read>107374182400</max_bytes_to_read> <!-- 100GB -->
            <max_rows_to_group_by>1000000</max_rows_to_group_by>
            <group_by_overflow_mode>throw</group_by_overflow_mode>
        </default>
    </profiles>
</clickhouse>
EOF

# GDE: Health check for goal monitoring
HEALTHCHECK --interval=30s --timeout=5s --retries=3 --start-period=40s \
    CMD clickhouse-client --query "SELECT 1" >/dev/null 2>&1

# Metadata labels
LABEL org.opencontainers.image.source="https://github.com/SigNoz/signoz"
LABEL org.opencontainers.image.description="ClickHouse for SigNoz - TDG/STAMP validated"
LABEL indrajaal.component="observability"
LABEL indrajaal.subsystem="clickhouse"

# Environment variables
ENV CLICKHOUSE_DB=signoz \
    CLICKHOUSE_USER=signoz \
    CLICKHOUSE_DEFAULT_ACCESS_MANAGEMENT=1

# Expose ports
EXPOSE 8123/tcp 9000/tcp 9005/tcp 9009/tcp

# Volumes
VOLUME ["/var/lib/clickhouse", "/var/log/clickhouse-server"]

# Run as clickhouse user (already configured in base image)
USER clickhouse
WORKDIR /var/lib/clickhouse

CMD ["clickhouse-server", "--config-file=/etc/clickhouse-server/config.xml"]
