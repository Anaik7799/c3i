#!/usr/bin/env dart
/// ═══════════════════════════════════════════════════════════════════════════════
/// INTELITOR STANDALONE DISTRIBUTED MODE STARTUP
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// Robust Dart script for starting Intelitor in full mesh cluster distributed mode:
/// - Erlang distribution enabled for Tailnet mesh
/// - Livebook remote attachment support
/// - CEPAF bridge connectivity
/// - Zenoh pub/sub mesh
/// - API access from network nodes
///
/// STAMP Compliance: SC-CLU-001 to SC-CLU-005
///
/// Usage:
///   dart run scripts/standalone/start_distributed.dart
///   dart run scripts/standalone/start_distributed.dart --background
///   dart run scripts/standalone/start_distributed.dart --verify-only
///
/// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:io';

/// ANSI color codes for terminal output
class Colors {
  static const String red = '\x1B[31m';
  static const String green = '\x1B[32m';
  static const String yellow = '\x1B[33m';
  static const String blue = '\x1B[34m';
  static const String cyan = '\x1B[36m';
  static const String reset = '\x1B[0m';
}

/// Network mode detection result
class NetworkMode {
  final String mode; // 'tailscale' or 'local'
  final String ip;
  final String hostname;
  final String suffix;
  final bool tailscaleAvailable;

  NetworkMode({
    required this.mode,
    required this.ip,
    required this.hostname,
    required this.suffix,
    required this.tailscaleAvailable,
  });

  Map<String, dynamic> toJson() => {
    'mode': mode,
    'ip': ip,
    'hostname': hostname,
    'suffix': suffix,
    'tailscale_available': tailscaleAvailable,
  };
}

/// Service health check result
class ServiceStatus {
  final String name;
  final String host;
  final int port;
  final bool healthy;
  final String? error;

  ServiceStatus({
    required this.name,
    required this.host,
    required this.port,
    required this.healthy,
    this.error,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'host': host,
    'port': port,
    'healthy': healthy,
    if (error != null) 'error': error,
  };
}

/// Container status
class ContainerStatus {
  final String name;
  final String status;
  final bool healthy;
  final String? ports;

  ContainerStatus({
    required this.name,
    required this.status,
    required this.healthy,
    this.ports,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'status': status,
    'healthy': healthy,
    if (ports != null) 'ports': ports,
  };
}

/// Main distributed startup manager
class DistributedStartup {
  final String projectRoot;
  late NetworkMode networkMode;
  late String erlangCookie;
  final List<ServiceStatus> serviceStatuses = [];
  final List<ContainerStatus> containerStatuses = [];

  DistributedStartup(this.projectRoot);

  /// Required services to check
  static const List<Map<String, dynamic>> requiredServices = [
    {'name': 'PostgreSQL', 'host': 'localhost', 'port': 5433},
    {'name': 'Redis', 'host': 'localhost', 'port': 6379},
    {'name': 'EPMD', 'host': 'localhost', 'port': 4369},
    {'name': 'Phoenix', 'host': 'localhost', 'port': 4000},
    {'name': 'OTLP', 'host': 'localhost', 'port': 4317},
    {'name': 'Prometheus', 'host': 'localhost', 'port': 9090},
    {'name': 'Grafana', 'host': 'localhost', 'port': 3000},
  ];

  /// Required containers
  static const List<String> requiredContainers = [
    'intelitor-db-standalone',
    'intelitor-obs-standalone',
  ];

  /// Print colored header
  void printHeader() {
    print('${Colors.cyan}═══════════════════════════════════════════════════════════════════════════════${Colors.reset}');
    print('${Colors.cyan}  INTELITOR STANDALONE DISTRIBUTED MODE${Colors.reset}');
    print('${Colors.cyan}═══════════════════════════════════════════════════════════════════════════════${Colors.reset}');
    print('');
  }

  /// Detect network mode (Tailscale vs Local)
  Future<NetworkMode> detectNetworkMode() async {
    print('${Colors.blue}[1/7] Detecting network mode...${Colors.reset}');

    try {
      // Check if Tailscale is available and running
      final tsStatus = await Process.run('tailscale', ['status', '--json']);

      if (tsStatus.exitCode == 0) {
        final status = jsonDecode(tsStatus.stdout as String);

        if (status['BackendState'] == 'Running') {
          // Get Tailscale IP
          final ipResult = await Process.run('tailscale', ['ip', '-4']);
          final tsIp = (ipResult.stdout as String).trim();

          // Get Tailscale DNS name
          final dnsResult = await Process.run('tailscale', ['status', '--self', '--json']);
          final selfInfo = jsonDecode(dnsResult.stdout as String);
          final dnsName = (selfInfo['Self']['DNSName'] as String).replaceAll(RegExp(r'\.$'), '');
          final suffix = dnsName.split('.').skip(1).join('.');

          print('${Colors.green}  ✓ Tailscale detected and running${Colors.reset}');
          print('    IP: $tsIp');
          print('    Hostname: $dnsName');
          print('    Suffix: $suffix');

          return NetworkMode(
            mode: 'tailscale',
            ip: tsIp,
            hostname: dnsName,
            suffix: suffix,
            tailscaleAvailable: true,
          );
        }
      }
    } catch (e) {
      // Tailscale not available
    }

    // Fall back to local mode
    final localIp = await _getLocalIp();
    final hostname = await _getHostname();

    print('${Colors.yellow}  ⚠ Using local mode (Tailscale not available)${Colors.reset}');
    print('    IP: $localIp');
    print('    Hostname: $hostname');

    return NetworkMode(
      mode: 'local',
      ip: localIp,
      hostname: hostname,
      suffix: 'local.intelitor',
      tailscaleAvailable: false,
    );
  }

  Future<String> _getLocalIp() async {
    try {
      final result = await Process.run('hostname', ['-I']);
      return (result.stdout as String).split(' ').first.trim();
    } catch (e) {
      return '127.0.0.1';
    }
  }

  Future<String> _getHostname() async {
    try {
      final result = await Process.run('hostname', ['-f']);
      return (result.stdout as String).trim();
    } catch (e) {
      return 'localhost';
    }
  }

  /// Setup Erlang cookie
  Future<String> setupErlangCookie() async {
    print('${Colors.blue}[2/7] Setting up Erlang cookie...${Colors.reset}');

    final cookieFile = File('${Platform.environment['HOME']}/.erlang.cookie');

    // Check environment variable first
    final envCookie = Platform.environment['RELEASE_COOKIE'];
    if (envCookie != null && envCookie.isNotEmpty) {
      print('${Colors.green}  ✓ Using RELEASE_COOKIE from environment${Colors.reset}');
      return envCookie;
    }

    // Check cookie file
    if (await cookieFile.exists()) {
      final cookie = (await cookieFile.readAsString()).trim();
      print('${Colors.green}  ✓ Using existing cookie from ${cookieFile.path}${Colors.reset}');
      return cookie;
    }

    // Generate new cookie
    final result = await Process.run('openssl', ['rand', '-base64', '32']);
    final cookie = (result.stdout as String).replaceAll(RegExp(r'[/+=]'), '').substring(0, 20);

    await cookieFile.writeAsString(cookie);
    await Process.run('chmod', ['400', cookieFile.path]);

    print('${Colors.green}  ✓ Generated new cookie: ${cookie.substring(0, 8)}...${Colors.reset}');
    return cookie;
  }

  /// Check container status
  Future<void> checkContainers() async {
    print('${Colors.blue}[3/7] Checking container status...${Colors.reset}');

    try {
      final result = await Process.run('podman', [
        'ps',
        '--format',
        '{{.Names}}\t{{.Status}}\t{{.Ports}}'
      ]);

      if (result.exitCode == 0) {
        final lines = (result.stdout as String).split('\n').where((l) => l.isNotEmpty);

        for (final line in lines) {
          final parts = line.split('\t');
          if (parts.length >= 2) {
            final name = parts[0];
            final status = parts[1];
            final ports = parts.length > 2 ? parts[2] : null;
            final healthy = status.contains('healthy') || status.contains('Up');

            containerStatuses.add(ContainerStatus(
              name: name,
              status: status,
              healthy: healthy,
              ports: ports,
            ));

            final icon = healthy ? '${Colors.green}✓' : '${Colors.red}✗';
            print('  $icon${Colors.reset} $name: $status');
          }
        }
      }
    } catch (e) {
      print('${Colors.red}  ✗ Error checking containers: $e${Colors.reset}');
    }

    // Start missing containers
    final runningNames = containerStatuses.map((c) => c.name).toSet();
    final missingContainers = requiredContainers.where((c) => !runningNames.contains(c));

    if (missingContainers.isNotEmpty) {
      print('${Colors.yellow}  Starting missing containers...${Colors.reset}');
      await Process.run('podman-compose', [
        '-f', '$projectRoot/podman-compose.yml',
        'up', '-d',
        ...missingContainers,
      ]);
      await Future.delayed(Duration(seconds: 5));
    }
  }

  /// Check service ports
  Future<void> checkServices() async {
    print('${Colors.blue}[4/7] Checking service ports...${Colors.reset}');

    for (final svc in requiredServices) {
      final status = await _checkPort(svc['host'] as String, svc['port'] as int);
      serviceStatuses.add(status);

      final icon = status.healthy ? '${Colors.green}✓' : '${Colors.red}✗';
      final errorMsg = status.error != null ? ' (${status.error})' : '';
      print('  $icon${Colors.reset} ${status.name} (${status.host}:${status.port})$errorMsg');
    }
  }

  Future<ServiceStatus> _checkPort(String host, int port) async {
    try {
      final socket = await Socket.connect(host, port, timeout: Duration(seconds: 2));
      await socket.close();
      return ServiceStatus(
        name: requiredServices.firstWhere((s) => s['port'] == port)['name'] as String,
        host: host,
        port: port,
        healthy: true,
      );
    } catch (e) {
      return ServiceStatus(
        name: requiredServices.firstWhere((s) => s['port'] == port)['name'] as String,
        host: host,
        port: port,
        healthy: false,
        error: e.toString().split(':').last.trim(),
      );
    }
  }

  /// Verify CEPAF bridge
  Future<void> verifyCepaf() async {
    print('${Colors.blue}[5/7] Verifying CEPAF bridge...${Colors.reset}');

    final cepafCli = File('$projectRoot/lib/cepaf/artifacts/cepaf-podman-cli');

    if (await cepafCli.exists()) {
      try {
        final result = await Process.run(cepafCli.path, ['--version']);
        print('${Colors.green}  ✓ CEPAF CLI available: ${(result.stdout as String).trim()}${Colors.reset}');

        final healthResult = await Process.run(cepafCli.path, ['health', 'summary']);
        print('    Health: ${(healthResult.stdout as String).trim()}');
      } catch (e) {
        print('${Colors.yellow}  ⚠ CEPAF CLI error: $e${Colors.reset}');
      }
    } else {
      print('${Colors.yellow}  ⚠ CEPAF CLI not found${Colors.reset}');
      print('    Fallback: Using direct podman commands');
    }
  }

  /// Display connection information
  void displayConnectionInfo() {
    print('${Colors.blue}[6/7] Connection Information${Colors.reset}');
    print('');
    print('${Colors.cyan}═══════════════════════════════════════════════════════════════════════════════${Colors.reset}');
    print('${Colors.cyan}  REMOTE ACCESS CONFIGURATION${Colors.reset}');
    print('${Colors.cyan}═══════════════════════════════════════════════════════════════════════════════${Colors.reset}');
    print('');
    print('${Colors.green}Erlang Node:${Colors.reset}');
    print('  Name:   intelitor@${networkMode.ip}');
    print('  Cookie: $erlangCookie');
    print('');
    print('${Colors.green}Network Access:${Colors.reset}');
    print('  Mode:   ${networkMode.mode}');
    print('  IP:     ${networkMode.ip}');
    print('  EPMD:   ${networkMode.ip}:4369');
    print('  Dist:   ${networkMode.ip}:9100-9105');
    print('');
    print('${Colors.green}Phoenix:${Colors.reset}');
    print('  URL:    http://${networkMode.ip}:4000');
    print('  API:    http://${networkMode.ip}:4000/api/v1');
    print('');
    print('${Colors.green}Livebook (from Windows):${Colors.reset}');
    print('  PowerShell:');
    print('    \$env:LIVEBOOK_COOKIE = "$erlangCookie"');
    print('    livebook server');
    print('');
    print('  Then in Livebook UI:');
    print('    Runtime → Attached node');
    print('    Name:   intelitor@${networkMode.ip}');
    print('    Cookie: $erlangCookie');
    print('');
    print('${Colors.green}Zenoh Topics:${Colors.reset}');
    print('  KPI:      intelitor/kpi/**');
    print('  Control:  intelitor/control/**');
    print('  Coord:    intelitor/coord/**');
    print('');
    print('${Colors.cyan}═══════════════════════════════════════════════════════════════════════════════${Colors.reset}');
    print('');
  }

  /// Build environment variables
  Map<String, String> buildEnvironment() {
    return {
      // Core distribution
      'RELEASE_NAME': 'intelitor',
      'RELEASE_DISTRIBUTION': 'name',
      'RELEASE_NODE': 'intelitor@${networkMode.ip}',
      'RELEASE_COOKIE': erlangCookie,

      // Tailscale/Cluster
      'TAILSCALE_DNS_SUFFIX': networkMode.suffix,
      'TS_IP_ADDRESS': networkMode.ip,
      'TS_HOSTNAME': networkMode.hostname,
      'DISTRIBUTED_MODE': 'true',
      'CLUSTER_STRATEGY': 'standalone',
      'CLUSTER_POLLING_INTERVAL': '5000',

      // Database
      'POSTGRES_USER': Platform.environment['POSTGRES_USER'] ?? 'postgres',
      'POSTGRES_PASSWORD': Platform.environment['POSTGRES_PASSWORD'] ?? 'postgres',
      'DATABASE_URL': Platform.environment['DATABASE_URL'] ??
          'ecto://postgres:postgres@localhost:5433/intelitor_dev',

      // Observability
      'OTEL_EXPORTER_OTLP_ENDPOINT': Platform.environment['OTEL_EXPORTER_OTLP_ENDPOINT'] ??
          'http://localhost:4317',
      'SIGNOZ_ENABLED': 'true',

      // Patient Mode
      'NO_TIMEOUT': 'true',
      'PATIENT_MODE': 'enabled',
      'INFINITE_PATIENCE': 'true',

      // Phoenix
      'PHX_HOST': networkMode.ip,
      'PHX_SERVER': 'true',
      'PORT': Platform.environment['PORT'] ?? '4000',

      // EPMD port range
      'ERL_EPMD_PORT': '4369',
      'ERLANG_DIST_PORT_MIN': '9100',
      'ERLANG_DIST_PORT_MAX': '9105',
    };
  }

  /// Start the application
  Future<void> startApplication() async {
    print('${Colors.blue}[7/7] Starting Intelitor in distributed mode...${Colors.reset}');
    print('');

    final env = buildEnvironment();
    final erlFlags = '-kernel inet_dist_listen_min 9100 inet_dist_listen_max 9105';

    final process = await Process.start(
      'iex',
      [
        '--name', 'intelitor@${networkMode.ip}',
        '--cookie', erlangCookie,
        '--erl', erlFlags,
        '-S', 'mix', 'phx.server',
      ],
      workingDirectory: projectRoot,
      environment: {...Platform.environment, ...env},
      mode: ProcessStartMode.inheritStdio,
    );

    // Wait for process to exit
    final exitCode = await process.exitCode;
    exit(exitCode);
  }

  /// Generate JSON status report
  Map<String, dynamic> generateReport() {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'network_mode': networkMode.toJson(),
      'erlang_cookie': '${erlangCookie.substring(0, 8)}...',
      'services': serviceStatuses.map((s) => s.toJson()).toList(),
      'containers': containerStatuses.map((c) => c.toJson()).toList(),
      'overall': {
        'services_healthy': serviceStatuses.every((s) => s.healthy),
        'containers_healthy': containerStatuses.every((c) => c.healthy),
        'ready': serviceStatuses.every((s) => s.healthy) &&
                 containerStatuses.every((c) => c.healthy),
      },
    };
  }

  /// Main run method
  Future<void> run({bool verifyOnly = false, bool jsonOutput = false}) async {
    if (!jsonOutput) {
      printHeader();
    }

    networkMode = await detectNetworkMode();
    erlangCookie = await setupErlangCookie();
    await checkContainers();
    await checkServices();
    await verifyCepaf();

    if (jsonOutput) {
      print(JsonEncoder.withIndent('  ').convert(generateReport()));
      return;
    }

    displayConnectionInfo();

    if (verifyOnly) {
      final allHealthy = serviceStatuses.every((s) => s.healthy) &&
                         containerStatuses.every((c) => c.healthy);
      exit(allHealthy ? 0 : 1);
    }

    await startApplication();
  }
}

void main(List<String> args) async {
  final projectRoot = Directory.current.path;
  final startup = DistributedStartup(projectRoot);

  final verifyOnly = args.contains('--verify-only') || args.contains('-v');
  final jsonOutput = args.contains('--json') || args.contains('-j');
  final showHelp = args.contains('--help') || args.contains('-h');

  if (showHelp) {
    print('''
Intelitor Standalone Distributed Mode Startup

Usage:
  dart run scripts/standalone/start_distributed.dart [options]

Options:
  --verify-only, -v   Only verify services, don't start the application
  --json, -j          Output status as JSON
  --help, -h          Show this help message

Examples:
  dart run scripts/standalone/start_distributed.dart
  dart run scripts/standalone/start_distributed.dart --verify-only
  dart run scripts/standalone/start_distributed.dart --json
''');
    exit(0);
  }

  await startup.run(verifyOnly: verifyOnly, jsonOutput: jsonOutput);
}
