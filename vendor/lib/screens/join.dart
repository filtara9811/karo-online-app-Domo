import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../catalog.dart';
import '../data.dart';
import '../theme.dart';

/// "Join as a seller" — prototype jaisa: guide video, 1 → 2 → ✓,
/// Step 1: kya dete hain (type + category + sub-service mapping), Step 2: dukaan details, Shop rent, Success
class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});
  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  int step = 0;
  String ty = 'svc';
  // "ty|Category" -> chuni sub-services
  final Map<String, List<String>> sel = {};
  // sub -> chune items
  final Map<String, List<String>> items = {};
  final _name = TextEditingController();
  final _owner = TextEditingController();
  final _phone = TextEditingController(text: Store.i.phone);
  final _area = TextEditingController(text: 'Bara Hindu Rao, Delhi');
  String rad = '5';
  String? role;
  String? biz;
  File? photo;
  String? plan;
  Map<String, dynamic>? saved;
  bool saving = false;

  int get selCount => sel.values.fold(0, (a, b) => a + b.length);
  int typeCount(String t) => sel.entries.where((e) => e.key.startsWith('$t|') && e.value.isNotEmpty).length;
  CType get T => Catalog.types[ty]!;

  void _snack(String m) => toast(context, m);

  // ---------------- navigation ----------------
  void _next() {
    if (step == 0) {
      if (selCount == 0) {
        _snack('⚠️ Pehle category chuniye — aap kis cheez me deal karte hain');
        return;
      }
      setState(() => step = 1);
      return;
    }
    if (step == 1) {
      if (_name.text.trim().length < 2) {
        _snack('⚠️ Shop / Business name likhein');
        return;
      }
      if (!RegExp(r'^[6-9]\d{9}$').hasMatch(_phone.text.trim())) {
        _snack('⚠️ 10 ank ka mobile number');
        return;
      }
      if (role == null) {
        _snack('"${Catalog.roleTitle(ty)}" chuniye');
        _rolePopup();
        return;
      }
      _rent();
    }
  }

  void _back() {
    if (step > 0) setState(() => step--);
  }

  // ---------------- popups ----------------
  Future<void> _rolePopup() async {
    final opts = Catalog.roleOpts(ty);
    final v = await showDialog<String>(
      context: context,
      barrierColor: Colors.black54,
      builder: (c) => _OptDialog(title: '🏷️ ${Catalog.roleTitle(ty)}', sub: Catalog.roleSub(ty), opts: opts, cur: role),
    );
    if (v != null) {
      setState(() => role = v);
      _snack('✓ ${Catalog.opt(opts, v)![2]}');
    }
  }

  Future<void> _radPopup() async {
    final v = await showDialog<String>(
      context: context,
      barrierColor: Colors.black54,
      builder: (c) => _OptDialog(title: '📍 Kitni doori tak kaam?', sub: 'Itni doori ke customers ki request aapko aayegi', opts: Catalog.rad, cur: rad),
    );
    if (v != null) setState(() => rad = v);
  }

  Future<void> _photo() async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: K.cream,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          ListTile(leading: const Text('📷', style: TextStyle(fontSize: 24)), title: Text('Camera se photo', style: tx(15, w: FontWeight.w700)), onTap: () => Navigator.pop(c, ImageSource.camera)),
          ListTile(leading: const Text('🖼️', style: TextStyle(fontSize: 24)), title: Text('Gallery se chunein', style: tx(15, w: FontWeight.w700)), onTap: () => Navigator.pop(c, ImageSource.gallery)),
          const SizedBox(height: 10),
        ]),
      ),
    );
    if (src == null) return;
    try {
      final x = await ImagePicker().pickImage(source: src, maxWidth: 1400, imageQuality: 80);
      if (x != null) setState(() => photo = File(x.path));
    } catch (e) {
      _snack('Photo nahi le paye: $e');
    }
  }

  Future<void> _openCat(Cat c) async {
    final key = '$ty|${c.n}';
    final res = await showModalBottomSheet<_PickResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SubPicker(cat: c, typeLabel: T.l, active: List.of(sel[key] ?? const []), items: {for (final e in items.entries) e.key: List.of(e.value)}),
    );
    if (res == null) return;
    setState(() {
      if (res.active.isEmpty) {
        sel.remove(key);
      } else {
        sel[key] = res.active;
      }
      items.addAll(res.items);
    });
  }

  Future<void> _rent() async {
    final p = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (_) => const _RentSheet(),
    );
    if (p == null) return;
    plan = p;
    setState(() => saving = true);
    try {
      final until = DateTime.now().add(Duration(days: p == 'trial' ? 7 : 30));
      final cats = <String>[];
      final subs = <String>[];
      sel.forEach((k, v) {
        if (v.isEmpty) return;
        cats.add(k.split('|')[1]);
        subs.addAll(v);
      });
      saved = await Store.i.saveVendor({
        'phone': _phone.text.trim(),
        'shop_name': _name.text.trim(),
        'owner_name': _owner.text.trim(),
        'area': _area.text.trim(),
        'ty': ty,
        'role': role,
        'biz': biz,
        'radius': rad,
        'cats': cats,
        'subs': subs,
        'items': {for (final s in subs) s: items[s] ?? []},
        'plan': p,
        'rent_until': '${until.year}-${until.month.toString().padLeft(2, '0')}-${until.day.toString().padLeft(2, '0')}',
      });
      if (!mounted) return;
      setState(() {
        saving = false;
        step = 2;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      _snack('⚠️ Save nahi hua: $e');
    }
  }

  // ---------------- UI ----------------
  static const _caps = ['Step 1 — प्रोडक्ट या सर्विस चुनें, फिर अपनी कैटेगरी', 'Step 2 — दुकान का नाम, मालिक, मोबाइल, एरिया और फोटो', 'हो गया! आपकी दुकान तैयार'];
  static const _scene = ['🧩', '🏪', '✅'];

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return PopScope(
      canPop: step == 0,
      onPopInvokedWithResult: (did, _) {
        if (!did) _back();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF6B6B5E),
        body: Column(children: [
          SizedBox(height: mq.padding.top + 18),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(color: K.cream, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
              child: Column(children: [
                const SizedBox(height: 10),
                Container(width: 44, height: 5, decoration: BoxDecoration(color: const Color(0xFFD9D2C3), borderRadius: BorderRadius.circular(3))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 14, 10),
                  child: Row(children: [
                    Expanded(child: Text('Join as a seller', style: sf(26))),
                    _circleBtn(Icons.close_rounded, () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                          title: Text('Logout karein?', style: tx(17, w: FontWeight.w800)),
                          content: Text('Dukaan abhi bani nahi hai. Dusre number se login karna ho to logout karein.', style: tx(13.5, w: FontWeight.w500)),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Nahi', style: tx(14, w: FontWeight.w800, c: K.sub))),
                            TextButton(onPressed: () => Navigator.pop(c, true), child: Text('Logout', style: tx(14, w: FontWeight.w800, c: K.orD))),
                          ],
                        ),
                      );
                      if (ok == true) Store.i.logout();
                    }),
                  ]),
                ),
                _GuideVideo(caption: _caps[step], scene: _scene[step], compact: step == 1),
                Padding(padding: const EdgeInsets.fromLTRB(22, 10, 22, 6), child: _StepDots(step: step)),
                Expanded(
                  child: Stack(children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 380),
                      switchInCurve: Curves.easeOutCubic,
                      transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(.15, 0), end: Offset.zero).animate(a), child: c)),
                      child: KeyedSubtree(key: ValueKey('$step-$ty'), child: [_step1, _step2, _step3][step]()),
                    ),
                    if (step == 0)
                      Positioned(
                        right: 14,
                        bottom: 12,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          _pill('🧩', 'AI se dukaan', const Color(0xFF2A2117), Colors.white, () => _snack('🧩 AI se dukaan — jald aa raha hai')),
                          const SizedBox(height: 8),
                          _pill('✨', 'Photo se auto-fill', null, K.txt, () => _snack('✨ Photo se auto-fill — jald aa raha hai')),
                        ]),
                      ),
                    if (saving)
                      Positioned.fill(
                        child: Container(
                          color: K.cream.withValues(alpha: .85),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const CircularProgressIndicator(color: K.orD),
                            const SizedBox(height: 12),
                            Text('Dukaan save ho rahi hai…', style: tx(14, w: FontWeight.w700, c: K.sub)),
                          ]),
                        ),
                      ),
                  ]),
                ),
                _footer(mq),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _footer(MediaQueryData mq) {
    final pad = EdgeInsets.fromLTRB(16, 10, 16, 12 + mq.padding.bottom);
    if (step == 2) {
      return Container(
        padding: pad,
        decoration: const BoxDecoration(color: K.cream, border: Border(top: BorderSide(color: Color(0xFFEFE7D6)))),
        child: _OrangeBtn(
          height: 52,
          onTap: () {
            if (saved != null) Store.i.applyVendor(saved!);
          },
          child: Text('Done', style: tx(17, w: FontWeight.w800, c: Colors.white)),
        ),
      );
    }
    if (step == 0) {
      return AnimatedSize(
        duration: const Duration(milliseconds: 260),
        child: selCount == 0
            ? const SizedBox(width: double.infinity)
            : Container(
                padding: pad,
                decoration: const BoxDecoration(color: K.cream, border: Border(top: BorderSide(color: Color(0xFFEFE7D6)))),
                child: _OrangeBtn(
                  height: 56,
                  onTap: _next,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('Next →', style: tx(17, w: FontWeight.w800, c: Colors.white)),
                    Text('Shop details', style: tx(11, w: FontWeight.w700, c: Colors.white.withValues(alpha: .85))),
                  ]),
                ),
              ),
      );
    }
    return Container(
      padding: pad,
      decoration: const BoxDecoration(color: K.cream, border: Border(top: BorderSide(color: Color(0xFFEFE7D6)))),
      child: Row(children: [
        GestureDetector(
          onTap: _back,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF1D7B8), width: 1.5)),
            child: const Icon(Icons.chevron_left_rounded, color: K.txt, size: 30),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _OrangeBtn(
            height: 58,
            onTap: _next,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('🏪 Shop rent shuru karein', style: tx(16.5, w: FontWeight.w800, c: Colors.white)),
              Text('₹1 me 1 hafta · ya ₹100 me aaj LIVE', style: tx(11, w: FontWeight.w700, c: Colors.white.withValues(alpha: .9))),
            ]),
          ),
        ),
      ]),
    );
  }

  // ---------- Step 1 ----------
  Widget _step1() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        Text('AAP KYA DETE HAIN?', style: tx(11.5, w: FontWeight.w800, c: K.sub).copyWith(letterSpacing: 1)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: K.sand, borderRadius: BorderRadius.circular(99)),
          child: Row(children: [
            for (final k in ['svc', 'prd', 'oth'])
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    ty = k;
                    role = null;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: ty == k ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(99),
                      boxShadow: ty == k ? K.shadow(.08) : null,
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(Catalog.types[k]!.e, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 5),
                      Text(Catalog.types[k]!.l, style: tx(14, w: FontWeight.w800, c: ty == k ? K.orD : const Color(0xFF8A7A5A))),
                      if (typeCount(k) > 0) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: K.orD, borderRadius: BorderRadius.circular(99)),
                          child: Text('${typeCount(k)}', style: tx(10.5, w: FontWeight.w800, c: Colors.white)),
                        ),
                      ],
                    ]),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 8),
        Text('${T.h} — category par tap karke chuniye', style: tx(12.5, w: FontWeight.w500, c: const Color(0xFF6E6656))),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.1,
          children: [for (final c in T.cats) _catTile(c)],
        ),
        if (selCount > 0) ...[
          const SizedBox(height: 16),
          Text('AAPNE CHUNA', style: tx(11.5, w: FontWeight.w800, c: K.sub).copyWith(letterSpacing: 1)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in sel.entries)
              if (e.value.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    final p = e.key.split('|');
                    setState(() => ty = p[0]);
                    _openCat(Catalog.types[p[0]]!.cats.firstWhere((c) => c.n == p[1]));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFFFFF1E2), borderRadius: BorderRadius.circular(99), border: Border.all(color: const Color(0xFFF7C99A))),
                    child: Text(
                      '${Catalog.types[e.key.split('|')[0]]!.cats.firstWhere((c) => c.n == e.key.split('|')[1]).e} ${e.key.split('|')[1]} · ${e.value.length}',
                      style: tx(12.5, w: FontWeight.w800, c: K.orD),
                    ),
                  ),
                ),
          ]),
        ],
      ],
    );
  }

  Widget _catTile(Cat c) {
    final n = (sel['$ty|${c.n}'] ?? const []).length;
    return GestureDetector(
      onTap: () => _openCat(c),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 200),
        scale: n > 0 ? 1.03 : 1,
        child: Stack(clipBehavior: Clip.none, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: n > 0 ? const Color(0xFFFFF1E2) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: n > 0 ? K.or : K.tile, width: 2),
            ),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(c.e, style: const TextStyle(fontSize: 26)),
                const SizedBox(height: 4),
                Text(c.n, style: tx(12.5, w: FontWeight.w800, c: n > 0 ? K.orD : K.txt), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(n > 0 ? '$n chuni' : '${c.subs.length} options', style: tx(10.5, w: FontWeight.w600, c: n > 0 ? K.orD : const Color(0xFF9A907C))),
              ]),
            ),
          ),
          if (n > 0)
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: K.orD, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                child: Text('$n', style: tx(10.5, w: FontWeight.w800, c: Colors.white)),
              ),
            ),
        ]),
      ),
    );
  }

  // ---------- Step 2 ----------
  Widget _step2() {
    final ro = Catalog.opt(Catalog.roleOpts(ty), role);
    final ra = Catalog.opt(Catalog.rad, rad);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text('Shop details', style: sf(22)),
        const SizedBox(height: 10),
        _field(_name, 'Shop / Business name'),
        _field(_owner, 'Owner name'),
        _field(_phone, 'Mobile number', phone: true),
        const SizedBox(height: 8),
        Text('Service area', style: sf(22)),
        const SizedBox(height: 10),
        Stack(alignment: Alignment.centerRight, children: [
          _field(_area, 'Area / market ka naam', bold: true, pr: 64),
          Positioned(
            right: 8,
            top: 7,
            child: GestureDetector(
              onTap: _radPopup,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(gradient: K.orGrad, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.location_on_outlined, color: Colors.white),
              ),
            ),
          ),
        ]),
        GestureDetector(
          onTap: _radPopup,
          child: Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text('${ra?[1] ?? '📍'} ${ra?[2] ?? '$rad km'} tak ke customers · badlein ›', style: tx(12, w: FontWeight.w700, c: K.orD)),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFEFE7D6))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Business details', style: tx(15, w: FontWeight.w800, c: K.txt)),
              const Spacer(),
              Text('Profile par badge dikhega', style: tx(11, w: FontWeight.w600, c: K.sub)),
            ]),
            const SizedBox(height: 10),
            Text(ty == 'svc' ? 'SERVICE KAISE DETE HAIN' : 'AAP KAUN HAIN', style: tx(11, w: FontWeight.w800, c: K.sub).copyWith(letterSpacing: 1)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _rolePopup,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ro == null ? Colors.white : const Color(0xFFEFFAF3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ro == null ? const Color(0xFFEFE7D6) : K.mintB),
                ),
                child: Row(children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: const Color(0xFFFFF4E4), borderRadius: BorderRadius.circular(12)),
                    child: Text(ro?[1] ?? '🏷️', style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(ro?[2] ?? Catalog.roleTitle(ty), style: tx(14, w: FontWeight.w800, c: K.txt)),
                      Text(ro?[3] ?? Catalog.roleOpts(ty).take(3).map((o) => o[2]).join(' / '), style: tx(11.5, w: FontWeight.w500, c: K.sub), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                  Text(ro == null ? 'Chunein ›' : 'Badlein ›', style: tx(12.5, w: FontWeight.w800, c: K.orD)),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Text('REGISTRATION', style: tx(11, w: FontWeight.w800, c: K.sub).copyWith(letterSpacing: 1)),
              const Spacer(),
              Text('optional', style: tx(11, w: FontWeight.w600, c: K.sub)),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final o in Catalog.biz.where((o) => o[0] != 'pub'))
                GestureDetector(
                  onTap: () => setState(() => biz = biz == o[0] ? null : o[0]),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: biz == o[0] ? const Color(0xFFFFF1E2) : Colors.white,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: biz == o[0] ? K.or : const Color(0xFFEFE7D6), width: 1.5),
                    ),
                    child: Text('${o[1]} ${_bizLabel(o)}', style: tx(12.5, w: FontWeight.w700, c: biz == o[0] ? K.orD : K.txt)),
                  ),
                ),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _photo,
          child: Container(
            height: photo == null ? 52 : 150,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5D9C2), width: 1.5),
              image: photo == null ? null : DecorationImage(image: FileImage(photo!), fit: BoxFit.cover),
            ),
            alignment: Alignment.center,
            child: photo == null
                ? Text('📷 Shop photo जोड़ें', style: tx(14, w: FontWeight.w600, c: const Color(0xFF8A8070)))
                : Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(99)),
                      child: Text('📷 Badlein', style: tx(12, w: FontWeight.w700, c: Colors.white)),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  String _bizLabel(Opt o) {
    switch (o[0]) {
      case 'shop':
        return 'Unregistered';
      case 'prop':
        return 'Proprietor (GST)';
      case 'pvt':
        return 'Pvt Ltd';
    }
    return o[2];
  }

  Widget _field(TextEditingController c, String hint, {bool phone = false, bool bold = false, double pr = 14}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType: phone ? TextInputType.phone : TextInputType.text,
        maxLength: phone ? 10 : null,
        textCapitalization: phone ? TextCapitalization.none : TextCapitalization.words,
        inputFormatters: phone ? [FilteringTextInputFormatter.digitsOnly] : null,
        style: tx(15.5, w: bold ? FontWeight.w800 : FontWeight.w600, c: K.txt),
        decoration: InputDecoration(
          counterText: '',
          hintText: hint,
          hintStyle: tx(15, w: FontWeight.w500, c: const Color(0xFFA79E8C)),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.fromLTRB(14, 17, pr, 17),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFECE4D2), width: 1.5)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: K.or, width: 1.8)),
        ),
      ),
    );
  }

  // ---------- Step 3 (success) ----------
  Widget _step3() {
    final ro = Catalog.opt(Catalog.roleOpts(ty), role);
    final until = DateTime.now().add(Duration(days: plan == 'trial' ? 7 : 30));
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final d = '${until.day} ${m[until.month - 1]}';
    return ListView(padding: const EdgeInsets.fromLTRB(20, 28, 20, 20), children: [
      Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.elasticOut,
          builder: (_, v, __) => Transform.scale(
            scale: v,
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(color: const Color(0xFF22A45D), shape: BoxShape.circle, boxShadow: [BoxShadow(color: const Color(0xFF22A45D).withValues(alpha: .35), blurRadius: 24)]),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 54),
            ),
          ),
        ),
      ),
      const SizedBox(height: 18),
      Text('Application submitted!', textAlign: TextAlign.center, style: sf(26)),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFFFF1E2), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF7C99A))),
        child: Column(children: [
          Text(plan == 'trial' ? '🎁 1 hafta trial (₹1) chalu' : '✅ Shop rent ₹100 bhara — aaj LIVE', style: tx(15, w: FontWeight.w800, c: const Color(0xFFC2540A))),
          const SizedBox(height: 3),
          Text('$d tak${plan == 'trial' ? ' free' : ''} · phir Shop rent ₹199/mahina', style: tx(12.5, w: FontWeight.w700, c: const Color(0xFF8A6A3A))),
        ]),
      ),
      const SizedBox(height: 14),
      Text('आपकी दुकान की जाँच 24 घंटे में हो जाएगी।\nVerification के बाद आप Nearby shops में दिखेंगे।', textAlign: TextAlign.center, style: tx(14, w: FontWeight.w500, c: const Color(0xFF7A7368), h: 1.5)),
      const SizedBox(height: 14),
      Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
        if (ro != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(color: const Color(0xFF1F9D57), borderRadius: BorderRadius.circular(99)),
            child: Text(ro[2].toUpperCase(), style: tx(11, w: FontWeight.w800, c: Colors.white).copyWith(letterSpacing: .5)),
          ),
        for (final e in sel.entries)
          if (e.value.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: const Color(0xFFFFF4E4), borderRadius: BorderRadius.circular(99)),
              child: Text(
                '${Catalog.types[e.key.split('|')[0]]!.cats.firstWhere((c) => c.n == e.key.split('|')[1]).e} ${e.key.split('|')[1]} · ${e.value.length}',
                style: tx(12, w: FontWeight.w800, c: const Color(0xFF8A5A1A)),
              ),
            ),
      ]),
      const SizedBox(height: 18),
      Center(child: Text('📱 ${_phone.text}  ·  🏪 ${_name.text}', style: tx(12.5, w: FontWeight.w700, c: K.sub))),
    ]);
  }

  Widget _circleBtn(IconData i, VoidCallback f) => GestureDetector(
        onTap: f,
        child: Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(color: Color(0xFFF1ECE2), shape: BoxShape.circle),
          child: Icon(i, size: 20, color: K.txt),
        ),
      );

  Widget _pill(String e, String t, Color? bg, Color fg, VoidCallback f) => GestureDetector(
        onTap: f,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: bg,
            gradient: bg == null ? const LinearGradient(colors: [Color(0xFFFFC46B), Color(0xFFFFA23B)]) : null,
            borderRadius: BorderRadius.circular(99),
            boxShadow: K.shadow(.2),
          ),
          child: Text('$e $t', style: tx(12.5, w: FontWeight.w800, c: fg)),
        ),
      );
}

// ======================= Guide video tile =======================
class _GuideVideo extends StatefulWidget {
  final String caption, scene;
  final bool compact;
  const _GuideVideo({required this.caption, required this.scene, required this.compact});
  @override
  State<_GuideVideo> createState() => _GuideVideoState();
}

class _GuideVideoState extends State<_GuideVideo> with TickerProviderStateMixin {
  late final AnimationController _p = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
  late final AnimationController _b = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
  bool paused = false;

  @override
  void dispose() {
    _p.dispose();
    _b.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.compact ? 62.0 : 150.0;
    return GestureDetector(
      onTap: () => setState(() {
        paused = !paused;
        paused ? _p.stop() : _p.repeat();
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        height: h,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF8E9A2E), Color(0xFFD9A030), Color(0xFFF29B38)]),
        ),
        child: Stack(children: [
          if (!widget.compact)
            Positioned(
              left: 0,
              right: 0,
              top: 18,
              child: AnimatedBuilder(
                animation: _b,
                builder: (_, c) => Transform.translate(offset: Offset(0, -6 * _b.value), child: c),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                  child: Text(widget.scene, key: ValueKey(widget.scene), textAlign: TextAlign.center, style: const TextStyle(fontSize: 60)),
                ),
              ),
            ),
          Positioned(
            left: 10,
            top: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: .55), borderRadius: BorderRadius.circular(10)),
              child: Text('● Guide video', style: tx(10.5, w: FontWeight.w700, c: Colors.white)),
            ),
          ),
          Positioned(
            right: 10,
            top: 8,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: .55), shape: BoxShape.circle),
              child: Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 18, color: Colors.white),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withValues(alpha: .3), Colors.transparent])),
              child: Text(widget.caption, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx(widget.compact ? 12 : 14, w: FontWeight.w700, c: Colors.white).copyWith(shadows: const [Shadow(blurRadius: 6, color: Colors.black54)])),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedBuilder(
              animation: _p,
              builder: (_, __) => LinearProgressIndicator(value: _p.value, minHeight: 4, backgroundColor: Colors.white.withValues(alpha: .35), color: Colors.white),
            ),
          ),
        ]),
      ),
    );
  }
}

// ======================= 1 — 2 — ✓ =======================
class _StepDots extends StatelessWidget {
  final int step;
  const _StepDots({required this.step});
  @override
  Widget build(BuildContext context) {
    Widget dot(int i) {
      final on = i <= step;
      return AnimatedScale(
        duration: const Duration(milliseconds: 400),
        scale: on ? 1.1 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: on ? K.or : const Color(0xFFEADFC6), shape: BoxShape.circle),
          child: i == 2 ? Icon(Icons.check_rounded, size: 16, color: on ? Colors.white : const Color(0xFF8A8373)) : Text('${i + 1}', style: tx(13, w: FontWeight.w700, c: on ? Colors.white : const Color(0xFF8A8373))),
        ),
      );
    }

    Widget line(int i) => Expanded(
          child: Container(
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(color: const Color(0xFFEADFC6), borderRadius: BorderRadius.circular(3)),
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 500),
                widthFactor: i < step ? 1 : 0,
                child: Container(decoration: BoxDecoration(color: K.or, borderRadius: BorderRadius.circular(3))),
              ),
            ),
          ),
        );
    return Row(children: [dot(0), line(0), dot(1), line(1), dot(2)]);
  }
}

// ======================= Orange button =======================
class _OrangeBtn extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final double height;
  const _OrangeBtn({required this.child, required this.onTap, this.height = 54});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(gradient: K.orGrad, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: K.orD.withValues(alpha: .3), blurRadius: 16, offset: const Offset(0, 6))]),
        child: child,
      ),
    );
  }
}

// ======================= Option popup (centre) =======================
class _OptDialog extends StatelessWidget {
  final String title, sub;
  final List<Opt> opts;
  final String? cur;
  const _OptDialog({required this.title, required this.sub, required this.opts, this.cur});
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title, style: sf(23))),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(width: 34, height: 34, decoration: const BoxDecoration(color: Color(0xFFF1ECE2), shape: BoxShape.circle), child: const Icon(Icons.close_rounded, size: 18)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(sub, style: tx(12.5, w: FontWeight.w600, c: K.sub)),
          const SizedBox(height: 10),
          Flexible(
            child: ListView(shrinkWrap: true, children: [
              for (final o in opts)
                GestureDetector(
                  onTap: () => Navigator.pop(context, o[0]),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: cur == o[0] ? const Color(0xFFFFF1E2) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cur == o[0] ? K.or : const Color(0xFFEFE7D6), width: 1.5),
                    ),
                    child: Row(children: [
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: const Color(0xFFFFF4E4), borderRadius: BorderRadius.circular(12)),
                        child: Text(o[1], style: const TextStyle(fontSize: 20)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(o[2], style: tx(14.5, w: FontWeight.w800, c: K.txt)),
                          Text(o[3], style: tx(12, w: FontWeight.w500, c: K.sub)),
                        ]),
                      ),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cur == o[0] ? K.orD : Colors.white,
                          border: Border.all(color: cur == o[0] ? K.orD : const Color(0xFFD9CDB5), width: 2),
                        ),
                        child: cur == o[0] ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
                      ),
                    ]),
                  ),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ======================= Sub-service picker (category mapping) =======================
class _PickResult {
  final List<String> active;
  final Map<String, List<String>> items;
  _PickResult(this.active, this.items);
}

class _SubPicker extends StatefulWidget {
  final Cat cat;
  final String typeLabel;
  final List<String> active;
  final Map<String, List<String>> items;
  const _SubPicker({required this.cat, required this.typeLabel, required this.active, required this.items});
  @override
  State<_SubPicker> createState() => _SubPickerState();
}

class _SubPickerState extends State<_SubPicker> {
  late final List<String> active = widget.active;
  late final Map<String, List<String>> items = widget.items;
  late final List<Sub> subs = [
    ...widget.cat.subs,
    for (final a in widget.active)
      if (!widget.cat.subs.any((s) => s.n == a)) Sub(widget.cat.e, a, []),
  ];
  String q = '';
  final _new = TextEditingController();
  final Map<String, TextEditingController> _itemNew = {};

  void _toggle(String s) => setState(() => active.contains(s) ? active.remove(s) : active.add(s));

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final shown = subs.where((s) => q.isEmpty || s.n.toLowerCase().contains(q.toLowerCase())).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        height: mq.size.height * .9,
        decoration: const BoxDecoration(color: K.cream, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 14, 14),
            decoration: const BoxDecoration(color: Color(0xFFFFF1E2), borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            child: Row(children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: K.shadow(.06)),
                child: Text(widget.cat.e, style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${widget.cat.n} — kaunsi services dete hain?', style: sf(21)),
                  const SizedBox(height: 2),
                  Text('Jitni chahein utni chuniye · ${widget.typeLabel}', style: tx(12, w: FontWeight.w700, c: const Color(0xFFB0661F))),
                ]),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(width: 36, height: 36, decoration: const BoxDecoration(color: Color(0xFFF1E3D2), shape: BoxShape.circle), child: const Icon(Icons.close_rounded, size: 18)),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => q = v),
                  style: tx(14.5, w: FontWeight.w600, c: K.txt),
                  decoration: InputDecoration(
                    hintText: '🔍 Khojein...',
                    hintStyle: tx(14.5, w: FontWeight.w500, c: const Color(0xFFA79E8C)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFECE4D2), width: 1.5)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: K.or, width: 1.5)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() {
                  final all = active.length == subs.length;
                  active.clear();
                  if (!all) active.addAll(subs.map((s) => s.n));
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(color: const Color(0xFFFFE8D2), borderRadius: BorderRadius.circular(14)),
                  child: Text(active.length == subs.length ? 'Sab OFF' : 'Sab ON', style: tx(13, w: FontWeight.w800, c: K.orD)),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
            child: Row(children: [
              Text('${subs.length} services', style: tx(12, w: FontWeight.w700, c: K.sub)),
              const Spacer(),
              Text('${active.length} active', style: tx(12, w: FontWeight.w800, c: const Color(0xFF1F9D57))),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              children: [
                for (final s in shown) _subCard(s),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFECE4D2), width: 1.5)),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _new,
                        style: tx(14, w: FontWeight.w600, c: K.txt),
                        decoration: InputDecoration(border: InputBorder.none, hintText: '+ Apni ${widget.typeLabel == 'Product' ? 'product category' : 'service'} likhein', hintStyle: tx(13.5, w: FontWeight.w500, c: const Color(0xFFA79E8C))),
                      ),
                    ),
                    _greenBtn('Jodein', () {
                      final t = _new.text.trim();
                      if (t.length < 2 || subs.any((s) => s.n.toLowerCase() == t.toLowerCase())) return;
                      setState(() {
                        subs.add(Sub(widget.cat.e, t, []));
                        active.add(t);
                        _new.clear();
                      });
                    }),
                  ]),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + mq.padding.bottom),
            decoration: const BoxDecoration(color: K.cream, border: Border(top: BorderSide(color: Color(0xFFEFE7D6)))),
            child: Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: const Color(0xFFF1E8D6), borderRadius: BorderRadius.circular(99)),
                    child: Text('Cancel', style: tx(16, w: FontWeight.w800, c: K.txt)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context, _PickResult(List.of(active), items)),
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(gradient: K.orGrad, borderRadius: BorderRadius.circular(99), boxShadow: [BoxShadow(color: K.orD.withValues(alpha: .3), blurRadius: 14, offset: const Offset(0, 5))]),
                    child: Text('✓ Save (${active.length} active)', style: tx(16, w: FontWeight.w800, c: Colors.white)),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _subCard(Sub s) {
    final on = active.contains(s.n);
    final chosen = items[s.n] ?? <String>[];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: on ? K.mint : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: on ? K.mintB : const Color(0xFFEFE7D6), width: on ? 1.6 : 1.2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: () => _toggle(s.n),
          behavior: HitTestBehavior.opaque,
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: on ? const Color(0xFFDDF3E6) : const Color(0xFFF4F1EA), borderRadius: BorderRadius.circular(13)),
              child: Text(s.e, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.n, style: tx(15, w: FontWeight.w800, c: K.txt)),
                Row(children: [
                  Container(width: 7, height: 7, decoration: BoxDecoration(color: on ? const Color(0xFF1F9D57) : const Color(0xFFBDB5A4), shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text(on ? 'Active' : 'Inactive', style: tx(11.5, w: FontWeight.w700, c: on ? const Color(0xFF1F9D57) : const Color(0xFF9A907C))),
                ]),
              ]),
            ),
            Switch(
              value: on,
              onChanged: (_) => _toggle(s.n),
              activeThumbColor: Colors.white,
              activeTrackColor: const Color(0xFF1F9D57),
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFFDCD5C6),
              trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
            ),
          ]),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          child: !on
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Divider(height: 1, color: Color(0xFFCDEBD8)),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: Text('KAUNSI SERVICES DETE HAIN? · ${chosen.length} chuni', style: tx(11, w: FontWeight.w800, c: const Color(0xFF1F7A47)).copyWith(letterSpacing: .4))),
                      GestureDetector(
                        onTap: () => setState(() {
                          final all = s.items.every((i) => chosen.contains(i.n));
                          items[s.n] = all ? [] : [...s.items.map((i) => i.n), ...chosen.where((c) => !s.items.any((i) => i.n == c))];
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)),
                          child: Text('Sab chunein', style: tx(11.5, w: FontWeight.w800, c: const Color(0xFF1F7A47))),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: .98,
                      children: [
                        for (final it in [...s.items, ...chosen.where((c) => !s.items.any((i) => i.n == c)).map((c) => Item(s.e, c, 0))])
                          _itemTile(s, it, chosen.contains(it.n)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFD6EEDF))),
                      child: Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _itemNew.putIfAbsent(s.n, () => TextEditingController()),
                            style: tx(13.5, w: FontWeight.w600, c: K.txt),
                            decoration: InputDecoration(border: InputBorder.none, hintText: '+ Apna service likhein', hintStyle: tx(13, w: FontWeight.w500, c: const Color(0xFFA79E8C))),
                          ),
                        ),
                        _greenBtn('Jodein', () {
                          final c = _itemNew[s.n]!;
                          final t = c.text.trim();
                          if (t.length < 2) return;
                          setState(() {
                            items[s.n] = [...chosen, t];
                            c.clear();
                          });
                        }),
                      ]),
                    ),
                    const SizedBox(height: 6),
                    Text('✨ Jo tick karenge wo aapki digital dukaan me demo photo + rate ke saath lag jayenge — baad me badal sakte hain', style: tx(11, w: FontWeight.w600, c: const Color(0xFF4F7A60))),
                  ]),
                ),
        ),
      ]),
    );
  }

  Widget _itemTile(Sub s, Item it, bool on) {
    return GestureDetector(
      onTap: () => setState(() {
        final l = List<String>.from(items[s.n] ?? const []);
        on ? l.remove(it.n) : l.add(it.n);
        items[s.n] = l;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
        decoration: BoxDecoration(
          color: on ? const Color(0xFFFFF1E2) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: on ? K.or : const Color(0xFFE6EFE9), width: 1.4),
        ),
        child: Stack(children: [
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(it.e, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 3),
              Text(it.n, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx(11, w: FontWeight.w800, c: K.txt, h: 1.15)),
              if (it.p > 0) Text('₹${_inr(it.p)}', style: tx(10.5, w: FontWeight.w700, c: K.sub)),
            ]),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(shape: BoxShape.circle, color: on ? K.orD : Colors.white, border: Border.all(color: on ? K.orD : const Color(0xFFCFC6B4), width: 1.5)),
              child: on ? const Icon(Icons.check_rounded, size: 11, color: Colors.white) : null,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _greenBtn(String t, VoidCallback f) => GestureDetector(
        onTap: f,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: const Color(0xFF1F9D57), borderRadius: BorderRadius.circular(11)),
          child: Text(t, style: tx(13, w: FontWeight.w800, c: Colors.white)),
        ),
      );
}

String _inr(int n) {
  final s = n.toString();
  if (s.length <= 3) return s;
  final last = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '${parts.join(',')},$last';
}

// ======================= Shop rent sheet =======================
class _RentSheet extends StatefulWidget {
  const _RentSheet();
  @override
  State<_RentSheet> createState() => _RentSheetState();
}

class _RentSheetState extends State<_RentSheet> {
  String plan = 'trial';
  String app = 'gpay';
  int phase = 0; // 0 choose, 1 paying, 2 done
  final _upi = TextEditingController();

  static const _apps = [
    ['gpay', 'G', 'GPay', Color(0xFF4285F4)],
    ['phonepe', 'Pe', 'PhonePe', Color(0xFF5F259F)],
    ['paytm', 'P', 'Paytm', Color(0xFF00BAF2)],
    ['bhim', 'B', 'BHIM', Color(0xFFF26522)],
  ];
  static const _m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  String _d(int days) {
    final t = DateTime.now().add(Duration(days: days));
    return '${t.day} ${_m[t.month - 1]}';
  }

  String get appName => (_apps.firstWhere((a) => a[0] == app))[2] as String;

  Future<void> _pay() async {
    setState(() => phase = 1);
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    setState(() => phase = 2);
    await Future.delayed(const Duration(milliseconds: 1300));
    if (mounted) Navigator.pop(context, plan);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final trial = plan == 'trial';
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        height: mq.size.height * .92,
        decoration: const BoxDecoration(color: K.cream, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Stack(children: [
          Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 14, 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 50,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: const Color(0xFFFFF1E2), borderRadius: BorderRadius.circular(14)),
                  child: const Text('🏪', style: TextStyle(fontSize: 26)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Shop rent shuru karein', style: sf(25)),
                    Text('Apni digital dukaan ka kiraya · kabhi bhi band', style: tx(12.5, w: FontWeight.w700, c: const Color(0xFFB0661F))),
                  ]),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(width: 36, height: 36, decoration: const BoxDecoration(color: Color(0xFFF1ECE2), shape: BoxShape.circle), child: const Icon(Icons.close_rounded, size: 18)),
                ),
              ]),
            ),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(0, 0, 0, 16), children: [
                const _GuideVideo(caption: 'Shop rent — apni digital dukaan ka kiraya', scene: '🏪', compact: false),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: _planCard('trial', '₹1', '1 hafta trial', '${_d(7)} tak free · ₹1 AutoPay', 'Pasand aaya to phir ₹199/mahina', null)),
                    const SizedBox(width: 10),
                    Expanded(child: _planCard('p100', '₹100', 'pehla mahina', 'Seedha Shop rent · ${_d(30)} tak', 'Phir ₹199/mahina AutoPay', 'AAJ HI LIVE')),
                  ]),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Text('UPI APP CHUNIYE', style: tx(11.5, w: FontWeight.w800, c: K.sub).copyWith(letterSpacing: 1)),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    for (final a in _apps)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => app = a[0] as String),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            decoration: BoxDecoration(
                              color: app == a[0] ? const Color(0xFFFFF1E2) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: app == a[0] ? K.or : const Color(0xFFEFE7D6), width: 1.5),
                            ),
                            child: Column(children: [
                              Container(
                                width: 32,
                                height: 32,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: a[3] as Color, borderRadius: BorderRadius.circular(9)),
                                child: Text(a[1] as String, style: tx(13, w: FontWeight.w800, c: Colors.white)),
                              ),
                              const SizedBox(height: 6),
                              Text(a[2] as String, style: tx(12, w: FontWeight.w700, c: K.txt)),
                            ]),
                          ),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _upi,
                    style: tx(14.5, w: FontWeight.w600, c: K.txt),
                    decoration: InputDecoration(
                      hintText: 'Ya UPI ID daalein (jaise 98xxxxxx@ybl)',
                      hintStyle: tx(14, w: FontWeight.w500, c: const Color(0xFFA79E8C)),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFECE4D2), width: 1.5)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: K.or, width: 1.5)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFFE8F6EC), borderRadius: BorderRadius.circular(16)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (final l in trial
                        ? ['Aaj sirf ₹1 AutoPay se katega — UPI mandate ban jayega.', '7 din saare features free, dukaan LIVE.', 'Pasand aaya to ${_d(7)} se Shop rent ₹199/mahina — usse pehle reminder aayega, mann na ho to band kar dein.']
                        : ['Aaj ₹100 — pehle mahine ka Shop rent.', 'Dukaan aaj hi LIVE + 🎁 ₹100 ke lead coins.', '${_d(30)} se ₹199/mahina AutoPay — kabhi bhi band kar sakte hain.'])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('✓ $l', style: tx(12.5, w: FontWeight.w600, c: const Color(0xFF1F5C36), h: 1.4)),
                      ),
                  ]),
                ),
              ]),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + mq.padding.bottom),
              child: _OrangeBtn(
                height: 56,
                onTap: _pay,
                child: Text(trial ? '₹1 AutoPay se 1 hafta trial shuru karein' : '₹100 bharein · aaj hi LIVE', style: tx(16, w: FontWeight.w800, c: Colors.white)),
              ),
            ),
          ]),
          if (phase > 0)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(color: K.cream.withValues(alpha: .93), borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: phase == 1
                        ? Column(key: const ValueKey(1), mainAxisSize: MainAxisSize.min, children: [
                            const SizedBox(width: 44, height: 44, child: CircularProgressIndicator(color: K.orD, strokeWidth: 3.5)),
                            const SizedBox(height: 16),
                            Text('$appName me ${trial ? '₹1' : '₹100'} ki request bheji…', style: tx(16, w: FontWeight.w800, c: K.txt)),
                            const SizedBox(height: 4),
                            Text(trial ? 'Apne UPI app me AutoPay mandate approve karein (demo)' : 'Apne UPI app me payment approve karein (demo)', style: tx(12.5, w: FontWeight.w600, c: K.sub)),
                          ])
                        : Column(key: const ValueKey(2), mainAxisSize: MainAxisSize.min, children: [
                            Container(
                              width: 78,
                              height: 78,
                              decoration: const BoxDecoration(color: Color(0xFF22A45D), shape: BoxShape.circle),
                              child: const Icon(Icons.check_rounded, color: Colors.white, size: 46),
                            ),
                            const SizedBox(height: 14),
                            Text(trial ? '1 hafta trial chalu! Dukaan LIVE' : 'Shop rent bhar diya! Dukaan LIVE', style: tx(17, w: FontWeight.w800, c: K.txt)),
                            const SizedBox(height: 4),
                            Text(trial ? '${_d(7)} tak free · phir ₹199/mahina Shop rent' : '${_d(30)} tak · phir ₹199/mahina', style: tx(13, w: FontWeight.w600, c: K.sub)),
                          ]),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _planCard(String k, String price, String t, String l1, String l2, String? tag) {
    final on = plan == k;
    return GestureDetector(
      onTap: () => setState(() => plan = k),
      child: Stack(clipBehavior: Clip.none, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          decoration: BoxDecoration(
            color: on ? const Color(0xFFFFF4E8) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: on ? K.orD : const Color(0xFFEFE7D6), width: on ? 2 : 1.3),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(TextSpan(children: [
              TextSpan(text: price, style: tx(22, w: FontWeight.w800, c: K.txt)),
              TextSpan(text: ' · $t', style: tx(12.5, w: FontWeight.w800, c: const Color(0xFF6E6656))),
            ])),
            const SizedBox(height: 4),
            Text(l1, style: tx(11.5, w: FontWeight.w700, c: K.txt)),
            const SizedBox(height: 6),
            Text(l2, style: tx(11, w: FontWeight.w800, c: k == 'trial' ? const Color(0xFFC2540A) : const Color(0xFF1F7A47))),
          ]),
        ),
        if (tag != null)
          Positioned(
            right: 8,
            top: -9,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFF1F9D57), borderRadius: BorderRadius.circular(6)),
              child: Text(tag, style: tx(9.5, w: FontWeight.w800, c: Colors.white)),
            ),
          ),
      ]),
    );
  }
}
