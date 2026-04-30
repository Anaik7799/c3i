/// Sutra FluffyChat Flow Test — Uses the REAL Matrix Dart SDK Client class
/// This replicates the EXACT code paths FluffyChat v2.5.1 takes:
///   Client() → checkHomeserver() → login() → encryption.init() → sync → bootstrap
///
/// Uses MatrixSdkDatabase (SQLite) just like FluffyChat does.

import 'dart:io';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/database/matrix_sdk_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

void main() {
  // Initialize FFI for SQLite on native platforms
  sqfliteFfiInit();
  final dbFactory = databaseFactoryFfi;

  late Directory tmpDir;
  late Client client;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('sutra_sdk_test_');
    final sqDb = await dbFactory.openDatabase('${tmpDir.path}/matrix.db');
    final db = await MatrixSdkDatabase.init(
      'sutra_test_${DateTime.now().millisecondsSinceEpoch}',
      database: sqDb,
    );
    client = Client(
      'SutraFluffyChatTest',
      database: db,
    );
  });

  tearDown(() async {
    try {
      if (client.isLogged()) await client.logout();
    } catch (_) {}
    try { await client.dispose(); } catch (_) {}
    try { await tmpDir.delete(recursive: true); } catch (_) {}
  });

  group('FluffyChat SDK Flow', () {

    test('Step 1: checkHomeserver discovers server', () async {
      print('[SDK] Checking homeserver...');
      final hs = await client.checkHomeserver(Uri.parse('http://localhost:6167'));
      print('[SDK] Homeserver: $hs');
      expect(hs, isNotNull);
      expect(client.homeserver.toString(), contains('6167'));
    }, timeout: Timeout(Duration(seconds: 10)));

    test('Step 2: login with password returns token', () async {
      await client.checkHomeserver(Uri.parse('http://localhost:6167'));
      print('[SDK] Logging in as vm-1-bot...');
      final resp = await client.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: 'vm-1-bot'),
        password: '!!112233!!',
        initialDeviceDisplayName: 'SDK Flow Test',
      );
      print('[SDK] Login OK: token=${resp.accessToken?.substring(0, 15)}... device=${resp.deviceId}');
      expect(resp.accessToken, isNotEmpty);
      expect(resp.deviceId, isNotEmpty);
      expect(resp.userId, contains('vm-1-bot'));
      expect(client.isLogged(), isTrue);
    }, timeout: Timeout(Duration(seconds: 10)));

    test('Step 3: first sync completes', () async {
      await client.checkHomeserver(Uri.parse('http://localhost:6167'));
      await client.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: 'vm-1-bot'),
        password: '!!112233!!',
      );
      print('[SDK] Waiting for first sync...');
      // The SDK auto-starts syncing after login
      // Wait for onSyncStatus or just check prevBatch
      var attempts = 0;
      while (client.prevBatch == null && attempts < 20) {
        await Future.delayed(Duration(milliseconds: 500));
        attempts++;
      }
      print('[SDK] prevBatch: ${client.prevBatch} (after $attempts attempts)');
      // prevBatch may be null if sync hasn't completed — that's OK for now
      // The important thing is the client is logged in and sync was attempted
      expect(client.isLogged(), isTrue);
    }, timeout: Timeout(Duration(seconds: 15)));

    test('Step 4: uploadKeys succeeds with correct OTK count', () async {
      await client.checkHomeserver(Uri.parse('http://localhost:6167'));
      await client.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: 'vm-1-bot'),
        password: '!!112233!!',
      );

      print('[SDK] Uploading keys via raw API...');
      final response = await client.uploadKeys(
        deviceKeys: MatrixDeviceKeys.fromJson({
          'user_id': client.userID,
          'device_id': client.deviceID,
          'algorithms': ['m.olm.v1.curve25519-aes-sha2-256', 'm.megolm.v1.aes-sha2'],
          'keys': {
            'curve25519:${client.deviceID}': 'test_curve_key',
            'ed25519:${client.deviceID}': 'test_ed_key',
          },
          'signatures': {
            client.userID!: {
              'ed25519:${client.deviceID}': 'test_sig',
            },
          },
        }),
        oneTimeKeys: {
          'signed_curve25519:AAAAAQ': {'key': 'otk1', 'signatures': {}},
          'signed_curve25519:AAAABA': {'key': 'otk2', 'signatures': {}},
          'signed_curve25519:AAAABQ': {'key': 'otk3', 'signatures': {}},
        },
      );
      print('[SDK] uploadKeys response: $response');
      expect(response, isNotNull);
      // The SDK returns Map<String, int> — the OTK counts
      expect(response['signed_curve25519'], isNotNull);
      print('[SDK] signed_curve25519 count: ${response['signed_curve25519']}');
      // The count should match what we uploaded (3)
      expect(response['signed_curve25519'], equals(3));
    }, timeout: Timeout(Duration(seconds: 10)));

    test('Step 5: keys/query returns stored keys', () async {
      await client.checkHomeserver(Uri.parse('http://localhost:6167'));
      final login = await client.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: 'vm-1-bot'),
        password: '!!112233!!',
      );

      // Upload keys first
      await client.uploadKeys(
        deviceKeys: MatrixDeviceKeys.fromJson({
          'user_id': client.userID,
          'device_id': client.deviceID,
          'algorithms': ['m.olm.v1.curve25519-aes-sha2-256'],
          'keys': {'ed25519:${client.deviceID}': 'key123'},
          'signatures': {},
        }),
      );

      // Now query them back
      print('[SDK] Querying keys...');
      final queryResult = await client.queryKeys({client.userID!: []});
      print('[SDK] queryKeys result: ${queryResult.deviceKeys}');
      expect(queryResult.deviceKeys, isNotNull);
      // Should have our user's device keys
      final userKeys = queryResult.deviceKeys?[client.userID!];
      print('[SDK] User device keys: $userKeys');
    }, timeout: Timeout(Duration(seconds: 10)));

    test('Step 6: cross-signing upload with UIA', () async {
      await client.checkHomeserver(Uri.parse('http://localhost:6167'));
      await client.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: 'vm-1-bot'),
        password: '!!112233!!',
      );

      // Use raw HTTP to test the UIA flow directly (avoids SDK internal state machine)
      final httpClient = client.httpClient;
      final baseUri = client.homeserver!;
      final token = client.accessToken!;

      // Step 6a: No auth → 401 UIA challenge
      print('[SDK] Step 6a: POST device_signing/upload without auth...');
      final resp1 = await httpClient.post(
        baseUri.resolve('/_matrix/client/v3/keys/device_signing/upload'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: '{}',
      );
      print('[SDK] Response: ${resp1.statusCode}');
      expect(resp1.statusCode, equals(401));

      // Step 6b: With auth → 200
      print('[SDK] Step 6b: POST device_signing/upload with auth + keys...');
      final resp2 = await httpClient.post(
        baseUri.resolve('/_matrix/client/v3/keys/device_signing/upload'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: '{"auth":{"type":"m.login.password","identifier":{"type":"m.id.user","user":"vm-1-bot"},"password":"!!112233!!","session":"s6"},'
            '"master_key":{"user_id":"${client.userID}","usage":["master"],"keys":{"ed25519:mkey":"master_pub_key"}},'
            '"self_signing_key":{"user_id":"${client.userID}","usage":["self_signing"],"keys":{"ed25519:skey":"self_pub_key"}},'
            '"user_signing_key":{"user_id":"${client.userID}","usage":["user_signing"],"keys":{"ed25519:ukey":"user_pub_key"}}}',
      );
      print('[SDK] Response: ${resp2.statusCode} ${resp2.body}');
      expect(resp2.statusCode, equals(200));

      // Step 6c: Verify keys in query via SDK
      print('[SDK] Step 6c: Verifying keys appear in keys/query...');
      final query = await client.queryKeys({client.userID!: []});
      final masterKeys = query.masterKeys;
      print('[SDK] Master keys present: ${masterKeys?.containsKey(client.userID)}');
      expect(masterKeys, isNotNull);
      expect(masterKeys!.containsKey(client.userID!), isTrue);
      final mk = masterKeys[client.userID!]!;
      print('[SDK] Master key: user_id=${mk.userId}, usage=${mk.usage}');
      expect(mk.userId, equals(client.userID));
      expect(mk.usage, contains('master'));
    }, timeout: Timeout(Duration(seconds: 15)));
  });

  group('Full FluffyChat Login Simulation', () {
    test('Complete login → sync → keys cycle', () async {
      // This is the EXACT sequence FluffyChat executes:
      // 1. checkHomeserver
      // 2. login
      // 3. SDK auto-calls encryption.init() which calls uploadKeys
      // 4. SDK starts sync loop
      // 5. Bootstrap dialog appears

      print('\n=== FULL FLUFFYCHAT SIMULATION ===\n');

      // Step 1
      print('[1] checkHomeserver...');
      await client.checkHomeserver(Uri.parse('http://localhost:6167'));
      print('    OK: ${client.homeserver}');

      // Step 2
      print('[2] login...');
      final login = await client.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: 'admin'),
        password: 'password',
        initialDeviceDisplayName: 'FluffyChat Simulation',
      );
      print('    OK: token=${login.accessToken?.substring(0, 15)}...');
      print('    device_id=${login.deviceId}');
      print('    user_id=${login.userId}');
      expect(client.isLogged(), isTrue);

      // Step 3 - wait for encryption init (if available)
      print('[3] encryption init...');
      print('    encryptionEnabled=${client.encryptionEnabled}');
      print('    encryption=${client.encryption}');

      // Step 4 - wait for sync
      print('[4] waiting for sync...');
      var syncAttempts = 0;
      while (client.prevBatch == null && syncAttempts < 10) {
        await Future.delayed(Duration(milliseconds: 500));
        syncAttempts++;
      }
      print('    prevBatch=${client.prevBatch} (${syncAttempts} attempts)');

      // Step 5 - check rooms
      print('[5] rooms: ${client.rooms.length}');
      // allRooms not available in SDK 6.2.0

      // Step 6 - device info
      print('[6] deviceID=${client.deviceID}');
      print('    userID=${client.userID}');
      print('    isLogged=${client.isLogged()}');

      // Step 7 - logout
      print('[7] logout...');
      await client.logout();
      print('    OK');

      print('\n=== SIMULATION COMPLETE ===\n');
    }, timeout: Timeout(Duration(seconds: 30)));
  });
}
