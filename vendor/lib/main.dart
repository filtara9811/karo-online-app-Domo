import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data.dart';
import 'ring.dart';
import 'theme.dart';
import 'screens/login.dart';
import 'screens/home.dart';
import 'screens/incoming.dart';

final navKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark));
  await Store.i.load();
  try {
    await Ring.i.init();
  } catch (e) {
    debugPrint('ring init: $e');
  }
  runApp(const KaroBusiness());
}

class KaroBusiness extends StatefulWidget {
  const KaroBusiness({super.key});
  @override
  State<KaroBusiness> createState() => _KaroBusinessState();
}

class _KaroBusinessState extends State<KaroBusiness> {
  @override
  void initState() {
    super.initState();
    Ring.i.opened.addListener(_openIncoming);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openIncoming());
  }

  void _openIncoming() {
    final id = Ring.i.opened.value;
    if (id == null || !Store.i.loggedIn) return;
    final r = Store.i.byId(id);
    Ring.i.opened.value = null;
    if (r == null) return;
    navKey.currentState?.push(MaterialPageRoute(builder: (_) => IncomingScreen(req: r), fullscreenDialog: true));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Karo Online Business',
      debugShowCheckedModeBanner: false,
      navigatorKey: navKey,
      theme: appTheme(),
      home: ListenableBuilder(
        listenable: Store.i,
        builder: (_, __) => Store.i.loggedIn ? const HomeScreen() : const LoginScreen(),
      ),
    );
  }
}
