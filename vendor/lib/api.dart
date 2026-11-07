import 'dart:convert';
import 'package:http/http.dart' as http;

/// Karo Online backend (Supabase — Committee Manager project ke "ko_" tables)
/// Sirf RPC functions se baat hoti hai. Ye publishable (public) key hai — secret nahi.
class Api {
  static const url = 'https://goyvhgpfxjpxkytpeigr.supabase.co';
  static const key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdveXZoZ3BmeGpweGt5dHBlaWdyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI2MDU4NzMsImV4cCI6MjEwODE4MTg3M30.5IYnhNkUtzjr8IvPoKezo-qnU1cLbXLbND9Kh6wOcmg';

  static Future<dynamic> rpc(String fn, [Map<String, dynamic> params = const {}]) async {
    final r = await http
        .post(
          Uri.parse('$url/rest/v1/rpc/$fn'),
          headers: {
            'apikey': key,
            'Authorization': 'Bearer $key',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(params),
        )
        .timeout(const Duration(seconds: 15));
    if (r.statusCode >= 300) {
      String msg = 'Server error ${r.statusCode}';
      try {
        final j = jsonDecode(r.body);
        msg = (j['message'] ?? msg).toString();
      } catch (_) {}
      throw ApiError(msg);
    }
    if (r.body.isEmpty) return null;
    return jsonDecode(utf8.decode(r.bodyBytes));
  }
}

class ApiError implements Exception {
  final String message;
  ApiError(this.message);
  @override
  String toString() => message;
}
