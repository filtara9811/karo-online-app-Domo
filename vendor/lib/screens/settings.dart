import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../catalog.dart';
import '../data.dart';
import '../theme.dart';
import 'join.dart';

/// ⚙ Lead settings — prototype jaisa: upar 6 tab card, neeche us tab ka kaam.
/// Categories = mapping: jo category / service chalu hai, sirf usi ki lead aayegi.
void openLeadSettings(BuildContext context, {String tab = 'cat'}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => LeadSettingsSheet(tab: tab),
  );
}

class LeadSettingsSheet extends StatefulWidget {
  final String tab;
  const LeadSettingsSheet({super.key, this.tab = 'cat'});
  @override
  State<LeadSettingsSheet> createState() => _LeadSettingsSheetState();
}

class _LeadSettingsSheetState extends State<LeadSettingsSheet> {
  late String k = widget.tab;
  bool saving = false;
  final Set<String> openCats = {};

  // ---- form state ----
  late final Map<String, dynamic> st = Store.i.settings;
  late final _name = TextEditingController(text: Store.i.shopName);
  late final _owner = TextEditingController(text: Store.i.ownerName);
  late final _addr = TextEditingController(text: (st['addr'] ?? Store.i.vendor?['area'] ?? '').toString());
  late final _about = TextEditingController(text: (st['about'] ?? '').toString());
  late String open = (st['open'] ?? '09:00').toString(), close = (st['close'] ?? '21:00').toString();
  late String? logo = st['logo'] as String?;
  late List<String> photos = List<String>.from(st['photos'] ?? const []);
  late String area = (st['area'] ?? 'mine').toString();
  late String km = (Store.i.vendor?['radius'] ?? '10').toString();
  late bool h24 = st['h24'] != false;
  late String from = (st['from'] ?? '09:00').toString(), to = (st['to'] ?? '21:00').toString();
  late Set<int> days = {...List<int>.from((st['days'] as List?)?.map((e) => (e as num).toInt()) ?? [1, 2, 3, 4, 5, 6, 7])};
  late String accept = (st['accept'] ?? 'manual').toString();
  late bool minStop = st['minStop'] != false;
  late int limit = (st['limit'] as num?)?.toInt() ?? 30;
  late bool sound = st['sound'] != false;

  // ---------------- mapping helpers ----------------
  Map<String, List<String>> get map {
    final m = <String, List<String>>{};
    final raw = st['map'];
    if (raw is Map) {
      raw.forEach((key, val) => m['$key'] = List<String>.from(val as List));
    }
    if (m.isEmpty) {
      // pehli baar: join me chuni category / services se banao
      final left = {...Store.i.subs};
      for (final c in Store.i.cats) {
        final cat = _cat(c);
        final mine = Store.i.subs.where((s) => cat != null && cat.subs.any((x) => x.n == s)).toList();
        m[c] = mine;
        left.removeAll(mine);
      }
      // apni likhi hui services (catalog me nahi) — pehli category me
      final extra = left.where((s) => !_known(s)).toList();
      if (extra.isNotEmpty) {
        if (m.isEmpty) {
          m['Meri services'] = extra;
        } else {
          m[m.keys.first] = [...m[m.keys.first]!, ...extra];
        }
      }
    }
    return m;
  }

  bool _known(String sub) {
    for (final t in Catalog.types.values) {
      for (final c in t.cats) {
        if (c.subs.any((x) => x.n == sub)) return true;
      }
    }
    return false;
  }

  Cat? _cat(String name) {
    for (final t in Catalog.types.values) {
      for (final c in t.cats) {
        if (c.n == name) return c;
      }
    }
    return null;
  }

  String _typeOf(String cat) {
    for (final t in Catalog.types.values) {
      if (t.cats.any((c) => c.n == cat)) return t.key;
    }
    return Store.i.vendor?['ty'] ?? 'svc';
  }

  Future<void> _saveMap(Map<String, List<String>> m, Set<String> active, {Map<String, dynamic>? items}) async {
    setState(() => saving = true);
    final cats = m.entries.where((e) => e.value.any(active.contains)).map((e) => e.key).toList();
    try {
      await Store.i.updateVendor({
        'cats': cats,
        'subs': active.toList(),
        if (items != null) 'items': items,
        'settings': {...Store.i.settings, 'map': m},
      });
      st['map'] = m;
    } catch (e) {
      if (mounted) toast(context, '⚠️ Save nahi hua: $e');
    }
    if (mounted) setState(() => saving = false);
  }

  Future<void> _saveSettings(Map<String, dynamic> patch, {Map<String, dynamic>? vendorPatch}) async {
    setState(() => saving = true);
    try {
      st.addAll(patch);
      await Store.i.updateVendor({...?vendorPatch, 'settings': {...Store.i.settings, ...patch}});
      if (mounted) toast(context, '✓ Save ho gaya — leads ab isi hisaab se aayengi');
    } catch (e) {
      if (mounted) toast(context, '⚠️ Save nahi hua: $e');
    }
    if (mounted) setState(() => saving = false);
  }

  int get _profilePct {
    var n = 0;
    if (logo != null) n++;
    if (_name.text.trim().length > 1) n++;
    if (_owner.text.trim().isNotEmpty) n++;
    if (_addr.text.trim().isNotEmpty) n++;
    if (_about.text.trim().isNotEmpty) n++;
    if (photos.isNotEmpty) n++;
    n++; // mobile
    return (n / 7 * 100).round();
  }

  // ---------------- build ----------------
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final m = map;
    final active = Store.i.subs.toSet();
    final onCats = m.entries.where((e) => e.value.any(active.contains)).length;
    final tabs = [
      ['cat', '🗂️', 'Categories', '$onCats chalu · ${active.length} services'],
      ['store', '🏪', 'Store profile', '$_profilePct% poora'],
      ['area', '📍', 'Service area', area == 'mine' ? 'Mera area' : (area == 'city' ? 'Poori city' : 'Multi-city')],
      ['time', '🕘', 'Timing', h24 ? '24 × 7' : '$from–$to'],
      ['acc', '✋', 'Accept', accept == 'auto' ? 'Auto accept' : 'Manual accept'],
      ['lim', '🎯', 'Lead limit', '$limit / din'],
    ];
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        height: mq.size.height * .9,
        decoration: const BoxDecoration(color: K.cream, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(width: 44, height: 5, decoration: BoxDecoration(color: const Color(0xFFD9D2C3), borderRadius: BorderRadius.circular(3))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 14, 10),
            child: Row(children: [
              const SizedBox(width: 38),
              Expanded(
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.settings_outlined, size: 24, color: K.txt),
                  const SizedBox(width: 6),
                  Text('Lead settings', style: sf(27)),
                ]),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(width: 38, height: 38, decoration: const BoxDecoration(color: Color(0xFFEDE7DC), shape: BoxShape.circle), child: const Icon(Icons.close_rounded, size: 20)),
              ),
            ]),
          ),
          SizedBox(
            height: 64,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                for (final t in tabs)
                  GestureDetector(
                    onTap: () => setState(() => k = t[0]),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
                      decoration: BoxDecoration(
                        color: k == t[0] ? K.ink : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: k == t[0] ? K.ink : const Color(0xFFEADFC6), width: 1.5),
                      ),
                      child: Row(children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: k == t[0] ? Colors.white12 : const Color(0xFFFFF1E2), borderRadius: BorderRadius.circular(12)),
                          child: Text(t[1], style: const TextStyle(fontSize: 18)),
                        ),
                        const SizedBox(width: 10),
                        Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(t[2], style: tx(14, w: FontWeight.w800, c: k == t[0] ? Colors.white : K.txt)),
                          Text(t[3], style: tx(11.5, w: FontWeight.w700, c: k == t[0] ? K.goldL : K.sub)),
                        ]),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
          const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 0), child: Divider(height: 1, color: Color(0xFFEADFC6))),
          Expanded(
            child: Stack(children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, .04), end: Offset.zero).animate(a), child: c)),
                child: KeyedSubtree(key: ValueKey(k), child: _body(m, active)),
              ),
              if (saving)
                const Positioned(top: 8, right: 16, child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: K.orD))),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _body(Map<String, List<String>> m, Set<String> active) {
    switch (k) {
      case 'store':
        return _store();
      case 'area':
        return _area();
      case 'time':
        return _time();
      case 'acc':
        return _acc();
      case 'lim':
        return _lim();
    }
    return _cats(m, active);
  }

  // ================= Categories (mapping) =================
  Widget _cats(Map<String, List<String>> m, Set<String> active) {
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 30), children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
        child: Text('KAUN SI LEADS CHAHIYE (CATEGORY MAPPING)', style: tx(12.5, w: FontWeight.w800, c: const Color(0xFF8A7A5A)).copyWith(letterSpacing: .8)),
      ),
      for (final e in m.entries) _catCard(e.key, e.value, m, active),
      const SizedBox(height: 4),
      GestureDetector(
        onTap: () => _addCategory(m, active),
        child: Container(
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: K.or, width: 1.6), color: const Color(0xFFFFF6EC)),
          child: Text('＋ Nayi category / product jodein', style: tx(14.5, w: FontWeight.w800, c: K.orD)),
        ),
      ),
      const SizedBox(height: 12),
      Text('💡 Jo service chalu (kaali) hai, customer ki usi request par aapke paas lead aayegi aur ghanti bajegi. Chip par tap karke on/off karein.', style: tx(12, w: FontWeight.w600, c: K.sub, h: 1.4)),
    ]);
  }

  Widget _catCard(String name, List<String> subs, Map<String, List<String>> m, Set<String> active) {
    final cat = _cat(name);
    final on = subs.where(active.contains).length;
    final isOpen = openCats.contains(name);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFEFE2C7), width: 1.6)),
      child: Column(children: [
        Row(children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFFFDF0DF), borderRadius: BorderRadius.circular(16)),
            child: Text(cat?.e ?? '🛍️', style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: tx(17, w: FontWeight.w800, c: K.txt, h: 1.15)),
              const SizedBox(height: 2),
              Text('$on/${subs.length} services chalu', style: tx(13, w: FontWeight.w600, c: K.sub)),
            ]),
          ),
          Switch(
            value: on > 0,
            onChanged: (v) {
              final a = {...active};
              v ? a.addAll(subs) : a.removeAll(subs);
              _saveMap(m, a);
            },
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFF16A34A),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFDCD5C6),
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => setState(() => isOpen ? openCats.remove(name) : openCats.add(name)),
            child: AnimatedRotation(
              turns: isOpen ? .5 : 0,
              duration: const Duration(milliseconds: 220),
              child: Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFFF3EEE4), borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.arrow_drop_down_rounded, size: 24)),
            ),
          ),
        ]),
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          child: !isOpen
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final s in subs)
                        GestureDetector(
                          onTap: () {
                            final a = {...active};
                            a.contains(s) ? a.remove(s) : a.add(s);
                            _saveMap(m, a);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color: active.contains(s) ? K.ink : Colors.white,
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(color: active.contains(s) ? K.ink : const Color(0xFFDCD3C0), width: 1.4),
                            ),
                            child: Text(s, style: tx(13, w: FontWeight.w800, c: active.contains(s) ? Colors.white : const Color(0xFF8A7A5A))),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      if (cat != null)
                        TextButton.icon(
                          onPressed: () => _editCat(cat, m, active),
                          icon: const Icon(Icons.edit_rounded, size: 16, color: K.orD),
                          label: Text('Services / rate badlein', style: tx(12.5, w: FontWeight.w800, c: K.orD)),
                        ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          final a = {...active}..removeAll(subs);
                          final mm = {...m}..remove(name);
                          _saveMap(mm, a);
                        },
                        child: Text('Hatayein', style: tx(12.5, w: FontWeight.w800, c: K.red)),
                      ),
                    ]),
                  ]),
                ),
        ),
      ]),
    );
  }

  Future<void> _editCat(Cat c, Map<String, List<String>> m, Set<String> active) async {
    final items = <String, List<String>>{};
    final raw = Store.i.vendor?['items'];
    if (raw is Map) raw.forEach((key, v) => items['$key'] = List<String>.from(v as List));
    final res = await showModalBottomSheet<PickResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SubPicker(cat: c, typeLabel: Catalog.types[_typeOf(c.n)]?.l ?? 'Service', active: [...(m[c.n] ?? const <String>[]).where(active.contains)], items: items),
    );
    if (res == null) return;
    final mm = {...m};
    final a = {...active}..removeAll(m[c.n] ?? const []);
    if (res.active.isEmpty) {
      mm.remove(c.n);
    } else {
      mm[c.n] = res.active;
      a.addAll(res.active);
    }
    items.addAll(res.items);
    await _saveMap(mm, a, items: items);
    openCats.add(c.n);
  }

  Future<void> _addCategory(Map<String, List<String>> m, Set<String> active) async {
    final c = await showModalBottomSheet<Cat>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CatChooser(),
    );
    if (c != null && mounted) await _editCat(c, m, active);
  }

  // ================= Store profile =================
  Future<String?> _pick() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 80);
      return x?.path;
    } catch (_) {
      return null;
    }
  }

  Widget _store() {
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 30), children: [
      GestureDetector(
        onTap: () async {
          final p = await _pick();
          if (p != null) setState(() => logo = p);
        },
        child: Row(children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: const Color(0xFFF6EDDD),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE6D6B6), width: 1.5),
              image: logo == null || !File(logo!).existsSync() ? null : DecorationImage(image: FileImage(File(logo!)), fit: BoxFit.cover),
            ),
            child: logo == null ? const Icon(Icons.storefront_outlined, color: K.orD, size: 32) : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Store logo', style: tx(17, w: FontWeight.w800, c: K.txt)),
              Text('Tap karke photo lagayein · $_profilePct% profile poora', style: tx(12.5, w: FontWeight.w600, c: K.sub)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      _lbl('Dukaan ka naam'),
      _in(_name, 'jaise: Ashu Electricals'),
      _lbl('Malik ka naam'),
      _in(_owner, 'Aapka naam'),
      _lbl('Mobile number'),
      _in(TextEditingController(text: Store.i.phone), '98XXXXXX10', enabled: false),
      _lbl('Pata (address)'),
      _in(_addr, 'Gali / market / shehar'),
      _lbl('Khulne ka time'),
      Row(children: [
        Expanded(child: _dd(open, _hours, (v) => setState(() => open = v))),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('–')),
        Expanded(child: _dd(close, _hours, (v) => setState(() => close = v))),
      ]),
      const SizedBox(height: 12),
      _lbl('Dukaan ke baare mein'),
      _in(_about, 'Aap kya kaam karte hain, kitne saal se...', lines: 3),
      _lbl('Store photos (${photos.length}/6)'),
      SizedBox(
        height: 84,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final p in photos)
            GestureDetector(
              onLongPress: () => setState(() => photos.remove(p)),
              child: Container(
                width: 84,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), image: File(p).existsSync() ? DecorationImage(image: FileImage(File(p)), fit: BoxFit.cover) : null, color: K.sand),
              ),
            ),
          if (photos.length < 6)
            GestureDetector(
              onTap: () async {
                final p = await _pick();
                if (p != null) setState(() => photos.add(p));
              },
              child: Container(
                width: 84,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE6D6B6), width: 1.5)),
                child: const Icon(Icons.add_rounded, color: K.orD, size: 30),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 18),
      _saveBtn(() => _saveSettings(
            {'logo': logo, 'photos': photos, 'addr': _addr.text.trim(), 'about': _about.text.trim(), 'open': open, 'close': close},
            vendorPatch: {'shop_name': _name.text.trim().isEmpty ? Store.i.shopName : _name.text.trim(), 'owner_name': _owner.text.trim()},
          )),
    ]);
  }

  // ================= Service area =================
  Widget _area() {
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 30), children: [
      for (final o in const [
        ['mine', '📍', 'Sirf mere area mein', 'Dukaan ke aas-paas ki leads'],
        ['city', '🏙️', 'Poori city mein', 'Ek city ke har area ki leads'],
        ['multi', '🌆', 'Multi-city', 'Kai shehron mein service'],
      ])
        _radio(area == o[0], o[1], o[2], o[3], () => setState(() => area = o[0])),
      const SizedBox(height: 8),
      _lbl('Kitni door tak'),
      _dd('$km km ke andar', const ['1 km ke andar', '3 km ke andar', '5 km ke andar', '10 km ke andar', '20 km ke andar', '50 km ke andar'], (v) => setState(() => km = v.split(' ').first)),
      const SizedBox(height: 18),
      _saveBtn(() => _saveSettings({'area': area}, vendorPatch: {'radius': km})),
    ]);
  }

  // ================= Timing =================
  Widget _time() {
    const dn = ['Som', 'Mang', 'Budh', 'Guru', 'Shuk', 'Shani', 'Ravi'];
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 30), children: [
      _switchRow('24 × 7 chalu', 'Din-raat leads aayengi', h24, (v) => setState(() => h24 = v)),
      const SizedBox(height: 14),
      AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: h24 ? .4 : 1,
        child: IgnorePointer(
          ignoring: h24,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _lbl('Kis time se kis time tak'),
            Row(children: [
              Expanded(child: _dd(from, _hours, (v) => setState(() => from = v))),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('–')),
              Expanded(child: _dd(to, _hours, (v) => setState(() => to = v))),
            ]),
          ]),
        ),
      ),
      const SizedBox(height: 14),
      _lbl('Kaun se din'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (var d = 1; d <= 7; d++)
          GestureDetector(
            onTap: () => setState(() => days.contains(d) ? days.remove(d) : days.add(d)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(color: days.contains(d) ? K.ink : Colors.white, borderRadius: BorderRadius.circular(99), border: Border.all(color: days.contains(d) ? K.ink : const Color(0xFFDCD3C0), width: 1.4)),
              child: Text(dn[d - 1], style: tx(13.5, w: FontWeight.w800, c: days.contains(d) ? Colors.white : const Color(0xFF8A7A5A))),
            ),
          ),
      ]),
      const SizedBox(height: 22),
      _saveBtn(() => _saveSettings({'h24': h24, 'from': from, 'to': to, 'days': (days.toList()..sort())})),
    ]);
  }

  // ================= Accept =================
  Widget _acc() {
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 30), children: [
      _radio(accept == 'manual', '✋', 'Manual accept', 'Har lead aap khud dekhkar accept karein', () => setState(() => accept = 'manual')),
      _radio(accept == 'auto', '⚡', 'Auto accept', 'Match hone par lead apne aap accept (coin kat-te hain)', () => setState(() => accept = 'auto')),
      const SizedBox(height: 6),
      _switchRow('Coins kam hone par rokein', '10 se kam coin par auto accept band', minStop, (v) => setState(() => minStop = v)),
      const SizedBox(height: 22),
      _saveBtn(() => _saveSettings({'accept': accept, 'minStop': minStop, 'minCoins': minStop ? 10 : 0})),
    ]);
  }

  // ================= Limit =================
  Widget _lim() {
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 30), children: [
      _lbl('Roz ki max leads'),
      Text('Itni leads ke baad us din band', style: tx(12.5, w: FontWeight.w600, c: K.sub)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final n in const [10, 20, 30, 50, 100])
          GestureDetector(
            onTap: () => setState(() => limit = n),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 60,
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: limit == n ? K.ink : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: limit == n ? K.ink : const Color(0xFFDCD3C0), width: 1.4)),
              child: Text('$n', style: tx(15, w: FontWeight.w800, c: limit == n ? Colors.white : K.txt)),
            ),
          ),
      ]),
      const SizedBox(height: 16),
      _switchRow('Lead aane par awaaz', 'Naya lead aate hi sound', sound, (v) => setState(() => sound = v)),
      const SizedBox(height: 22),
      _saveBtn(() => _saveSettings({'limit': limit, 'sound': sound})),
    ]);
  }

  // ---------------- small widgets ----------------
  static final _hours = [for (var h = 5; h <= 23; h++) '${h.toString().padLeft(2, '0')}:00'];

  Widget _lbl(String t) => Padding(padding: const EdgeInsets.only(bottom: 8, top: 4), child: Text(t, style: tx(13, w: FontWeight.w800, c: const Color(0xFF6E6656))));

  Widget _in(TextEditingController c, String h, {int lines = 1, bool enabled = true}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          enabled: enabled,
          maxLines: lines,
          onChanged: (_) => setState(() {}),
          style: tx(15, w: FontWeight.w600, c: K.txt),
          decoration: InputDecoration(
            hintText: h,
            hintStyle: tx(15, w: FontWeight.w500, c: const Color(0xFFA79E8C)),
            filled: true,
            fillColor: enabled ? Colors.white : const Color(0xFFF6F1E7),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFECE4D2), width: 1.5)),
            disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFECE4D2), width: 1.5)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: K.or, width: 1.6)),
          ),
        ),
      );

  Widget _dd(String v, List<String> opts, ValueChanged<String> f) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFECE4D2), width: 1.5)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: opts.contains(v) ? v : opts.first,
            isExpanded: true,
            style: tx(15, w: FontWeight.w700, c: K.txt),
            items: [for (final o in opts) DropdownMenuItem(value: o, child: Text(o))],
            onChanged: (x) {
              if (x != null) f(x);
            },
          ),
        ),
      );

  Widget _radio(bool on, String e, String t, String s, VoidCallback f) => GestureDetector(
        onTap: f,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: on ? const Color(0xFFFFF4E8) : Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: on ? K.orD : const Color(0xFFEFE2C7), width: on ? 2 : 1.4)),
          child: Row(children: [
            Container(width: 46, height: 46, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFFFDF0DF), borderRadius: BorderRadius.circular(14)), child: Text(e, style: const TextStyle(fontSize: 22))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t, style: tx(15, w: FontWeight.w800, c: K.txt)),
                Text(s, style: tx(12, w: FontWeight.w500, c: K.sub)),
              ]),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(shape: BoxShape.circle, color: on ? K.orD : Colors.white, border: Border.all(color: on ? K.orD : const Color(0xFFD9CDB5), width: 2)),
              child: on ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
            ),
          ]),
        ),
      );

  Widget _switchRow(String t, String s, bool v, ValueChanged<bool> f) => Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFEFE2C7))),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t, style: tx(15, w: FontWeight.w800, c: K.txt)),
              Text(s, style: tx(12, w: FontWeight.w500, c: K.sub)),
            ]),
          ),
          Switch(
            value: v,
            onChanged: f,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFF16A34A),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFDCD5C6),
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ]),
      );

  Widget _saveBtn(VoidCallback f) => GestureDetector(
        onTap: saving ? null : f,
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(gradient: K.orGrad, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: K.orD.withValues(alpha: .3), blurRadius: 16, offset: const Offset(0, 6))]),
          child: saving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : Text('Save karein', style: tx(17, w: FontWeight.w800, c: Colors.white)),
        ),
      );
}

/// Nayi category chunne ke liye: Service / Product / Other + tiles
class _CatChooser extends StatefulWidget {
  const _CatChooser();
  @override
  State<_CatChooser> createState() => _CatChooserState();
}

class _CatChooserState extends State<_CatChooser> {
  String ty = Store.i.vendor?['ty'] ?? 'svc';
  @override
  Widget build(BuildContext context) {
    final t = Catalog.types[ty]!;
    return Container(
      height: MediaQuery.of(context).size.height * .8,
      decoration: const BoxDecoration(color: K.cream, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(children: [
        const SizedBox(height: 10),
        Container(width: 44, height: 5, decoration: BoxDecoration(color: const Color(0xFFD9D2C3), borderRadius: BorderRadius.circular(3))),
        Padding(padding: const EdgeInsets.fromLTRB(18, 12, 18, 10), child: Align(alignment: Alignment.centerLeft, child: Text('Category chuniye', style: sf(25)))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: K.sand, borderRadius: BorderRadius.circular(99)),
            child: Row(children: [
              for (final k in ['svc', 'prd', 'oth'])
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => ty = k),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: ty == k ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(99)),
                      child: Text('${Catalog.types[k]!.e} ${Catalog.types[k]!.l}', style: tx(13.5, w: FontWeight.w800, c: ty == k ? K.orD : const Color(0xFF8A7A5A))),
                    ),
                  ),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: GridView.count(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.1,
            children: [
              for (final c in t.cats)
                GestureDetector(
                  onTap: () => Navigator.pop(context, c),
                  child: Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: K.tile, width: 2)),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(c.e, style: const TextStyle(fontSize: 26)),
                      const SizedBox(height: 4),
                      Text(c.n, style: tx(12.5, w: FontWeight.w800, c: K.txt), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('${c.subs.length} options', style: tx(10.5, w: FontWeight.w600, c: const Color(0xFF9A907C))),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ]),
    );
  }
}
