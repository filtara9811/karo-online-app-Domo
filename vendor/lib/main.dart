import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api.dart';
import 'catalog.dart';
import 'data.dart';
import 'ring.dart';
import 'theme.dart';
import 'screens/login.dart';
import 'screens/join.dart';
import 'screens/home.dart';
import 'screens/incoming.dart';

final navKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark));
  await Catalog.load();
  await Api.init();
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

  /// Ghanti wali notification par tap → wahi request poori screen par
  Future<void> _openIncoming() async {
    final id = Ring.i.opened.value;
    if (id == null || !Store.i.joined) return;
    Ring.i.opened.value = null;
    await Store.i.refresh();
    final r = Store.i.byId(id);
    if (r == null) return; // pehle hi le li / band ho gayi
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
        builder: (_, __) {
          final s = Store.i;
          final Widget w = !s.loggedIn ? const LoginScreen() : (!s.joined ? const JoinScreen() : const HomeScreen());
          return AnimatedSwitcher(duration: const Duration(milliseconds: 350), child: KeyedSubtree(key: ValueKey(w.runtimeType), child: w));
        },
      ),
    );
  }
}
