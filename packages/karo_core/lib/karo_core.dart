/// Karo Online — saanjha core (pure Dart, Flutter ke bina bhi chalta hai).
///
/// ```dart
/// final auth = KaroAuth(KaroConfig.fromEnvironment(), store);
/// await auth.load();
/// await auth.sendOtp('9876543210');
/// await auth.verifyOtp('9876543210', '123456');
/// final api = KaroApi(auth);
/// final me = await api.rpc('ko_me');
/// ```
library;

export 'src/config.dart';
export 'src/errors.dart';
export 'src/phone.dart';
export 'src/session.dart';
export 'src/auth.dart';
export 'src/api.dart';
