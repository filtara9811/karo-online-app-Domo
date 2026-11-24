import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme.dart';

/// Marketplace wali apni dukaan — bottom sheet me, Normal / Edit mode
const kShopUrl = 'https://filtara9811.github.io/karo-online-app-Domo/';

Future<void> openShopEditor(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ShopEditor(),
  );
}

class _ShopEditor extends StatefulWidget {
  const _ShopEditor();
  @override
  State<_ShopEditor> createState() => _ShopEditorState();
}

class _ShopEditorState extends State<_ShopEditor> {
  late final WebViewController _c;
  bool edit = true;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFDFAF3))
      ..setNavigationDelegate(NavigationDelegate(onPageFinished: (_) {
        if (mounted) setState(() => loading = false);
      }))
      ..loadRequest(Uri.parse('$kShopUrl?shop=my&mode=edit&vendor=1'));
  }

  void _mode(bool e) {
    setState(() => edit = e);
    _c.runJavaScript("window.koShopMode&&koShopMode('${e ? 'edit' : 'view'}')");
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height * .92;
    return Container(
      height: h,
      decoration: const BoxDecoration(color: Color(0xFFFDFAF3), borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        const SizedBox(height: 8),
        Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(9))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
          child: Row(children: [
            Expanded(child: Text('Meri dukaan', style: tx(18, w: FontWeight.w800))),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(color: const Color(0xFFF1E9D8), borderRadius: BorderRadius.circular(99)),
              child: Row(children: [
                for (final e in [false, true])
                  GestureDetector(
                    onTap: () => _mode(e),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(color: edit == e ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(99)),
                      child: Text(e ? '✏️ Edit' : '👁 Normal', style: tx(12.5, w: FontWeight.w800, c: edit == e ? K.ink : K.muted)),
                    ),
                  ),
              ]),
            ),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
          ]),
        ),
        Expanded(
          child: Stack(children: [
            WebViewWidget(controller: _c),
            if (loading) const Center(child: CircularProgressIndicator(color: K.acc)),
          ]),
        ),
      ]),
    );
  }
}
