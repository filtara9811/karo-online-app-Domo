import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data.dart';
import '../ring.dart';
import '../theme.dart';
import 'requests.dart';
import 'profile.dart';
import 'soon.dart';

/// Vendor ka main screen — prototype "Lead Bazar" (Leads | My Shop) + neeche nav
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Ring.i.askNotifications();
      if (Store.i.online) await Ring.i.setOnline(true);
    });
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
                    Text('${s.online ? 5 : 0} online', style: tx(12.5, w: FontWeight.w700, c: K.green)),
                    const Spacer(),
                    _round(Icons.notifications_none_rounded, () => openRequests(context)),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _Seg(index: tab, onTap: (i) => setState(() => tab = i)),
                ),
                const SizedBox(height: 10),
                Expanded(child: tab == 0 ? const LeadsTab() : const MyShopTab()),
              ],
            ),
          ),
          bottomNavigationBar: _BottomNav(
            leads: s.pendingLeads.length,
            orders: s.pendingOrders.length,
            onKhata: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SoonScreen(title: 'Khata Book', step: 4, icon: Icons.menu_book_rounded))),
            onRequests: () => openRequests(context),
            onProfile: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
        );
      },
    );
  }

  Widget _round(IconData i, VoidCallback f) => GestureDetector(
        onTap: f,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: K.shadow(.1)),
          child: Icon(i, color: K.ink, size: 24),
        ),
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

// ================= LEADS TAB =================
class LeadsTab extends StatefulWidget {
  const LeadsTab({super.key});
  @override
  State<LeadsTab> createState() => _LeadsTabState();
}

class _LeadsTabState extends State<LeadsTab> {
  String filter = 'sab';
  String q = '';

  @override
  Widget build(BuildContext context) {
    final s = Store.i;
    final list = s.leads.where((l) {
      if (filter == 'naya' && l.status != 'chal') return false;
      if (filter == 'pending' && l.status != 'pending') return false;
      if (q.isNotEmpty && !('${l.name} ${l.service} ${l.area}'.toLowerCase().contains(q.toLowerCase()))) return false;
      return true;
    }).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
      children: [
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
            const Icon(Icons.chevron_right_rounded, color: K.muted),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          _stat('${s.leads.length}', 'Kul leads', Icons.inbox_rounded, K.ink, sel: true),
          _stat('${s.count('pending')}', 'Pending', Icons.hourglass_bottom_rounded, const Color(0xFFD97706)),
          _stat('${s.count('chal')}', 'Chal rahi', Icons.build_circle_outlined, const Color(0xFF2563EB)),
          _stat('${s.count('done')}', 'Done', Icons.check_circle_outline_rounded, K.green),
        ]),
        const SizedBox(height: 12),
        _chart(s),
        const SizedBox(height: 16),
        Row(children: [
          Text('AAJ KI LEADS', style: tx(12, w: FontWeight.w800, c: K.muted).copyWith(letterSpacing: 1)),
          const Spacer(),
          Text('${s.count('chal')} aayi · ${s.count('done')} pakki', style: tx(12, w: FontWeight.w800, c: K.green)),
        ]),
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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _chip('sab', 'Sab', s.leads.length),
            _chip('naya', 'Chal rahi', s.count('chal')),
            _chip('pending', 'Pending', s.count('pending')),
          ]),
        ),
        const SizedBox(height: 10),
        for (final l in list) LeadCard(lead: l),
        if (list.isEmpty)
          Padding(padding: const EdgeInsets.all(30), child: Text('Koi lead nahi mili', textAlign: TextAlign.center, style: tx(13, c: K.muted))),
      ],
    );
  }

  Widget _wallet(BuildContext context, Store s) {
    return Box(
      gradient: K.darkCard,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('${s.coins}', style: tx(32, w: FontWeight.w800, c: Colors.white)),
          const SizedBox(width: 8),
          Expanded(child: Text('coins available', style: tx(13.5, w: FontWeight.w700, c: K.goldL))),
          GestureDetector(
            onTap: () async {
              final v = !s.online;
              s.setOnline(v);
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
                Container(
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
          const Spacer(),
          GestureDetector(
            onTap: () {
              s.addCoins(100);
              toast(context, '+100 coins (demo) — asli recharge chaaran 2 me');
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

  Widget _stat(String n, String t, IconData i, Color c, {bool sel = false}) => Expanded(
        child: Container(
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
      );

  Widget _chart(Store s) {
    const v = [2, 3, 2, 4, 3, 5, 6, 7, 9, 8, 10, 12, 11, 14];
    return Box(
      child: Column(children: [
        SizedBox(
          height: 70,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var k = 0; k < v.length; k++)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: 8 + v[k] / 14 * 62,
                  decoration: BoxDecoration(color: k > 7 ? K.ink : K.goldL, borderRadius: BorderRadius.circular(5)),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Text('Won · ${s.count('done') + s.count('chal')} leads', style: tx(12, c: K.muted)),
          const Spacer(),
          Text('All time', style: tx(12, c: K.muted)),
        ]),
      ]),
    );
  }

  Widget _chip(String k, String t, int n) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => setState(() => filter = k),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: filter == k ? K.ink : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: filter == k ? K.ink : K.line),
            ),
            child: Row(children: [
              Text(t, style: tx(13, w: FontWeight.w800, c: filter == k ? Colors.white : K.ink)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: filter == k ? Colors.white24 : K.iv, borderRadius: BorderRadius.circular(10)),
                child: Text('$n', style: tx(11, w: FontWeight.w800, c: filter == k ? Colors.white : K.muted)),
              ),
            ]),
          ),
        ),
      );
}

class LeadCard extends StatelessWidget {
  final Req lead;
  const LeadCard({super.key, required this.lead});

  static const _st = {
    'chal': ['Chal rahi', Color(0xFF2563EB), Color(0xFFEAF1FF)],
    'done': ['Done', Color(0xFF2F9E5F), Color(0xFFE7F7EE)],
    'pending': ['Pending', Color(0xFFD97706), Color(0xFFFFF4DC)],
  };

  @override
  Widget build(BuildContext context) {
    final st = _st[lead.status] ?? _st['chal']!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Box(
        padding: const EdgeInsets.all(12),
        onTap: () => _sheet(context),
        child: Row(children: [
          CircleAvatar(radius: 22, backgroundColor: const Color(0xFFFFF1DE), child: Icon(lead.icon, color: K.acc, size: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(lead.name, style: tx(15, w: FontWeight.w800), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 6),
                Text('· ${lead.service}', style: tx(12, c: K.muted)),
              ]),
              const SizedBox(height: 2),
              Text('${lead.area} · ${lead.km.toStringAsFixed(1)} km', style: tx(11.5, c: K.muted, w: FontWeight.w500), overflow: TextOverflow.ellipsis),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(ago(lead.at), style: tx(11, c: K.muted)),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: st[2] as Color, borderRadius: BorderRadius.circular(10)),
              child: Text(st[0] as String, style: tx(10.5, w: FontWeight.w800, c: st[1] as Color)),
            ),
          ]),
        ]),
      ),
    );
  }

  void _sheet(BuildContext context) {
    showDialog(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              CircleAvatar(radius: 24, backgroundColor: const Color(0xFFFFF1DE), child: Icon(lead.icon, color: K.acc)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(lead.name, style: tx(17, w: FontWeight.w800)),
                  Text(lead.service, style: tx(12.5, c: K.muted)),
                ]),
              ),
              IconButton(onPressed: () => Navigator.pop(c), icon: const Icon(Icons.close_rounded)),
            ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: K.iv, borderRadius: BorderRadius.circular(14)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(lead.need, style: tx(14, w: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('${lead.area} · ${lead.km.toStringAsFixed(1)} km · ${ago(lead.at)}', style: tx(12, c: K.muted)),
              ]),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _act(Icons.call_rounded, 'Call', K.green, () => launchUrl(Uri.parse('tel:9999999999')))),
              const SizedBox(width: 8),
              Expanded(child: _act(Icons.chat_rounded, 'WhatsApp', const Color(0xFF25D366), () => launchUrl(Uri.parse('https://wa.me/919999999999'), mode: LaunchMode.externalApplication))),
            ]),
            const SizedBox(height: 12),
            Text('Status badlein', style: tx(12, c: K.muted, w: FontWeight.w800)),
            const SizedBox(height: 6),
            Row(children: [
              for (final e in _st.entries)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: lead.status == e.key ? e.value[2] as Color : null,
                        side: BorderSide(color: e.value[1] as Color),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Store.i.setStatus(lead, e.key);
                        Navigator.pop(c);
                      },
                      child: Text(e.value[0] as String, style: tx(11.5, w: FontWeight.w800, c: e.value[1] as Color)),
                    ),
                  ),
                ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _act(IconData i, String t, Color c, VoidCallback f) => ElevatedButton.icon(
        onPressed: f,
        icon: Icon(i, size: 18, color: Colors.white),
        label: Text(t, style: tx(13.5, w: FontWeight.w800, c: Colors.white)),
        style: ElevatedButton.styleFrom(backgroundColor: c, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      );
}

// ================= MY SHOP TAB (chaaran 3 me poora) =================
class MyShopTab extends StatelessWidget {
  const MyShopTab({super.key});
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
      children: [
        Box(
          gradient: K.darkCard,
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.storefront_rounded, color: K.ink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(Store.i.shopName, style: tx(18, w: FontWeight.w800, c: Colors.white)),
                  Text('LIVE · aaj', style: tx(11.5, c: K.goldL)),
                ]),
              ),
              const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 34),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              _m('SALES', '₹9,941'),
              _m('INVOICE', '7'),
              _m('VISITORS', '27'),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        Box(
          child: Column(children: [
            const Icon(Icons.construction_rounded, color: K.gold, size: 36),
            const SizedBox(height: 8),
            Text('My Shop poora chaaran 3 me banega', style: tx(15, w: FontWeight.w800), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('Aaj ke orders, POS / Naya bill, invoice, products aur stock — bilkul prototype jaisa', style: tx(12.5, c: K.muted), textAlign: TextAlign.center),
          ]),
        ),
      ],
    );
  }

  Widget _m(String a, String b) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(a, style: tx(10, w: FontWeight.w800, c: K.goldL).copyWith(letterSpacing: 1)),
          Text(b, style: tx(22, w: FontWeight.w800, c: Colors.white)),
        ]),
      );
}
