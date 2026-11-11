import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'errors.dart';
import 'phone.dart';
import 'session.dart';

/// Mobile + OTP login (Supabase Auth, seedha REST — koi bhari SDK nahi,
/// isliye background isolate (ghanti service) me bhi chalta hai).
class KaroAuth {
  final KaroConfig config;
  final SessionStore store;
  final http.Client _http;
  final int Function() _nowSec;

  Session? _session;
  Future<Session?>? _refreshing;
  final _changes = StreamController<Session?>.broadcast();

  KaroAuth(
    this.config,
    this.store, {
    http.Client? client,
    int Function()? nowSec,
  })  : _http = client ?? http.Client(),
        _nowSec = nowSec ?? (() => DateTime.now().millisecondsSinceEpoch ~/ 1000);

  Session? get session => _session;
  bool get signedIn => _session != null;
  String get phone => _session?.phone ?? '';
  String get userId => _session?.userId ?? '';

  /// Login / logout hone par
  Stream<Session?> get changes => _changes.stream;

  Map<String, String> get _headers => {'apikey': config.anonKey, 'Content-Type': 'application/json'};

  /// ऐप khulte hi: rakha hua session padho
  Future<void> load() async {
    _session = Session.decode(await store.read());
  }

  /// OTP bhejo. [phone] koi bhi format — 10 ank nikal lete hain.
  Future<void> sendOtp(String phone) async {
    final p = normalizePhone(phone);
    if (p == null) throw const KaroError('Sahi 10 ankon ka mobile number daaliye');
    final r = await _post(config.auth('otp'), {'phone': e164(p), 'channel': 'sms', 'create_user': true});
    if (r.statusCode >= 300) throw KaroError.fromBytes(r.statusCode, r.bodyBytes, fallback: 'OTP nahi gaya');
  }

  /// OTP jaancho → login
  Future<Session> verifyOtp(String phone, String code) async {
    final p = normalizePhone(phone);
    if (p == null) throw const KaroError('Sahi 10 ankon ka mobile number daaliye');
    final c = code.trim();
    if (!RegExp(r'^\d{4,10}$').hasMatch(c)) throw const KaroError('OTP ke saare ank daaliye');
    final r = await _post(config.auth('verify'), {'type': 'sms', 'phone': e164(p), 'token': c});
    if (r.statusCode >= 300) throw KaroError.fromBytes(r.statusCode, r.bodyBytes, fallback: 'OTP galat hai');
    final s = Session.fromAuthResponse(Map<String, dynamic>.from(jsonDecode(utf8.decode(r.bodyBytes)) as Map), nowSec: _nowSec());
    await _set(s);
    return s;
  }

  /// API call ke liye taaza access token (zaroorat ho to refresh). null = login nahi.
  Future<String?> accessToken({bool forceRefresh = false}) async {
    // Doosra isolate (background ghanti) shayad refresh kar chuka ho — store se taaza padho
    final stored = Session.decode(await store.read());
    if (stored == null) {
      if (_session != null) {
        _session = null;
        _changes.add(null);
      }
      return null;
    }
    _session = stored;
    if (!forceRefresh && stored.expiresAt - _nowSec() > 60) return stored.accessToken;
    final s = await (_refreshing ??= _refresh(stored).whenComplete(() => _refreshing = null));
    return s?.accessToken;
  }

  Future<Session?> _refresh(Session old) async {
    final http.Response r;
    try {
      r = await _post(config.auth('token', {'grant_type': 'refresh_token'}), {'refresh_token': old.refreshToken});
    } catch (_) {
      throw const KaroError('Internet nahi chal raha');
    }
    if (r.statusCode < 300) {
      final s = Session.fromAuthResponse(Map<String, dynamic>.from(jsonDecode(utf8.decode(r.bodyBytes)) as Map), nowSec: _nowSec());
      await _set(s);
      return s;
    }
    if (r.statusCode >= 500) throw KaroError.fromBytes(r.statusCode, r.bodyBytes);
    // Refresh token bekaar — par shayad doosre isolate ne abhi naya likha ho
    final again = Session.decode(await store.read());
    if (again != null && again.refreshToken != old.refreshToken && again.expiresAt - _nowSec() > 60) {
      _session = again;
      return again;
    }
    await _set(null);
    return null;
  }

  Future<void> signOut() async {
    final s = _session;
    await _set(null);
    if (s != null) {
      try {
        await _http
            .post(config.auth('logout'), headers: {..._headers, 'Authorization': 'Bearer ${s.accessToken}'})
            .timeout(const Duration(seconds: 8));
      } catch (_) {}
    }
  }

  Future<void> _set(Session? s) async {
    _session = s;
    await store.write(s?.encode());
    _changes.add(s);
  }

  Future<http.Response> _post(Uri u, Map<String, dynamic> body) =>
      _http.post(u, headers: _headers, body: jsonEncode(body)).timeout(const Duration(seconds: 20));
}
