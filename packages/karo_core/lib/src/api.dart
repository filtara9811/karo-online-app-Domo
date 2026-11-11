import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth.dart';
import 'errors.dart';

/// Backend RPC. Login ho to user ke token se, warna anon (customer bina login).
/// Server har vendor ko token se pehchanta hai — ऐप kabhi vendor id nahi bhejti.
class KaroApi {
  final KaroAuth auth;
  final http.Client _http;
  final Duration timeout;

  KaroApi(this.auth, {http.Client? client, this.timeout = const Duration(seconds: 15)})
      : _http = client ?? http.Client();

  Future<dynamic> rpc(String fn, [Map<String, dynamic> params = const {}]) async {
    final token = await auth.accessToken();
    var r = await _call(fn, params, token);
    if (r.statusCode == 401 && token != null) {
      // token server ne maana nahi — ek baar refresh karke dobara
      final t2 = await auth.accessToken(forceRefresh: true);
      if (t2 != null) r = await _call(fn, params, t2);
    }
    if (r.statusCode >= 300) {
      final e = KaroError.fromBytes(r.statusCode, r.bodyBytes);
      if (e.needsLogin && token != null) await auth.signOut();
      throw e;
    }
    if (r.body.isEmpty) return null;
    return jsonDecode(utf8.decode(r.bodyBytes));
  }

  Future<http.Response> _call(String fn, Map<String, dynamic> params, String? token) async {
    try {
      return await _http
          .post(
            auth.config.rpc(fn),
            headers: {
              'apikey': auth.config.anonKey,
              'Authorization': 'Bearer ${token ?? auth.config.anonKey}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(params),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const KaroError('Server jawab nahi de raha — internet check karein');
    } on http.ClientException {
      // http 1.x: mobile (SocketException) aur web dono ki network galti yahi
      throw const KaroError('Internet nahi chal raha');
    }
  }
}
