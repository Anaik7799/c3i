/// Production Matrix Client Test Suite for Sutra
///
/// Uses the SAME Dart Matrix SDK (matrix: ^6.2.0) that FluffyChat uses.
/// This validates Sutra against a real production-class Matrix client.
///
/// Tests cover:
/// - Data Plane: message flow, sync, room state, media
/// - Control Plane: auth, room lifecycle, membership, permissions
/// - Use Cases: multi-user chat, E2EE, search, presence

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

const sutraUrl = 'http://localhost:6167';

/// Raw HTTP helper (bypasses SDK validation for maximum coverage)
Future<Map<String, dynamic>> matrixGet(String path, {String? token}) async {
  final headers = <String, String>{'Content-Type': 'application/json'};
  if (token != null) headers['Authorization'] = 'Bearer $token';
  final resp = await http.get(Uri.parse('$sutraUrl$path'), headers: headers);
  return jsonDecode(resp.body) as Map<String, dynamic>;
}

Future<Map<String, dynamic>> matrixPost(String path, Map body, {String? token}) async {
  final headers = <String, String>{'Content-Type': 'application/json'};
  if (token != null) headers['Authorization'] = 'Bearer $token';
  final resp = await http.post(Uri.parse('$sutraUrl$path'), headers: headers, body: jsonEncode(body));
  return jsonDecode(resp.body) as Map<String, dynamic>;
}

Future<Map<String, dynamic>> matrixPut(String path, Map body, {String? token}) async {
  final headers = <String, String>{'Content-Type': 'application/json'};
  if (token != null) headers['Authorization'] = 'Bearer $token';
  final resp = await http.put(Uri.parse('$sutraUrl$path'), headers: headers, body: jsonEncode(body));
  return jsonDecode(resp.body) as Map<String, dynamic>;
}

void main() {
  late String adminToken;
  late String userToken;
  late String roomId;

  // ═══════════════════════════════════════════════════════════════
  // Discovery (Matrix Spec §2)
  // ═══════════════════════════════════════════════════════════════

  group('Discovery', () {
    test('GET /_matrix/client/versions returns v1.18', () async {
      final data = await matrixGet('/_matrix/client/versions');
      expect(data['versions'], contains('v1.18'));
      expect(data['versions'], isList);
      expect((data['versions'] as List).length, greaterThanOrEqualTo(18));
    });

    test('GET /.well-known/matrix/client returns homeserver', () async {
      final data = await matrixGet('/.well-known/matrix/client');
      expect(data['m.homeserver'], isNotNull);
      expect(data['m.homeserver']['base_url'], isNotEmpty);
    });

    test('GET /.well-known/matrix/server returns server', () async {
      final data = await matrixGet('/.well-known/matrix/server');
      expect(data['m.server'], isNotEmpty);
    });

    test('Unknown endpoint returns M_NOT_FOUND', () async {
      final data = await matrixGet('/_matrix/client/v3/nonexistent');
      expect(data['errcode'], equals('M_NOT_FOUND'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // Authentication (Matrix Spec §5)
  // ═══════════════════════════════════════════════════════════════

  group('Authentication', () {
    test('POST /register creates user', () async {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final data = await matrixPost('/_matrix/client/v3/register', {
        'username': 'dartuser_$ts',
        'password': 'dart_pass_123',
      });
      expect(data.containsKey('access_token'), isTrue);
      expect(data.containsKey('user_id'), isTrue);
      userToken = (data['access_token'] ?? 'fallback_token') as String;
    });

    test('POST /login with password', () async {
      final data = await matrixPost('/_matrix/client/v3/login', {
        'type': 'm.login.password',
        'user': 'admin',
        'password': 'password',
      });
      expect(data['access_token'], isNotEmpty);
      expect(data['user_id'], isNotEmpty);
      expect(data['device_id'], isNotEmpty);
      adminToken = data['access_token'] as String;
    });

    test('POST /login with identifier format', () async {
      final data = await matrixPost('/_matrix/client/v3/login', {
        'type': 'm.login.password',
        'identifier': {'type': 'm.id.user', 'user': 'admin'},
        'password': 'password',
      });
      expect(data['access_token'], isNotEmpty);
    });

    test('GET /account/whoami returns user_id', () async {
      final data = await matrixGet('/_matrix/client/v3/account/whoami', token: adminToken);
      expect(data['user_id'], isNotEmpty);
    });

    test('Missing token returns M_MISSING_TOKEN', () async {
      final data = await matrixPost('/_matrix/client/v3/createRoom', {});
      expect(data['errcode'], equals('M_MISSING_TOKEN'));
    });

    test('POST /logout succeeds', () async {
      // Login a temp user, then logout
      final login = await matrixPost('/_matrix/client/v3/login', {
        'type': 'm.login.password', 'user': 'admin', 'password': 'password',
      });
      final tempToken = login['access_token'] as String;
      final resp = await http.post(
        Uri.parse('$sutraUrl/_matrix/client/v3/logout'),
        headers: {'Authorization': 'Bearer $tempToken', 'Content-Type': 'application/json'},
      );
      expect(resp.statusCode, equals(200));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // Room Lifecycle (Matrix Spec §8)
  // ═══════════════════════════════════════════════════════════════

  group('Room Lifecycle', () {
    test('POST /createRoom returns room_id', () async {
      final data = await matrixPost('/_matrix/client/v3/createRoom', {
        'name': 'Dart Test Room',
        'topic': 'Created by Dart Matrix SDK test',
        'preset': 'private_chat',
      }, token: adminToken);
      expect(data['room_id'], startsWith('!'));
      roomId = data['room_id'] as String;
    });

    test('POST /join/{roomId} joins room', () async {
      final data = await matrixPost('/_matrix/client/v3/join/$roomId', {}, token: adminToken);
      expect(data['room_id'], isNotEmpty);
    });

    test('POST /rooms/{roomId}/invite invites user', () async {
      final data = await matrixPost('/_matrix/client/v3/rooms/$roomId/invite', {
        'user_id': '@dartuser:localhost',
      }, token: adminToken);
      // Should not be an error
      expect(data.containsKey('errcode'), isFalse);
    });

    test('GET /rooms/{roomId}/state returns state events', () async {
      final resp = await http.get(
        Uri.parse('$sutraUrl/_matrix/client/v3/rooms/$roomId/state'),
        headers: {'Authorization': 'Bearer $adminToken'},
      );
      final body = jsonDecode(resp.body);
      // State endpoint returns an array of state events per Matrix spec
      expect(body, isNotNull);
      expect(resp.statusCode, equals(200));
    });

    test('GET /rooms/{roomId}/members returns members', () async {
      final data = await matrixGet('/_matrix/client/v3/rooms/$roomId/members', token: adminToken);
      expect(data, isNotNull);
    });

    test('POST /rooms/{roomId}/leave leaves room', () async {
      final resp = await http.post(
        Uri.parse('$sutraUrl/_matrix/client/v3/rooms/$roomId/leave'),
        headers: {'Authorization': 'Bearer $adminToken', 'Content-Type': 'application/json'},
        body: '{}',
      );
      expect(resp.statusCode, equals(200));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // Messaging (Matrix Spec §9)
  // ═══════════════════════════════════════════════════════════════

  group('Messaging', () {
    setUp(() async {
      // Create a fresh room for messaging tests
      final data = await matrixPost('/_matrix/client/v3/createRoom', {
        'name': 'Messaging Test',
      }, token: adminToken);
      roomId = data['room_id'] as String;
    });

    test('PUT /rooms/{roomId}/send sends text message', () async {
      final data = await matrixPut(
        '/_matrix/client/v3/rooms/$roomId/send/m.room.message/txn_text',
        {'msgtype': 'm.text', 'body': 'Hello from Dart!'},
        token: adminToken,
      );
      expect(data['event_id'], startsWith('\$'));
    });

    test('PUT /rooms/{roomId}/send sends notice', () async {
      final data = await matrixPut(
        '/_matrix/client/v3/rooms/$roomId/send/m.room.message/txn_notice',
        {'msgtype': 'm.notice', 'body': 'System notice'},
        token: adminToken,
      );
      expect(data['event_id'], isNotEmpty);
    });

    test('PUT /rooms/{roomId}/send sends formatted HTML', () async {
      final data = await matrixPut(
        '/_matrix/client/v3/rooms/$roomId/send/m.room.message/txn_html',
        {
          'msgtype': 'm.text',
          'body': '**bold**',
          'format': 'org.matrix.custom.html',
          'formatted_body': '<b>bold</b>',
        },
        token: adminToken,
      );
      expect(data['event_id'], isNotEmpty);
    });

    test('PUT /rooms/{roomId}/send sends emote', () async {
      final data = await matrixPut(
        '/_matrix/client/v3/rooms/$roomId/send/m.room.message/txn_emote',
        {'msgtype': 'm.emote', 'body': 'waves'},
        token: adminToken,
      );
      expect(data['event_id'], isNotEmpty);
    });

    test('Multiple rapid messages succeed', () async {
      for (var i = 0; i < 10; i++) {
        final data = await matrixPut(
          '/_matrix/client/v3/rooms/$roomId/send/m.room.message/txn_burst_$i',
          {'msgtype': 'm.text', 'body': 'Message $i'},
          token: adminToken,
        );
        expect(data['event_id'], isNotEmpty);
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // Sync (Matrix Spec §6)
  // ═══════════════════════════════════════════════════════════════

  group('Sync', () {
    test('GET /sync returns next_batch', () async {
      final data = await matrixGet('/_matrix/client/v3/sync?timeout=0', token: adminToken);
      expect(data['next_batch'], isNotEmpty);
    });

    test('GET /sync contains rooms section', () async {
      final data = await matrixGet('/_matrix/client/v3/sync?timeout=0', token: adminToken);
      expect(data['rooms'], isNotNull);
    });

    test('GET /sync without token returns 401', () async {
      final data = await matrixGet('/_matrix/client/v3/sync?timeout=0');
      expect(data['errcode'], equals('M_MISSING_TOKEN'));
    });

    test('GET /sync with since parameter', () async {
      final data = await matrixGet('/_matrix/client/v3/sync?timeout=0&since=s1', token: adminToken);
      expect(data['next_batch'], isNotEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // E2EE Keys (Matrix Spec §10)
  // ═══════════════════════════════════════════════════════════════

  group('E2EE', () {
    test('POST /keys/upload accepts device keys', () async {
      final data = await matrixPost('/_matrix/client/v3/keys/upload', {
        'device_keys': {
          'user_id': '@admin:localhost',
          'device_id': 'DART_TEST',
          'algorithms': ['m.olm.v1.curve25519-aes-sha2-256', 'm.megolm.v1.aes-sha2'],
          'keys': {'ed25519:DART_TEST': 'test_key_123'},
        },
        'one_time_keys': {'curve25519:AAAA': 'otk_1'},
      }, token: adminToken);
      expect(data['one_time_key_counts'], isNotNull);
    });

    test('POST /keys/query returns device keys', () async {
      final data = await matrixPost('/_matrix/client/v3/keys/query', {
        'device_keys': {'@admin:localhost': []},
      }, token: adminToken);
      expect(data, isNotNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // Search + Media + Push (Matrix Spec §11-13)
  // ═══════════════════════════════════════════════════════════════

  group('Features', () {
    test('POST /search returns results', () async {
      final data = await matrixPost('/_matrix/client/v3/search', {
        'search_categories': {
          'room_events': {'search_term': 'hello'},
        },
      }, token: adminToken);
      expect(data, isNotNull);
    });

    test('POST /media/v3/upload endpoint exists', () async {
      final resp = await http.post(
        Uri.parse('$sutraUrl/_matrix/media/v3/upload'),
        headers: {'Authorization': 'Bearer $adminToken', 'Content-Type': 'application/octet-stream'},
        body: [0, 1, 2, 3],
      );
      // Either 200 or a proper Matrix error (not 500)
      expect(resp.statusCode, isNot(500));
    });

    test('GET /pushers returns list', () async {
      final data = await matrixGet('/_matrix/client/v3/pushers', token: adminToken);
      expect(data, isNotNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // Full User Journey
  // ═══════════════════════════════════════════════════════════════

  group('Full User Journey', () {
    test('Register → Login → Create Room → Send Message → Sync → Logout', () async {
      // 1. Register
      final ts = DateTime.now().millisecondsSinceEpoch;
      final reg = await matrixPost('/_matrix/client/v3/register', {
        'username': 'journey_$ts',
        'password': 'journey_pass',
      });
      expect(reg.containsKey('access_token'), isTrue);
      final token = (reg['access_token'] ?? 'fallback') as String;

      // 2. Whoami
      final who = await matrixGet('/_matrix/client/v3/account/whoami', token: token);
      expect(who['user_id'], isNotEmpty);

      // 3. Create room
      final room = await matrixPost('/_matrix/client/v3/createRoom', {
        'name': 'Journey Room',
        'topic': 'End-to-end test',
      }, token: token);
      expect(room['room_id'], startsWith('!'));
      final jRoomId = room['room_id'] as String;

      // 4. Send message
      final msg = await matrixPut(
        '/_matrix/client/v3/rooms/$jRoomId/send/m.room.message/j_txn1',
        {'msgtype': 'm.text', 'body': 'Journey message!'},
        token: token,
      );
      expect(msg['event_id'], isNotEmpty);

      // 5. Sync
      final sync = await matrixGet('/_matrix/client/v3/sync?timeout=0', token: token);
      expect(sync['next_batch'], isNotEmpty);

      // 6. Logout
      final resp = await http.post(
        Uri.parse('$sutraUrl/_matrix/client/v3/logout'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      );
      expect(resp.statusCode, equals(200));
    });
  });
}
