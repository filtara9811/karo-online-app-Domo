import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Karo Online — Customer app
/// LIVE: ऐप khulte hi GitHub Pages se taaza version load hota hai — GitHub par
/// docs/ me badlav push hote hi ऐप me dikh jaata hai (APK dobara install nahi karni).
/// Net na ho to ऐप ke andar rakha offline copy (assets/web/index.html) chalta hai.
const kLiveUrl = 'https://filtara9811.github.io/karo-online-app-Domo/';

/// ऐप-के-अंदर update: GitHub Release (latest) me rakhi version.json + APK
const kRel = 'https://github.com/filtara9811/karo-online-app-Domo/releases/latest/download';
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

class _WebHomeState extends State<WebHome> with WidgetsBindingObserver {
  late final WebViewController _c;
  bool _loading = true;
  bool _offline = false;
  DateTime? _lastBack;
  DateTime _pausedAt = DateTime.now();

  // update
  int? _newBuild;
  String _newName = '';
  String _newNotes = '';
  bool _updHidden = false;
  int? _prog; // null = download shuru nahi hua
  String _updMsg = '';

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
    WidgetsBinding.instance.addObserver(this);
    Future.delayed(const Duration(seconds: 3), _checkUpdate);
    final c = WebViewController(onPermissionRequest: _onPermission)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF3ECDD))
      ..addJavaScriptChannel('KaroApp', onMessageReceived: (m) => _openExternal(m.message))
      ..addJavaScriptChannel('KaroFile', onMessageReceived: (m) => _onFile(m.message))
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
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState st) {
    if (st == AppLifecycleState.paused) _pausedAt = DateTime.now();
    if (st == AppLifecycleState.resumed) {
      _checkUpdate();
      // 10 minute se zyada band rahi to screens ka taaza version
      if (DateTime.now().difference(_pausedAt).inMinutes >= 10 && !_offline) {
        _c.loadRequest(Uri.parse('$kLiveUrl?v=${DateTime.now().millisecondsSinceEpoch}'),
            headers: const {'Cache-Control': 'no-cache'});
      }
    }
  }

  Future<void> _checkUpdate() async {
    if (_prog != null) return;
    try {
      final info = await PackageInfo.fromPlatform();
      final cur = int.tryParse(info.buildNumber) ?? 0;
      final r = await http
          .get(Uri.parse('$kRel/version.json?t=${DateTime.now().millisecondsSinceEpoch}'))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return;
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final nb = (j['build'] as num?)?.toInt() ?? 0;
      if (nb > cur && mounted) {
        setState(() {
          _newBuild = nb;
          _newName = '${j['name'] ?? ''}';
          _newNotes = '${j['notes'] ?? ''}';
        });
      }
    } catch (_) {}
  }

  Future<void> _startUpdate() async {
    setState(() {
      _prog = 0;
      _updMsg = 'Download ho raha hai…';
    });
    final client = http.Client();
    try {
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/karo-online-$_newBuild.apk');
      final resp = await client.send(http.Request('GET',
          Uri.parse('$kRel/karo-online.apk?t=${DateTime.now().millisecondsSinceEpoch}')));
      if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
      final total = resp.contentLength ?? 0;
      final sink = f.openWrite();
      var got = 0;
      await for (final chunk in resp.stream) {
        sink.add(chunk);
        got += chunk.length;
        if (total > 0 && mounted) {
          final p = (got * 100 ~/ total).clamp(0, 100).toInt();
          if (p != _prog) setState(() => _prog = p);
        }
      }
      await sink.close();
      if (!mounted) return;
      setState(() {
        _prog = 100;
        _updMsg = 'Install screen par "Update" dabayein';
      });
      final r = await OpenFilex.open(f.path, type: 'application/vnd.android.package-archive');
      if (!mounted) return;
      if (r.type != ResultType.done) {
        setState(() {
          _prog = null;
          _updMsg = r.type == ResultType.permissionDenied
              ? 'Settings me "Install unknown apps" ki anumati dein, phir dobara Update dabayein'
              : 'Install nahi khula — dobara Update dabayein';
        });
      } else {
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) setState(() => _prog = null);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _prog = null;
          _updMsg = 'Update nahi ho paya — net check karke dobara try karein';
        });
      }
    } finally {
      client.close();
    }
  }

  Widget _updateCard() {
    final busy = _prog != null;
    return Positioned(
      left: 12,
      right: 12,
      bottom: 12 + MediaQuery.of(context).padding.bottom,
      child: Material(
        elevation: 12,
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xFF17130F),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
          child: Row(children: [
            busy
                ? SizedBox(
                    width: 38,
                    height: 38,
                    child: Stack(alignment: Alignment.center, children: [
                      CircularProgressIndicator(
                          value: (_prog ?? 0) > 0 ? (_prog! / 100) : null,
                          strokeWidth: 3.5,
                          color: const Color(0xFFF47B20),
                          backgroundColor: Colors.white12),
                      Text('${_prog ?? 0}%',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                    ]))
                : Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(color: const Color(0xFFF47B20), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.system_update_rounded, color: Colors.white, size: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(busy ? 'Update ho raha hai' : 'Naya update aaya hai · $_newName',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 2),
                Text(_updMsg.isNotEmpty ? _updMsg : (_newNotes.isNotEmpty ? _newNotes : 'Naye features aur sudhaar'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFFE9D8AE), fontSize: 11.5)),
              ]),
            ),
            if (!busy) ...[
              TextButton(
                  onPressed: () => setState(() => _updHidden = true),
                  child: const Text('Baad me', style: TextStyle(color: Colors.white54))),
              FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF47B20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: _startUpdate,
                  child: const Text('Update', style: TextStyle(fontWeight: FontWeight.w800))),
            ],
          ]),
        ),
      ),
    );
  }

  /// Web se file (bill photo / PDF / card): share = WhatsApp wagairah, save = gallery me
  Future<void> _onFile(String raw) async {
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final name = ('${j['name'] ?? 'karo-online.png'}').replaceAll(RegExp(r'[^\w.\-]'), '_');
      final bytes = base64Decode('${j['b64'] ?? ''}');
      final text = '${j['text'] ?? ''}';
      final act = '${j['act'] ?? 'share'}';
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/$name');
      await f.writeAsBytes(bytes, flush: true);
      if (act == 'save' && (name.endsWith('.png') || name.endsWith('.jpg'))) {
        try {
          if (!await Gal.hasAccess()) await Gal.requestAccess();
          await Gal.putImage(f.path, album: 'Karo Online');
          _snack('✓ Photo gallery me save ho gayi (Karo Online album)');
          return;
        } catch (_) {
          // gallery nahi mili to share sheet se save karne do
        }
      }
      await Share.shareXFiles([XFile(f.path, mimeType: '${j['mime'] ?? ''}'.isEmpty ? null : '${j['mime']}')],
          text: text.isEmpty ? null : text);
    } catch (_) {
      _snack('File bhej nahi paye — dobara try karein');
    }
  }

  void _snack(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

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
            if (_newBuild != null && !_updHidden && !_loading) _updateCard(),
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
