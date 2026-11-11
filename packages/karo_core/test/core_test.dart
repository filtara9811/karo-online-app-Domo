import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:karo_core/karo_core.dart';
import 'package:test/test.dart';

const cfg = KaroConfig(url: 'https://x.supabase.co', anonKey: 'ANON');

/// Nakli Supabase: OTP, verify, refresh, logout, RPC
class FakeServer {
  int now = 1000000;
  final calls = <String>[];
  int refreshCount = 0;
  bool refreshFails = false;
  String validToken = 'acc1';
  bool rpcRejectsOnce = false;

  Map<String, dynamic> sessionJson(String acc, String ref, {int ttl = 3600}) => {
        'access_token': acc,
        'refresh_token': ref,
        'expires_in': ttl,
        'expires_at': now + ttl,
        'user': {'id': 'u-1', 'phone': '919876543210'},
      };

  late final client = MockClient((req) async {
    final path = req.url.path;
    calls.add('${req.method} $path${req.url.query.isEmpty ? '' : '?${req.url.query}'}');
    expect(req.headers['apikey'], 'ANON');
    final body = req.body.isEmpty ? {} : jsonDecode(req.body) as Map;
    switch (path) {
      case '/auth/v1/otp':
        if (body['phone'] != '+919876543210') return http.Response('{"msg":"Invalid phone number"}', 400);
        return http.Response('{}', 200);
      case '/auth/v1/verify':
        if (body['token'] != '123456') return http.Response('{"code":403,"error_code":"otp_expired","msg":"Token has expired or is invalid"}', 403);
        return http.Response(jsonEncode(sessionJson('acc1', 'ref1')), 200);
      case '/auth/v1/token':
        refreshCount++;
        if (refreshFails) return http.Response('{"error_code":"refresh_token_not_found","msg":"Invalid Refresh Token"}', 400);
        validToken = 'acc${refreshCount + 1}';
        return http.Response(jsonEncode(sessionJson(validToken, 'ref${refreshCount + 1}')), 200);
      case '/auth/v1/logout':
        return http.Response('', 204);
      case '/rest/v1/rpc/ko_me':
        final auth = req.headers['Authorization'];
        if (rpcRejectsOnce) {
          rpcRejectsOnce = false;
          return http.Response('{"code":"PGRST301","message":"JWT expired"}', 401);
        }
        if (auth != 'Bearer $validToken') return http.Response('{"code":"PGRST301","message":"JWT expired"}', 401);
        return http.Response('{"shop_name":"A"}', 200);
      case '/rest/v1/rpc/ko_lead_create':
        expect(req.headers['Authorization'], 'Bearer ANON');
        return http.Response('{"id":1,"token":"t"}', 200);
      case '/rest/v1/rpc/ko_boom':
        // charset header ke bina UTF-8 (asli server jaisa bura case)
        return http.Response.bytes(utf8.encode('{"code":"P0001","message":"Coins kam hain — recharge karein"}'), 400);
    }
    return http.Response('not found', 404);
  });
}

void main() {
  group('normalizePhone', () {
    test('formats', () {
      expect(normalizePhone('+91 98765-43210'), '9876543210');
      expect(normalizePhone('09876543210'), '9876543210');
      expect(normalizePhone('919876543210'), '9876543210');
      expect(normalizePhone('5876543210'), isNull);
      expect(normalizePhone('12345'), isNull);
      expect(normalizePhone(null), isNull);
    });
  });

  group('KaroAuth', () {
    late FakeServer srv;
    late MemorySessionStore store;
    late KaroAuth auth;
    setUp(() {
      srv = FakeServer();
      store = MemorySessionStore();
      auth = KaroAuth(cfg, store, client: srv.client, nowSec: () => srv.now);
    });

    test('OTP → verify → session store me', () async {
      await auth.sendOtp('98765 43210');
      final s = await auth.verifyOtp('9876543210', '123456');
      expect(s.phone, '9876543210');
      expect(auth.signedIn, isTrue);
      expect(Session.decode(store.value)!.accessToken, 'acc1');
    });

    test('galat number / galat OTP → saaf Hinglish error', () async {
      expect(() => auth.sendOtp('123'), throwsA(isA<KaroError>()));
      await expectLater(
          auth.verifyOtp('9876543210', '000000'),
          throwsA(isA<KaroError>().having((e) => e.message, 'msg', contains('OTP galat'))));
      expect(auth.signedIn, isFalse);
    });

    test('token khatam hone se pehle refresh, ek saath kai call = ek hi refresh', () async {
      await auth.verifyOtp('9876543210', '123456');
      srv.now += 3590; // 10 sec bache
      final t = await Future.wait([auth.accessToken(), auth.accessToken(), auth.accessToken()]);
      expect(t, everyElement('acc2'));
      expect(srv.refreshCount, 1);
    });

    test('doosre isolate ne refresh kar diya → store se naya token, refresh nahi', () async {
      await auth.verifyOtp('9876543210', '123456');
      store.value = Session(accessToken: 'accX', refreshToken: 'refX', expiresAt: srv.now + 3600, userId: 'u-1', phone: '9876543210').encode();
      expect(await auth.accessToken(), 'accX');
      expect(srv.refreshCount, 0);
    });

    test('refresh token bekaar → logout', () async {
      await auth.verifyOtp('9876543210', '123456');
      srv.now += 4000;
      srv.refreshFails = true;
      final events = <Session?>[];
      auth.changes.listen(events.add);
      expect(await auth.accessToken(), isNull);
      expect(auth.signedIn, isFalse);
      expect(store.value, isNull);
      await Future<void>.delayed(Duration.zero);
      expect(events.last, isNull);
    });

    test('load(): rakha session wapas', () async {
      await auth.verifyOtp('9876543210', '123456');
      final a2 = KaroAuth(cfg, store, client: srv.client, nowSec: () => srv.now);
      await a2.load();
      expect(a2.phone, '9876543210');
    });
  });

  group('KaroApi', () {
    late FakeServer srv;
    late KaroAuth auth;
    late KaroApi api;
    setUp(() {
      srv = FakeServer();
      auth = KaroAuth(cfg, MemorySessionStore(), client: srv.client, nowSec: () => srv.now);
      api = KaroApi(auth, client: srv.client);
    });

    test('bina login = anon key (customer)', () async {
      expect((await api.rpc('ko_lead_create', {'p': {}}))['token'], 't');
    });

    test('login = user token', () async {
      await auth.verifyOtp('9876543210', '123456');
      expect((await api.rpc('ko_me'))['shop_name'], 'A');
    });

    test('401 → ek baar refresh karke dobara', () async {
      await auth.verifyOtp('9876543210', '123456');
      srv.rpcRejectsOnce = true;
      srv.validToken = 'acc2';
      expect((await api.rpc('ko_me'))['shop_name'], 'A');
      expect(srv.refreshCount, 1);
    });

    test('server ka message seedha', () async {
      await expectLater(api.rpc('ko_boom'), throwsA(isA<KaroError>().having((e) => e.message, 'm', 'Coins kam hain — recharge karein')));
    });
  });
}
