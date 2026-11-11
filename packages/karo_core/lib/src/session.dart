import 'dart:convert';

/// Login session (Supabase Auth). [expiresAt] = seconds since epoch.
class Session {
  final String accessToken;
  final String refreshToken;
  final int expiresAt;
  final String userId;
  final String phone; // 10 ank

  const Session({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.userId,
    required this.phone,
  });

  /// GoTrue ka jawab (verify / refresh) → Session
  factory Session.fromAuthResponse(Map<String, dynamic> j, {required int nowSec}) {
    final user = (j['user'] as Map?) ?? const {};
    final p = '${user['phone'] ?? ''}'.replaceAll(RegExp(r'\D'), '');
    final exp = (j['expires_at'] as num?)?.toInt() ?? (nowSec + ((j['expires_in'] as num?)?.toInt() ?? 3600));
    return Session(
      accessToken: '${j['access_token']}',
      refreshToken: '${j['refresh_token']}',
      expiresAt: exp,
      userId: '${user['id'] ?? ''}',
      phone: p.length >= 10 ? p.substring(p.length - 10) : p,
    );
  }

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'expires_at': expiresAt,
        'user_id': userId,
        'phone': phone,
      };

  factory Session.fromJson(Map<String, dynamic> j) => Session(
        accessToken: '${j['access_token']}',
        refreshToken: '${j['refresh_token']}',
        expiresAt: (j['expires_at'] as num).toInt(),
        userId: '${j['user_id'] ?? ''}',
        phone: '${j['phone'] ?? ''}',
      );

  String encode() => jsonEncode(toJson());

  static Session? decode(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return Session.fromJson(Map<String, dynamic>.from(jsonDecode(s) as Map));
    } catch (_) {
      return null;
    }
  }
}

/// Session kahan rakhein — Flutter me SharedPreferences / secure storage.
/// Background isolate bhi isi se padhta hai, isliye [read] har baar taaza padhe.
abstract class SessionStore {
  Future<String?> read();
  Future<void> write(String? value);
}

class MemorySessionStore implements SessionStore {
  String? value;
  MemorySessionStore([this.value]);
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? v) async => value = v;
}
