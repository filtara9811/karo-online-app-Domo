import 'package:karo_core/karo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'package:karo_core/karo_core.dart' show KaroError;

/// Karo Online backend — saanjha `karo_core` package ke upar patli parat.
/// Login (OTP) ke baad server har call me token se dukaan pehchanta hai —
/// ऐप kabhi vendor id nahi bhejti, isliye koi doosre ki dukaan nahi chala sakta.
///
/// Main ऐप aur background ghanti service (alag isolate) dono [init] karte hain;
/// session SharedPreferences me hai taaki dono ek hi login use karein.
class Api {
  static KaroAuth? _auth;
  static KaroApi? _api;

  static KaroAuth get auth => _auth!;

  static Future<void> init() async {
    if (_auth != null) return;
    final a = KaroAuth(KaroConfig.fromEnvironment(), _PrefsSessionStore());
    await a.load();
    _auth = a;
    _api = KaroApi(a);
  }

  static Future<dynamic> rpc(String fn, [Map<String, dynamic> params = const {}]) => _api!.rpc(fn, params);
}

class _PrefsSessionStore implements SessionStore {
  static const _k = 'karo_session';

  @override
  Future<String?> read() async {
    final p = await SharedPreferences.getInstance();
    await p.reload(); // doosre isolate ka likha bhi dikhe
    return p.getString(_k);
  }

  @override
  Future<void> write(String? value) async {
    final p = await SharedPreferences.getInstance();
    if (value == null) {
      await p.remove(_k);
    } else {
      await p.setString(_k, value);
    }
  }
}
