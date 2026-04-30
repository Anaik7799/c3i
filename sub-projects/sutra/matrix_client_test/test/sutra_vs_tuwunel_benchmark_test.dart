/// Sutra vs Tuwunel Benchmark Suite
/// Runs identical tests against both servers with timing.
/// Sutra: http://localhost:6167 (Gleam, BEAM VM, in-memory KV)
/// Tuwunel: http://127.0.0.1:6168 (Rust, RocksDB, production-grade)

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

const servers = {
  'Sutra':   'http://localhost:6167',
  'Tuwunel': 'http://127.0.0.1:6168',
};

var _c = 0;
final results = <String, List<Map<String, dynamic>>>{};

Future<Map<String, String>> reg(String base, String pfx) async {
  final n = '${pfx}_${++_c}_${DateTime.now().millisecondsSinceEpoch}';
  final r = await http.post(Uri.parse('$base/_matrix/client/v3/register'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'username': n, 'password': 'p_$n', 'auth': {'type': 'm.login.dummy'}}));
  final d = jsonDecode(r.body);
  return {'t': d['access_token']??'', 'u': d['user_id']??'', 'd': d['device_id']??'', 'n': n, 'p': 'p_$n'};
}

Future<Map<String, dynamic>> timed(String name, String server, Future<http.Response> Function() fn) async {
  final sw = Stopwatch()..start();
  final r = await fn();
  sw.stop();
  final ms = sw.elapsedMilliseconds;
  final result = {'test': name, 'server': server, 'ms': ms, 'status': r.statusCode, 'size': r.bodyBytes.length};
  results.putIfAbsent(server, () => []).add(result);
  return result;
}

void main() {
  for (final entry in servers.entries) {
    final sName = entry.key;
    final base = entry.value;

    group('[$sName] Benchmark', () {
      // Discovery
      test('B01 well-known', () async {
        final r = await timed('well-known', sName, () => http.get(Uri.parse('$base/.well-known/matrix/client')));
        expect(r['status'], anyOf(200, 404));
      });
      test('B02 versions', () async {
        final r = await timed('versions', sName, () => http.get(Uri.parse('$base/_matrix/client/versions')));
        expect(r['status'], 200);
      });
      test('B03 capabilities', () async {
        final r = await timed('capabilities', sName, () => http.get(Uri.parse('$base/_matrix/client/v3/capabilities')));
        expect(r['status'], anyOf(200, 401));
      });
      test('B04 login flows', () async {
        final r = await timed('login_flows', sName, () => http.get(Uri.parse('$base/_matrix/client/v3/login')));
        expect(r['status'], 200);
      });
      test('B05 federation version', () async {
        final r = await timed('fed_version', sName, () => http.get(Uri.parse('$base/_matrix/federation/v1/version')));
        expect(r['status'], 200);
      });

      // Registration
      test('B06 register', () async {
        final r = await timed('register', sName, () => http.post(Uri.parse('$base/_matrix/client/v3/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'username': 'bench_${++_c}_${DateTime.now().millisecondsSinceEpoch}', 'password': 'pass', 'auth': {'type': 'm.login.dummy'}})));
        expect(r['status'], 200);
      });

      // Login
      test('B07 login', () async {
        final r = await timed('login', sName, () => http.post(Uri.parse('$base/_matrix/client/v3/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'type': 'm.login.password', 'identifier': {'type': 'm.id.user', 'user': 'admin'}, 'password': 'password'})));
        expect(r['status'], 200);
      });
      test('B08 whoami', () async {
        final u = await reg(base, 'b08');
        final r = await timed('whoami', sName, () => http.get(Uri.parse('$base/_matrix/client/v3/account/whoami'),
          headers: {'Authorization': 'Bearer ${u['t']}'}));
        expect(r['status'], 200);
      });

      // Room operations
      test('B09 createRoom', () async {
        final u = await reg(base, 'b09');
        final r = await timed('createRoom', sName, () => http.post(Uri.parse('$base/_matrix/client/v3/createRoom'),
          headers: {'Authorization': 'Bearer ${u['t']}', 'Content-Type': 'application/json'},
          body: jsonEncode({'name': 'Bench Room'})));
        expect(r['status'], 200);
      });

      // Messaging
      test('B10 send message', () async {
        final u = await reg(base, 'b10');
        final cr = jsonDecode((await http.post(Uri.parse('$base/_matrix/client/v3/createRoom'),
          headers: {'Authorization': 'Bearer ${u['t']}', 'Content-Type': 'application/json'}, body: '{}')).body);
        final rid = cr['room_id'];
        final r = await timed('send_msg', sName, () => http.put(
          Uri.parse('$base/_matrix/client/v3/rooms/$rid/send/m.room.message/bench10'),
          headers: {'Authorization': 'Bearer ${u['t']}', 'Content-Type': 'application/json'},
          body: jsonEncode({'msgtype': 'm.text', 'body': 'Benchmark message'})));
        expect(r['status'], 200);
      });

      // Sync
      test('B11 initial sync', () async {
        final u = await reg(base, 'b11');
        final r = await timed('sync_initial', sName, () => http.get(
          Uri.parse('$base/_matrix/client/v3/sync?timeout=0'),
          headers: {'Authorization': 'Bearer ${u['t']}'}));
        expect(r['status'], 200);
      });

      // Sliding Sync
      test('B12 sliding sync', () async {
        final u = await reg(base, 'b12');
        final r = await timed('sliding_sync', sName, () => http.post(
          Uri.parse('$base/_matrix/client/unstable/org.matrix.simplified_msc3575/sync'),
          headers: {'Authorization': 'Bearer ${u['t']}', 'Content-Type': 'application/json'},
          body: jsonEncode({'lists': {'all': {'ranges': [[0, 20]], 'timeline_limit': 10}}})));
        expect(r['status'], anyOf(200, 404));
      });

      // E2EE
      test('B13 keys/upload', () async {
        final u = await reg(base, 'b13');
        final r = await timed('keys_upload', sName, () => http.post(
          Uri.parse('$base/_matrix/client/v3/keys/upload'),
          headers: {'Authorization': 'Bearer ${u['t']}', 'Content-Type': 'application/json'},
          body: jsonEncode({'device_keys': {'user_id': u['u'], 'device_id': u['d'],
            'algorithms': ['m.olm.v1.curve25519-aes-sha2-256'], 'keys': {'ed25519:${u['d']}': 'k'}, 'signatures': {}},
            'one_time_keys': {'curve25519:BK1': 'v1', 'curve25519:BK2': 'v2'}})));
        expect(r['status'], 200);
      });
      test('B14 keys/query', () async {
        final u = await reg(base, 'b14');
        await http.post(Uri.parse('$base/_matrix/client/v3/keys/upload'),
          headers: {'Authorization': 'Bearer ${u['t']}', 'Content-Type': 'application/json'},
          body: jsonEncode({'device_keys': {'user_id': u['u'], 'device_id': u['d'],
            'algorithms': ['m.olm.v1.curve25519-aes-sha2-256'], 'keys': {'ed25519:${u['d']}': 'k'}, 'signatures': {}}}));
        final r = await timed('keys_query', sName, () => http.post(
          Uri.parse('$base/_matrix/client/v3/keys/query'),
          headers: {'Authorization': 'Bearer ${u['t']}', 'Content-Type': 'application/json'},
          body: jsonEncode({'device_keys': {u['u']!: []}})));
        expect(r['status'], 200);
      });

      // Media
      test('B15 media upload', () async {
        final u = await reg(base, 'b15');
        final r = await timed('media_upload', sName, () => http.post(
          Uri.parse('$base/_matrix/media/v3/upload?filename=bench.txt'),
          headers: {'Authorization': 'Bearer ${u['t']}', 'Content-Type': 'text/plain'},
          body: 'Benchmark content for media upload test'));
        expect(r['status'], anyOf(200, 404));
      });

      // Profile
      test('B16 profile', () async {
        final u = await reg(base, 'b16');
        final r = await timed('profile_get', sName, () => http.get(
          Uri.parse('$base/_matrix/client/v3/profile/${u['u']}/displayname'),
          headers: {'Authorization': 'Bearer ${u['t']}'}));
        expect(r['status'], anyOf(200, 404));
      });

      // Presence
      test('B17 presence', () async {
        final u = await reg(base, 'b17');
        final r = await timed('presence_set', sName, () => http.put(
          Uri.parse('$base/_matrix/client/v3/presence/${u['u']}/status'),
          headers: {'Authorization': 'Bearer ${u['t']}', 'Content-Type': 'application/json'},
          body: jsonEncode({'presence': 'online', 'status_msg': 'benchmarking'})));
        expect(r['status'], anyOf(200, 404));
      });

      // Devices
      test('B18 devices', () async {
        final u = await reg(base, 'b18');
        final r = await timed('devices', sName, () => http.get(
          Uri.parse('$base/_matrix/client/v3/devices'),
          headers: {'Authorization': 'Bearer ${u['t']}'}));
        expect(r['status'], 200);
      });

      // Push rules
      test('B19 pushrules', () async {
        final u = await reg(base, 'b19');
        final r = await timed('pushrules', sName, () => http.get(
          Uri.parse('$base/_matrix/client/v3/pushrules/'),
          headers: {'Authorization': 'Bearer ${u['t']}'}));
        expect(r['status'], 200);
      });

      // Account data
      test('B20 account data', () async {
        final u = await reg(base, 'b20');
        await http.put(Uri.parse('$base/_matrix/client/v3/user/${u['u']}/account_data/m.bench'),
          headers: {'Authorization': 'Bearer ${u['t']}', 'Content-Type': 'application/json'},
          body: jsonEncode({'bench': true}));
        final r = await timed('acct_data', sName, () => http.get(
          Uri.parse('$base/_matrix/client/v3/user/${u['u']}/account_data/m.bench'),
          headers: {'Authorization': 'Bearer ${u['t']}'}));
        expect(r['status'], 200);
      });

      // Typing
      test('B21 typing', () async {
        final u = await reg(base, 'b21');
        final cr = jsonDecode((await http.post(Uri.parse('$base/_matrix/client/v3/createRoom'),
          headers: {'Authorization': 'Bearer ${u['t']}', 'Content-Type': 'application/json'}, body: '{}')).body);
        final r = await timed('typing', sName, () => http.put(
          Uri.parse('$base/_matrix/client/v3/rooms/${cr['room_id']}/typing/${u['u']}'),
          headers: {'Authorization': 'Bearer ${u['t']}', 'Content-Type': 'application/json'},
          body: jsonEncode({'typing': true, 'timeout': 5000})));
        expect(r['status'], 200);
      });

      // Logout
      test('B22 logout', () async {
        final u = await reg(base, 'b22');
        final r = await timed('logout', sName, () => http.post(
          Uri.parse('$base/_matrix/client/v3/logout'),
          headers: {'Authorization': 'Bearer ${u['t']}'}));
        expect(r['status'], 200);
      });

      // Throughput: 10 rapid messages
      test('B23 throughput (10 msgs)', () async {
        final u = await reg(base, 'b23');
        final cr = jsonDecode((await http.post(Uri.parse('$base/_matrix/client/v3/createRoom'),
          headers: {'Authorization': 'Bearer ${u['t']}', 'Content-Type': 'application/json'}, body: '{}')).body);
        final rid = cr['room_id'];
        final sw = Stopwatch()..start();
        for (var i = 0; i < 10; i++) {
          await http.put(Uri.parse('$base/_matrix/client/v3/rooms/$rid/send/m.room.message/thr$i'),
            headers: {'Authorization': 'Bearer ${u['t']}', 'Content-Type': 'application/json'},
            body: jsonEncode({'msgtype': 'm.text', 'body': 'Msg $i'}));
        }
        sw.stop();
        results.putIfAbsent(sName, () => []).add({'test': 'throughput_10msg', 'server': sName, 'ms': sw.elapsedMilliseconds, 'status': 200, 'size': 0});
        expect(sw.elapsedMilliseconds, lessThan(30000));
      });

      // Cross-signing UIA
      test('B24 cross-signing UIA', () async {
        final u = await reg(base, 'b24');
        final r1 = await timed('xs_uia_401', sName, () => http.post(
          Uri.parse('$base/_matrix/client/v3/keys/device_signing/upload'),
          headers: {'Authorization': 'Bearer ${u['t']}', 'Content-Type': 'application/json'},
          body: '{}'));
        expect(r1['status'], 401);
        final r2 = await timed('xs_uia_200', sName, () => http.post(
          Uri.parse('$base/_matrix/client/v3/keys/device_signing/upload'),
          headers: {'Authorization': 'Bearer ${u['t']}', 'Content-Type': 'application/json'},
          body: jsonEncode({'auth': {'type': 'm.login.password', 'identifier': {'type': 'm.id.user', 'user': u['n']}, 'password': u['p'], 'session': 'bench'},
            'master_key': {'user_id': u['u'], 'usage': ['master'], 'keys': {'ed25519:bm': 'bmk'}}})));
        expect(r2['status'], 200);
      });

      // Key backup
      test('B25 key backup', () async {
        final u = await reg(base, 'b25');
        final r = await timed('key_backup', sName, () => http.put(
          Uri.parse('$base/_matrix/client/v3/room_keys/version'),
          headers: {'Authorization': 'Bearer ${u['t']}', 'Content-Type': 'application/json'},
          body: jsonEncode({'algorithm': 'm.megolm_backup.v1.curve25519-aes-sha2', 'auth_data': {'public_key': 'bpk'}})));
        expect(r['status'], anyOf(200, 404));
      });
    });
  }

  // Print summary after all tests
  tearDownAll(() {
    print('\n${"═" * 80}');
    print('  BENCHMARK RESULTS: SUTRA vs TUWUNEL');
    print('${"═" * 80}');
    print('');
    print('${"Test".padRight(25)} ${"Sutra ms".padRight(12)} ${"Tuwunel ms".padRight(12)} ${"Winner".padRight(10)} ${"S-Status".padRight(10)} ${"T-Status".padRight(10)}');
    print('─' * 80);

    final sutraResults = results['Sutra'] ?? [];
    final tuwunelResults = results['Tuwunel'] ?? [];
    final testNames = sutraResults.map((r) => r['test'] as String).toSet();

    var sutraWins = 0, tuwunelWins = 0, ties = 0;

    for (final name in testNames) {
      final sr = sutraResults.firstWhere((r) => r['test'] == name, orElse: () => {'ms': -1, 'status': 0});
      final tr = tuwunelResults.firstWhere((r) => r['test'] == name, orElse: () => {'ms': -1, 'status': 0});
      final sMs = sr['ms'] as int;
      final tMs = tr['ms'] as int;
      final winner = sMs < 0 || tMs < 0 ? 'N/A' : sMs < tMs ? 'Sutra' : tMs < sMs ? 'Tuwunel' : 'Tie';
      if (winner == 'Sutra') sutraWins++;
      else if (winner == 'Tuwunel') tuwunelWins++;
      else ties++;
      print('${name.padRight(25)} ${sMs.toString().padRight(12)} ${tMs.toString().padRight(12)} ${winner.padRight(10)} ${sr['status'].toString().padRight(10)} ${tr['status'].toString().padRight(10)}');
    }

    print('─' * 80);
    print('Sutra wins: $sutraWins  |  Tuwunel wins: $tuwunelWins  |  Ties: $ties');
    print('═' * 80);
  });
}
