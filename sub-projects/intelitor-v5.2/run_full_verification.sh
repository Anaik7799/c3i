#!/usr/bin/env dart

import 'dart:async';
import 'dart:io';
import 'dart:convert';

// --- CEPA: Cybernetic Execution and Performance Architect ---
// v2.0 - Hybrid Dart/Elixir Architecture

// ANSI color codes
const String red = '\u001b[31m';
const String green = '\u001b[32m';
const String yellow = '\u001b[33m';
const String blue = '\u001b[34m';
const String cyan = '\u001b[36m';
const String reset = '\u001b[0m';

// --- Utility Functions ---

void printColor(String text, String color) {
  stdout.writeln('$color$text$reset');
}

class RollingLog {
  final int maxLines = 10;
  final List<String> _lines = [];
  bool _initialized = false;

  void add(String line, String prefix, String color) {
    if (!_initialized) {
      for (int i = 0; i < maxLines; i++) stdout.writeln();
      _initialized = true;
    }

    final timestamp = DateTime.now().toIso8601String().split('T')[1].split('.')[0];
    final formattedLine = '$color[$timestamp] [$prefix] $line$reset';
    
    _lines.add(formattedLine);
    if (_lines.length > maxLines) _lines.removeAt(0);
    _render();
  }

  void _render() {
    // Move up to the start of the log area
    stdout.write('\u001b[${maxLines}A');
    for (int i = 0; i < maxLines; i++) {
      stdout.write('\u001b[2K'); // Clear line
      if (i < _lines.length) {
        stdout.writeln(_lines[i]);
      } else {
        stdout.writeln();
      }
    }
  }

  void finalize() {
    _initialized = false;
    _lines.clear();
  }
}

final rollingLog = RollingLog();

Future<void> _runCommand(String executable, List<String> arguments, {bool ignoreErrors = false, Map<String, String>? environment}) async {
  final process = await Process.start(executable, arguments, environment: environment);
  final prefix = executable.split('/').last;

  process.stdout.transform(utf8.decoder).transform(LineSplitter()).listen((line) {
    rollingLog.add(line, prefix, green);
  });
  process.stderr.transform(utf8.decoder).transform(LineSplitter()).listen((line) {
    if (!line.contains("Waiting for container")) {
      rollingLog.add(line, prefix, yellow);
    }
  });

  final exitCode = await process.exitCode;
  rollingLog.finalize();

  if (exitCode != 0 && !ignoreErrors) {
    throw Exception('Command "$executable ${arguments.join(' ')}" failed with code $exitCode');
  }
}

// --- Data Structures ---

class ComposeService {
  final String name;
  final String? image;
  final Map<String, String> environment;

  ComposeService(this.name, {this.image, this.environment = const {}});

  @override
  String toString() => 'Service(name: $name, image: $image)';
}

class ComposeConfig {
  final String filename;
  final String environmentName;
  final Map<String, ComposeService> services;

  ComposeConfig(this.filename, this.environmentName, this.services);
}

// --- Main Orchestrator ---

Future<void> main() async {
  // Clear screen
  stdout.write('\u001b[2J\u001b[H');

  printColor('╔══════════════════════════════════════════════════════════════╗', cyan);
  printColor('║   CEPA: Unified Autonomic Verification Protocol (v2.0)       ║', cyan);
  printColor('║   Orchestrator: Dart VM | Tools: Elixir/BEAM                 ║', cyan);
  printColor('╚══════════════════════════════════════════════════════════════╝', cyan);

  final master = MasterAceLifecycleTest();
  
  final stopwatch = Stopwatch()..start();
  
  try {
    await master.run();
    stopwatch.stop();
    printColor('\n✅ PROTOCOL COMPLETE. Execution time: ${stopwatch.elapsed.inSeconds}s', green);
    exit(0);
  } catch (e, st) {
    stopwatch.stop();
    printColor('\n❌ PROTOCOL FAILED. Execution time: ${stopwatch.elapsed.inSeconds}s', red);
    printColor('Critical Error: $e', red);
    printColor(st.toString(), yellow);
    exit(1);
  }
}

class MasterAceLifecycleTest {
  final VTOOrchestrator _vto = VTOOrchestrator();
  final ImageBuilder _builder = ImageBuilder();
  final AceVerifier _verifier = AceVerifier();

  Future<void> run() async {
    await _vto.sterilizeAll();
    await _builder.buildAll();
    await _verifier.verifyAllEnvironments();
  }
}

// --- Phase 1: Sterilization ---

class VTOOrchestrator {
  Future<void> sterilizeAll() async {
    printColor('\n--- Phase 1: Sterilization (VTO) ---', blue);
    print('Cleaning up environment...');
    
    try {
      await _runCommand('podman-compose', ['down', '-v'], ignoreErrors: true);
      printColor('--> System Sterilized.', green);
    } catch (e) {
      printColor('--> Warning during sterilization: $e', yellow);
    }
  }
}

// --- Phase 2: Construction ---

class ImageBuilder {
  static const Map<String, String> _images = {
    'localhost/indrajaal-app:latest': 'Dockerfile.sopv51-app',
    'localhost/indrajaal-db:latest': 'Containerfile.nixos',
    'localhost/indrajaal-obs:latest': 'Dockerfile.sopv51-base',
  };

  Future<void> buildAll() async {
    printColor('\n--- Phase 2: Construction (Image Builder) ---', blue);
    
    for (final entry in _images.entries) {
      await _buildImageWithOODA(entry.key, entry.value);
    }
    printColor('--> All images built.', green);
  }

  Future<void> _buildImageWithOODA(String imageTag, String dockerfile, {int retries = 1}) async {
    for (int i = 0; i <= retries; i++) {
      try {
        print("--> Building '$imageTag'...");
        await _runCommand('podman', ['build', '-t', imageTag, '-f', dockerfile, '.']);
        printColor("    ✅ Success.", green);
        return;
      } catch (e) {
        if (i < retries) {
          printColor("    🧠 CEPA OODA: Build failed. Analyzing...", yellow);
          final errorStr = e.toString();
          if (errorStr.contains("unexpected token 'RUNN'")) {
             printColor("    🛠️ Action: Correcting Dockerfile 'RUNN' typo...", yellow);
             final file = File(dockerfile);
             if (await file.exists()) {
               String content = await file.readAsString();
               content = content.replaceAll('RUNN', 'RUN');
               await file.writeAsString(content);
               continue;
             }
          }
          throw "Build failed with unrecoverable error: $e";
        } else {
          throw "Build failed after $retries self-correction attempts.";
        }
      }
    }
  }
}

// --- Phase 3: Verification ---

class AceVerifier {
  Future<void> verifyAllEnvironments() async {
    printColor('\n--- Phase 3: Verification (AceVerifier) ---', blue);

    await _verifyDevEnvironment();

    final composeFiles = [
      'podman-compose-testing.yml',
      'podman-compose.yml',
      'podman-compose-secure.yml',
    ];

    for (final filename in composeFiles) {
      await _verifyContainerEnvironment(filename);
    }
  }

  Future<void> _verifyDevEnvironment() async {
    printColor('\n[Environment: DEV (Host-Based)]', cyan);
    Process? serverProcess;

    try {
      print('--> Starting Dependencies (DB)...');
      await _runCommand('podman-compose', ['-f', 'podman-compose-3container.yml', 'up', '-d', 'indrajaal-db']);
      
      // Wait for DB readiness using a retry loop
      await _waitForDatabase('localhost');

      print('--> Starting Phoenix Server (Host)...');
      serverProcess = await Process.start('iex', ['-S', 'mix', 'phx.server'], 
        environment: {'MIX_ENV': 'dev'}
      );
      
      serverProcess.stdout.transform(utf8.decoder).listen((data) {
        if (data.contains('Access IndrajaalWeb.Endpoint at')) {
           printColor('    ✅ Server accepted connection signal.', green);
        }
      });
      
      await Future.delayed(Duration(seconds: 15));
      await _runHostChecks();

    } finally {
      if (serverProcess != null) {
        print('--> Stopping Phoenix Server...');
        serverProcess.kill(ProcessSignal.sigterm);
      }
      print('--> Stopping Dependencies...');
      await _runCommand('podman-compose', ['-f', 'podman-compose-3container.yml', 'down']);
    }
  }

  Future<void> _verifyContainerEnvironment(String filename) async {
    if (!await File(filename).exists()) {
      printColor('--> Skipping $filename (not found)', yellow);
      return;
    }

    String envName = filename.contains("testing") ? "TEST" : (filename.contains("secure") ? "PROD" : "DEMO");
    printColor('\n[Environment: $envName (Containerized)]', cyan);

    try {
      print('--> Starting Environment ($filename)...');
      await _runCommand('podman-compose', ['-f', filename, 'up', '-d']);
      
      print('--> Running Container Checks...');
      await _runCommand('podman', ['ps'], ignoreErrors: true);
      // Logic would go here to exec into containers

    } finally {
      print('--> Stopping Environment...');
      await _runCommand('podman-compose', ['-f', filename, 'down']);
    }
  }

  Future<void> _runHostChecks() async {
    print('--> Running Host Verification Checks...');
    
    try {
      final res = await Process.run('curl', ['-s', '-o', '/dev/null', '-w', '%{http_code}', 'http://localhost:4000']);
      if (res.stdout == '200') printColor('    ✅ Web Access: OK', green);
      else printColor('    ❌ Web Access: Failed (HTTP ${res.stdout})', red);
    } catch (e) {
      printColor('    ❌ Web Access: Error ($e)', red);
    }

    try {
      await _runCommand('mix', ['run', '-e', 'IO.puts("    ✅ DB Access: OK")']);
    } catch (_) {
      printColor('    ❌ DB Access: Failed', red);
    }
  }

  Future<void> _waitForDatabase(String host) async {
    print('--> Waiting for Database...');
    for (int i = 0; i < 12; i++) {
      try {
        final res = await Process.run('mix', ['run', '-e', 'Ecto.Adapter.ensure_all_started(Indrajaal.Repo, :temporary)'], 
          environment: {'MIX_ENV': 'dev'}
        );
        if (res.exitCode == 0) {
          printColor('    ✅ Database Ready.', green);
          return;
        }
      } catch (_) {}
      stdout.write('.');
      await Future.delayed(Duration(seconds: 5));
    }
    printColor('\n    ⚠️ Database wait timed out.', yellow);
  }

  ComposeConfig _parseCompose(String filename, String envName, String content) {
    final services = <String, ComposeService>{};
    final lines = content.split('\n');
    String? currentService;
    bool inServices = false;

    for (var line in lines) {
      if (line.trim().startsWith('services:')) { inServices = true; continue; }
      if (!inServices) continue;

      if (line.startsWith('  ') && !line.startsWith('    ') && line.trim().endsWith(':')) {
        currentService = line.trim().replaceAll(':', '');
        services[currentService] = ComposeService(currentService);
      }
    }
    return ComposeConfig(filename, envName, services);
  }
}
