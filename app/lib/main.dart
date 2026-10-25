import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Karo Online — Customer app
/// LIVE: ऐप khulte hi GitHub Pages se taaza version load hota hai — GitHub par
/// docs/ me badlav push hote hi ऐप me dikh jaata hai (APK dobara install nahi karni).
/// Net na ho to ऐप ke andar rakha offline copy (assets/web/index.html) chalta hai.
const kLiveUrl = 'https://filtara9811.github.io/karo-online-app-Domo/';
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const KaroApp());
}

class KaroApp extends StatelessWidget {
  const KaroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Karo Online',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFFF47B20)),
      home: const WebHome(),
    );
  }
}

class WebHome extends StatefulWidget {
  const WebHome({super.key});

  @override
  State<WebHome> createState() => _WebHomeState();
}

class _WebHomeState extends State<WebHome> {
  late final WebViewController _c;
  bool _loading = true;
  bool _offline = false;
  DateTime? _lastBack;

  // Prototype ke andar ye script daalte hain: window.open, WhatsApp, call, mail
  // jaise links ko phone ke apps me kholne ke liye.
  static const _bridge = r'''
(function(){
  if(window.__karoBridge) return; window.__karoBridge=1;
  var ext=function(u){ try{ KaroApp.postMessage(String(u)); }catch(e){} };
  window.open=function(u){ if(u) ext(u); return null; };
  document.addEventListener('click',function(e){
    var a=e.target.closest&&e.target.closest('a[href]'); if(!a) return;
    var h=a.getAttribute('href')||'';
    if(/^(https?:|tel:|mailto:|whatsapp:|upi:|intent:|sms:)/i.test(h)){ e.preventDefault(); ext(a.href); }
  },true);
})();
''';

  @override
  void initState() {
    super.initState();
    final c = WebViewController(onPermissionRequest: _onPermission)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF3ECDD))
      ..addJavaScriptChannel('KaroApp', onMessageReceived: (m) => _openExternal(m.message))
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) async {
          await _c.runJavaScript(_bridge);
          if (mounted) setState(() => _loading = false);
        },
        onWebResourceError: (err) {
          // live page na mile (net nahi / Pages band) to offline copy
          if ((err.isForMainFrame ?? false) && !_offline) {
            _offline = true;
            _c.loadFlutterAsset('assets/web/index.html');
          }
        },
        onHttpError: (err) {
          final code = err.response?.statusCode ?? 0;
          final url = err.request?.uri.toString() ?? '';
          if (code >= 400 && url.startsWith(kLiveUrl) && url.split('?').first == kLiveUrl && !_offline) {
            _offline = true;
            _c.loadFlutterAsset('assets/web/index.html');
          }
        },
        onNavigationRequest: (req) {
          final u = req.url;
          if (u.startsWith(kLiveUrl)) return NavigationDecision.navigate;
          if (u.startsWith('file:') || u.startsWith('about:') || u.startsWith('data:') || u.startsWith('blob:')) {
            return NavigationDecision.navigate;
          }
          if (req.isMainFrame) {
            _openExternal(u);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ));

    final p = c.platform;
    if (p is AndroidWebViewController) {
      // video bina tap ke chale (login, support, referral videos)
      p.setMediaPlaybackRequiresUserGesture(false);
      // photo upload (KYC, product photo) ke liye gallery / camera
      p.setOnShowFileSelector(_pickFiles);
    }
    _c = c;
    // har baar taaza version (cache se purana na aaye)
    c.loadRequest(Uri.parse('$kLiveUrl?v=${DateTime.now().millisecondsSinceEpoch}'),
        headers: const {'Cache-Control': 'no-cache'});
  }

  // QR scanner (camera) aur voice search (mic) ke liye phone se permission maang kar WebView ko dena
  Future<void> _onPermission(WebViewPermissionRequest req) async {
    var ok = true;
    if (req.types.contains(WebViewPermissionResourceType.camera)) {
      ok = (await Permission.camera.request()).isGranted && ok;
    }
    if (req.types.contains(WebViewPermissionResourceType.microphone)) {
      ok = (await Permission.microphone.request()).isGranted && ok;
    }
    if (ok) {
      await req.grant();
    } else {
      await req.deny();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Camera / mic ki permission chahiye — Settings › Apps › Karo Online › Permissions')));
      }
    }
  }

  Future<List<String>> _pickFiles(FileSelectorParams params) async {
    final picker = ImagePicker();
    try {
      final cam = params.isCaptureEnabled;
      final x = await picker.pickImage(
          source: cam ? ImageSource.camera : ImageSource.gallery, imageQuality: 80, maxWidth: 1600);
      if (x == null) return [];
      return [Uri.file(x.path).toString()];
    } catch (_) {
      return [];
    }
  }

  Future<void> _openExternal(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ye link khul nahi paya')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBack != null && now.difference(_lastBack!) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
          return;
        }
        _lastBack = now;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Band karne ke liye dobara back dabayein'), duration: Duration(seconds: 2)),
        );
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF3ECDD),
        body: SafeArea(
          top: false,
          bottom: false,
          child: Stack(children: [
            WebViewWidget(controller: _c),
            if (_loading)
              Container(
                color: const Color(0xFFF47B20),
                alignment: Alignment.center,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset('assets/logo.png', width: 120, height: 120),
                  ),
                  const SizedBox(height: 18),
                  const Text('Karo Online',
                      style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 18),
                  const SizedBox(
                      width: 26, height: 26, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)),
                ]),
              ),
          ]),
        ),
      ),
    );
  }
}
