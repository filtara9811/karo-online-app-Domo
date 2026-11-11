import 'dart:convert';

/// Server / network ki galti — [message] seedha user ko dikhane layak (Hinglish).
class KaroError implements Exception {
  final String message;
  final int? status;
  final String? code;
  const KaroError(this.message, {this.status, this.code});

  /// Session khatam / login zaroori — ऐप ko login screen par bhejna chahiye.
  bool get needsLogin => status == 401 || code == '28000' || code == 'PGRST301' || code == 'session_expired';

  @override
  String toString() => message;

  /// Supabase (GoTrue / PostgREST) ke error body se saaf message.
  /// Body hamesha UTF-8 me padhte hain (charset header na ho to bhi Hindi / "—" sahi rahe).
  static KaroError fromBytes(int status, List<int> bytes, {String fallback = 'Server error'}) =>
      fromResponse(status, utf8.decode(bytes, allowMalformed: true), fallback: fallback);

  static KaroError fromResponse(int status, String body, {String fallback = 'Server error'}) {
    String msg = '$fallback ($status)';
    String? code;
    try {
      final j = jsonDecode(body);
      if (j is Map) {
        code = (j['code'] ?? j['error_code'] ?? j['error'])?.toString();
        final m = j['message'] ?? j['msg'] ?? j['error_description'];
        if (m != null && '$m'.isNotEmpty) msg = '$m';
      }
    } catch (_) {}
    return KaroError(_hinglish(msg), status: status, code: code);
  }

  static String _hinglish(String m) {
    final l = m.toLowerCase();
    if (l.contains('token has expired') || l.contains('invalid otp') || l.contains('otp_expired')) {
      return 'OTP galat hai ya purana ho gaya — dobara bhejein';
    }
    if (l.contains('rate limit') || l.contains('too many') || l.contains('for security purposes')) {
      return 'Bahut baar koshish — thodi der baad try karein';
    }
    if (l.contains('jwt expired')) return 'Session khatam — dobara login karein';
    if (l.contains('phone') && l.contains('invalid')) return 'Mobile number galat hai';
    return m;
  }
}
