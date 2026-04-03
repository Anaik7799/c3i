import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:get_it/get_it.dart';
import 'package:cepa_orchestrator/cepa/cepa.dart' hide expect;
import 'package:cepa_orchestrator/cepa/orchestrator.dart';
import 'package:talker/talker.dart';

@GenerateMocks([ProcessRunner, VTOOrchestrator, ImageBuilder, Talker, Process, Stream, NetworkService, Socket])
import 'cepa_test.mocks.dart';

void main() {
  final getIt = GetIt.instance;

  setUp(() async {
    await getIt.reset();
    getIt.registerLazySingleton<ProcessRunner>(() => MockProcessRunner());
    getIt.registerLazySingleton<NetworkService>(() => MockNetworkService());
    getIt.registerLazySingleton<VTOOrchestrator>(() => MockVTOOrchestrator());
    getIt.registerLazySingleton<ImageBuilder>(() => MockImageBuilder());
    getIt.registerSingleton<Talker>(MockTalker());
  });

  group('CEPA CLI', () {
    test('Help flag shows usage', () async {
      final capture = await runCapturingPrint(() async {
        final exitCode = await entryPoint(['--help']);
        expect(exitCode, 0);
      });
      expect(capture, contains('Show this help message.'));
    });

    test('Unified Pipeline - Infrastructure only', () async {
      final mockRunner = getIt<ProcessRunner>() as MockProcessRunner;
      when(mockRunner.run(any, any, ignoreErrors: anyNamed('ignoreErrors')))
          .thenAnswer((_) async {});

      final capture = await runCapturingPrint(() async {
        final exitCode = await entryPoint(['--infra', '--no-sterilize', '--no-build']);
        expect(exitCode, 0);
      });
      
      verify(mockRunner.run('podman', ['info'], ignoreErrors: true)).called(1);
      verify(mockRunner.run('mix', ['--version'])).called(1);
      expect(capture, contains('Phase 0: Infrastructure Verification'));
    });

    test('Unified Pipeline - Full Run', () async {
       final mockVto = getIt<VTOOrchestrator>() as MockVTOOrchestrator;
       final mockBuilder = getIt<ImageBuilder>() as MockImageBuilder;
       final mockNetwork = getIt<NetworkService>() as MockNetworkService;
       final mockRunner = getIt<ProcessRunner>() as MockProcessRunner;
       
       // Stub mocks to print so we can verify flow via capture
       when(mockVto.sterilizeAll()).thenAnswer((_) async { print('Phase 1: Sterilization (Mocked)'); });
       when(mockBuilder.buildAll()).thenAnswer((_) async { print('Phase 2: Construction (Mocked)'); });
       
       when(mockNetwork.connect(any, any, timeout: anyNamed('timeout')))
           .thenAnswer((_) async => MockSocket());
       
       when(mockRunner.run(any, any, ignoreErrors: anyNamed('ignoreErrors')))
           .thenAnswer((_) async {});
           
       when(mockRunner.runProcess(any, any, environment: anyNamed('environment')))
           .thenAnswer((invocation) async {
             final exec = invocation.positionalArguments[0] as String;
             final args = invocation.positionalArguments[1] as List<String>;
             
             if (exec == 'podman' && args.contains('ps')) {
               return ProcessResult(0, 0, 'intelitor-obs intelitor-db running', '');
             }
             if (exec == 'curl') {
               return ProcessResult(0, 0, '200', '');
             }
             if (exec == 'mix') {
               return ProcessResult(0, 0, 'Success', '');
             }
             return ProcessResult(0, 0, 'Success', '');
           });

       final mockProcess = MockProcess();
       when(mockProcess.stdout).thenAnswer((_) => Stream.fromIterable([utf8.encode('Access IntelitorWeb.Endpoint at localhost:4000')]));
       when(mockProcess.stderr).thenAnswer((_) => Stream.empty());
       when(mockProcess.exitCode).thenAnswer((_) async => 0);
       when(mockProcess.kill(any)).thenReturn(true);
       
       when(mockRunner.start(any, any, environment: anyNamed('environment')))
           .thenAnswer((_) async => mockProcess);

       final devCompose = File('podman-compose.dev.yml');
       if (!devCompose.existsSync()) {
         await devCompose.writeAsString('services:\n  db:\n    image: postgres');
       }

       try {
         int resultExitCode = -1;
         final capture = await runCapturingPrint(() async {
           resultExitCode = await entryPoint(['--env', 'DEV', '--yes', '--test', '--infra']); 
         });
         
         if (resultExitCode != 0) {
            print('DEBUG CAPTURE (Exit Code: $resultExitCode):\n$capture');
         }

         expect(resultExitCode, 0, reason: "Pipeline failed.");
         expect(capture, contains('Phase 0: Infrastructure Verification'));
         expect(capture, contains('Phase 1: Sterilization (Mocked)'));
         expect(capture, contains('Phase 2: Construction (Mocked)'));
         expect(capture, contains('Phase 3: Verification'));
         expect(capture, contains('Phase: Unit & Integration Tests'));
         expect(capture, contains('✅ PROTOCOL COMPLETE'));
       } finally {
         if (devCompose.existsSync()) await devCompose.delete();
       }
    });
  });
}

Future<String> runCapturingPrint(Future<void> Function() callback) async {
  final buffer = StringBuffer();
  final spec = ZoneSpecification(
    print: (_, __, ___, String msg) {
      buffer.writeln(msg);
    },
  );
  
  await runZoned(callback, zoneSpecification: spec);
  return buffer.toString();
}
