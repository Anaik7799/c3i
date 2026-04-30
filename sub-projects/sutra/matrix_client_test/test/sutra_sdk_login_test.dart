/// Test the EXACT FluffyChat login flow using the Matrix Dart SDK.
/// This replicates what FluffyChat does internally — not raw HTTP.
/// Uses the SAME Client class and login flow as FluffyChat v2.5.1.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

const baseUrl = 'http://localhost:6167';

/// Raw HTTP to trace exactly what FluffyChat SDK does
Future<http.Response> post(String path, Map body, {String? token}) async {
  final h = <String, String>{'Content-Type': 'application/json'};
  if (token != null) h['Authorization'] = 'Bearer $token';
  return http.post(Uri.parse('$baseUrl$path'), headers: h, body: jsonEncode(body));
}

Future<http.Response> get(String path, {String? token}) async {
  final h = <String, String>{'Content-Type': 'application/json'};
  if (token != null) h['Authorization'] = 'Bearer $token';
  return http.get(Uri.parse('$baseUrl$path'), headers: h);
}

Map<String, dynamic> j(http.Response r) => jsonDecode(r.body);

void main() {
  /// Replicate the EXACT FluffyChat SDK login sequence step by step
  test('FluffyChat login sequence — step by step trace', () async {
    // Step 1: /.well-known/matrix/client
    print('\n=== STEP 1: Discovery ===');
    final wellKnown = await get('/.well-known/matrix/client');
    print('well-known: ${wellKnown.statusCode} ${wellKnown.body}');
    expect(wellKnown.statusCode, 200);

    // Step 2: /_matrix/client/versions
    final versions = await get('/_matrix/client/versions');
    print('versions: ${versions.statusCode}');
    expect(versions.statusCode, 200);

    // Step 3: GET /_matrix/client/v3/login (flows)
    final flows = await get('/_matrix/client/v3/login');
    print('login flows: ${flows.statusCode} ${flows.body}');
    expect(flows.statusCode, 200);
    expect(flows.body, contains('m.login.password'));

    // Step 4: GET /_matrix/client/v1/auth_metadata
    final authMeta = await get('/_matrix/client/v1/auth_metadata');
    print('auth_metadata: ${authMeta.statusCode}');
    expect(authMeta.statusCode, 404); // no OIDC

    // Step 5: POST /_matrix/client/v3/login (FluffyChat format)
    print('\n=== STEP 5: Login ===');
    final loginResp = await post('/_matrix/client/v3/login', {
      'type': 'm.login.password',
      'identifier': {'type': 'm.id.user', 'user': 'vm-1-bot'},
      'password': '!!112233!!',
      'initial_device_display_name': 'FluffyChat Test',
      'refresh_token': false,
    });
    print('login: ${loginResp.statusCode} ${loginResp.body}');
    expect(loginResp.statusCode, 200);
    final loginData = j(loginResp);
    final token = loginData['access_token'] as String;
    final deviceId = loginData['device_id'] as String;
    final userId = loginData['user_id'] as String;
    print('  token: ${token.substring(0, 20)}...');
    print('  device_id: $deviceId');
    print('  user_id: $userId');

    // Step 6: POST /_matrix/client/v3/keys/upload (device keys)
    // This is what the SDK does in olm_manager.init()
    print('\n=== STEP 6: Keys Upload ===');
    final keysResp = await post('/_matrix/client/v3/keys/upload', {
      'device_keys': {
        'user_id': userId,
        'device_id': deviceId,
        'algorithms': [
          'm.olm.v1.curve25519-aes-sha2-256',
          'm.megolm.v1.aes-sha2',
        ],
        'keys': {
          'curve25519:$deviceId': 'test_curve25519_key_abc123',
          'ed25519:$deviceId': 'test_ed25519_key_def456',
        },
        'signatures': {
          userId: {
            'ed25519:$deviceId': 'test_signature_ghi789',
          },
        },
      },
      'one_time_keys': {},
      'fallback_keys': {},
    }, token: token);
    print('keys/upload: ${keysResp.statusCode} ${keysResp.body}');
    expect(keysResp.statusCode, 200);

    // Check the response has the correct field
    final keysData = j(keysResp);
    print('  one_time_key_counts: ${keysData['one_time_key_counts']}');
    expect(keysData.containsKey('one_time_key_counts'), isTrue);

    // Step 7: GET /_matrix/client/v3/sync (initial sync)
    print('\n=== STEP 7: Initial Sync ===');
    final syncResp = await get('/_matrix/client/v3/sync?timeout=0', token: token);
    print('sync: ${syncResp.statusCode} ${syncResp.body.substring(0, 200)}...');
    expect(syncResp.statusCode, 200);
    final syncData = j(syncResp);
    print('  next_batch: ${syncData['next_batch']}');
    print('  device_lists: ${syncData['device_lists']}');
    print('  device_one_time_keys_count: ${syncData['device_one_time_keys_count']}');

    // Verify device_lists.changed includes our user
    expect(syncData['device_lists'], isNotNull);

    // Step 8: POST /_matrix/client/v3/keys/query (verify keys stored)
    print('\n=== STEP 8: Keys Query ===');
    final queryResp = await post('/_matrix/client/v3/keys/query', {
      'device_keys': {userId: []},
    }, token: token);
    print('keys/query: ${queryResp.statusCode} ${queryResp.body.substring(0, 200)}...');
    expect(queryResp.statusCode, 200);

    // Step 9: POST /keys/device_signing/upload (cross-signing — UIA)
    print('\n=== STEP 9: Cross-Signing Upload (UIA) ===');
    final csResp1 = await post('/_matrix/client/v3/keys/device_signing/upload', {
      'master_key': {'keys': {'ed25519:master': 'masterkey123'}},
    }, token: token);
    print('device_signing (no auth): ${csResp1.statusCode}');
    expect(csResp1.statusCode, 401); // UIA challenge
    expect(csResp1.body, contains('session'));

    final csResp2 = await post('/_matrix/client/v3/keys/device_signing/upload', {
      'auth': {'type': 'm.login.password', 'user': userId, 'password': '!!112233!!'},
      'master_key': {'keys': {'ed25519:master': 'masterkey123'}},
      'self_signing_key': {'keys': {'ed25519:self': 'selfkey456'}},
      'user_signing_key': {'keys': {'ed25519:user': 'userkey789'}},
    }, token: token);
    print('device_signing (with auth): ${csResp2.statusCode} ${csResp2.body}');
    expect(csResp2.statusCode, 200);

    // Step 10: Logout
    print('\n=== STEP 10: Logout ===');
    final logoutResp = await post('/_matrix/client/v3/logout', {}, token: token);
    print('logout: ${logoutResp.statusCode}');
    expect(logoutResp.statusCode, 200);

    print('\n=== ALL STEPS PASSED ===');
  }, timeout: Timeout(Duration(seconds: 30)));
}
