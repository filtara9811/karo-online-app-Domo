import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data.dart';
import '../shop.dart';
import '../theme.dart';

// =============== Product jodna / badalna ===============
Future<void> editProduct(BuildContext context, Product? p) async {
  final name = TextEditingController(text: p?.name ?? '');
  final price = TextEditingController(text: p == null ? '' : '${p.price}');
  final stock = TextEditingController(text: p?.stock?.toString() ?? '');
  String emoji = p?.emoji ?? '🛍️';
  String group = p?.group ?? (Shop.i.groups.isNotEmpty ? Shop.i.groups.first : 'Other');
  bool off = p?.off ?? false;
  const emojis = ['🛍️', '👕', '👖', '👗', '🥻', '👟', '📱', '💡', '🔧', '❄️', '🧹', '💇', '🍲', '🍰', '🧴', '💊', '📦', '🛠️'];
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          decoration: const BoxDecoration(color: K.iv, borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: K.line, borderRadius: BorderRadius.circular(3)))),
              const SizedBox(height: 12),
              Row(children: [
                Text(p == null ? '＋ Naya product' : 'Product badlein', style: tx(19, w: FontWeight.w800)),
                const Spacer(),
                if (p != null)
                  IconButton(
                    onPressed: () {
                      Shop.i.removeProduct(p);
                      Navigator.pop(c);
                    },
                    icon: const Icon(Icons.delete_outline_rounded, color: K.red),
                  ),
              ]),
              const SizedBox(height: 10),
              SizedBox(
                height: 46,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (final e in emojis)
                    GestureDetector(
                      onTap: () => set(() => emoji = e),
                      child: Container(
                        width: 44,
                        margin: const EdgeInsets.only(right: 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: emoji == e ? const Color(0xFFFFF1DE) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: emoji == e ? K.gold : K.line)),
                        child: Text(e, style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 10),
              _in(name, 'Product / service ka naam'),
              Row(children: [
                Expanded(child: _in(price, 'Rate ₹', num: true)),
                const SizedBox(width: 10),
                Expanded(child: _in(stock, 'Stock (pcs) — service ho to khali', num: true)),
              ]),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final g in {...Shop.i.groups, 'Other'})
                  ChoiceChip(label: Text(g, style: tx(12, w: FontWeight.w700)), selected: group == g, onSelected: (_) => set(() => group = g), selectedColor: K.goldL),
              ]),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: !off,
                onChanged: (v) => set(() => off = !v),
                activeThumbColor: K.green,
                title: Text(off ? 'Band (OFF) — bill me nahi aayega' : 'Chalu — bik raha hai', style: tx(13.5, w: FontWeight.w700)),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    final n = name.text.trim();
                    final pr = int.tryParse(price.text.trim()) ?? 0;
                    if (n.length < 2 || pr <= 0) {
                      toast(c, 'Naam aur rate daaliye');
                      return;
                    }
                    final st = int.tryParse(stock.text.trim());
                    if (p == null) {
                      Shop.i.addProduct(Product(id: 'u${DateTime.now().millisecondsSinceEpoch}', name: n, emoji: emoji, group: group, price: pr, stock: st, off: off));
                    } else {
                      final np = Product(id: p.id, name: n, emoji: emoji, group: group, price: pr, stock: st, off: off);
                      final i = Shop.i.products.indexOf(p);
                      if (i >= 0) Shop.i.products[i] = np;
                      Shop.i.updateProduct();
                    }
                    Navigator.pop(c);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: K.ink, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: Text(p == null ? 'Dukaan me jodein' : 'Save karein', style: tx(15.5, w: FontWeight.w800, c: Colors.white)),
                ),
              ),
            ]),
          ),
        ),
      ),
    ),
  );
}

Widget _in(TextEditingController c, String h, {bool num = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType: num ? TextInputType.number : TextInputType.text,
        inputFormatters: num ? [FilteringTextInputFormatter.digitsOnly] : null,
        style: tx(15, w: FontWeight.w700),
        decoration: InputDecoration(
          hintText: h,
          hintStyle: tx(13, c: K.muted, w: FontWeight.w500),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: K.line)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: K.gold, width: 1.5)),
        ),
      ),
    );

// =============== Tokri → grahak → bill ===============
void openBill(BuildContext context) {
  showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => const _BillSheet());
}

class _BillSheet extends StatefulWidget {
  const _BillSheet();
  @override
  State<_BillSheet> createState() => _BillSheetState();
}

class _BillSheetState extends State<_BillSheet> {
  final _name = TextEditingController();
  final _ph = TextEditingController();
  String pay = 'Cash';

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return ListenableBuilder(
      listenable: Shop.i,
      builder: (context, _) {
        final s = Shop.i;
        return Padding(
          padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
          child: Container(
            constraints: BoxConstraints(maxHeight: mq.size.height * .9),
            decoration: const BoxDecoration(color: K.iv, borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 10),
              Container(width: 44, height: 5, decoration: BoxDecoration(color: K.line, borderRadius: BorderRadius.circular(3))),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 10, 4),
                child: Row(children: [
                  Text('🧾 Naya bill', style: tx(20, w: FontWeight.w800)),
                  const Spacer(),
                  TextButton(onPressed: () {
                    s.clearCart();
                    Navigator.pop(context);
                  }, child: Text('Khali karein', style: tx(12.5, w: FontWeight.w800, c: K.red))),
                ]),
              ),
              Flexible(
                child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 4, 16, 10), children: [
                  for (final l in s.cart.values)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: K.line)),
                      child: Row(children: [
                        Container(width: 42, height: 42, alignment: Alignment.center, decoration: BoxDecoration(color: K.iv, borderRadius: BorderRadius.circular(12)), child: Text(l.p.emoji, style: const TextStyle(fontSize: 22))),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(l.p.name, style: tx(13.5, w: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text('${l.qty} × ₹${l.p.price}', style: tx(12, c: K.muted)),
                          ]),
                        ),
                        _step(Icons.remove_rounded, () => s.dec(l.p)),
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('${l.qty}', style: tx(15, w: FontWeight.w800))),
                        _step(Icons.add_rounded, () => s.add(l.p)),
                        const SizedBox(width: 8),
                        SizedBox(width: 64, child: Text(inr(l.total), textAlign: TextAlign.right, style: tx(13.5, w: FontWeight.w800))),
                      ]),
                    ),
                  const SizedBox(height: 6),
                  Text('GRAHAK', style: tx(11, w: FontWeight.w800, c: K.muted).copyWith(letterSpacing: 1)),
                  const SizedBox(height: 6),
                  if (s.customers.isNotEmpty)
                    SizedBox(
                      height: 38,
                      child: ListView(scrollDirection: Axis.horizontal, children: [
                        for (final c in s.customers.take(12))
                          GestureDetector(
                            onTap: () => setState(() {
                              _name.text = c['name'] ?? '';
                              _ph.text = c['phone'] ?? '';
                            }),
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99), border: Border.all(color: K.line)),
                              child: Text('👤 ${c['name']}', style: tx(12, w: FontWeight.w700)),
                            ),
                          ),
                      ]),
                    ),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: _in(_name, 'Naam (khali = Walk-in)')),
                    const SizedBox(width: 8),
                    Expanded(child: _in(_ph, 'Mobile (WhatsApp bill)', num: true)),
                  ]),
                  Text('PAYMENT', style: tx(11, w: FontWeight.w800, c: K.muted).copyWith(letterSpacing: 1)),
                  const SizedBox(height: 6),
                  Row(children: [
                    for (final p in const ['Cash', 'UPI', 'Card', 'Udhaar'])
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => pay = p),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: pay == p ? K.ink : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: pay == p ? K.ink : K.line)),
                            child: Text(p, style: tx(13, w: FontWeight.w800, c: pay == p ? Colors.white : K.ink)),
                          ),
                        ),
                      ),
                  ]),
                ]),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: SizedBox(
                    height: 56,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: s.cart.isEmpty
                          ? null
                          : () {
                              final b = s.checkout(customer: _name.text.trim(), phone: _ph.text.trim(), pay: pay);
                              Navigator.pop(context);
                              Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceScreen(bill: b)));
                            },
                      style: ElevatedButton.styleFrom(backgroundColor: K.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                      child: Text('Bill banayein · ${inr(s.cartTotal)}', style: tx(16.5, w: FontWeight.w800, c: Colors.white)),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _step(IconData i, VoidCallback f) => GestureDetector(
        onTap: f,
        child: Container(width: 28, height: 28, decoration: BoxDecoration(color: K.iv, borderRadius: BorderRadius.circular(8)), child: Icon(i, size: 16)),
      );
}

// =============== Invoice ===============
class InvoiceScreen extends StatefulWidget {
  final Bill bill;
  const InvoiceScreen({super.key, required this.bill});
  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  String fmt = '3"';

  String get upiLink {
    final b = widget.bill;
    return 'upi://pay?pa=${Uri.encodeComponent(Shop.i.upi)}&pn=${Uri.encodeComponent(Store.i.shopName)}&am=${b.total}&cu=INR&tn=${Uri.encodeComponent('Bill ${b.no}')}';
  }

  Future<void> _askUpi() async {
    final c = TextEditingController(text: Shop.i.upi);
    final v = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text('Aapka UPI ID', style: tx(17, w: FontWeight.w800)),
        content: TextField(controller: c, decoration: const InputDecoration(hintText: 'jaise 98xxxxxxxx@ybl'), autofocus: true),
        actions: [TextButton(onPressed: () => Navigator.pop(d, c.text), child: Text('Save', style: tx(14, w: FontWeight.w800, c: K.acc)))],
      ),
    );
    if (v != null && v.contains('@')) setState(() => Shop.i.setUpi(v));
  }

  String _text() {
    final b = widget.bill;
    final sb = StringBuffer('🧾 *${Store.i.shopName}*\nBill #${b.no} · ${b.at.day}/${b.at.month}/${b.at.year} ${hm(b.at)}\nGrahak: ${b.customer}\n\n');
    for (final i in b.items) {
      sb.writeln('${i['name']}  ${i['qty']} × ₹${i['price']} = ₹${(i['qty'] as num) * (i['price'] as num)}');
    }
    sb.writeln('\n*Kul: ${inr(b.total)}* · ${b.pay}');
    if (Shop.i.upi.isNotEmpty) sb.writeln('UPI: ${Shop.i.upi}');
    sb.writeln('\nDhanyavaad! — Karo Online');
    return sb.toString();
  }

  Future<Uint8List> _pdf(PdfPageFormat f) async {
    final b = widget.bill;
    final doc = pw.Document();
    final width = fmt == '3"' ? 80 * PdfPageFormat.mm : (fmt == '4"' ? 104 * PdfPageFormat.mm : PdfPageFormat.a4.width);
    final pf = fmt == 'A4' ? PdfPageFormat.a4 : PdfPageFormat(width, double.infinity, marginAll: 4 * PdfPageFormat.mm);
    String rs(num n) => 'Rs. ${n.round()}';
    doc.addPage(pw.Page(
      pageFormat: pf,
      build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.Text(Store.i.shopName, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.Text('${Store.i.vendor?['area'] ?? ''} · +91 ${Store.i.phone}', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9)),
        pw.Divider(),
        pw.Text('Bill #${b.no}   ${b.at.day}/${b.at.month}/${b.at.year} ${hm(b.at)}', style: const pw.TextStyle(fontSize: 9)),
        pw.Text('Customer: ${b.customer}${b.phone.isNotEmpty ? ' (${b.phone})' : ''}', style: const pw.TextStyle(fontSize: 9)),
        pw.Divider(),
        for (final i in b.items)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(children: [
              pw.Expanded(child: pw.Text('${i['name']}\n${i['qty']} x ${rs(i['price'] as num)}', style: const pw.TextStyle(fontSize: 10))),
              pw.Text(rs((i['qty'] as num) * (i['price'] as num)), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ]),
          ),
        pw.Divider(),
        pw.Row(children: [
          pw.Expanded(child: pw.Text('TOTAL (${b.pay})', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
          pw.Text(rs(b.total), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        ]),
        if (Shop.i.upi.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Center(child: pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: upiLink, width: 90, height: 90)),
          pw.Text('UPI: ${Shop.i.upi}', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9)),
        ],
        pw.SizedBox(height: 6),
        pw.Text('Dhanyavaad! · Powered by Karo Online', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8)),
      ]),
    ));
    return doc.save();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.bill;
    final w = fmt == '3"' ? 300.0 : (fmt == '4"' ? 360.0 : 420.0);
    return Scaffold(
      backgroundColor: const Color(0xFFEDE8DE),
      appBar: AppBar(backgroundColor: K.iv, surfaceTintColor: K.iv, title: Text('Bill #${b.no}', style: tx(18, w: FontWeight.w800))),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(children: [
            for (final f in const ['3"', '4"', 'A4'])
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => fmt = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: fmt == f ? K.ink : Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Text(f == 'A4' ? '📄 A4' : '🧾 $f', style: tx(13, w: FontWeight.w800, c: fmt == f ? Colors.white : K.ink)),
                  ),
                ),
              ),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: w,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), boxShadow: K.shadow(.12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(Store.i.shopName, textAlign: TextAlign.center, style: tx(17, w: FontWeight.w800)),
                  Text('${Store.i.vendor?['area'] ?? ''} · +91 ${Store.i.phone}', textAlign: TextAlign.center, style: tx(11, c: K.muted)),
                  const Divider(height: 18),
                  Text('Bill #${b.no} · ${b.at.day}/${b.at.month}/${b.at.year} ${hm(b.at)}', style: tx(11.5, w: FontWeight.w700)),
                  Text('Grahak: ${b.customer}${b.phone.isNotEmpty ? ' · ${b.phone}' : ''}', style: tx(11.5, c: K.muted)),
                  const Divider(height: 18),
                  for (final i in b.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        Text(i['emoji'] ?? '', style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${i['name']}', style: tx(12.5, w: FontWeight.w700)),
                            Text('${i['qty']} × ₹${i['price']}', style: tx(11, c: K.muted)),
                          ]),
                        ),
                        Text(inr((i['qty'] as num) * (i['price'] as num)), style: tx(13, w: FontWeight.w800)),
                      ]),
                    ),
                  const Divider(height: 18),
                  Row(children: [
                    Text('KUL · ${b.pay}', style: tx(13, w: FontWeight.w800)),
                    const Spacer(),
                    Text(inr(b.total), style: tx(20, w: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 12),
                  if (Shop.i.upi.isNotEmpty) ...[
                    Center(child: QrImageView(data: upiLink, size: 140, padding: EdgeInsets.zero)),
                    const SizedBox(height: 4),
                    Text('Scan karke ${inr(b.total)} bharein · ${Shop.i.upi}', textAlign: TextAlign.center, style: tx(11, w: FontWeight.w700, c: K.muted)),
                  ] else
                    OutlinedButton.icon(onPressed: _askUpi, icon: const Icon(Icons.qr_code_rounded), label: Text('UPI ID daalein — bill par QR aayega', style: tx(12.5, w: FontWeight.w700))),
                  const SizedBox(height: 10),
                  Text('Dhanyavaad! · Karo Online', textAlign: TextAlign.center, style: tx(11, c: K.muted)),
                ]),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Row(children: [
              Expanded(
                child: _act('WhatsApp', Icons.chat_rounded, const Color(0xFF25D366), () {
                  final ph = b.phone.replaceAll(RegExp(r'\D'), '');
                  launchUrl(Uri.parse('https://wa.me/${ph.isEmpty ? '' : '91$ph'}?text=${Uri.encodeComponent(_text())}'), mode: LaunchMode.externalApplication);
                }),
              ),
              const SizedBox(width: 8),
              Expanded(child: _act('Print', Icons.print_rounded, K.ink, () => Printing.layoutPdf(onLayout: _pdf, name: 'Bill_${b.no}'))),
              const SizedBox(width: 8),
              Expanded(child: _act('PDF', Icons.picture_as_pdf_rounded, K.acc, () async => Printing.sharePdf(bytes: await _pdf(PdfPageFormat.a4), filename: 'Bill_${b.no}.pdf'))),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _act(String t, IconData i, Color c, VoidCallback f) => ElevatedButton.icon(
        onPressed: f,
        icon: Icon(i, color: Colors.white, size: 18),
        label: Text(t, style: tx(13.5, w: FontWeight.w800, c: Colors.white)),
        style: ElevatedButton.styleFrom(backgroundColor: c, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      );
}

// =============== Orders (7 kadam ki patti) ===============
void openOrders(BuildContext context, {DateTime? day}) {
  showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => _OrdersSheet(day: day));
}

class _OrdersSheet extends StatefulWidget {
  final DateTime? day;
  const _OrdersSheet({this.day});
  @override
  State<_OrdersSheet> createState() => _OrdersSheetState();
}

class _OrdersSheetState extends State<_OrdersSheet> {
  int tab = 0; // 0 sab, 1 online, 2 pos
  String q = '';
  late DateTime? day = widget.day;

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'abhi';
    if (d.inMinutes < 60) return '${d.inMinutes} min pehle';
    if (d.inHours < 24) return '${d.inHours} ghante pehle';
    return '${d.inDays} din pehle';
  }

  @override
  Widget build(BuildContext context) {
    final s = Shop.i;
    final all = s.bills.where((b) {
      if (day != null && !(b.at.year == day!.year && b.at.month == day!.month && b.at.day == day!.day)) return false;
      if (q.isNotEmpty && !('${b.customer} ${b.no} ${b.items.map((e) => e['name']).join(' ')}'.toLowerCase().contains(q.toLowerCase()))) return false;
      return true;
    }).toList();
    final list = tab == 1 ? <Bill>[] : all;
    return Container(
      height: MediaQuery.of(context).size.height * .92,
      decoration: const BoxDecoration(color: K.iv, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(children: [
        const SizedBox(height: 10),
        Container(width: 44, height: 5, decoration: BoxDecoration(color: K.line, borderRadius: BorderRadius.circular(3))),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 12, 8),
          child: Row(children: [
            Text('📦 Orders', style: tx(22, w: FontWeight.w800)),
            if (day != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => day = null),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFE3F3EC), borderRadius: BorderRadius.circular(99)),
                  child: Text('${day!.day}/${day!.month} ✕', style: tx(12, w: FontWeight.w800, c: K.green)),
                ),
              ),
            ],
            const Spacer(),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded), style: IconButton.styleFrom(backgroundColor: Colors.white)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            _stat('${s.bills.length}', 'KUL SAB', dark: true),
            _stat('0', 'CHAL RAHE'),
            _stat('0', 'NAYE'),
            _stat(inr(s.bills.fold<int>(0, (a, b) => a + b.total)), 'POORE (${s.bills.length})', flex: 2),
          ]),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: const Color(0xFFEDE6D6), borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              _tab(0, 'Sab', all.length),
              _tab(1, '🌐 Online', 0),
              _tab(2, '🧾 POS / Dukaan', all.length),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: TextField(
            onChanged: (v) => setState(() => q = v),
            style: tx(14),
            decoration: InputDecoration(
              hintText: 'Naam, order no. ya item…',
              hintStyle: tx(13.5, c: K.muted, w: FontWeight.w500),
              prefixIcon: const Icon(Icons.search_rounded, color: K.muted),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: K.line)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: K.gold)),
            ),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(child: Text(tab == 1 ? 'Online orders digital dukaan judte hi yahan aayenge' : 'Koi order nahi', textAlign: TextAlign.center, style: tx(13.5, w: FontWeight.w700, c: K.muted)))
              : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [for (final b in list) _OrderCard(b: b, ago: _ago(b.at))]),
        ),
      ]),
    );
  }

  Widget _stat(String n, String l, {bool dark = false, int flex = 1}) => Expanded(
        flex: flex,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: dark ? K.ink : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: dark ? K.ink : K.line)),
          child: Column(children: [
            FittedBox(child: Text(n, style: tx(17, w: FontWeight.w800, c: dark ? Colors.white : K.ink))),
            Text(l, style: tx(9, w: FontWeight.w800, c: dark ? Colors.white70 : K.muted)),
          ]),
        ),
      );

  Widget _tab(int i, String t, int n) => Expanded(
        flex: i == 2 ? 3 : 2,
        child: GestureDetector(
          onTap: () => setState(() => tab = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: tab == i ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(11)),
            child: Text('$t  $n', style: tx(12.5, w: FontWeight.w800, c: tab == i ? K.ink : K.muted), maxLines: 1),
          ),
        ),
      );
}

class _OrderCard extends StatefulWidget {
  final Bill b;
  final String ago;
  const _OrderCard({required this.b, required this.ago});
  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool open = false;
  @override
  Widget build(BuildContext context) {
    final b = widget.b;
    final paid = b.pay != 'Udhaar';
    return GestureDetector(
      onTap: () => setState(() => open = !open),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: K.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Stack(clipBehavior: Clip.none, children: [
              CircleAvatar(radius: 20, backgroundColor: const Color(0xFF3F5A3A), child: Text(b.customer[0].toUpperCase(), style: tx(15, w: FontWeight.w800, c: Colors.white))),
              Positioned(
                right: -3,
                top: -3,
                child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: K.ink, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)), child: Text('${b.items.length}', style: tx(9, w: FontWeight.w800, c: Colors.white))),
              ),
            ]),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(b.customer, style: tx(15, w: FontWeight.w800), overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: const Color(0xFFFFF4D6), borderRadius: BorderRadius.circular(6)),
                    child: Text('🧾 POS', style: tx(10, w: FontWeight.w800, c: const Color(0xFF9A6A00))),
                  ),
                ]),
                Text('#${b.no} · ${widget.ago} · Dukaan se', style: tx(11, c: K.muted)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(inr(b.total), style: tx(15, w: FontWeight.w800)),
              Text(b.pay, style: tx(10.5, w: FontWeight.w700, c: K.muted)),
            ]),
          ]),
          const SizedBox(height: 8),
          Text(b.items.map((e) => '${e['name']} ×${e['qty']}').join(', '), style: tx(12, w: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Row(children: [
            for (var k = 0; k < 7; k++)
              Expanded(
                child: Container(
                  height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(color: (paid || k < 5) ? K.green : const Color(0xFFE6DFD0), borderRadius: BorderRadius.circular(3)),
                ),
              ),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Text(paid ? '✓ Counter par diya · Paid' : '⏳ Counter par diya · Udhaar baaki', style: tx(11.5, w: FontWeight.w800, c: paid ? K.green : const Color(0xFFD97706))),
            const Spacer(),
            Text(open ? 'Band ▴' : 'Detail ▾', style: tx(11, w: FontWeight.w700, c: K.muted)),
          ]),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: !open
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(children: [
                      for (final i in b.items)
                        Row(children: [
                          Text('${i['emoji']} ${i['name']}', style: tx(12, w: FontWeight.w600)),
                          const Spacer(),
                          Text('${i['qty']} × ₹${i['price']}', style: tx(12, w: FontWeight.w700)),
                        ]),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceScreen(bill: b))),
                          icon: const Icon(Icons.receipt_long_rounded, size: 18, color: K.acc),
                          label: Text('Bill dekhein / bhejein', style: tx(12.5, w: FontWeight.w800, c: K.acc)),
                        ),
                      ),
                    ]),
                  ),
          ),
        ]),
      ),
    );
  }
}
