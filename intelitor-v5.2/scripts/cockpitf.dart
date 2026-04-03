#!/usr/bin/env dart
// cockpitf.dart - Quick F# Cockpit launcher
// Usage: dart run scripts/cockpitf.dart [command]
// Commands: deploy, status, test, ux, monitor, logs, cleanup (default: deploy)

import 'dart:io';

void main(List<String> args) async {
  final scriptDir = File(Platform.script.toFilePath()).parent.path;
  final projectRoot = Directory('$scriptDir/..').resolveSymbolicLinksSync();
  final cockpitScript = '$projectRoot/lib/cepaf/scripts/CockpitOperations.fsx';
  final devenvDotnet = '$projectRoot/.devenv/profile/bin/dotnet';

  final cmd = args.isNotEmpty ? args[0] : 'deploy';

  if (!File(cockpitScript).existsSync()) {
    stderr.writeln('Error: CockpitOperations.fsx not found at $cockpitScript');
    exit(1);
  }

  // Try devenv dotnet first, fall back to PATH
  final dotnetPath = File(devenvDotnet).existsSync() ? devenvDotnet : 'dotnet';

  final process = await Process.start(
    dotnetPath,
    ['fsi', cockpitScript, cmd],
    workingDirectory: projectRoot,
    mode: ProcessStartMode.inheritStdio,
    environment: {
      ...Platform.environment,
      'DOTNET_ROOT': '$projectRoot/.devenv/profile',
    },
  );

  exit(await process.exitCode);
}
