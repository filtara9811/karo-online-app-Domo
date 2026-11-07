import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../data.dart';
import '../shop.dart';
import '../theme.dart';
import 'pos.dart';
import 'soon.dart';

/// My Shop — prototype jaisa: sunehra shop card (5 slide), aaj ke orders, POS · Naya bill, neeche bill bar
class MyShopTab extends StatefulWidget {
  const MyShopTab({super.key});
  @override
  State<MyShopTab> createState() => _MyShopTabState();
}

class _MyShopTabState extends State<MyShopTab> {
  final _pc = PageController(viewportFraction: 1);
  int slide = 0;
  String group = 'All';
  String q = '';
  bool search = false;
  int day = 0; // 0 = aaj

  @override
  void initState() {
    super.initState();
    Shop.i.load();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Shop.i,
      builder: (context, _) {
        final s = Shop.i;
        final prods = s.products.where((p) {
          if (group != 'All' && p.group != group) return false;
          if (q.isNotEmpty && !p.name.toLowerCase().contains(q.toLowerCase())) return false;
          return true;
        }).toList();
        return Stack(children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 190),
            children: [
              SizedBox(
                height: 252,
                child: PageView(
                  controller: _pc,
                  onPageChanged: (i) => setState(() => slide = i),
                  children: [_shopCard(s), _qrCard(s), _stockCard(s), _invoiceCard(s), _khataCard()],
                ),
              ),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var k = 0; k < 5; k++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: slide == k ? 18 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(color: slide == k ? K.ink2 : const Color(0xFFD9CFBB), borderRadius: BorderRadius.circular(3)),
                  ),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Text('AAJ KE ORDERS', style: tx(12, w: FontWeight.w800, c: K.muted).copyWith(letterSpacing: 1)),
                const Spacer(),
                Text('${s.todayBills} order · 0 online · ${s.todayBills} offline', style: tx(11.5, w: FontWeight.w800, c: K.green)),
              ]),
              const SizedBox(height: 8),
              _days(s),
              const SizedBox(height: 16),
              Row(children: [
                Text('POS · Naya bill', style: tx(17, w: FontWeight.w800)),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() {
                    search = !search;
                    if (!search) q = '';
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(color: const Color(0xFFEFEAFB), borderRadius: BorderRadius.circular(99)),
                    child: Text('🔎 ${s.products.length}', style: tx(12, w: FontWeight.w800, c: const Color(0xFF6D4BD8))),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => editProduct(context, null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: K.ink, borderRadius: BorderRadius.circular(99)),
                    child: Text('＋ Add product', style: tx(12.5, w: FontWeight.w800, c: Colors.white)),
                  ),
                ),
              ]),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                child: !search
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: TextField(
                          autofocus: true,
                          onChanged: (v) => setState(() => q = v),
                          style: tx(14),
                          decoration: InputDecoration(
                            hintText: 'Product / service khojein',
                            prefixIcon: const Icon(Icons.search_rounded, color: K.muted),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: K.line)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: K.gold)),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 40,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  _chip('All', s.products.length),
                  for (final g in s.groups) _chip(g, s.products.where((p) => p.group == g).length),
                ]),
              ),
              const SizedBox(height: 10),
              if (prods.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(children: [
                    const Text('🛍️', style: TextStyle(fontSize: 40)),
                    Text('Koi product nahi — "＋ Add product" se jodein', textAlign: TextAlign.center, style: tx(13, c: K.muted)),
                  ]),
                ),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: .64,
                children: [for (final p in prods) _ProductTile(p: p)],
              ),
            ],
          ),
          Positioned(
            right: 18,
            bottom: 96,
            child: GestureDetector(
              onTap: () => openOrders(context),
              child: Stack(clipBehavior: Clip.none, children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(color: K.ink, shape: BoxShape.circle, border: Border.all(color: const Color(0xFFF5E6C8), width: 3), boxShadow: K.shadow(.3)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 20),
                    Text('Orders', style: tx(9.5, w: FontWeight.w800, c: Colors.white)),
                  ]),
                ),
                if (s.todayBills > 0)
                  Positioned(
                    right: -3,
                    top: -3,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(color: K.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                      child: Text('${s.todayBills}', style: tx(10, w: FontWeight.w800, c: Colors.white)),
                    ),
                  ),
              ]),
            ),
          ),
          Positioned(left: 12, right: 12, bottom: 12, child: _PosBar(s: s)),
        ]);
      },
    );
  }

  // ---------- 5 slides ----------
  BoxDecoration get _goldCard => BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2B1F10), Color(0xFF5A4019), Color(0xFF8F6A2A)]),
        boxShadow: K.shadow(.2),
      );

  Widget _shopCard(Shop s) {
    final now = DateTime.now();
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: _goldCard,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Stack(clipBehavior: Clip.none, children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.storefront_rounded, color: K.ink, size: 28)),
            Positioned(right: -4, bottom: -4, child: Container(padding: const EdgeInsets.all(3), decoration: const BoxDecoration(color: K.acc, shape: BoxShape.circle), child: const Icon(Icons.edit_rounded, size: 11, color: Colors.white))),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(Store.i.shopName, style: tx(19, w: FontWeight.w800, c: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
              Row(children: [
                Container(width: 7, height: 7, decoration: BoxDecoration(color: s.open ? const Color(0xFFFF5A4E) : Colors.white38, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text('${s.open ? 'LIVE' : 'BAND'} · aaj, ${now.day} ${m[now.month - 1]}', style: tx(11.5, w: FontWeight.w700, c: Colors.white70)),
              ]),
            ]),
          ),
          Column(children: [
            Container(width: 42, height: 42, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.qr_code_2_rounded, color: K.ink, size: 30)),
            const SizedBox(height: 3),
            Text('QR', style: tx(10, w: FontWeight.w700, c: Colors.white70)),
          ]),
        ]),
        const SizedBox(height: 6),
        Center(
          child: GestureDetector(
            onTap: s.toggleOpen,
            child: Container(
              padding: const EdgeInsets.fromLTRB(4, 3, 10, 3),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12), borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white24)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 30,
                  height: 18,
                  padding: const EdgeInsets.all(2),
                  alignment: s.open ? Alignment.centerRight : Alignment.centerLeft,
                  decoration: BoxDecoration(color: s.open ? K.green : Colors.white30, borderRadius: BorderRadius.circular(10)),
                  child: Container(width: 14, height: 14, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                ),
                const SizedBox(width: 6),
                Text(s.open ? 'OPEN' : 'CLOSED', style: tx(10.5, w: FontWeight.w800, c: Colors.white)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(children: [
          _m('SALES', inr(s.todaySales), '${s.todayPcs} pcs / kaam'),
          _m('INVOICE', '${s.todayBills}', 'aaj ke bill'),
          _m('LEADS', '${Store.i.leads.length}', '${Store.i.count('done')} pakki'),
        ]),
        const Spacer(),
        Row(children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: .25), borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                const Text('📦', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('AVAILABLE STOCK', style: tx(9, w: FontWeight.w800, c: K.goldL).copyWith(letterSpacing: .5)),
                    Text(s.stockPcs > 0 ? '${s.stockPcs} pcs · ${inrK(s.stockValue)}' : '${s.products.length} items', style: tx(12.5, w: FontWeight.w800, c: Colors.white)),
                  ]),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: K.green.withValues(alpha: .35), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF6EE7A8).withValues(alpha: .5))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('AAJ KI SALE', style: tx(9, w: FontWeight.w800, c: const Color(0xFFBDF5D3))),
              Text('▲ ${inr(s.todaySales)} ›', style: tx(12.5, w: FontWeight.w800, c: Colors.white)),
            ]),
          ),
        ]),
      ]),
    );
  }

  Widget _m(String a, String b, String c) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(a, style: tx(10, w: FontWeight.w800, c: K.goldL).copyWith(letterSpacing: .8)),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(b, style: tx(24, w: FontWeight.w800, c: Colors.white))),
          Text(c, style: tx(10.5, w: FontWeight.w600, c: Colors.white60), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      );

  Widget _slideCard({required String title, required String sub, required Widget child, String? cta, VoidCallback? onCta}) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: K.line), boxShadow: K.shadow(.05)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: tx(16, w: FontWeight.w800)),
                Text(sub, style: tx(11.5, c: K.muted)),
              ]),
            ),
            if (cta != null) GestureDetector(onTap: onCta, child: Text(cta, style: tx(12, w: FontWeight.w800, c: K.acc))),
          ]),
          const SizedBox(height: 10),
          Expanded(child: child),
        ]),
      );

  Widget _qrCard(Shop s) {
    final link = 'https://filtara9811.github.io/karo-online-app-Domo/?shop=${Store.i.vendorId}';
    return _slideCard(
      title: '📇 Mera QR & Standee',
      sub: 'Dukaan par lagayein · grahak scan karke judein',
      cta: 'Standee ›',
      onCta: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SoonScreen(title: 'QR Standee', step: 4, icon: Icons.qr_code_2_rounded))),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: K.line)),
          child: QrImageView(data: link, size: 130, padding: EdgeInsets.zero),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(Store.i.shopName, style: tx(15, w: FontWeight.w800), maxLines: 2),
            const SizedBox(height: 4),
            Text('Grahak is QR ko scan karke aapki digital dukaan khol sakte hain', style: tx(11.5, c: K.muted)),
            const SizedBox(height: 8),
            Text('${s.products.length} items dukaan me', style: tx(12, w: FontWeight.w800, c: K.green)),
          ]),
        ),
      ]),
    );
  }

  Widget _stockCard(Shop s) => _slideCard(
        title: 'Total Stock',
        sub: 'Kitna available, kitna bacha',
        child: Column(children: [
          Row(children: [
            _box('${s.products.length}', 'ITEMS'),
            _box('${s.stockPcs}', 'PCS'),
            _box('${s.lowItems}', 'LOW', c: const Color(0xFFD97706)),
            _box('${s.outItems}', 'OUT / OFF', c: K.red),
          ]),
          const Spacer(),
          Row(children: [
            Text('Stock value ${inr(s.stockValue)}', style: tx(12.5, w: FontWeight.w800)),
            const Spacer(),
            Text('Aaj bika ${s.todayPcs}', style: tx(12.5, w: FontWeight.w800, c: K.green)),
          ]),
        ]),
      );

  Widget _box(String n, String l, {Color c = K.ink}) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(color: K.iv, borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Text(n, style: tx(20, w: FontWeight.w800, c: c)),
            Text(l, style: tx(9.5, w: FontWeight.w800, c: K.muted)),
          ]),
        ),
      );

  Widget _invoiceCard(Shop s) => _slideCard(
        title: 'Recent invoices',
        sub: 'Kul ${inr(s.bills.fold<int>(0, (a, b) => a + b.total))} · ${s.bills.length} bill',
        cta: 'Sab ›',
        onCta: () => openOrders(context),
        child: s.bills.isEmpty
            ? Center(child: Text('Abhi koi bill nahi — neeche POS se banayein', style: tx(12.5, c: K.muted)))
            : ListView(padding: EdgeInsets.zero, children: [
                for (final b in s.bills.take(4))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      CircleAvatar(radius: 15, backgroundColor: K.iv, child: Text(b.customer[0].toUpperCase(), style: tx(12, w: FontWeight.w800))),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${b.customer}\n#${b.no} · ${hm(b.at)} · ${b.items.length} itm', style: tx(11.5, w: FontWeight.w600), maxLines: 2)),
                      Text(inr(b.total), style: tx(13, w: FontWeight.w800)),
                    ]),
                  ),
              ]),
      );

  Widget _khataCard() => _slideCard(
        title: '📒 Khata Book',
        sub: 'Udhaar, supplier, kharcha — sab yahan',
        cta: 'Kholein ›',
        onCta: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SoonScreen(title: 'Khata Book', step: 4, icon: Icons.menu_book_rounded))),
        child: Row(children: [
          _box('${Shop.i.bills.where((b) => b.pay == 'Udhaar').length}', 'UDHAAR BILL', c: K.red),
          _box(inrK(Shop.i.bills.where((b) => b.pay == 'Udhaar').fold<int>(0, (a, b) => a + b.total)), 'MILNA HAI', c: const Color(0xFFD97706)),
          _box('${Shop.i.customers.length}', 'GRAHAK'),
        ]),
      );

  Widget _days(Shop s) {
    final now = DateTime.now();
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return SizedBox(
      height: 76,
      child: ListView(scrollDirection: Axis.horizontal, children: [
        for (var d = 0; d < 14; d++)
          Builder(builder: (_) {
            final t = now.subtract(Duration(days: d));
            final on = day == d;
            final n = s.billsOn(t).length;
            return GestureDetector(
              onTap: () {
                setState(() => day = d);
                openOrders(context, day: t);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 58,
                margin: const EdgeInsets.only(right: 7),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: on ? const Color(0xFF1F4D33) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: on ? Colors.transparent : K.line),
                ),
                child: Column(children: [
                  Text(d == 0 ? 'Today' : wd[t.weekday - 1], style: tx(10, w: FontWeight.w700, c: on ? Colors.white70 : K.muted)),
                  Text('${t.day}', style: tx(18, w: FontWeight.w800, c: on ? Colors.white : K.ink)),
                  Text(inrK(s.salesOn(t)), style: tx(9.5, w: FontWeight.w800, c: on ? const Color(0xFF9BE8B9) : K.green)),
                  Text('$n order', style: tx(8.5, w: FontWeight.w600, c: on ? Colors.white60 : K.muted)),
                ]),
              ),
            );
          }),
      ]),
    );
  }

  Widget _chip(String g, int n) {
    final on = group == g;
    return GestureDetector(
      onTap: () => setState(() => group = g),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: on ? K.goldGrad : null,
          color: on ? null : Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: on ? Colors.transparent : K.line),
        ),
        child: Row(children: [
          Text(g, style: tx(13.5, w: FontWeight.w800, c: K.ink)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(color: on ? Colors.white54 : K.iv, borderRadius: BorderRadius.circular(99)),
            child: Text('$n', style: tx(11, w: FontWeight.w800, c: K.ink2)),
          ),
        ]),
      ),
    );
  }
}

const _pastels = [Color(0xFFE6EEF9), Color(0xFFF7EEDD), Color(0xFFF6E3E7), Color(0xFFE3F3EC), Color(0xFFF1E9FA), Color(0xFFFFF4D6)];

class _ProductTile extends StatelessWidget {
  final Product p;
  const _ProductTile({required this.p});
  @override
  Widget build(BuildContext context) {
    final q = Shop.i.cart[p.id]?.qty ?? 0;
    final bg = _pastels[p.name.hashCode.abs() % _pastels.length];
    return GestureDetector(
      onTap: () => Shop.i.add(p),
      onLongPress: () => editProduct(context, p),
      child: Opacity(
        opacity: p.off ? .55 : 1,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: q > 0 ? K.gold : K.line, width: q > 0 ? 1.8 : 1)),
          child: Column(children: [
            Expanded(
              child: Stack(clipBehavior: Clip.none, children: [
                Container(
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
                  child: Text(p.emoji, style: const TextStyle(fontSize: 40)),
                ),
                if (!p.off)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: -10,
                    child: Center(
                      child: q == 0
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFFC94D), Color(0xFFF5A623)]), borderRadius: BorderRadius.circular(99), boxShadow: K.shadow(.15)),
                              child: Text('+ Add', style: tx(11.5, w: FontWeight.w800, c: K.ink)),
                            )
                          : Container(
                              decoration: BoxDecoration(color: K.ink, borderRadius: BorderRadius.circular(99)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                GestureDetector(onTap: () => Shop.i.dec(p), child: const Padding(padding: EdgeInsets.fromLTRB(8, 3, 4, 3), child: Icon(Icons.remove_rounded, size: 15, color: Colors.white))),
                                Text('$q', style: tx(12.5, w: FontWeight.w800, c: Colors.white)),
                                GestureDetector(onTap: () => Shop.i.add(p), child: const Padding(padding: EdgeInsets.fromLTRB(4, 3, 8, 3), child: Icon(Icons.add_rounded, size: 15, color: Colors.white))),
                              ]),
                            ),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 14),
            Text(p.name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx(11.5, w: FontWeight.w800, h: 1.2)),
            const SizedBox(height: 2),
            Text(p.off ? '₹${p.price} · OFF' : '₹${p.price}${p.stock != null ? ' · ${p.stock} pcs' : ''}', style: tx(11, w: FontWeight.w800, c: p.off ? K.red : const Color(0xFFA9792B))),
            const SizedBox(height: 2),
          ]),
        ),
      ),
    );
  }
}

/// Neeche kaala bill bar — scan, tokri (₹ / khali), grahak
class _PosBar extends StatelessWidget {
  final Shop s;
  const _PosBar({required this.s});
  @override
  Widget build(BuildContext context) {
    final has = s.cartQty > 0;
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: K.ink, borderRadius: BorderRadius.circular(32), boxShadow: K.shadow(.35)),
      child: Row(children: [
        IconButton(onPressed: () => toast(context, 'Barcode / QR scan — agle update me'), icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF6EE7A8))),
        Expanded(
          child: GestureDetector(
            onTap: () => has ? openBill(context) : toast(context, 'Pehle product par "+ Add" dabayein'),
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(26), border: Border.all(color: Colors.white38, width: 1.5)),
              child: Row(children: [
                Container(width: 34, height: 34, decoration: BoxDecoration(color: has ? const Color(0xFFFFC94D) : Colors.white, shape: BoxShape.circle), child: const Center(child: Text('🛍️', style: TextStyle(fontSize: 17)))),
                const SizedBox(width: 8),
                Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(inr(s.cartTotal), style: tx(15, w: FontWeight.w800, c: Colors.white)),
                  Text(has ? '${s.cartQty} item · bill banayein ›' : 'khali', style: tx(10, w: FontWeight.w600, c: Colors.white60)),
                ]),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () => has ? openBill(context) : toast(context, 'Pehle product jodein, phir grahak chunein'),
          child: Container(width: 46, height: 46, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.person_add_alt_1_rounded, color: K.ink)),
        ),
      ]),
    );
  }
}
