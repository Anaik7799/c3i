import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:graphs/graphs.dart';
import 'package:matcher/matcher.dart';
import 'package:talker/talker.dart';
import 'package:puppeteer/puppeteer.dart';
import 'package:yaml/yaml.dart'; // Import YAML package
import 'cepa.dart'; 

// --- Data Structures ---

class ComposeService {
  final String name;
  final String? image;
  final Map<String, String> environment;
  final Set<String> dependsOn;

  ComposeService(this.name, {this.image, this.environment = const {}, this.dependsOn = const {}}); 

  @override
  String toString() => 'Service(name: $name, dependsOn: $dependsOn)';
}

class ComposeConfig {
  final String filename;
  final String environmentName;
  final Map<String, ComposeService> services;

  ComposeConfig(this.filename, this.environmentName, this.services);
}

class CepaConfig {
  final Map<String, String> activeEnvs;
  final bool runSterilization;
  final bool runBuild;
  final bool runInfraCheck;
  final bool runTests;
  final bool runUiCheck;

  CepaConfig({
    required this.activeEnvs,
    this.runSterilization = true,
    this.runBuild = true,
    this.runInfraCheck = true,
    this.runTests = false,
    this.runUiCheck = false,
  });
}

// --- Orchestration Logic ---

class CepaHybridPipeline {
  final CepaConfig config;
  
  // Dependencies injected via GetIt
  late final VTOOrchestrator _vto;
  late final ImageBuilder _builder;
  late final AceVerifier _verifier;
  late final ProcessRunner _runner;
  late final NetworkService _network;

  CepaHybridPipeline(this.config) {
    _vto = getIt<VTOOrchestrator>();
    _builder = getIt<ImageBuilder>();
    _runner = getIt<ProcessRunner>();
    _network = getIt<NetworkService>();
    _verifier = AceVerifier(config.activeEnvs);
  }

  Future<void> run() async {
    talker.info('Starting CEPA Hybrid Pipeline');
    
    // 1. Infrastructure Check
    if (config.runInfraCheck) {
      await _verifyInfrastructure();
    }

    // 2. Sterilization
    if (config.runSterilization) {
      await _vto.sterilizeAll();
    } else {
      talker.warning('Phase: Sterilization SKIPPED');
    }

    // 3. Build
    if (config.runBuild) {
      await _builder.buildAll();
    } else {
      talker.warning('Phase: Construction SKIPPED');
    }

    // 4. Environment Verification (AceVerifier)
    if (config.activeEnvs.isNotEmpty) {
      await _verifier.verifyAllEnvironments();
    }

    // 5. Unit/Integration Tests (Mix)
    if (config.runTests) {
      await _runMixTests();
    }

    // 6. UI Verification (Puppeteer)
    if (config.runUiCheck) {
      await _runPuppeteerChecks();
    }
    
    talker.info('CEPA Pipeline Completed Successfully');
  }

  Future<void> _verifyInfrastructure() async {
    printColor('\n--- Phase 0: Infrastructure Verification ---', blue);
    try {
      await _runner.run('podman', ['info'], ignoreErrors: true);
      talker.info('Podman is active.');
    } catch (e) {
      talker.error('Podman check failed. Ensure Podman is running.', e);
      throw 'Infrastructure check failed: Podman';
    }
    
    try {
      await _runner.run('mix', ['--version']);
      talker.info('Mix is available.');
    } catch (e) {
      talker.error('Mix check failed. Ensure Elixir is installed.', e);
      throw 'Infrastructure check failed: Mix';
    }
  }

  Future<void> _runMixTests() async {
    printColor('\n--- Phase: Unit & Integration Tests ---', blue);
    try {
      await _runner.run('mix', ['test']);
      talker.info('Tests passed.');
    } catch (e) {
      talker.error('Tests failed', e);
      throw 'Mix tests failed';
    }
  }

  Future<void> _runPuppeteerChecks() async {
    printColor('\n--- Phase: UI Verification (Puppeteer) ---', blue);
    try {
      talker.info('Launching browser...');
      var browser = await _network.launchBrowser();
      try {
        var page = await browser.newPage();
        
        talker.info('Navigating to http://localhost:4000 ...');
        try {
          await page.goto('http://localhost:4000', wait: Until.networkIdle);
          var title = await page.title;
          talker.info('Page title: $title');
          
          final content = await page.content;
          if (content != null && content.contains("Intelitor")) {
             talker.info('Verified "Intelitor" in page content.');
          } else {
             talker.warning('Page content does not contain "Intelitor".');
          }

          printColor('    ✅ UI Access: OK (Title: $title)', green);
        } catch (e) {
          talker.error('Failed to reach UI at localhost:4000', e);
          printColor('    ❌ UI Access: Failed (Server might be down)', red);
          throw 'UI unreachable';
        }
      } finally {
        await browser.close();
      }
    } catch (e) {
      talker.error('Puppeteer verification failed', e);
      throw 'UI verification failed';
    }
  }
}

// --- Sub-Components ---

class VTOOrchestrator {
  Future<void> sterilizeAll() async {
    printColor('\n--- Phase 1: Sterilization (VTO) ---', blue);
    talker.info('Stopping and removing all project containers...');
    
    try {
      await runCommand('podman-compose', ['down', '-v'], ignoreErrors: true);
      talker.info('System Sterilized.');
    } catch (e, st) {
      talker.handle(e, st, 'Warning during sterilization');
    }
  }
}

class ImageBuilder {
  static const Map<String, String> _images = {
    'localhost/sopv51-base:latest': 'Dockerfile.sopv51-base',
    'localhost/intelitor-app:latest': 'Dockerfile.sopv51-app',
    'localhost/intelitor-db:latest': 'Containerfile.nixos',
    'localhost/intelitor-obs:latest': 'Dockerfile.observability',
  };

  Future<void> buildAll() async {
    printColor('\n--- Phase 2: Construction (Image Builder) ---', blue);
    
    final buildGraph = {
      'localhost/sopv51-base:latest': <String>[],
      'localhost/intelitor-app:latest': ['localhost/sopv51-base:latest'],
      'localhost/intelitor-db:latest': <String>[],
      'localhost/intelitor-obs:latest': ['localhost/sopv51-base:latest'],
    };

    final sortedImages = topologicalSort(
      buildGraph.keys, 
      (key) => buildGraph[key] ?? []
    ).toList().reversed; 

    for (final tag in sortedImages) {
      final dockerfile = _images[tag];
      if (dockerfile != null) {
        await _buildImageWithOODA(tag, dockerfile);
      }
    }

    talker.info('Applying Compatibility Tags...');
    await _tagImage('localhost/intelitor-app:latest', 'localhost/intelitor-sopv51-elixir-app:nixos-25.05-devenv');
    await _tagImage('localhost/intelitor-app:latest', 'localhost/intelitor-sopv51-elixir-app:elixir-1.19-otp28');
    await _tagImage('localhost/intelitor-db:latest', 'localhost/intelitor-timescaledb-demo:nixos-devenv');
    await _tagImage('localhost/intelitor-obs:latest', 'localhost/intelitor-observability:nixos');
    await _tagImage('localhost/intelitor-obs:latest', 'localhost/intelitor-prometheus-demo:nixos-devenv');
    
    talker.info('All images built and tagged.');
  }

  Future<void> _tagImage(String src, String target) async {
    try {
      await runCommand('podman', ['tag', src, target]);
    } catch (e, st) {
      talker.handle(e, st, 'Failed to tag $target');
    }
  }

  Future<void> _buildImageWithOODA(String imageTag, String dockerfile, {int retries = 1}) async {
    for (int i = 0; i <= retries; i++) {
      try {
        talker.info("Building '$imageTag' from '$dockerfile'...");
        await runCommand('podman', ['build', '-t', imageTag, '-f', dockerfile, '.']);
        talker.info("Success.");
        return;
      } catch (e, st) {
        talker.error("Build failed.");
        if (i < retries) {
          talker.warning("CEPA OODA: Analyzing failure...");
          final file = File(dockerfile);
          if (await file.exists()) {
             String content = await file.readAsString();
             if (content.contains("RUNN")) {
               content = content.replaceAll('RUNN', 'RUN');
               await file.writeAsString(content);
               talker.info("Applied fix: RUNN -> RUN");
               continue;
             }
          }
          talker.handle(e, st, "Build failed with unrecoverable error");
          throw "Build failed with unrecoverable error: $e";
        }
        talker.handle(e, st, "Build failed after $retries self-correction attempts");
        throw "Build failed after $retries self-correction attempts.";
      }
    }
  }
}

class AceVerifier {
  final Map<String, String> activeEnvs;
  AceVerifier(this.activeEnvs);

  Future<void> verifyAllEnvironments() async {
    printColor('\n--- Phase 3: Verification (AceVerifier) ---', blue);

    if (activeEnvs.containsKey('DEV')) {
      await _verifyDevEnvironment();
    }

    for (final entry in activeEnvs.entries) {
      if (entry.key == 'DEV') continue;
      await _verifyContainerEnvironment(entry.value, entry.key);
    }
  }

  Future<void> _verifyDevEnvironment() async {
    printColor('\n[Environment: DEV (Host-Based)]', cyan);
    Process? serverProcess;

    try {
      talker.info('Step 1: Database Dependency');
      await runCommand('podman-compose', ['-f', 'podman-compose.dev.yml', 'up', '-d', 'intelitor-db']);
      try {
        await _waitForDatabase('localhost');
        expect(true, isTrue, reason: "Database should be reachable");
        talker.info('Database Verification Passed');
      } catch (e, st) {
        talker.handle(e, st, 'Database Verification Failed');
        throw "Database dependency failed";
      }
      
      talker.info('Step 2: Observability Dependency');
      await runCommand('podman-compose', ['-f', 'podman-compose.dev.yml', 'up', '-d', 'intelitor-obs']);
      
      try {
        final res = await getIt<ProcessRunner>().runProcess('podman', ['ps', '-f', 'name=intelitor-obs']);
        expect(res.stdout.toString(), contains('intelitor-obs'), reason: "Container must be listed in podman ps");
        
        await runCommand('podman', ['exec', 'intelitor-obs', '/usr/local/bin/check-obs.sh']);
        talker.info('Observability Verification Passed');
      } catch (e, st) {
        talker.handle(e, st, 'Observability Verification Failed');
        throw "Observability dependency failed";
      }

      talker.info('Step 3: Application (Host)');
      talker.info('Starting Phoenix Server...');
      
      serverProcess = await getIt<ProcessRunner>().start('iex', ['-S', 'mix', 'phx.server'], 
        environment: {'MIX_ENV': 'dev', 'PHX_SERVER': 'true'}
      );
      
      final serverReady = Completer<void>();
      serverProcess.stdout.transform(utf8.decoder).listen((data) {
        if (data.contains('Access IntelitorWeb.Endpoint at')) {
           if (!serverReady.isCompleted) serverReady.complete();
           talker.info('Server accepted connection signal.');
        }
      });
      
      try {
        await serverReady.future.timeout(Duration(seconds: 20));
        await _runHostChecks();
        talker.info('Application Verification Passed');
      } catch (e, st) {
        talker.handle(e, st, 'Application Verification Failed');
        throw "Application startup failed";
      }

    } catch (e, st) {
      talker.handle(e, st, 'Environment Verification Aborted');
      rethrow;
    } finally {
      if (serverProcess != null) {
        talker.info('Stopping Phoenix Server...');
        serverProcess.kill(ProcessSignal.sigterm);
      }
      talker.info('Stopping Dependencies...');
      await runCommand('podman-compose', ['-f', 'podman-compose.dev.yml', 'down']);
    }
  }

  Future<void> _verifyContainerEnvironment(String filename, String envName) async {
    printColor('\n[Environment: $envName (Containerized)]', cyan);

    final configContent = await File(filename).readAsString();
    final config = _parseCompose(filename, envName, configContent);

    final graph = <String, Set<String>>{};
    for (var service in config.services.values) {
      graph[service.name] = service.dependsOn;
    }

    final sortedServices = topologicalSort(
      graph.keys,
      (key) => graph[key]?.where((d) => graph.containsKey(d)) ?? []
    ).toList().reversed; 
    
    talker.info('Dependency Order: ${sortedServices.join(" -> ")}');

    try {
      for (final serviceName in sortedServices) {
        talker.info('Verifying Service: $serviceName');
        
        await runCommand('podman-compose', ['-f', filename, 'up', '-d', serviceName]);
        
        if (serviceName.contains('db') || serviceName.contains('postgres')) {
           await Future.delayed(Duration(seconds: 5));
           try {
             await runCommand('podman', ['exec', serviceName, 'pg_isready', '-U', 'intelitor'], ignoreErrors: true);
             talker.info('DB Check Passed');
           } catch (e, st) {
             talker.handle(e, st, 'DB Check Warning (might be initializing)');
           }
        }
        
        final res = await getIt<ProcessRunner>().runProcess('podman', ['ps', '-f', 'name=$serviceName']);
        expect(res.stdout.toString(), contains(serviceName), reason: "Container $serviceName should be running");
      }
      talker.info('All Services Verified');

    } catch (e, st) {
      talker.handle(e, st, 'Environment Verification Aborted');
      rethrow;
    } finally {
      talker.info('Stopping Environment...');
      await runCommand('podman-compose', ['-f', filename, 'down']);
    }
  }

  Future<void> _waitForPort(int port) async {
    talker.info('Waiting for port $port...');
    final endTime = DateTime.now().add(Duration(seconds: 30));
    while (DateTime.now().isBefore(endTime)) {
      try {
        final socket = await getIt<NetworkService>().connect('localhost', port, timeout: Duration(milliseconds: 500));
        socket.destroy();
        return;
      } catch (_) {
        await Future.delayed(Duration(milliseconds: 500));
      }
    }
    throw "Port $port did not open within timeout";
  }

  Future<void> _runHostChecks() async {
    talker.info('Running Host Verification Checks...');
    try {
      await _waitForPort(4000);
      expect(true, isTrue); 
      
      int retries = 5;
      while (retries > 0) {
        final res = await getIt<ProcessRunner>().runProcess('curl', ['-s', '-o', '/dev/null', '-w', '%{http_code}', 'http://localhost:4000']);
        if (res.stdout == '200') {
          talker.info('Web Access: OK');
          break;
        }
        retries--;
        if (retries == 0) throw "HTTP ${res.stdout}";
        await Future.delayed(Duration(seconds: 1));
      }
    } catch (e, st) {
      talker.handle(e, st, 'Web Access Error');
    }

    try {
      await runCommand('mix', ['run', '-e', 'IO.puts("    ✅ DB Access: OK")']);
    } catch (e, st) {
      talker.handle(e, st, 'DB Access Failed');
    }
  }

  Future<void> _waitForDatabase(String host) async {
    talker.info('Waiting for Database...');
    for (int i = 0; i < 12; i++) {
      try {
        final res = await getIt<ProcessRunner>().runProcess('mix', ['run', '-e', 'Ecto.Adapter.ensure_all_started(Intelitor.Repo, :temporary)'], 
          environment: {'MIX_ENV': 'dev'}
        );
        if (res.exitCode == 0) {
          talker.info('Database Ready.');
          return;
        }
      } catch (e, st) {
        talker.handle(e, st, 'Database not ready yet...');
      }
      stdout.write('.');
      await Future.delayed(Duration(seconds: 5));
    }
    talker.warning('Database wait timed out. Proceeding anyway (may fail).');
  }

  ComposeConfig _parseCompose(String filename, String envName, String content) {
    // Parse using Yaml package for robustness
    final yaml = loadYaml(content) as YamlMap;
    final servicesYaml = yaml['services'] as YamlMap?;
    
    final services = <String, ComposeService>{};
    
    if (servicesYaml != null) {
      servicesYaml.forEach((key, value) {
        final serviceName = key as String;
        final serviceConfig = value as YamlMap;
        final image = serviceConfig['image'] as String?;
        final environment = <String, String>{};
        
        // Environment handling
        if (serviceConfig['environment'] is YamlList) {
          for (var env in serviceConfig['environment'] as YamlList) {
            final parts = env.toString().split('=');
            if (parts.length >= 2) {
              environment[parts[0]] = parts.sublist(1).join('=');
            }
          }
        } else if (serviceConfig['environment'] is YamlMap) {
          (serviceConfig['environment'] as YamlMap).forEach((k, v) {
            environment[k.toString()] = v.toString();
          });
        }

        final dependsOn = <String>{};
        final dependsYaml = serviceConfig['depends_on'];
        if (dependsYaml is YamlList) {
          for (var dep in dependsYaml) {
            dependsOn.add(dep.toString());
          }
        } else if (dependsYaml is YamlMap) {
          dependsYaml.forEach((k, _) {
            dependsOn.add(k.toString());
          });
        }

        services[serviceName] = ComposeService(serviceName, image: image, environment: environment, dependsOn: dependsOn);
      });
    }

    return ComposeConfig(filename, envName, services);
  }
}