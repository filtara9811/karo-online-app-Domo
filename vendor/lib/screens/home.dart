import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../catalog.dart';
import '../data.dart';
import '../ring.dart';
import '../shop.dart';
import '../theme.dart';
import 'incoming.dart';
import 'myshop.dart';
import 'requests.dart';
import 'profile.dart';
import 'settings.dart';
import 'soon.dart';

/// Vendor ka main screen — upar Chrome jaisi tab patti (Leads | My Shop), swipe se badlein
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _pc = PageController();
  double page = 0;
  StreamSubscription<Req>? _sub;
  StreamSubscription<int>? _bg;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pc.addListener(() => setState(() => page = _pc.page ?? 0));
    Store.i.startPolling();
    Shop.i.load();
    _sub = Store.i.newLead.stream.listen(_incoming);
    _bg = Ring.i.leadFromBg.stream.listen((_) => Store.i.refresh());
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Ring.i.askNotifications();
      if (Store.i.online) await Ring.i.setOnline(true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _bg?.cancel();
    Store.i.stopPolling();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      Store.i.startPolling();
    } else if (s == AppLifecycleState.paused) {
      Store.i.stopPolling();
    }
  }

  bool _showing = false;
  Future<void> _incoming(Req r) async {
    if (_showing || !mounted) return;
    _showing = true;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => IncomingScreen(req: r), fullscreenDialog: true));
    _showing = false;
  }

  void _go(int i) {
    HapticFeedback.selectionClick();
    _pc.animateToPage(i, duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: ListenableBuilder(
        listenable: Listenable.merge([Store.i, Shop.i]),
        builder: (context, _) {
          final s = Store.i;
          return Scaffold(
            backgroundColor: K.iv,
            body: Column(children: [
              _ChromeTabs(page: page, leads: s.inbox.length + s.count('new'), shop: Shop.i.todayBills, onTap: _go),
              Expanded(
                child: PageView(
                  controller: _pc,
                  children: const [LeadsTab(), MyShopTab()],
                ),
              ),
            ]),
            bottomNavigationBar: _BottomNav(
              leads: s.inbox.length,
              orders: Shop.i.todayBills,
              onKhata: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SoonScreen(title: 'Khata Book', step: 4, icon: Icons.menu_book_rounded))),
              onRequests: () => openRequests(context),
              onProfile: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
            ),
          );
        },
      ),
    );
  }
}

/// Chrome browser jaisi tab patti: chuna hua tab cream (neeche body se juda), doosra kaala
class _ChromeTabs extends StatelessWidget {
  final double page;
  final int leads, shop;
  final ValueChanged<int> onTap;
  const _ChromeTabs({required this.page, required this.leads, required this.shop, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final t = page.clamp(0.0, 1.0);
    Widget tab(int i, IconData ic, String label, int n, Color badge) {
      final on = (i == 0 ? 1 - t : t);
      final fg = Color.lerp(const Color(0xFFE9B04A), K.ink, on)!;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onTap(i),
          child: Row(mainAxisAlignment: i == 0 ? MainAxisAlignment.start : MainAxisAlignment.end, children: [
            if (i == 0) const SizedBox(width: 22),
            Icon(ic, size: 21, color: fg),
            const SizedBox(width: 8),
            Text(label, style: tx(17, w: FontWeight.w800, c: fg)),
            const SizedBox(width: 8),
            if (n > 0)
              Container(
                constraints: const BoxConstraints(minWidth: 24),
                height: 24,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: badge, shape: n > 9 ? BoxShape.rectangle : BoxShape.circle, borderRadius: n > 9 ? BorderRadius.circular(12) : null),
                child: Text('$n', style: tx(12, w: FontWeight.w800, c: Colors.white)),
              ),
            if (i == 1) const SizedBox(width: 22),
          ]),
        ),
      );
    }

    return Column(children: [
      Container(height: top, color: const Color(0xFFEFE9DD)),
      SizedBox(
        height: 60,
        child: CustomPaint(
          painter: _TabPainter(t),
          child: Row(children: [
            tab(0, Icons.bolt_rounded, 'Leads', leads, K.ink),
            tab(1, Icons.storefront_outlined, 'My Shop', shop, const Color(0xFFEE6A0D)),
          ]),
        ),
      ),
    ]);
  }
}

class _TabPainter extends CustomPainter {
  final double t; // 0 = Leads chuna, 1 = My Shop chuna
  _TabPainter(this.t);
  @override
  void paint(Canvas c, Size s) {
    // poori patti kaali-bhoori
    final dark = Paint()
      ..shader = const LinearGradient(colors: [Color(0xFF1E160D), Color(0xFF3A2A16)]).createShader(Offset.zero & s);
    c.drawRect(Offset.zero & s, dark);
    // cream tab — Leads chuna ho to baayein, warna daayein. Beech ka dhalaan curve se.
    final w = s.width, h = s.height, r = 26.0, slope = 58.0;
    final split = w * (0.47 + 0.06 * t); // dhalaan ka beech
    final cream = Paint()..color = K.iv;
    final p = Path();
    if (t < .5) {
      final k = 1 - t * 2; // 1 → 0
      final x = split;
      p.moveTo(0, h);
      p.lineTo(0, 0);
      p.lineTo(x - slope / 2 - r, 0);
      p.quadraticBezierTo(x - slope / 2, 0, x - slope / 2 + 10, 14);
      p.cubicTo(x, h * .55, x + slope / 2 - 14, h, x + slope / 2 + r, h);
      p.close();
      cream.color = K.iv.withValues(alpha: 0.3 + 0.7 * k);
    } else {
      final k = (t - .5) * 2; // 0 → 1
      final x = split;
      p.moveTo(w, h);
      p.lineTo(w, 0);
      p.lineTo(x + slope / 2 + r, 0);
      p.quadraticBezierTo(x + slope / 2, 0, x + slope / 2 - 10, 14);
      p.cubicTo(x, h * .55, x - slope / 2 + 14, h, x - slope / 2 - r, h);
      p.close();
      cream.color = K.iv.withValues(alpha: 0.3 + 0.7 * k);
    }
    c.drawShadow(p, Colors.black, 6, false);
    c.drawPath(p, cream);
  }

  @override
  bool shouldRepaint(_TabPainter o) => o.t != t;
}

class _BottomNav extends StatelessWidget {
  final int leads, orders;
  final VoidCallback onKhata, onRequests, onProfile;
  const _BottomNav({required this.leads, required this.orders, required this.onKhata, required this.onRequests, required this.onProfile});

  @override
  Widget build(BuildContext context) {
    Widget side(IconData i, String t, VoidCallback f) => Expanded(
          child: InkWell(
            onTap: f,
            borderRadius: BorderRadius.circular(20),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(i, color: const Color(0xFFB9AD92), size: 24),
              const SizedBox(height: 3),
              Text(t, style: tx(12, c: const Color(0xFFB9AD92))),
            ]),
          ),
        );
    Widget badge(int n, Color c) => n == 0
        ? const SizedBox.shrink()
        : Container(
            constraints: const BoxConstraints(minWidth: 22),
            height: 22,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(11), border: Border.all(color: K.ink, width: 2)),
            child: Text('$n', style: tx(11.5, w: FontWeight.w800, c: Colors.white)),
          );
    return SafeArea(
      top: false,
      child: Container(
        height: 68,
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        decoration: BoxDecoration(color: K.ink, borderRadius: BorderRadius.circular(30), boxShadow: K.shadow(.35)),
        child: Row(children: [
          side(Icons.menu_book_rounded, 'Khata', onKhata),
          SizedBox(
            width: 92,
            child: GestureDetector(
              onTap: onRequests,
              child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                _Pulse(on: leads > 0),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(gradient: K.goldGrad, shape: BoxShape.circle, boxShadow: K.shadow(.45)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.notifications_active_rounded, color: K.ink, size: 22),
                    Text('Requests', style: tx(9.5, w: FontWeight.w800, c: K.ink)),
                  ]),
                ),
                Positioned(top: -2, left: 8, child: badge(orders, K.green)),
                Positioned(top: -2, right: 8, child: badge(leads, K.red)),
              ]),
            ),
          ),
          side(Icons.person_rounded, 'My Profile', onProfile),
        ]),
      ),
    );
  }
}

/// Requests button ke peeche halki dhadkan jab nayi lead ho
class _Pulse extends StatefulWidget {
  final bool on;
  const _Pulse({required this.on});
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.on) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        width: 60 + _c.value * 26,
        height: 60 + _c.value * 26,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: K.goldL.withValues(alpha: 1 - _c.value), width: 2)),
      ),
    );
  }
}


// ================= LEADS TAB =================
class LeadsTab extends StatefulWidget {
  const LeadsTab({super.key});
  @override
  State<LeadsTab> createState() => _LeadsTabState();
}

class _LeadsTabState extends State<LeadsTab> with AutomaticKeepAliveClientMixin {
  String filter = 'all';
  String q = '';
  DateTime? day; // null = sab din
  String range = 'All time';
  bool collapsed = false;

  @override
  bool get wantKeepAlive => true;

  bool _same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  int _earn(Iterable<Req> l) => l.fold(0, (a, b) => a + b.budget);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = Store.i;
    final now = DateTime.now();
    var list = s.leads.where((l) {
      if (day != null && !_same(l.at, day!)) return false;
      if (range == 'Aaj' && !_same(l.at, now)) return false;
      if (range == '7 din' && now.difference(l.at).inDays >= 7) return false;
      if (range == '30 din' && now.difference(l.at).inDays >= 30) return false;
      switch (filter) {
        case 'new':
          if (!(now.difference(l.at).inHours < 24 && l.step == 'accept')) return false;
          break;
        case 'pending':
          if (l.step != 'accept') return false;
          break;
        case 'proc':
          if (!['action', 'working', 'reached'].contains(l.step)) return false;
          break;
        case 'done':
          if (!['done', 'review'].contains(l.step)) return false;
          break;
        case 'skip':
          if (l.step != 'skip') return false;
          break;
      }
      if (q.isNotEmpty && !('${l.name} ${l.service} ${l.area} ${l.need}'.toLowerCase().contains(q.toLowerCase()))) return false;
      return true;
    }).toList();
    list.sort((a, b) => (s.pinned.contains(b.id) ? 1 : 0).compareTo(s.pinned.contains(a.id) ? 1 : 0));
    final todayL = s.leads.where((l) => _same(l.at, now));
    return Stack(children: [
      RefreshIndicator(
        color: K.acc,
        onRefresh: s.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
          children: [
            Row(children: [
              Text('Lead Bazar', style: tx(21, w: FontWeight.w800)),
              const SizedBox(width: 10),
              Text(s.online ? '${s.inbox.length} khuli' : 'offline', style: tx(13.5, w: FontWeight.w800, c: s.online ? K.green : K.muted)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => collapsed = !collapsed),
                child: AnimatedRotation(
                  turns: collapsed ? .5 : 0,
                  duration: const Duration(milliseconds: 260),
                  child: Container(width: 52, height: 52, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: K.shadow(.1)), child: const Icon(Icons.keyboard_arrow_down_rounded, size: 30, color: K.ink)),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            if (s.inbox.isNotEmpty) ...[_bazarStrip(s), const SizedBox(height: 12)],
            AnimatedSize(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              child: collapsed ? const SizedBox(width: double.infinity) : _topCard(s),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Text('AAJ KI LEADS', style: tx(12.5, w: FontWeight.w800, c: const Color(0xFF7A7058)).copyWith(letterSpacing: 1)),
              const Spacer(),
              Text('${todayL.length} aayi · ${todayL.where((l) => ['done', 'review'].contains(l.step)).length} pakki', style: tx(13, w: FontWeight.w800, c: const Color(0xFF15803D))),
            ]),
            const SizedBox(height: 10),
            _days(s),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: K.line)),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => q = v),
                    style: tx(14),
                    decoration: InputDecoration(
                      hintText: 'Search leads by service',
                      hintStyle: tx(14, c: K.muted, w: FontWeight.w500),
                      prefixIcon: const Icon(Icons.search_rounded, color: K.ink2),
                      filled: true,
                      fillColor: const Color(0xFFF7F2E8),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: (v) => setState(() {
                    range = v;
                    day = null;
                  }),
                  itemBuilder: (_) => [for (final r in const ['Aaj', '7 din', '30 din', 'All time']) PopupMenuItem(value: r, child: Text(r, style: tx(14, w: FontWeight.w700)))],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                    decoration: BoxDecoration(color: const Color(0xFFF7F2E8), borderRadius: BorderRadius.circular(16)),
                    child: Row(children: [
                      const Icon(Icons.calendar_today_outlined, size: 16, color: K.ink2),
                      const SizedBox(width: 6),
                      Text(day == null ? range : '${day!.day}/${day!.month}', style: tx(14, w: FontWeight.w800)),
                      const Icon(Icons.arrow_drop_down_rounded, color: K.muted),
                    ]),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 42,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                _chip('all', 'Sab', s.leads.length, null),
                _chip('new', 'New leads', s.count('new'), '✨'),
                _chip('pending', 'Pending leads', s.count('pending'), '⏳'),
                _chip('proc', 'Processing', s.count('chal'), '⚙️'),
                _chip('done', 'Completed', s.count('done'), '✅'),
                _chip('skip', 'Skipped', s.count('skip'), '❌'),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
              child: Text('📌 Kisi lead par lambi press karke use pin karein', style: tx(11.5, w: FontWeight.w600, c: K.muted)),
            ),
            if (list.isNotEmpty)
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: K.line)),
                child: Column(children: [
                  for (var k = 0; k < list.length; k++) ...[
                    LeadCard(key: ValueKey(list[k].id), lead: list[k]),
                    if (k < list.length - 1) const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF0EADF)),
                  ],
                ]),
              )
            else
              Padding(
                padding: const EdgeInsets.all(30),
                child: Column(children: [
                  const Text('📭', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 8),
                  Text(s.leads.isEmpty ? 'Abhi koi lead nahi' : 'Is filter me koi lead nahi', textAlign: TextAlign.center, style: tx(14, w: FontWeight.w700, c: K.muted)),
                  if (s.leads.isEmpty) Text('Customer request bhejte hi yahan aayegi aur ghanti bajegi', textAlign: TextAlign.center, style: tx(12, c: K.muted)),
                ]),
              ),
            if (s.error != null)
              Padding(padding: const EdgeInsets.only(top: 8), child: Text('⚠️ Server se judne me dikkat: ${s.error}', textAlign: TextAlign.center, style: tx(11.5, c: K.red))),
          ],
        ),
      ),
      Positioned(
        right: 16,
        bottom: 16,
        child: GestureDetector(
          onTap: () => _newLead(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF8A2B), Color(0xFFF26A12)]), borderRadius: BorderRadius.circular(99), boxShadow: [BoxShadow(color: const Color(0xFFF26A12).withValues(alpha: .4), blurRadius: 18, offset: const Offset(0, 6))]),
            child: Text('＋ New lead', style: tx(16.5, w: FontWeight.w800, c: Colors.white)),
          ),
        ),
      ),
    ]);
  }

  // ---------- upar ka safed card: wallet, settings, ginti, chart ----------
  Widget _topCard(Store s) {
    final st = s.settings;
    final auto = st['accept'] == 'auto';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), border: Border.all(color: K.line), boxShadow: K.shadow(.04)),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
          decoration: BoxDecoration(gradient: K.darkCard, borderRadius: BorderRadius.circular(22)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              TweenAnimationBuilder<double>(
                tween: Tween(end: s.coins.toDouble()),
                duration: const Duration(milliseconds: 600),
                builder: (_, v, __) => Text('${v.round()}', style: tx(36, w: FontWeight.w800, c: Colors.white)),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _wallet(context, s),
                child: Row(children: [
                  Text('coins available', style: tx(14, w: FontWeight.w700, c: K.goldL)),
                  const Icon(Icons.arrow_drop_down_rounded, color: K.goldL),
                ]),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () async {
                  final v = !s.online;
                  await s.setOnline(v);
                  await Ring.i.setOnline(v);
                  if (mounted) toast(context, v ? 'Aap ONLINE hain — nayi request par ghanti bajegi' : 'Offline — requests nahi aayengi');
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.fromLTRB(14, 7, 6, 7),
                  decoration: BoxDecoration(color: s.online ? K.green.withValues(alpha: .18) : Colors.white10, borderRadius: BorderRadius.circular(30), border: Border.all(color: s.online ? K.green : Colors.white24, width: 1.5)),
                  child: Row(children: [
                    Text(s.online ? 'Online' : 'Offline', style: tx(14, w: FontWeight.w800, c: s.online ? const Color(0xFF6EE7A8) : Colors.white70)),
                    const SizedBox(width: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 44,
                      height: 24,
                      padding: const EdgeInsets.all(2),
                      alignment: s.online ? Alignment.centerRight : Alignment.centerLeft,
                      decoration: BoxDecoration(color: s.online ? K.green : Colors.white24, borderRadius: BorderRadius.circular(20)),
                      child: Container(width: 20, height: 20, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                    ),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.savings_outlined, size: 14, color: K.goldL),
              const SizedBox(width: 6),
              Text('LEAD WALLET', style: tx(12, w: FontWeight.w800, c: K.goldL).copyWith(letterSpacing: 1)),
              if (auto) ...[
                const SizedBox(width: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: K.green, borderRadius: BorderRadius.circular(6)), child: Text('⚡ AUTO', style: tx(9.5, w: FontWeight.w800, c: Colors.white))),
              ],
            ]),
          ]),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => openLeadSettings(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(color: const Color(0xFFFFFDF8), borderRadius: BorderRadius.circular(30), border: Border.all(color: const Color(0xFFF0E3C8), width: 1.5)),
            child: Row(children: [
              const Icon(Icons.settings_outlined, size: 20, color: K.ink),
              const SizedBox(width: 10),
              Text('Lead settings', style: tx(15.5, w: FontWeight.w800)),
              const Spacer(),
              Flexible(
                child: Text(
                  s.cats.isEmpty ? 'Category chunein' : '${s.cats.length} category · ${s.subs.length} service',
                  style: tx(12, w: FontWeight.w700, c: K.muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: K.muted),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          _stat('all', '${s.leads.length}', 'Kul leads', Icons.inbox_outlined, K.ink, const Color(0xFFB45309)),
          _stat('pending', '${s.count('pending')}', 'Pending', Icons.hourglass_empty_rounded, const Color(0xFFEA580C), const Color(0xFFEA580C)),
          _stat('proc', '${s.count('chal')}', 'Chal rahi', Icons.build_outlined, const Color(0xFF2563EB), const Color(0xFFB45309)),
          _stat('done', '${s.count('done')}', 'Done', Icons.check_circle_outline_rounded, const Color(0xFF15803D), const Color(0xFFB45309)),
        ]),
        const SizedBox(height: 12),
        _chart(s),
      ]),
    );
  }

  Widget _stat(String k, String n, String t, IconData i, Color c, Color ic) {
    final sel = filter == k;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => filter = k),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: sel ? K.ink : const Color(0xFFF0E3C8), width: sel ? 2.5 : 1.5)),
          child: Column(children: [
            Icon(i, color: ic, size: 22),
            const SizedBox(height: 4),
            Text(n, style: tx(26, w: FontWeight.w800, c: c)),
            Text(t, style: tx(12, w: FontWeight.w700, c: const Color(0xFF6E6656))),
          ]),
        ),
      ),
    );
  }

  Widget _chart(Store s) {
    // pichhle 18 din ki leads
    final now = DateTime.now();
    final v = [for (var d = 17; d >= 0; d--) s.leads.where((l) => _same(l.at, now.subtract(Duration(days: d)))).length];
    final mx = v.fold<int>(1, (a, b) => b > a ? b : a);
    return Column(children: [
      const Divider(height: 1, color: Color(0xFFF0EADF)),
      const SizedBox(height: 10),
      SizedBox(
        height: 80,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var k = 0; k < v.length; k++)
            Expanded(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 400 + k * 30),
                curve: Curves.easeOutCubic,
                builder: (_, a, __) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  height: (12 + (v[k] / mx) * 66) * a,
                  decoration: BoxDecoration(color: k >= 9 ? K.ink : const Color(0xFFEADBB8), borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Text('Won · ${s.count('done')} leads', style: tx(13, w: FontWeight.w600, c: const Color(0xFF7A7058))),
        const Spacer(),
        Text('All time', style: tx(13, w: FontWeight.w600, c: const Color(0xFF7A7058))),
      ]),
    ]);
  }

  // ---------- din ki patti + MONTH ----------
  Widget _days(Store s) {
    final now = DateTime.now();
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return SizedBox(
      height: 98,
      child: ListView(scrollDirection: Axis.horizontal, children: [
        for (var d = 0; d < 14; d++)
          Builder(builder: (_) {
            final t = DateTime(now.year, now.month, now.day).subtract(Duration(days: d));
            final l = s.leads.where((x) => _same(x.at, t));
            final on = day != null ? _same(day!, t) : d == 0;
            final done = l.where((x) => ['done', 'review'].contains(x.step)).length;
            return GestureDetector(
              onTap: () => setState(() => day = (day != null && _same(day!, t)) ? null : t),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 64,
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                decoration: BoxDecoration(
                  color: on ? const Color(0xFF1F4D33) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: on ? Colors.transparent : const Color(0xFFF0E3C8), width: 1.5),
                ),
                child: Column(children: [
                  Text(d == 0 ? 'Today' : wd[t.weekday - 1], style: tx(11, w: FontWeight.w700, c: on ? Colors.white70 : K.muted)),
                  Text('${t.day}', style: tx(22, w: FontWeight.w800, c: on ? Colors.white : K.ink, h: 1.1)),
                  Text(inrK(_earn(l)), style: tx(11.5, w: FontWeight.w800, c: on ? const Color(0xFF86EFAC) : const Color(0xFF15803D))),
                  Text('${l.length} lead', style: tx(10, w: FontWeight.w600, c: on ? Colors.white60 : K.muted)),
                  const Spacer(),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(value: l.isEmpty ? 0 : done / l.length, minHeight: 4, backgroundColor: on ? Colors.white24 : const Color(0xFFEFEAE0), color: const Color(0xFF22C55E)),
                  ),
                  const SizedBox(height: 6),
                ]),
              ),
            );
          }),
        GestureDetector(
          onTap: () => _month(s),
          child: Container(
            width: 72,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFF0E3C8), width: 1.5)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.calendar_month_outlined, size: 26, color: K.ink),
              const SizedBox(height: 4),
              Text('MONTH', style: tx(11.5, w: FontWeight.w800, c: K.ink)),
            ]),
          ),
        ),
      ]),
    );
  }

  Future<void> _month(Store s) async {
    final d = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MonthSheet(leads: s.leads),
    );
    if (d != null) setState(() => day = d);
  }

  Widget _chip(String k, String t, int n, String? e) {
    final on = filter == k;
    return GestureDetector(
      onTap: () => setState(() => filter = k),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: on ? K.ink : Colors.white, borderRadius: BorderRadius.circular(99), border: Border.all(color: on ? K.ink : const Color(0xFFEADFC6), width: 1.4)),
        child: Row(children: [
          if (e != null) ...[Text(e, style: const TextStyle(fontSize: 13)), const SizedBox(width: 5)],
          Text(t, style: tx(13.5, w: FontWeight.w800, c: on ? Colors.white : K.ink)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(color: on ? Colors.white24 : const Color(0xFFF3EEE4), borderRadius: BorderRadius.circular(99)),
            child: Text('$n', style: tx(11.5, w: FontWeight.w800, c: on ? Colors.white : K.ink2)),
          ),
        ]),
      ),
    );
  }

  /// ⚡ LEAD BAZAR · N khuli — upar horizontal cards
  Widget _bazarStrip(Store s) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('⚡ LEAD BAZAR · ${s.inbox.length} khuli', style: tx(12, w: FontWeight.w800, c: K.acc).copyWith(letterSpacing: .8)),
        const Spacer(),
        GestureDetector(onTap: () => openRequests(context), child: Text('Sab dekhein ›', style: tx(12, w: FontWeight.w800, c: K.acc))),
      ]),
      const SizedBox(height: 8),
      SizedBox(
        height: 262,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: s.inbox.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) => SizedBox(width: MediaQuery.of(context).size.width * .8, child: _BazarCard(req: s.inbox[i])),
        ),
      ),
    ]);
  }

  void _wallet(BuildContext context, Store s) {
    showModalBottomSheet(
      context: context,
      backgroundColor: K.iv,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('💰 Lead wallet', style: sf(25)),
            const SizedBox(height: 6),
            Text('${s.coins} coins · 1 coin = ₹10 · 1 lead = 1–3 coin', style: tx(13, w: FontWeight.w600, c: K.sub)),
            const SizedBox(height: 14),
            Row(children: [
              for (final n in const [50, 100, 300])
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      Navigator.pop(c);
                      await s.addCoins(n);
                      if (context.mounted) toast(context, '+$n coins (demo) — asli recharge Razorpay se aayega');
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: K.line)),
                      child: Column(children: [
                        Text('+$n', style: tx(20, w: FontWeight.w800)),
                        Text('₹${n * 10}', style: tx(12, w: FontWeight.w700, c: K.muted)),
                      ]),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 10),
            Text('Kul ${s.leads.fold<int>(0, (a, b) => a + b.coins)} coin leads par lage', textAlign: TextAlign.center, style: tx(12, c: K.muted)),
          ]),
        ),
      ),
    );
  }

  Future<void> _newLead(BuildContext context) async {
    final name = TextEditingController(), ph = TextEditingController(), need = TextEditingController(), bud = TextEditingController();
    String svc = Store.i.subs.isNotEmpty ? Store.i.subs.first : 'Apni lead';
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            decoration: const BoxDecoration(color: K.cream, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            child: SafeArea(
              top: false,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: const Color(0xFFD9D2C3), borderRadius: BorderRadius.circular(3)))),
                const SizedBox(height: 12),
                Text('＋ New lead', style: sf(26)),
                Text('Dukaan par aaya / phone aaya grahak — yahan likhein, coin nahi katega', style: tx(12.5, w: FontWeight.w600, c: K.sub)),
                const SizedBox(height: 12),
                _f(name, 'Grahak ka naam'),
                _f(ph, 'Mobile (optional)', num: true),
                SizedBox(
                  height: 40,
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    for (final x in {...Store.i.subs, 'Apni lead'})
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(label: Text(x, style: tx(12.5, w: FontWeight.w700)), selected: svc == x, onSelected: (_) => set(() => svc = x), selectedColor: K.goldL),
                      ),
                  ]),
                ),
                const SizedBox(height: 10),
                _f(need, 'Kya chahiye? (jaise: kal subah AC service)'),
                _f(bud, 'Budget ₹ (optional)', num: true),
                GestureDetector(
                  onTap: () async {
                    if (name.text.trim().isEmpty) {
                      toast(c, 'Naam likhein');
                      return;
                    }
                    Navigator.pop(c);
                    try {
                      await Store.i.addManualLead({'name': name.text.trim(), 'phone': ph.text.trim(), 'service': svc, 'icon': Catalog.iconFor(svc), 'need': need.text.trim(), 'budget': bud.text.trim()});
                      if (context.mounted) toast(context, '✓ Lead jud gayi');
                    } catch (e) {
                      if (context.mounted) toast(context, '⚠️ $e');
                    }
                  },
                  child: Container(
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(gradient: K.orGrad, borderRadius: BorderRadius.circular(16)),
                    child: Text('Lead jodein', style: tx(16.5, w: FontWeight.w800, c: Colors.white)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _f(TextEditingController c, String h, {bool num = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          keyboardType: num ? TextInputType.number : TextInputType.text,
          inputFormatters: num ? [FilteringTextInputFormatter.digitsOnly] : null,
          style: tx(15, w: FontWeight.w600),
          decoration: InputDecoration(
            hintText: h,
            hintStyle: tx(14.5, w: FontWeight.w500, c: const Color(0xFFA79E8C)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFECE4D2), width: 1.5)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: K.or, width: 1.6)),
          ),
        ),
      );
}

/// Mahine ka calendar — har din ki kamai + leads, tap = us din ki leads
class _MonthSheet extends StatefulWidget {
  final List<Req> leads;
  const _MonthSheet({required this.leads});
  @override
  State<_MonthSheet> createState() => _MonthSheetState();
}

class _MonthSheetState extends State<_MonthSheet> {
  late DateTime m = DateTime(DateTime.now().year, DateTime.now().month);
  static const _mn = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  static const _wd = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = DateUtils.getDaysInMonth(m.year, m.month);
    final lead = widget.leads.where((l) => l.at.year == m.year && l.at.month == m.month);
    final pakki = lead.where((l) => ['done', 'review'].contains(l.step)).length;
    final earn = lead.fold<int>(0, (a, b) => a + b.budget);
    final first = DateTime(m.year, m.month, 1).weekday % 7; // Sun = 0
    final isCur = m.year == now.year && m.month == now.month;
    return Container(
      padding: EdgeInsets.fromLTRB(14, 14, 14, 14 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(color: Color(0xFFFFFCF5), borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          _btn(Icons.chevron_left_rounded, () => setState(() => m = DateTime(m.year, m.month - 1))),
          Expanded(child: Text('${_mn[m.month - 1]} ${m.year}', textAlign: TextAlign.center, style: tx(19, w: FontWeight.w800))),
          _btn(Icons.chevron_right_rounded, isCur ? null : () => setState(() => m = DateTime(m.year, m.month + 1))),
          const SizedBox(width: 8),
          _btn(Icons.close_rounded, () => Navigator.pop(context)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _sum('LEAD SE KAMAI', inr(earn)),
          _sum('LEADS', '${lead.length}'),
          _sum('PAKKI', '$pakki'),
        ]),
        const SizedBox(height: 10),
        Row(children: [for (final w in _wd) Expanded(child: Text(w, textAlign: TextAlign.center, style: tx(10.5, w: FontWeight.w700, c: K.muted)))]),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: .82,
          children: [
            for (var k = 0; k < first; k++) const SizedBox(),
            for (var d = 1; d <= days; d++)
              Builder(builder: (_) {
                final t = DateTime(m.year, m.month, d);
                final l = widget.leads.where((x) => x.at.year == t.year && x.at.month == t.month && x.at.day == d);
                final fut = t.isAfter(now);
                final today = isCur && d == now.day;
                return GestureDetector(
                  onTap: fut ? null : () => Navigator.pop(context, t),
                  child: Opacity(
                    opacity: fut ? .35 : 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: today ? const Color(0xFF1F4D33) : (l.isNotEmpty ? Colors.white : const Color(0xFFFAF7F0)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: today ? Colors.transparent : const Color(0xFFEFE6D2)),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(_wd[t.weekday % 7], style: tx(8.5, w: FontWeight.w600, c: today ? Colors.white60 : K.muted)),
                        Text('$d', style: tx(15, w: FontWeight.w800, c: today ? Colors.white : K.ink)),
                        Text(l.isEmpty ? '·' : inrK(l.fold<int>(0, (a, b) => a + b.budget)), style: tx(8.5, w: FontWeight.w800, c: today ? const Color(0xFF86EFAC) : const Color(0xFF15803D))),
                      ]),
                    ),
                  ),
                );
              }),
          ],
        ),
        const SizedBox(height: 10),
        Text('Kisi bhi date par tap karein — us din ke saare leads khulenge', style: tx(11.5, w: FontWeight.w600, c: K.muted)),
      ]),
    );
  }

  Widget _sum(String l, String v) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFEFE6D2))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l, style: tx(9.5, w: FontWeight.w800, c: K.muted).copyWith(letterSpacing: .5)),
            FittedBox(child: Text(v, style: tx(18, w: FontWeight.w800))),
          ]),
        ),
      );

  Widget _btn(IconData i, VoidCallback? f) => GestureDetector(
        onTap: f,
        child: Container(width: 38, height: 38, decoration: BoxDecoration(color: const Color(0xFFF1ECE2), borderRadius: BorderRadius.circular(12)), child: Icon(i, color: f == null ? K.muted : K.ink)),
      );
}

/// Lead Bazar ka khula card — timer, kitno ne li, budget, Accept · N coin
class _BazarCard extends StatefulWidget {
  final Req req;
  const _BazarCard({required this.req});
  @override
  State<_BazarCard> createState() => _BazarCardState();
}

class _BazarCardState extends State<_BazarCard> {
  Timer? _t;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.req;
    final left = r.left;
    final mm = left.isNegative ? '00:00' : '${left.inMinutes.toString().padLeft(2, '0')}:${(left.inSeconds % 60).toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFF1D7B8), width: 1.5), boxShadow: K.shadow(.06)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 40, height: 40, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFFFFF1DE), borderRadius: BorderRadius.circular(12)), child: Text(r.icon, style: const TextStyle(fontSize: 20))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.name, style: tx(15, w: FontWeight.w800), overflow: TextOverflow.ellipsis),
              Text('${r.service}${r.area.isNotEmpty ? ' · ${r.area.split(',').first}' : ''}', style: tx(11.5, c: K.muted), overflow: TextOverflow.ellipsis),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('⏱ $mm', style: tx(12.5, w: FontWeight.w800, c: K.acc)),
            Text('${r.taken}/${r.slots} vendor', style: tx(11, c: K.muted)),
          ]),
        ]),
        const SizedBox(height: 8),
        Text('${r.name} ne ${hm(r.at)} par bheja${r.area.isNotEmpty ? ' · 📍 ${r.area}' : ''}', style: tx(11, c: K.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFFAF6EC), borderRadius: BorderRadius.circular(12)),
          child: Text('"${r.need.isEmpty ? '${r.service} chahiye' : r.need}"', style: tx(13, w: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(height: 8),
        Row(children: [
          _kv('Budget', r.budget > 0 ? '₹${r.budget}' : '—'),
          _kv('Lead kitno ko', '${r.taken} ne li · ${r.slots - r.taken} baaki'),
          _kv('Band hogi', '$mm me'),
        ]),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            onPressed: busy
                ? null
                : () async {
                    setState(() => busy = true);
                    final err = await Store.i.accept(r);
                    if (!context.mounted) return;
                    setState(() => busy = false);
                    toast(context, err ?? '✓ ${r.coins} coin kata — ${r.name} ki lead aapki');
                  },
            style: ElevatedButton.styleFrom(backgroundColor: K.green, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : Text('✓ Accept · ${r.coins} coin', style: tx(15, w: FontWeight.w800, c: Colors.white)),
          ),
        ),
        const SizedBox(height: 4),
        Center(child: Text('Accept ke baad naam, number dikhega · call kar sakte hain', style: tx(10.5, c: K.muted))),
      ]),
    );
  }

  Widget _kv(String k, String v) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: tx(10, c: K.muted)),
          Text(v, style: tx(11.5, w: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      );
}


/// Lead card — prototype jaisa: gol avatar + chhota icon, naam · service, zaroorat, status pill ▾,
/// daayein samay + "Accepted", neeche 5 kadam: Accept → Action → Working → Done → Review
class LeadCard extends StatefulWidget {
  final Req lead;
  const LeadCard({super.key, required this.lead});
  @override
  State<LeadCard> createState() => _LeadCardState();
}

class _LeadCardState extends State<LeadCard> {
  bool open = false;

  static const _pill = {
    'accept': ['🧾', 'Pending order', Color(0xFF7C3AED), Color(0xFFF1E9FE)],
    'action': ['⚙️', 'Processing', Color(0xFF2563EB), Color(0xFFE8F0FE)],
    'working': ['⚙️', 'Processing', Color(0xFF2563EB), Color(0xFFE8F0FE)],
    'reached': ['⚙️', 'Processing', Color(0xFF2563EB), Color(0xFFE8F0FE)],
    'done': ['✅', 'Completed', Color(0xFF15803D), Color(0xFFE7F7EE)],
    'review': ['✅', 'Completed', Color(0xFF15803D), Color(0xFFE7F7EE)],
    'skip': ['❌', 'Skipped', Color(0xFFDC2626), Color(0xFFFDECEC)],
  };

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'abhi';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  Future<void> _menu(Req l) async {
    final v = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: K.iv,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Text('Lead ka status', style: tx(17, w: FontWeight.w800)),
          const SizedBox(height: 6),
          for (final s in [...kSteps, 'skip'])
            ListTile(
              leading: Text(_pill[s]![0] as String, style: const TextStyle(fontSize: 20)),
              title: Text('${kStepLabel[s]}', style: tx(15, w: FontWeight.w700)),
              trailing: l.step == s ? const Icon(Icons.check_circle_rounded, color: K.green) : null,
              onTap: () => Navigator.pop(c, s),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (v != null) Store.i.setStep(l, v);
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lead;
    final p = _pill[l.step] ?? _pill['accept']!;
    final skip = l.step == 'skip';
    final done = ['done', 'review'].contains(l.step);
    final pinned = Store.i.pinned.contains(l.id);
    return InkWell(
      onTap: () => setState(() => open = !open),
      onLongPress: () {
        HapticFeedback.mediumImpact();
        Store.i.togglePin(l.id);
        toast(context, pinned ? 'Pin hataya' : '📌 Lead pin ho gayi — sabse upar rahegi');
      },
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Stack(clipBehavior: Clip.none, children: [
              CircleAvatar(radius: 27, backgroundColor: const Color(0xFF3A2E27), child: Text(l.initial, style: tx(22, w: FontWeight.w700, c: Colors.white))),
              Positioned(
                right: -4,
                bottom: -4,
                child: Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: const Color(0xFFFFF4D6), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white, width: 2)),
                  child: Text(l.icon, style: const TextStyle(fontSize: 13)),
                ),
              ),
              if (pinned) const Positioned(left: -4, top: -6, child: Text('📌', style: TextStyle(fontSize: 14))),
            ]),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: l.name, style: tx(17, w: FontWeight.w800)),
                    TextSpan(text: ' · ${l.service}', style: tx(12.5, w: FontWeight.w600, c: K.muted)),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(l.need.isEmpty ? '${l.service} chahiye' : l.need, style: tx(14, w: FontWeight.w500, c: const Color(0xFF5B5346)), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _menu(l),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: p[3] as Color, borderRadius: BorderRadius.circular(99)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(p[0] as String, style: const TextStyle(fontSize: 11)),
                      const SizedBox(width: 5),
                      Text(p[1] as String, style: tx(12, w: FontWeight.w800, c: p[2] as Color)),
                      Icon(Icons.arrow_drop_down_rounded, size: 18, color: p[2] as Color),
                    ]),
                  ),
                ),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_ago(l.at), style: tx(12.5, w: FontWeight.w600, c: K.muted)),
              const SizedBox(height: 4),
              Text(skip ? 'Skipped' : (done ? 'Done ✓' : 'Accepted'), style: tx(13, w: FontWeight.w800, c: skip ? K.muted : (done ? const Color(0xFF15803D) : const Color(0xFF2563EB)))),
            ]),
          ]),
          const SizedBox(height: 14),
          Padding(padding: const EdgeInsets.only(left: 6), child: _Steps(step: l.step)),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: open ? _details(l) : const SizedBox(width: double.infinity),
          ),
        ]),
      ),
    );
  }

  Widget _details(Req l) {
    final idx = kSteps.indexOf(l.step);
    final next = idx >= 0 && idx < kSteps.length - 1 ? kSteps[idx + 1] : null;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: K.iv, borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('📍 ${l.area.isEmpty ? '—' : l.area}  ·  🕐 ${hm(l.at)}${l.budget > 0 ? '  ·  💰 ₹${l.budget}' : ''}', style: tx(12.5, w: FontWeight.w600, c: K.ink2)),
            if (l.phone.isNotEmpty) Text('📞 +91 ${l.phone}', style: tx(12.5, w: FontWeight.w800, c: K.ink2)),
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _act(Icons.call_rounded, 'Call', K.green, l.phone.isEmpty ? null : () => launchUrl(Uri.parse('tel:${l.phone}')))),
          const SizedBox(width: 8),
          Expanded(
            child: _act(Icons.chat_rounded, 'WhatsApp', const Color(0xFF25D366), l.phone.isEmpty ? null : () => launchUrl(Uri.parse('https://wa.me/91${l.phone}?text=${Uri.encodeComponent('Namaste ${l.name} ji, Karo Online se aapki ${l.service} request mili hai.')}'), mode: LaunchMode.externalApplication)),
          ),
        ]),
        if (next != null && l.step != 'skip') ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: () => Store.i.setStep(l, next),
              style: ElevatedButton.styleFrom(backgroundColor: K.ink, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: Text('Aage: ${kStepLabel[next]} ›', style: tx(14.5, w: FontWeight.w800, c: Colors.white)),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _act(IconData i, String t, Color c, VoidCallback? f) => ElevatedButton.icon(
        onPressed: f,
        icon: Icon(i, size: 18, color: Colors.white),
        label: Text(t, style: tx(13.5, w: FontWeight.w800, c: Colors.white)),
        style: ElevatedButton.styleFrom(backgroundColor: c, disabledBackgroundColor: c.withValues(alpha: .35), elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      );
}

/// 5 kadam ki patti, naam ke saath
class _Steps extends StatelessWidget {
  final String step;
  const _Steps({required this.step});
  @override
  Widget build(BuildContext context) {
    const labels = ['Accept', 'Action', 'Working', 'Done', 'Review'];
    final skip = step == 'skip';
    var idx = kSteps.indexOf(step == 'reached' ? 'working' : step);
    if (idx < 0) idx = 0;
    const g = Color(0xFF16A34A), o = Color(0xFFF97316), grey = Color(0xFFD6D0C4), red = Color(0xFFDC2626);
    final dots = <Widget>[];
    for (var k = 0; k < 5; k++) {
      Color c;
      Widget? inner;
      bool fill = false;
      if (skip) {
        c = k == 0 ? red : grey;
        fill = k == 0;
        inner = k == 0 ? const Icon(Icons.close_rounded, size: 11, color: Colors.white) : null;
      } else if (k < idx || (k == idx && ['done', 'review'].contains(step))) {
        c = g;
        fill = true;
        inner = const Icon(Icons.check_rounded, size: 11, color: Colors.white);
      } else if (k == idx || (k == idx + 1 && ['done', 'review'].contains(step))) {
        c = o;
      } else {
        c = grey;
      }
      dots.add(Expanded(
        child: Column(children: [
          SizedBox(
            height: 18,
            child: Row(children: [
              Expanded(child: k == 0 ? const SizedBox() : Container(height: 2.5, color: (!skip && k <= idx) ? g : grey)),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(shape: BoxShape.circle, color: fill ? c : Colors.white, border: Border.all(color: c, width: 2.2)),
                child: inner,
              ),
              Expanded(child: k == 4 ? const SizedBox() : Container(height: 2.5, color: (!skip && k < idx) ? g : grey)),
            ]),
          ),
          const SizedBox(height: 4),
          Text(skip && k == 0 ? 'Rejected' : labels[k], style: tx(10.5, w: FontWeight.w700, c: skip ? (k == 0 ? red : const Color(0xFFBDB5A4)) : (k <= idx ? (c == o ? o : g) : const Color(0xFFBDB5A4)))),
        ]),
      ));
    }
    return Row(children: dots);
  }
}
