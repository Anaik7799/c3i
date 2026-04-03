#!/usr/bin/env dart

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:args/args.dart';
import 'package:graphs/graphs.dart';
import 'package:matcher/matcher.dart';
import 'package:timing/timing.dart';
import 'package:posix/posix.dart' as posix;
import 'package:logger/logger.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:puppeteer/puppeteer.dart';

import 'orchestrator.dart';

// --- CEPA: Shared Utilities & Configuration ---

// ANSI color codes
const String red = '\u001b[31m';
const String green = '\u001b[32m';
const String yellow = '\u001b[33m';
const String blue = '\u001b[34m';
const String cyan = '\u001b[36m';
const String reset = '\u001b[0m';

final getIt = GetIt.instance;

final talker = Talker(
  settings: TalkerSettings(
    useConsoleLogs: true,
    useHistory: true,
  ),
);

final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 80,
    colors: true,
    printEmojis: true,
    printTime: true,
  ),
);

class ProcessRunner {
  Future<void> run(String executable, List<String> arguments, {bool ignoreErrors = false, Map<String, String>? environment}) async {
    final tracker = SyncTimeTracker();
    
    await tracker.track(() async {
      talker.log('Executing: $executable ${arguments.join(' ')}', logLevel: LogLevel.debug);
      
      final process = await start(executable, arguments, environment: environment);
      final prefix = executable.split('/').last;

      process.stdout.transform(utf8.decoder).transform(LineSplitter()).listen((line) {
        talker.log('[$prefix] $line', logLevel: LogLevel.verbose);
      });
      process.stderr.transform(utf8.decoder).transform(LineSplitter()).listen((line) {
        talker.log('[$prefix] $line', logLevel: LogLevel.warning);
      });

      final exitCode = await process.exitCode;

      if (exitCode != 0 && !ignoreErrors) {
        final error = 'Command "$executable ${arguments.join(' ')}" failed with code $exitCode';
        talker.error(error);
        throw Exception(error);
      }
    });
    
    talker.info('Command "$executable" took ${tracker.duration.inMilliseconds}ms');
  }

  Future<ProcessResult> runProcess(String executable, List<String> arguments, {Map<String, String>? environment}) async {
    talker.log('Running Sync-like: $executable ${arguments.join(' ')}', logLevel: LogLevel.debug);
    return Process.run(executable, arguments, environment: environment);
  }

  Future<Process> start(String executable, List<String> arguments, {Map<String, String>? environment}) async {
    return Process.start(executable, arguments, environment: environment);
  }
}

class NetworkService {
  Future<Socket> connect(dynamic host, int port, {Duration? timeout}) async {
    return Socket.connect(host, port, timeout: timeout);
  }

  Future<Browser> launchBrowser({bool? headless, List<String>? args}) async {
    return puppeteer.launch(headless: headless, args: args);
  }
}

void setupServiceLocator() {
  if (!getIt.isRegistered<Talker>()) {
    getIt.registerSingleton<Talker>(talker);
  }
  if (!getIt.isRegistered<ProcessRunner>()) {
    getIt.registerLazySingleton<ProcessRunner>(() => ProcessRunner());
  }
  if (!getIt.isRegistered<NetworkService>()) {
    getIt.registerLazySingleton<NetworkService>(() => NetworkService());
  }
  if (!getIt.isRegistered<VTOOrchestrator>()) {
    getIt.registerLazySingleton<VTOOrchestrator>(() => VTOOrchestrator());
  }
  if (!getIt.isRegistered<ImageBuilder>()) {
    getIt.registerLazySingleton<ImageBuilder>(() => ImageBuilder());
  }
}

// --- Custom Matcher Context ---
void expect(dynamic actual, Matcher matcher, {String? reason}) {
  final matchState = {};
  if (matcher.matches(actual, matchState)) return;

  final description = StringDescription();
  description.add('Expected: ').addDescriptionOf(matcher).add('\n');
  description.add('  Actual: ').addDescriptionOf(actual).add('\n');
  
  final mismatchDescription = StringDescription();
  matcher.describeMismatch(actual, mismatchDescription, matchState, false);
  if (mismatchDescription.length > 0) {
    description.add('   Which: ').add(mismatchDescription.toString()).add('\n');
  }
  if (reason != null) {
    description.add('  Reason: $reason\n');
  }
  
  talker.error('Test Expectation Failed: ${description.toString()}');
  throw TestFailure(description.toString());
}

class TestFailure implements Exception {
  final String message;
  TestFailure(this.message);
  @override
  String toString() => message;
}

void printColor(String text, String color) {
  print('$color$text$reset');
}

Future<void> runCommand(String executable, List<String> arguments, {bool ignoreErrors = false, Map<String, String>? environment}) async {
  await getIt<ProcessRunner>().run(executable, arguments, ignoreErrors: ignoreErrors, environment: environment);
}

// --- Main CLI Entry Point ---

Future<void> main(List<String> arguments) async {
  final exitCode = await entryPoint(arguments);
  exit(exitCode);
}

Future<int> entryPoint(List<String> arguments) async {
  setupServiceLocator();

  final pid = posix.getpid();
  talker.info('CEPA starting with PID: $pid');

  // Clear screen
  stdout.write('\u001b[2J\u001b[H');

  printColor('╔══════════════════════════════════════════════════════════════╗', cyan);
  printColor('║   CEPA: Unified Autonomic Verification Protocol (v2.1)       ║', cyan);
  printColor('║   Orchestrator: Dart VM | Mode: Unified Hybrid Pipeline      ║', cyan);
  printColor('║   Location: lib/cepa/cepa.dart                               ║', cyan);
  printColor('╚══════════════════════════════════════════════════════════════╝', cyan);

  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help message.')
    ..addFlag('yes', abbr: 'y', negatable: false, help: 'Auto-confirm execution.')
    ..addFlag('sterilize', negatable: true, defaultsTo: true, help: 'Run VTO sterilization phase.')
    ..addFlag('build', negatable: true, defaultsTo: true, help: 'Run Image Builder phase.')
    ..addMultiOption('env', abbr: 'e', help: 'Environments to verify (DEV, TEST, DEMO, PROD).', allowed: ['DEV', 'TEST', 'DEMO', 'PROD'])
    ..addFlag('test', abbr: 't', negatable: false, help: 'Run Mix tests.')
    ..addFlag('infra', abbr: 'i', negatable: false, defaultsTo: true, help: 'Verify infrastructure.')
    ..addFlag('ui', negatable: false, help: 'Run UI verification using Puppeteer.');

  ArgResults argResults;
  try {
    argResults = parser.parse(arguments);
  } catch (e) {
    printColor('Error parsing arguments: $e', red);
    talker.handle(e);
    print(parser.usage);
    return 1;
  }

  if (argResults['help'] as bool) {
    print(parser.usage);
    return 0;
  }

  return await runPipeline(argResults);
}

Future<int> runPipeline(ArgResults argResults) async {
  final envMap = {
    'DEV': 'podman-compose.dev.yml',
    'TEST': 'podman-compose-testing.yml',
    'DEMO': 'podman-compose.yml',
    'PROD': 'podman-compose-secure.yml',
  };

  final activeEnvs = <String, String>{};
  final requestedEnvs = argResults['env'] as List<String>;
  final envsToCheck = requestedEnvs.isNotEmpty ? requestedEnvs : envMap.keys;

  for (final name in envsToCheck) {
    // Only check if specific environments were requested, otherwise we might just be running tests/infra
    if (requestedEnvs.isNotEmpty || argResults['sterilize'] || argResults['build']) {
      final file = envMap[name]!;
      final exists = File(file).existsSync();
      if (exists) {
        activeEnvs[name] = file;
        print('    [$name] File: $file -> ${green}READY$reset');
      } else if (requestedEnvs.contains(name)) {
        print('    [$name] File: $file -> ${red}MISSING$reset');
      }
    }
  }

  if (activeEnvs.isEmpty && (requestedEnvs.isNotEmpty || (!argResults['test'] && !argResults['ui'] && !argResults['infra']))) {
     // If user asked for envs but none found, OR user asked for nothing specific (defaulting to classic flow), warn.
     if (requestedEnvs.isNotEmpty) {
       talker.error('No valid environment configurations found for selected targets. Aborting.');
       return 1;
     }
  }

  if (activeEnvs.isNotEmpty && !(argResults['yes'] as bool)) {
    stdout.writeln('\nDo you want to proceed with verification? (y/n)');
    stdout.write('> ');
    final input = stdin.readLineSync()?.toLowerCase().trim();

    if (input != 'y') {
      talker.warning('Verification cancelled by user.');
      return 0;
    }
  } else if (activeEnvs.isNotEmpty) {
    talker.info('Auto-confirm enabled (-y). Proceeding...');
  }

  final config = CepaConfig(
    activeEnvs: activeEnvs,
    runSterilization: argResults['sterilize'] as bool,
    runBuild: argResults['build'] as bool,
    runInfraCheck: argResults['infra'] as bool,
    runTests: argResults['test'] as bool,
    runUiCheck: argResults['ui'] as bool,
  );

  final pipeline = CepaHybridPipeline(config);
  
  final tracker = SyncTimeTracker();
  int status = 0;
  
  await tracker.track(() async {
    try {
      await pipeline.run();
      printColor('\n✅ PROTOCOL COMPLETE.', green);
    } catch (e, st) {
      printColor('\n❌ PROTOCOL FAILED.', red);
      talker.handle(e, st, 'Critical failure in Pipeline');
      status = 1;
    }
  });
  
  talker.info('Total execution time: ${tracker.duration.inSeconds}s');
  return status;
}