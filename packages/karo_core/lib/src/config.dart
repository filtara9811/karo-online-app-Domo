/// Backend kahan hai. Build ke waqt badal sakte hain:
///   flutter build apk --dart-define=KARO_SUPABASE_URL=https://xxx.supabase.co --dart-define=KARO_SUPABASE_KEY=...
/// (KEY = Supabase ki publishable / anon key — public hoti hai, secret nahi.
///  Asli suraksha server ke RLS + RPC me hai, key chhupane me nahi.)
class KaroConfig {
  final String url;
  final String anonKey;

  const KaroConfig({required this.url, required this.anonKey});

  /// Default: abhi wala project. Naya project banne par yahin (ya --dart-define se) badlein.
  static const defaultUrl = 'https://goyvhgpfxjpxkytpeigr.supabase.co';
  static const defaultKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdveXZoZ3BmeGpweGt5dHBlaWdyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI2MDU4NzMsImV4cCI6MjEwODE4MTg3M30.5IYnhNkUtzjr8IvPoKezo-qnU1cLbXLbND9Kh6wOcmg';

  factory KaroConfig.fromEnvironment() {
    const u = String.fromEnvironment('KARO_SUPABASE_URL');
    const k = String.fromEnvironment('KARO_SUPABASE_KEY');
    return KaroConfig(url: u.isEmpty ? defaultUrl : u, anonKey: k.isEmpty ? defaultKey : k);
  }

  Uri auth(String path, [Map<String, String>? q]) => Uri.parse('$url/auth/v1/$path').replace(queryParameters: q);
  Uri rpc(String fn) => Uri.parse('$url/rest/v1/rpc/$fn');
}
