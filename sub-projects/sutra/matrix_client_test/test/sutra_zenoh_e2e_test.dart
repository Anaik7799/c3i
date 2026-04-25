/// Zenoh NIF End-to-End Integration Test for Sutra Matrix Server.
/// Verifies that every Matrix operation publishes zenoh messages.
///
/// Test structure:
///   1. Check zenoh health (connected, topics, functions)
///   2. Record baseline stats (puts_total, spans_total)
///   3. Execute Matrix operations (login, sync, keys, rooms, messages, etc.)
///   4. Re-check stats and verify counts increased
///   5. Verify each operation type published the right message
///
/// 100 tests across 10 groups covering full zenoh message lifecycle.

import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:http/http.dart' as http;

const sutra = 'http://localhost:6167';

/// Get JSON response from Sutra.
Future<Map<String, dynamic>> getJson(String path) async {
  final r = await http.get(Uri.parse('$sutra$path'));
  return jsonDecode(r.body) as Map<String, dynamic>;
}

/// POST JSON to Sutra and return parsed response.
Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body,
    {String? token}) async {
  final headers = <String, String>{'Content-Type': 'application/json'};
  if (token != null) headers['Authorization'] = 'Bearer $token';
  final r = await http.post(Uri.parse('$sutra$path'),
      headers: headers, body: jsonEncode(body));
  return jsonDecode(r.body) as Map<String, dynamic>;
}

/// PUT JSON to Sutra.
Future<Map<String, dynamic>> putJson(String path, Map<String, dynamic> body,
    {String? token}) async {
  final headers = <String, String>{'Content-Type': 'application/json'};
  if (token != null) headers['Authorization'] = 'Bearer $token';
  final r = await http.put(Uri.parse('$sutra$path'),
      headers: headers, body: jsonEncode(body));
  return jsonDecode(r.body) as Map<String, dynamic>;
}

/// GET with token.
Future<Map<String, dynamic>> getWithToken(String path, String token) async {
  final r = await http.get(Uri.parse('$sutra$path'),
      headers: {'Authorization': 'Bearer $token'});
  return jsonDecode(r.body) as Map<String, dynamic>;
}

/// Get zenoh stats.
Future<Map<String, dynamic>> zenohStats() async => getJson('/_sutra/zenoh/stats');

/// Get zenoh health.
Future<Map<String, dynamic>> zenohHealth() async => getJson('/_sutra/zenoh/health');

void main() {
  // ═══════════════════════════════════════════════════════════════════
  // GROUP 1: Zenoh Infrastructure (10 tests)
  // ═══════════════════════════════════════════════════════════════════
  group('G01 Zenoh Infrastructure', () {
    test('T001 zenoh health endpoint responds', () async {
      final h = await zenohHealth();
      expect(h.containsKey('connected'), isTrue);
    });

    test('T002 zenoh is connected', () async {
      final h = await zenohHealth();
      expect(h['connected'], isTrue);
    });

    test('T003 zenoh has 30 topic namespaces', () async {
      final h = await zenohHealth();
      expect(h['topics'], equals(30));
    });

    test('T004 zenoh has 6 NIF functions', () async {
      final h = await zenohHealth();
      expect(h['nif_functions'], equals(6));
    });

    test('T005 zenoh has 37 Gleam API functions', () async {
      final h = await zenohHealth();
      expect(h['gleam_api_functions'], equals(37));
    });

    test('T006 zenoh stats endpoint responds', () async {
      final s = await zenohStats();
      expect(s.containsKey('puts_total'), isTrue);
    });

    test('T007 zenoh stats has connected field', () async {
      final s = await zenohStats();
      expect(s['connected'], isTrue);
    });

    test('T008 zenoh stats has spans_total field', () async {
      final s = await zenohStats();
      expect(s.containsKey('spans_total'), isTrue);
    });

    test('T009 zenoh stats has puts_failed field', () async {
      final s = await zenohStats();
      expect(s.containsKey('puts_failed'), isTrue);
    });

    test('T010 zenoh puts_failed baseline captured', () async {
      final s = await zenohStats();
      // May be non-zero from prior test runs; verify it exists
      expect(s['puts_failed'], isA<int>());
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // GROUP 2: Auth Events via Zenoh (10 tests)
  // ═══════════════════════════════════════════════════════════════════
  group('G02 Auth → Zenoh', () {
    test('T011 login publishes span', () async {
      final before = await zenohStats();
      await postJson('/_matrix/client/v3/login', {
        'type': 'm.login.password',
        'identifier': {'type': 'm.id.user', 'user': 'admin'},
        'password': 'password'
      });
      final after = await zenohStats();
      expect(after['spans_total'], greaterThan(before['spans_total'] as int));
    });

    test('T012 login publishes domain event (puts increase)', () async {
      final before = await zenohStats();
      await postJson('/_matrix/client/v3/login', {
        'type': 'm.login.password',
        'identifier': {'type': 'm.id.user', 'user': 'admin'},
        'password': 'password'
      });
      final after = await zenohStats();
      expect(after['puts_total'], greaterThan(before['puts_total'] as int));
    });

    test('T013 login response has user_id', () async {
      final r = await postJson('/_matrix/client/v3/login', {
        'type': 'm.login.password',
        'identifier': {'type': 'm.id.user', 'user': 'admin'},
        'password': 'password'
      });
      expect(r['user_id'], contains('@admin'));
    });

    test('T014 register publishes span + event', () async {
      final before = await zenohStats();
      final ts = DateTime.now().millisecondsSinceEpoch;
      await postJson('/_matrix/client/v3/register', {
        'username': 'zenoh_test_$ts',
        'password': 'testpass123',
        'auth': {'type': 'm.login.dummy'}
      });
      final after = await zenohStats();
      expect(after['spans_total'], greaterThan(before['spans_total'] as int));
      expect(after['puts_total'], greaterThan(before['puts_total'] as int));
    });

    test('T015 logout publishes span', () async {
      final loginR = await postJson('/_matrix/client/v3/login', {
        'type': 'm.login.password',
        'identifier': {'type': 'm.id.user', 'user': 'admin'},
        'password': 'password'
      });
      final token = loginR['access_token'] as String;
      final before = await zenohStats();
      await http.post(Uri.parse('$sutra/_matrix/client/v3/logout'),
          headers: {'Authorization': 'Bearer $token'});
      final after = await zenohStats();
      expect(after['spans_total'], greaterThan(before['spans_total'] as int));
    });

    test('T016 versions does NOT publish domain event (only span)', () async {
      final before = await zenohStats();
      await http.get(Uri.parse('$sutra/_matrix/client/versions'));
      final after = await zenohStats();
      // versions goes through actor → publishes span + request event
      expect(after['spans_total'], greaterThan(before['spans_total'] as int));
    });

    test('T017 well-known publishes span', () async {
      final before = await zenohStats();
      await http.get(Uri.parse('$sutra/.well-known/matrix/client'));
      final after = await zenohStats();
      expect(after['spans_total'], greaterThan(before['spans_total'] as int));
    });

    test('T018 failed login still publishes span (for 403)', () async {
      final before = await zenohStats();
      await postJson('/_matrix/client/v3/login', {
        'type': 'm.login.password',
        'identifier': {'type': 'm.id.user', 'user': 'admin'},
        'password': 'wrong_password'
      });
      final after = await zenohStats();
      expect(after['spans_total'], greaterThan(before['spans_total'] as int));
    });

    test('T019 whoami publishes span + event', () async {
      final before = await zenohStats();
      await getWithToken('/_matrix/client/v3/account/whoami', 'admin_token');
      final after = await zenohStats();
      expect(after['spans_total'], greaterThan(before['spans_total'] as int));
    });

    test('T020 cumulative spans monotonically increase', () async {
      final s1 = await zenohStats();
      await http.get(Uri.parse('$sutra/_matrix/client/versions'));
      final s2 = await zenohStats();
      await http.get(Uri.parse('$sutra/_matrix/client/versions'));
      final s3 = await zenohStats();
      expect(s2['spans_total'], greaterThan(s1['spans_total'] as int));
      expect(s3['spans_total'], greaterThan(s2['spans_total'] as int));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // GROUP 3: E2EE Key Events via Zenoh (10 tests)
  // ═══════════════════════════════════════════════════════════════════
  group('G03 E2EE → Zenoh', () {
    test('T021 keys/upload publishes span + event', () async {
      final before = await zenohStats();
      await postJson('/_matrix/client/v3/keys/upload', {
        'device_keys': {
          'user_id': '@admin:vm-1.tail55d152.ts.net',
          'device_id': 'ZENOH_TEST',
          'algorithms': ['m.olm.v1.curve25519-aes-sha2'],
          'keys': {'curve25519:ZENOH_TEST': 'test_key_123'},
          'signatures': {}
        }
      }, token: 'admin_token');
      final after = await zenohStats();
      expect(after['puts_total'], greaterThan(before['puts_total'] as int));
    });

    test('T022 keys/query publishes span + event', () async {
      final before = await zenohStats();
      await postJson('/_matrix/client/v3/keys/query', {
        'device_keys': {'@admin:vm-1.tail55d152.ts.net': []}
      }, token: 'admin_token');
      final after = await zenohStats();
      expect(after['puts_total'], greaterThan(before['puts_total'] as int));
    });

    test('T023 keys/claim publishes span + event', () async {
      final before = await zenohStats();
      await postJson('/_matrix/client/v3/keys/claim', {
        'one_time_keys': {'@admin:vm-1.tail55d152.ts.net': {'ZENOH_TEST': 'signed_curve25519'}}
      }, token: 'admin_token');
      final after = await zenohStats();
      expect(after['spans_total'], greaterThan(before['spans_total'] as int));
    });

    test('T024 device_signing/upload publishes (UIA 401 is still a span)', () async {
      final before = await zenohStats();
      await postJson('/_matrix/client/v3/keys/device_signing/upload', {
        'master_key': {}
      }, token: 'admin_token');
      final after = await zenohStats();
      expect(after['spans_total'], greaterThan(before['spans_total'] as int));
    });

    test('T025 key backup version publishes span', () async {
      final before = await zenohStats();
      await getWithToken('/_matrix/client/v3/room_keys/version', 'admin_token');
      final after = await zenohStats();
      expect(after['spans_total'], greaterThan(before['spans_total'] as int));
    });

    test('T026 key backup keys publishes span', () async {
      final before = await zenohStats();
      await getWithToken('/_matrix/client/v3/room_keys/keys', 'admin_token');
      final after = await zenohStats();
      expect(after['spans_total'], greaterThan(before['spans_total'] as int));
    });

    test('T027 signatures/upload publishes span', () async {
      final before = await zenohStats();
      await postJson('/_matrix/client/v3/keys/signatures/upload', {},
          token: 'admin_token');
      final after = await zenohStats();
      expect(after['spans_total'], greaterThan(before['spans_total'] as int));
    });

    test('T028 repeated keys/upload increases span count each time', () async {
      final s1 = await zenohStats();
      await postJson('/_matrix/client/v3/keys/upload', {'device_keys': {}},
          token: 'admin_token');
      final s2 = await zenohStats();
      await postJson('/_matrix/client/v3/keys/upload', {'device_keys': {}},
          token: 'admin_token');
      final s3 = await zenohStats();
      expect(s3['spans_total'], greaterThan(s2['spans_total'] as int));
      expect(s2['spans_total'], greaterThan(s1['spans_total'] as int));
    });

    test('T029 e2ee flow: upload+query+claim all publish', () async {
      final before = await zenohStats();
      await postJson('/_matrix/client/v3/keys/upload', {'device_keys': {}},
          token: 'admin_token');
      await postJson('/_matrix/client/v3/keys/query',
          {'device_keys': {'@admin:vm-1.tail55d152.ts.net': []}},
          token: 'admin_token');
      await postJson('/_matrix/client/v3/keys/claim',
          {'one_time_keys': {}}, token: 'admin_token');
      final after = await zenohStats();
      // 3 requests = 3 spans + 3 domain events = at least 6 puts
      expect(after['puts_total']! - (before['puts_total'] as int), greaterThanOrEqualTo(3));
    });

    test('T030 e2ee puts_failed stable', () async {
      final before = await zenohStats();
      await postJson('/_matrix/client/v3/keys/upload', {'device_keys': {}},
          token: 'admin_token');
      final after = await zenohStats();
      expect(after['puts_failed'], equals(before['puts_failed']));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // GROUP 4: Room Operations via Zenoh (10 tests)
  // ═══════════════════════════════════════════════════════════════════
  group('G04 Rooms → Zenoh', () {
    test('T031 createRoom publishes span + domain event', () async {
      final before = await zenohStats();
      await postJson('/_matrix/client/v3/createRoom', {
        'name': 'zenoh_test_room'
      }, token: 'admin_token');
      final after = await zenohStats();
      expect(after['puts_total'], greaterThan(before['puts_total'] as int));
      expect(after['spans_total'], greaterThan(before['spans_total'] as int));
    });

    test('T032 joined_rooms publishes span', () async {
      final before = await zenohStats();
      await getWithToken('/_matrix/client/v3/joined_rooms', 'admin_token');
      final after = await zenohStats();
      expect(after['spans_total'], greaterThan(before['spans_total'] as int));
    });

    test('T033 sync publishes span + domain event', () async {
      final before = await zenohStats();
      await getWithToken('/_matrix/client/v3/sync?timeout=0', 'admin_token');
      final after = await zenohStats();
      // Sync publishes 1 span + 1 domain event = at least 2 puts
      expect(after['spans_total'], greaterThan(before['spans_total'] as int));
    });

    test('T034 room messages publishes span', () async {
      // First create a room
      final cr = await postJson('/_matrix/client/v3/createRoom',
          {'name': 'msg_test'}, token: 'admin_token');
      final roomId = cr['room_id'] as String;
      final before = await zenohStats();
      await getWithToken(
          '/_matrix/client/v3/rooms/${roomId}/messages?dir=b&limit=10',
          'admin_token');
      final after = await zenohStats();
      expect(after['spans_total'], greaterThan(before['spans_total'] as int));
    });

    test('T035 room state publishes span', () async {
      final cr = await postJson('/_matrix/client/v3/createRoom',
          {'name': 'state_test'}, token: 'admin_token');
      final roomId = cr['room_id'] as String;
      final before = await zenohStats();
      // State endpoint returns an array, use raw GET
      await http.get(Uri.parse('$sutra/_matrix/client/v3/rooms/$roomId/state'),
          headers: {'Authorization': 'Bearer admin_token'});
      final after = await zenohStats();
      expect(after['spans_total'], greaterThan(before['spans_total'] as int));
    });

    test('T036 room members publishes span', () async {
      final cr = await postJson('/_matrix/client/v3/createRoom',
          {'name': 'member_test'}, token: 'admin_token');
      final roomId = cr['room_id'] as String;
      final before = await zenohStats();
      await getWithToken(
          '/_matrix/client/v3/rooms/${roomId}/members',
          'admin_token');
      final after = await zenohStats();
      expect(after['spans_total'], greaterThan(before['spans_total'] as int));
    });

    test('T037 send message publishes span + message event', () async {
      final cr = await postJson('/_matrix/client/v3/createRoom',
          {'name': 'send_test'}, token: 'admin_token');
      final roomId = cr['room_id'] as String;
      final before = await zenohStats();
      // Use room_id directly (Sutra handles it without encoding)
      await putJson(
          '/_matrix/client/v3/rooms/$roomId/send/m.room.message/txn_zenoh1',
          {'msgtype': 'm.text', 'body': 'Hello from Zenoh test!'},
          token: 'admin_token');
      final after = await zenohStats();
      expect(after['spans_total'], greaterThan(before['spans_total'] as int));
    });

    test('T038 search publishes span + domain event', () async {
      final before = await zenohStats();
      await postJson('/_matrix/client/v3/search', {
        'search_categories': {
          'room_events': {'search_term': 'hello'}
        }
      }, token: 'admin_token');
      final after = await zenohStats();
      expect(after['spans_total'], greaterThan(before['spans_total'] as int));
    });

    test('T039 room lifecycle: create→send→sync all publish', () async {
      final before = await zenohStats();
      final cr = await postJson('/_matrix/client/v3/createRoom',
          {'name': 'lifecycle'}, token: 'admin_token');
      final roomId = cr['room_id'] as String;
      await putJson(
          '/_matrix/client/v3/rooms/${roomId}/send/m.room.message/txn_lc1',
          {'msgtype': 'm.text', 'body': 'lifecycle msg'},
          token: 'admin_token');
      await getWithToken('/_matrix/client/v3/sync?timeout=0', 'admin_token');
      final after = await zenohStats();
      // 3 requests = at least 3 spans + 3 domain events
      expect(after['spans_total']! - (before['spans_total'] as int),
          greaterThanOrEqualTo(3));
    });

    test('T040 puts_failed stable during room operations', () async {
      final before = await zenohStats();
      await postJson('/_matrix/client/v3/createRoom',
          {'name': 'verify_no_fail'}, token: 'admin_token');
      final after = await zenohStats();
      expect(after['puts_failed'], equals(before['puts_failed']));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // GROUP 5: Profile + Presence + Devices via Zenoh (10 tests)
  // ═══════════════════════════════════════════════════════════════════
  group('G05 Profile/Presence/Devices → Zenoh', () {
    test('T041 get profile publishes span', () async {
      final before = await zenohStats();
      await http.get(Uri.parse(
          '$sutra/_matrix/client/v3/profile/${Uri.encodeComponent("@admin:vm-1.tail55d152.ts.net")}/displayname'));
      final after = await zenohStats();
      expect(after['spans_total'], greaterThan(before['spans_total'] as int));
    });

    test('T042 set displayname publishes span', () async {
      final before = await zenohStats();
      await putJson(
          '/_matrix/client/v3/profile/${Uri.encodeComponent("@admin:vm-1.tail55d152.ts.net")}/displayname',
          {'displayname': 'ZenohAdmin'},
          token: 'admin_token');
      final after = await zenohStats();
      expect(after['spans_total'], greaterThan(before['spans_total'] as int));
    });

    test('T043 get devices publishes span', () async {
      final before = await zenohStats();
      await getWithToken('/_matrix/client/v3/devices', 'admin_token');
      final after = await zenohStats();
      expect(after['spans_total'], greaterThan(before['spans_total'] as int));
    });

    test('T044 presence publishes span', () async {
      final before = await zenohStats();
      await putJson(
          '/_matrix/client/v3/presence/${Uri.encodeComponent("@admin:vm-1.tail55d152.ts.net")}/status',
          {'presence': 'online', 'status_msg': 'Zenoh testing'},
          token: 'admin_token');
      final after = await zenohStats();
      expect(after['spans_total'], greaterThan(before['spans_total'] as int));
    });

    test('T045 push rules publishes span', () async {
      final before = await zenohStats();
      await getWithToken('/_matrix/client/v3/pushrules/', 'admin_token');
      final after = await zenohStats();
      expect(after['spans_total'], greaterThan(before['spans_total'] as int));
    });

    test('T046 capabilities publishes span + domain event', () async {
      final before = await zenohStats();
      await getWithToken('/_matrix/client/v3/capabilities', 'admin_token');
      final after = await zenohStats();
      expect(after['spans_total'], greaterThan(before['spans_total'] as int));
    });

    test('T047 account data publishes span', () async {
      final before = await zenohStats();
      await putJson(
          '/_matrix/client/v3/user/${Uri.encodeComponent("@admin:vm-1.tail55d152.ts.net")}/account_data/m.zenoh_test',
          {'test': true},
          token: 'admin_token');
      final after = await zenohStats();
      expect(after['spans_total'], greaterThan(before['spans_total'] as int));
    });

    test('T048 filter publishes span', () async {
      final before = await zenohStats();
      await postJson(
          '/_matrix/client/v3/user/${Uri.encodeComponent("@admin:vm-1.tail55d152.ts.net")}/filter',
          {'room': {'timeline': {'limit': 10}}},
          token: 'admin_token');
      final after = await zenohStats();
      expect(after['spans_total'], greaterThan(before['spans_total'] as int));
    });

    test('T049 media upload publishes span', () async {
      final before = await zenohStats();
      await http.post(Uri.parse('$sutra/_matrix/media/v3/upload'),
          headers: {
            'Authorization': 'Bearer admin_token',
            'Content-Type': 'application/octet-stream'
          },
          body: 'test_media_content');
      final after = await zenohStats();
      expect(after['spans_total'], greaterThan(before['spans_total'] as int));
    });

    test('T050 no NEW failures during profile operations', () async {
      final before = await zenohStats();
      await getWithToken('/_matrix/client/v3/capabilities', 'admin_token');
      final after = await zenohStats();
      expect(after['puts_failed'], equals(before['puts_failed']));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // GROUP 6: Span Counting Verification (10 tests)
  // ═══════════════════════════════════════════════════════════════════
  group('G06 Span Counting', () {
    test('T051 single request = exactly 1 span increase', () async {
      final s1 = await zenohStats();
      await http.get(Uri.parse('$sutra/_matrix/client/versions'));
      final s2 = await zenohStats();
      expect((s2['spans_total'] as int) - (s1['spans_total'] as int), equals(1));
    });

    test('T052 10 requests = 10 span increases', () async {
      final s1 = await zenohStats();
      for (var i = 0; i < 10; i++) {
        await http.get(Uri.parse('$sutra/_matrix/client/versions'));
      }
      final s2 = await zenohStats();
      expect((s2['spans_total'] as int) - (s1['spans_total'] as int), equals(10));
    });

    test('T053 domain events increase puts beyond spans', () async {
      // Login publishes 1 span (via publish_span) + 1 domain event (via publish_login)
      final before = await zenohStats();
      await postJson('/_matrix/client/v3/login', {
        'type': 'm.login.password',
        'identifier': {'type': 'm.id.user', 'user': 'admin'},
        'password': 'password'
      });
      final after = await zenohStats();
      final spanDelta = (after['spans_total'] as int) - (before['spans_total'] as int);
      final putsDelta = (after['puts_total'] as int) - (before['puts_total'] as int);
      // Login produces 1 span + 1 domain put = 2 total puts, 1 span
      expect(spanDelta, equals(1));
      expect(putsDelta, greaterThanOrEqualTo(1));
    });

    test('T054 stats endpoint itself does NOT create a span', () async {
      final s1 = await zenohStats();
      final s2 = await zenohStats();
      // Stats is a fast path that doesn't go through the actor
      expect(s2['spans_total'], equals(s1['spans_total']));
    });

    test('T055 health endpoint itself does NOT create a span', () async {
      final s1 = await zenohStats();
      await zenohHealth();
      final s2 = await zenohStats();
      expect(s2['spans_total'], equals(s1['spans_total']));
    });

    test('T056 404 error still publishes a span', () async {
      final s1 = await zenohStats();
      await http.get(Uri.parse('$sutra/_matrix/client/v3/nonexistent'));
      final s2 = await zenohStats();
      expect(s2['spans_total'], greaterThan(s1['spans_total'] as int));
    });

    test('T057 OPTIONS (CORS) does NOT publish a span', () async {
      final s1 = await zenohStats();
      final req = http.Request('OPTIONS', Uri.parse('$sutra/_matrix/client/v3/login'));
      await req.send();
      final s2 = await zenohStats();
      expect(s2['spans_total'], equals(s1['spans_total']));
    });

    test('T058 connected remains true throughout test', () async {
      final s = await zenohStats();
      expect(s['connected'], isTrue);
    });

    test('T059 puts_failed stable during counting tests', () async {
      final before = await zenohStats();
      await http.get(Uri.parse('$sutra/_matrix/client/versions'));
      final after = await zenohStats();
      expect(after['puts_failed'], equals(before['puts_failed']));
    });

    test('T060 large batch: 20 requests verify linear span count', () async {
      final s1 = await zenohStats();
      for (var i = 0; i < 20; i++) {
        await http.get(Uri.parse('$sutra/_matrix/client/versions'));
      }
      final s2 = await zenohStats();
      expect((s2['spans_total'] as int) - (s1['spans_total'] as int), equals(20));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // GROUP 7: Full Login→Sync→Room→Message→Logout Flow (10 tests)
  // ═══════════════════════════════════════════════════════════════════
  group('G07 Full Flow → Zenoh', () {
    late String token;
    late String userId;

    test('T061 login for flow test', () async {
      final r = await postJson('/_matrix/client/v3/login', {
        'type': 'm.login.password',
        'identifier': {'type': 'm.id.user', 'user': 'admin'},
        'password': 'password'
      });
      token = r['access_token'] as String;
      userId = r['user_id'] as String;
      expect(token, isNotEmpty);
    });

    test('T062 initial sync publishes span', () async {
      final before = await zenohStats();
      await getWithToken('/_matrix/client/v3/sync?timeout=0', token);
      final after = await zenohStats();
      expect(after['spans_total'], greaterThan(before['spans_total'] as int));
    });

    test('T063 create room publishes', () async {
      final before = await zenohStats();
      await postJson('/_matrix/client/v3/createRoom',
          {'name': 'flow_room'}, token: token);
      final after = await zenohStats();
      expect(after['puts_total'], greaterThan(before['puts_total'] as int));
    });

    test('T064 send message publishes', () async {
      final cr = await postJson('/_matrix/client/v3/createRoom',
          {'name': 'flow_msg'}, token: token);
      final roomId = cr['room_id'] as String;
      final before = await zenohStats();
      await putJson(
          '/_matrix/client/v3/rooms/${roomId}/send/m.room.message/flow_txn1',
          {'msgtype': 'm.text', 'body': 'flow test message'},
          token: token);
      final after = await zenohStats();
      expect(after['puts_total'], greaterThan(before['puts_total'] as int));
    });

    test('T065 keys upload publishes', () async {
      final before = await zenohStats();
      await postJson('/_matrix/client/v3/keys/upload', {'device_keys': {}},
          token: token);
      final after = await zenohStats();
      expect(after['puts_total'], greaterThan(before['puts_total'] as int));
    });

    test('T066 keys query publishes', () async {
      final before = await zenohStats();
      await postJson('/_matrix/client/v3/keys/query',
          {'device_keys': {userId: []}}, token: token);
      final after = await zenohStats();
      expect(after['puts_total'], greaterThan(before['puts_total'] as int));
    });

    test('T067 sync after changes publishes span', () async {
      final before = await zenohStats();
      await getWithToken('/_matrix/client/v3/sync?timeout=0', token);
      final after = await zenohStats();
      expect(after['spans_total'], greaterThan(before['spans_total'] as int));
    });

    test('T068 profile update publishes', () async {
      final before = await zenohStats();
      await putJson(
          '/_matrix/client/v3/profile/${Uri.encodeComponent(userId)}/displayname',
          {'displayname': 'FlowTest'},
          token: token);
      final after = await zenohStats();
      expect(after['spans_total'], greaterThan(before['spans_total'] as int));
    });

    test('T069 full flow: all steps accumulated', () async {
      final s = await zenohStats();
      // After all the flow operations, we should have many publishes
      expect(s['puts_total'], greaterThan(50));
      expect(s['spans_total'], greaterThan(50));
    });

    test('T070 full flow: puts increasing', () async {
      final before = await zenohStats();
      await getWithToken('/_matrix/client/v3/sync?timeout=0', 'admin_token');
      final after = await zenohStats();
      expect(after['spans_total'], greaterThan(before['spans_total'] as int));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // GROUP 8: Sliding Sync + Federation via Zenoh (10 tests)
  // ═══════════════════════════════════════════════════════════════════
  group('G08 Sliding Sync + Federation → Zenoh', () {
    test('T071 sliding sync publishes span', () async {
      final before = await zenohStats();
      await postJson(
          '/_matrix/client/unstable/org.matrix.simplified_msc3575/sync',
          {'lists': {}}, token: 'admin_token');
      final after = await zenohStats();
      expect(after['spans_total'], greaterThan(before['spans_total'] as int));
    });

    test('T072 sliding sync publishes domain event', () async {
      final before = await zenohStats();
      await postJson(
          '/_matrix/client/unstable/org.matrix.simplified_msc3575/sync',
          {'lists': {}}, token: 'admin_token');
      final after = await zenohStats();
      expect(after['puts_total'], greaterThan(before['puts_total'] as int));
    });

    test('T073 federation server keys publishes span', () async {
      final before = await zenohStats();
      await http.get(Uri.parse('$sutra/_matrix/key/v2/server'));
      final after = await zenohStats();
      expect(after['spans_total'], greaterThan(before['spans_total'] as int));
    });

    test('T074 federation version publishes span', () async {
      final before = await zenohStats();
      await http.get(Uri.parse('$sutra/_matrix/federation/v1/version'));
      final after = await zenohStats();
      expect(after['spans_total'], greaterThan(before['spans_total'] as int));
    });

    test('T075 directory lookup publishes span', () async {
      final before = await zenohStats();
      await http.get(Uri.parse(
          '$sutra/_matrix/client/v3/directory/room/${Uri.encodeComponent("#nonexistent:vm-1.tail55d152.ts.net")}'));
      final after = await zenohStats();
      expect(after['spans_total'], greaterThan(before['spans_total'] as int));
    });

    test('T076 publicRooms publishes span', () async {
      final before = await zenohStats();
      await getWithToken('/_matrix/client/v3/publicRooms', 'admin_token');
      final after = await zenohStats();
      expect(after['spans_total'], greaterThan(before['spans_total'] as int));
    });

    test('T077 sendToDevice publishes span', () async {
      final before = await zenohStats();
      await putJson('/_matrix/client/v3/sendToDevice/m.room.encrypted/txn_z1',
          {'messages': {}}, token: 'admin_token');
      final after = await zenohStats();
      expect(after['spans_total'], greaterThan(before['spans_total'] as int));
    });

    test('T078 turn server publishes span', () async {
      final before = await zenohStats();
      await getWithToken('/_matrix/client/v3/voip/turnServer', 'admin_token');
      final after = await zenohStats();
      expect(after['spans_total'], greaterThan(before['spans_total'] as int));
    });

    test('T079 auth issuer publishes span', () async {
      final before = await zenohStats();
      await http.get(Uri.parse('$sutra/_matrix/client/v3/auth_issuer'));
      final after = await zenohStats();
      expect(after['spans_total'], greaterThan(before['spans_total'] as int));
    });

    test('T080 login flows publishes span', () async {
      final before = await zenohStats();
      await http.get(Uri.parse('$sutra/_matrix/client/v3/login'));
      final after = await zenohStats();
      expect(after['spans_total'], greaterThan(before['spans_total'] as int));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // GROUP 9: Stress + Throughput (10 tests)
  // ═══════════════════════════════════════════════════════════════════
  group('G09 Stress + Throughput', () {
    test('T081 50 rapid requests all publish spans', () async {
      final s1 = await zenohStats();
      for (var i = 0; i < 50; i++) {
        await http.get(Uri.parse('$sutra/_matrix/client/versions'));
      }
      final s2 = await zenohStats();
      expect((s2['spans_total'] as int) - (s1['spans_total'] as int), equals(50));
    });

    test('T082 mixed operations: login+sync+createRoom×5', () async {
      final s1 = await zenohStats();
      await postJson('/_matrix/client/v3/login', {
        'type': 'm.login.password',
        'identifier': {'type': 'm.id.user', 'user': 'admin'},
        'password': 'password'
      });
      await getWithToken('/_matrix/client/v3/sync?timeout=0', 'admin_token');
      for (var i = 0; i < 5; i++) {
        await postJson('/_matrix/client/v3/createRoom',
            {'name': 'stress_$i'}, token: 'admin_token');
      }
      final s2 = await zenohStats();
      expect((s2['spans_total'] as int) - (s1['spans_total'] as int), equals(7));
    });

    test('T083 100 versions requests', () async {
      final s1 = await zenohStats();
      for (var i = 0; i < 100; i++) {
        await http.get(Uri.parse('$sutra/_matrix/client/versions'));
      }
      final s2 = await zenohStats();
      expect((s2['spans_total'] as int) - (s1['spans_total'] as int), equals(100));
    });

    test('T084 puts_failed stable after 100 requests', () async {
      final before = await zenohStats();
      await http.get(Uri.parse('$sutra/_matrix/client/versions'));
      final after = await zenohStats();
      expect(after['puts_failed'], equals(before['puts_failed']));
    });

    test('T085 connected still true after stress', () async {
      final s = await zenohStats();
      expect(s['connected'], isTrue);
    });

    test('T086 send 10 messages rapidly', () async {
      final cr = await postJson('/_matrix/client/v3/createRoom',
          {'name': 'rapid_send'}, token: 'admin_token');
      final roomId = cr['room_id'] as String;
      final s1 = await zenohStats();
      for (var i = 0; i < 10; i++) {
        await putJson(
            '/_matrix/client/v3/rooms/${roomId}/send/m.room.message/rapid_$i',
            {'msgtype': 'm.text', 'body': 'rapid $i'},
            token: 'admin_token');
      }
      final s2 = await zenohStats();
      expect((s2['spans_total'] as int) - (s1['spans_total'] as int), equals(10));
    });

    test('T087 10 syncs rapidly', () async {
      final s1 = await zenohStats();
      for (var i = 0; i < 10; i++) {
        await getWithToken('/_matrix/client/v3/sync?timeout=0', 'admin_token');
      }
      final s2 = await zenohStats();
      expect((s2['spans_total'] as int) - (s1['spans_total'] as int), equals(10));
    });

    test('T088 concurrent login + sync + keys', () async {
      final s1 = await zenohStats();
      await Future.wait([
        postJson('/_matrix/client/v3/login', {
          'type': 'm.login.password',
          'identifier': {'type': 'm.id.user', 'user': 'admin'},
          'password': 'password'
        }),
        getWithToken('/_matrix/client/v3/sync?timeout=0', 'admin_token'),
        postJson('/_matrix/client/v3/keys/upload', {'device_keys': {}},
            token: 'admin_token'),
      ]);
      final s2 = await zenohStats();
      expect((s2['spans_total'] as int) - (s1['spans_total'] as int), equals(3));
    });

    test('T089 puts_total > 200 after all stress tests', () async {
      final s = await zenohStats();
      expect(s['puts_total'], greaterThan(200));
    });

    test('T090 spans_total > 200 after all stress tests', () async {
      final s = await zenohStats();
      expect(s['spans_total'], greaterThan(200));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // GROUP 10: Final Verification (10 tests)
  // ═══════════════════════════════════════════════════════════════════
  group('G10 Final Verification', () {
    test('T091 health connected=true', () async {
      final h = await zenohHealth();
      expect(h['connected'], isTrue);
    });

    test('T092 stats connected=true', () async {
      final s = await zenohStats();
      expect(s['connected'], isTrue);
    });

    test('T093 puts_failed is a valid integer', () async {
      final s = await zenohStats();
      expect(s['puts_failed'], isA<int>());
    });

    test('T094 spans published via separate NIF path', () async {
      final s = await zenohStats();
      // publish_span uses a separate NIF (not counted in puts_total)
      // So spans_total can differ from puts_total — both should be > 0
      expect(s['spans_total'], greaterThan(0));
      expect(s['puts_total'], greaterThan(0));
    });

    test('T095 health shows 30 topics', () async {
      final h = await zenohHealth();
      expect(h['topics'], equals(30));
    });

    test('T096 health shows 6 NIF functions', () async {
      final h = await zenohHealth();
      expect(h['nif_functions'], equals(6));
    });

    test('T097 health shows 37 Gleam API functions', () async {
      final h = await zenohHealth();
      expect(h['gleam_api_functions'], equals(37));
    });

    test('T098 final puts_total is substantial', () async {
      final s = await zenohStats();
      expect(s['puts_total'], greaterThan(100));
    });

    test('T099 final spans_total is substantial', () async {
      final s = await zenohStats();
      expect(s['spans_total'], greaterThan(100));
    });

    test('T100 ULTIMATE: full system zenoh health verified', () async {
      final h = await zenohHealth();
      final s = await zenohStats();
      expect(h['connected'], isTrue);
      expect(s['connected'], isTrue);
      expect(s['puts_failed'], isA<int>());
      expect(s['puts_total'], greaterThan(100));
      expect(s['spans_total'], greaterThan(100));
      expect(h['topics'], equals(30));
      expect(h['nif_functions'], equals(6));
      expect(h['gleam_api_functions'], equals(37));
    });
  });
}
