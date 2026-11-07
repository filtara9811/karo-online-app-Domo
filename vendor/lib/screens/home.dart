import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data.dart';
import '../ring.dart';
import '../theme.dart';
import 'incoming.dart';
import 'myshop.dart';
import 'requests.dart';
import 'profile.dart';
import 'soon.dart';

/// Vendor ka main screen — prototype "Lead Bazar" (Leads | My Shop) + neeche nav
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int tab = 0;
  StreamSubscription<Req>? _sub;
  StreamSubscription<int>? _bg;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Store.i.startPolling();
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.i,
      builder: (context, _) {
        final s = Store.i;
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 14, 8),
                  child: Row(children: [
                    Text('Lead Bazar', style: tx(19, w: FontWeight.w800)),
                    const SizedBox(width: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Text(
                        s.online ? '● online' : '● offline',
                        key: ValueKey(s.online),
                        style: tx(12.5, w: FontWeight.w700, c: s.online ? K.green : K.muted),
                      ),
                    ),
                    const Spacer(),
                    _round(Icons.notifications_none_rounded, () => openRequests(context), badge: s.inbox.length),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _Seg(index: tab, onTap: (i) => setState(() => tab = i)),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    child: tab == 0 ? const LeadsTab(key: ValueKey(0)) : const MyShopTab(key: ValueKey(1)),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: _BottomNav(
            leads: s.inbox.length,
            orders: 0,
            onKhata: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SoonScreen(title: 'Khata Book', step: 4, icon: Icons.menu_book_rounded))),
            onRequests: () => openRequests(context),
            onProfile: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
        );
      },
    );
  }

  Widget _round(IconData i, VoidCallback f, {int badge = 0}) => GestureDetector(
        onTap: f,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: K.shadow(.1)),
            child: Icon(i, color: K.ink, size: 24),
          ),
          if (badge > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: K.red, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white, width: 2)),
                child: Text('$badge', style: tx(10.5, w: FontWeight.w800, c: Colors.white)),
              ),
            ),
        ]),
      );
}

class _Seg extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _Seg({required this.index, required this.onTap});
  @override
  Widget build(BuildContext context) {
    Widget b(int i, IconData ic, String t) => Expanded(
          child: GestureDetector(
            onTap: () => onTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 44,
              decoration: BoxDecoration(color: index == i ? K.ink : Colors.transparent, borderRadius: BorderRadius.circular(13)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(ic, size: 18, color: index == i ? Colors.white : K.muted),
                const SizedBox(width: 7),
                Text(t, style: tx(14.5, w: FontWeight.w800, c: index == i ? Colors.white : K.muted)),
              ]),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFEDE6D6), borderRadius: BorderRadius.circular(16)),
      child: Row(children: [b(0, Icons.bolt_rounded, 'Leads'), b(1, Icons.storefront_rounded, 'My Shop')]),
    );
  }
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

class _LeadsTabState extends State<LeadsTab> {
  String filter = 'sab';
  String q = '';
  int day = -1; // -1 = sab din

  @override
  Widget build(BuildContext context) {
    final s = Store.i;
    final today = DateTime.now();
    bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
    final list = s.leads.where((l) {
      if (day >= 0 && !sameDay(l.at, today.subtract(Duration(days: day)))) return false;
      if (filter == 'pending' && l.step != 'accept') return false;
      if (filter == 'chal' && !['action', 'working', 'reached'].contains(l.step)) return false;
      if (filter == 'done' && !['done', 'review'].contains(l.step)) return false;
      if (q.isNotEmpty && !('${l.name} ${l.service} ${l.area}'.toLowerCase().contains(q.toLowerCase()))) return false;
      return true;
    }).toList();
    return RefreshIndicator(
      color: K.acc,
      onRefresh: s.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
        children: [
          if (s.inbox.isNotEmpty) ...[
            _bazarStrip(s),
            const SizedBox(height: 12),
          ],
          _wallet(context, s),
          const SizedBox(height: 10),
          Box(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            radius: 30,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SoonScreen(title: 'Lead settings', step: 2, icon: Icons.tune_rounded))),
            child: Row(children: [
              const Icon(Icons.tune_rounded, size: 18, color: K.gold),
              const SizedBox(width: 8),
              Text('Lead settings', style: tx(13.5, w: FontWeight.w800)),
              const Spacer(),
              Text(s.subs.take(2).join(', ') + (s.subs.length > 2 ? ' +${s.subs.length - 2}' : ''), style: tx(11.5, c: K.muted)),
              const Icon(Icons.chevron_right_rounded, color: K.muted),
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            _stat('sab', '${s.leads.length}', 'Kul leads', Icons.inbox_rounded, K.ink),
            _stat('pending', '${s.count('pending')}', 'Pending', Icons.hourglass_bottom_rounded, const Color(0xFFD97706)),
            _stat('chal', '${s.count('chal')}', 'Chal rahi', Icons.build_circle_outlined, const Color(0xFF2563EB)),
            _stat('done', '${s.count('done')}', 'Done', Icons.check_circle_outline_rounded, K.green),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Text('AAJ KI LEADS', style: tx(12, w: FontWeight.w800, c: K.muted).copyWith(letterSpacing: 1)),
            const Spacer(),
            Text('${s.leads.where((l) => sameDay(l.at, today)).length} aayi · ${s.leads.where((l) => sameDay(l.at, today) && ['done', 'review'].contains(l.step)).length} pakki', style: tx(12, w: FontWeight.w800, c: K.green)),
          ]),
          const SizedBox(height: 10),
          _dayStrip(s),
          const SizedBox(height: 10),
          TextField(
            onChanged: (v) => setState(() => q = v),
            style: tx(14),
            decoration: InputDecoration(
              hintText: 'Search leads by service, customer',
              hintStyle: tx(13.5, c: K.muted, w: FontWeight.w500),
              prefixIcon: const Icon(Icons.search_rounded, color: K.muted),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: K.line)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: K.line)),
            ),
          ),
          const SizedBox(height: 10),
          for (final l in list) LeadCard(key: ValueKey(l.id), lead: l),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.all(30),
              child: Column(children: [
                const Text('📭', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 8),
                Text(s.leads.isEmpty ? 'Abhi koi lead nahi' : 'Is filter me koi lead nahi', textAlign: TextAlign.center, style: tx(14, w: FontWeight.w700, c: K.muted)),
                if (s.leads.isEmpty)
                  Text('Customer request bhejte hi yahan aayegi aur ghanti bajegi', textAlign: TextAlign.center, style: tx(12, c: K.muted)),
              ]),
            ),
          if (s.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('⚠️ Server se judne me dikkat: ${s.error}', textAlign: TextAlign.center, style: tx(11.5, c: K.red)),
            ),
        ],
      ),
    );
  }

  /// ⚡ LEAD BAZAR · N khuli — upar horizontal cards (prototype jaisa)
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

  Widget _dayStrip(Store s) {
    final now = DateTime.now();
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    Widget chip(int d) {
      final t = now.subtract(Duration(days: d));
      final n = s.leads.where((l) => l.at.year == t.year && l.at.month == t.month && l.at.day == t.day).length;
      final on = day == d;
      return GestureDetector(
        onTap: () => setState(() => day = on ? -1 : d),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 84,
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
          decoration: BoxDecoration(
            gradient: on ? K.darkCard : null,
            color: on ? null : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: on ? Colors.transparent : K.line),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d == 0 ? 'Today ${t.day}' : '${wd[t.weekday - 1]} ${t.day}', style: tx(12.5, w: FontWeight.w800, c: on ? Colors.white : K.ink)),
            Text('$n lead', style: tx(11.5, w: FontWeight.w700, c: on ? K.goldL : K.muted)),
            const SizedBox(height: 5),
            Container(height: 3, width: 26, decoration: BoxDecoration(color: n > 0 ? K.green : K.line, borderRadius: BorderRadius.circular(3))),
          ]),
        ),
      );
    }

    return SizedBox(
      height: 70,
      child: ListView(scrollDirection: Axis.horizontal, children: [
        GestureDetector(
          onTap: () => setState(() => day = -1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 92,
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
            decoration: BoxDecoration(gradient: day == -1 ? K.darkCard : null, color: day == -1 ? null : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: day == -1 ? Colors.transparent : K.line)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('All days', style: tx(12.5, w: FontWeight.w800, c: day == -1 ? Colors.white : K.ink)),
              Text('${s.leads.length} lead', style: tx(11.5, w: FontWeight.w700, c: day == -1 ? K.goldL : K.muted)),
              const SizedBox(height: 5),
              Container(height: 3, width: 40, decoration: BoxDecoration(color: K.green, borderRadius: BorderRadius.circular(3))),
            ]),
          ),
        ),
        for (var d = 0; d < 14; d++) chip(d),
      ]),
    );
  }

  Widget _wallet(BuildContext context, Store s) {
    return Box(
      gradient: K.darkCard,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: s.coins.toDouble()),
            duration: const Duration(milliseconds: 600),
            builder: (_, v, __) => Text('${v.round()}', style: tx(32, w: FontWeight.w800, c: Colors.white)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text('coins available', style: tx(13.5, w: FontWeight.w700, c: K.goldL))),
          GestureDetector(
            onTap: () async {
              final v = !s.online;
              await s.setOnline(v);
              await Ring.i.setOnline(v);
              if (context.mounted) toast(context, v ? 'Aap ONLINE hain — nayi request par ghanti bajegi' : 'Offline — requests nahi aayengi');
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
              decoration: BoxDecoration(
                color: s.online ? K.green.withValues(alpha: .18) : Colors.white10,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: s.online ? K.green : Colors.white24),
              ),
              child: Row(children: [
                Text(s.online ? 'Online' : 'Offline', style: tx(13, w: FontWeight.w800, c: s.online ? const Color(0xFF6EE7A8) : Colors.white70)),
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 40,
                  height: 22,
                  padding: const EdgeInsets.all(2),
                  alignment: s.online ? Alignment.centerRight : Alignment.centerLeft,
                  decoration: BoxDecoration(color: s.online ? K.green : Colors.white24, borderRadius: BorderRadius.circular(20)),
                  child: Container(width: 18, height: 18, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                ),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFF5B90F), shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('LEAD WALLET', style: tx(11, w: FontWeight.w800, c: K.goldL).copyWith(letterSpacing: 1)),
          const SizedBox(width: 8),
          Expanded(child: Text('1 coin = ₹10 · 1 lead = 1–3 coin', style: tx(10.5, c: Colors.white54), overflow: TextOverflow.ellipsis)),
          GestureDetector(
            onTap: () async {
              await s.addCoins(100);
              if (context.mounted) toast(context, '+100 coins (demo) — asli recharge Razorpay se aayega');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(gradient: K.goldGrad, borderRadius: BorderRadius.circular(20)),
              child: Text('+ Recharge', style: tx(12, w: FontWeight.w800, c: K.ink)),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _stat(String k, String n, String t, IconData i, Color c) {
    final sel = filter == k;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => filter = k),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: sel ? K.ink : K.line, width: sel ? 2 : 1),
          ),
          child: Column(children: [
            Icon(i, color: c, size: 22),
            const SizedBox(height: 4),
            Text(n, style: tx(22, w: FontWeight.w800, c: c)),
            Text(t, style: tx(11, c: K.muted)),
          ]),
        ),
      ),
    );
  }
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

/// Lead card — Happy Food My Orders jaisa: bada icon, ⌄, neeche 6 kadam ki progress patti
class LeadCard extends StatefulWidget {
  final Req lead;
  const LeadCard({super.key, required this.lead});
  @override
  State<LeadCard> createState() => _LeadCardState();
}

class _LeadCardState extends State<LeadCard> {
  bool open = false;

  static const _col = {
    'accept': Color(0xFFD97706),
    'action': Color(0xFF7C3AED),
    'working': Color(0xFF2563EB),
    'reached': Color(0xFF0891B2),
    'done': Color(0xFF2F9E5F),
    'review': Color(0xFFB58A3A),
  };

  String _when(DateTime t) {
    final n = DateTime.now();
    if (t.year == n.year && t.month == n.month && t.day == n.day) return 'Today, ${hm(t)}';
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${t.day} ${m[t.month - 1]}, ${hm(t)}';
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lead;
    final c = _col[l.step] ?? K.acc;
    final idx = kSteps.indexOf(l.step);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => setState(() => open = !open),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: open ? K.goldL : K.line, width: open ? 1.5 : 1),
            boxShadow: K.shadow(open ? .09 : .05),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(
                width: 62,
                height: 62,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFF4E4), Color(0xFFFBE3C4)]),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFF3DDBC)),
                ),
                child: Text(l.icon, style: const TextStyle(fontSize: 30)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.name, style: tx(17, w: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('${l.service}${l.area.isNotEmpty ? ' · ${l.area.split(',').first}' : ''}', style: tx(13.5, w: FontWeight.w600, c: K.ink2), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: '${_when(l.at)} • ', style: tx(12, c: K.muted, w: FontWeight.w500)),
                      TextSpan(text: kStepLabel[l.step] ?? l.step, style: tx(12, w: FontWeight.w800, c: c)),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: open ? .5 : 0,
                duration: const Duration(milliseconds: 220),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(color: Color(0xFFEFEBE3), shape: BoxShape.circle),
                  child: const Icon(Icons.keyboard_arrow_down_rounded, color: K.gold, size: 26),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            _StepBar(idx: idx < 0 ? 0 : idx, icon: l.icon),
            const SizedBox(height: 6),
            Row(children: [
              Text('Abhi: ${kStepLabel[l.step]}', style: tx(11.5, w: FontWeight.w800, c: c)),
              const Spacer(),
              Text('${(idx < 0 ? 0 : idx) + 1}/6', style: tx(11.5, w: FontWeight.w700, c: K.muted)),
            ]),
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: open ? _details(context, l) : const SizedBox(width: double.infinity),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _details(BuildContext context, Req l) {
    final idx = kSteps.indexOf(l.step);
    final next = idx >= 0 && idx < kSteps.length - 1 ? kSteps[idx + 1] : null;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: K.iv, borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.need.isEmpty ? '${l.service} chahiye' : l.need, style: tx(14, w: FontWeight.w700)),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.location_on_rounded, size: 14, color: K.red),
              const SizedBox(width: 3),
              Expanded(child: Text('${l.area.isEmpty ? '—' : l.area} · ${ago(l.at)}${l.budget > 0 ? ' · Budget ₹${l.budget}' : ''}', style: tx(12, c: K.muted), overflow: TextOverflow.ellipsis)),
            ]),
            if (l.phone.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('📞 +91 ${l.phone}', style: tx(12.5, w: FontWeight.w800, c: K.ink2)),
            ],
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
        if (next != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: () => Store.i.setStep(l, next),
              style: ElevatedButton.styleFrom(backgroundColor: K.ink, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: Text('Aage: ${kStepLabel[next]} ›', style: tx(14.5, w: FontWeight.w800, c: Colors.white)),
            ),
          ),
        ],
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final st in kSteps)
            GestureDetector(
              onTap: () => Store.i.setStep(l, st),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: l.step == st ? (_col[st] ?? K.acc).withValues(alpha: .12) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: (_col[st] ?? K.acc).withValues(alpha: l.step == st ? 1 : .3), width: 1.3),
                ),
                child: Text(kStepLabel[st]!, style: tx(11.5, w: FontWeight.w800, c: _col[st] ?? K.acc)),
              ),
            ),
        ]),
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

/// 6 kadam: Accept → Action → Working → Pahunch gaye → Done → Review
class _StepBar extends StatelessWidget {
  final int idx;
  final String icon;
  const _StepBar({required this.idx, required this.icon});

  static const g = Color(0xFF2F9E5F), grey = Color(0xFFD9D4C8);
  static const _ic = [Icons.person_rounded, Icons.bolt_rounded, Icons.build_rounded, Icons.location_on_rounded, Icons.check_rounded, Icons.star_rounded];

  @override
  Widget build(BuildContext context) {
    final kids = <Widget>[];
    for (var k = 0; k < 6; k++) {
      final done = k < idx, cur = k == idx;
      final c = done ? g : (cur ? (k == 5 ? const Color(0xFFB58A3A) : (k == 4 ? g : const Color(0xFF2563EB))) : grey);
      kids.add(_dot(_ic[k], c, filled: done || cur, pulse: cur && k < 4));
      if (k < 5) {
        kids.add(Expanded(
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: LinearGradient(colors: [(k < idx ? g : grey).withValues(alpha: .8), (k + 1 <= idx ? g : grey).withValues(alpha: .8)]),
            ),
          ),
        ));
      }
    }
    return SizedBox(height: 30, child: Row(children: kids));
  }

  Widget _dot(IconData i, Color c, {bool filled = false, bool pulse = false}) => Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: filled ? c : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: filled ? Colors.white : c, width: filled ? 2.2 : 1.6),
          boxShadow: [BoxShadow(color: (filled ? c : Colors.black).withValues(alpha: pulse ? .45 : .12), blurRadius: pulse ? 12 : 5, spreadRadius: pulse ? 2 : 0)],
        ),
        child: Icon(i, size: 15, color: filled ? Colors.white : c),
      );
}
