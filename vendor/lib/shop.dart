import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'catalog.dart';
import 'data.dart';

/// Dukaan ka product / service (POS me bikta hai)
class Product {
  final String id, name, emoji, group;
  int price;
  int? stock; // null = service (stock nahi)
  bool off;
  Product({required this.id, required this.name, required this.emoji, required this.group, required this.price, this.stock, this.off = false});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'emoji': emoji, 'group': group, 'price': price, 'stock': stock, 'off': off};
  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'],
        name: j['name'],
        emoji: j['emoji'] ?? '🛍️',
        group: j['group'] ?? 'Other',
        price: (j['price'] as num).toInt(),
        stock: (j['stock'] as num?)?.toInt(),
        off: j['off'] == true,
      );
}

class Line {
  final Product p;
  int qty;
  Line(this.p, this.qty);
  int get total => p.price * qty;
}

/// Bana hua bill (POS / dukaan se)
class Bill {
  final String no, customer, phone, pay;
  final DateTime at;
  final List<Map<String, dynamic>> items; // name, emoji, qty, price
  final int total;
  Bill({required this.no, required this.customer, required this.phone, required this.pay, required this.at, required this.items, required this.total});

  int get pcs => items.fold(0, (a, b) => a + (b['qty'] as num).toInt());
  Map<String, dynamic> toJson() => {'no': no, 'customer': customer, 'phone': phone, 'pay': pay, 'at': at.toIso8601String(), 'items': items, 'total': total};
  factory Bill.fromJson(Map<String, dynamic> j) => Bill(
        no: j['no'],
        customer: j['customer'] ?? 'Walk-in',
        phone: j['phone'] ?? '',
        pay: j['pay'] ?? 'Cash',
        at: DateTime.parse(j['at']),
        items: List<Map<String, dynamic>>.from((j['items'] as List).map((e) => Map<String, dynamic>.from(e))),
        total: (j['total'] as num).toInt(),
      );
}

class Shop extends ChangeNotifier {
  Shop._();
  static final Shop i = Shop._();

  List<Product> products = [];
  List<Bill> bills = [];
  final Map<String, Line> cart = {};
  String upi = '';
  bool open = true;
  int billNo = 1001;
  List<Map<String, String>> customers = [];

  String get _k => 'shop_${Store.i.vendorId}';

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_k);
    if (s != null) {
      final j = jsonDecode(s);
      products = [for (final x in j['products'] ?? []) Product.fromJson(Map<String, dynamic>.from(x))];
      bills = [for (final x in j['bills'] ?? []) Bill.fromJson(Map<String, dynamic>.from(x))];
      upi = j['upi'] ?? '';
      open = j['open'] ?? true;
      billNo = j['billNo'] ?? 1001;
      customers = [for (final x in j['customers'] ?? []) Map<String, String>.from(x)];
    }
    if (products.isEmpty) _seedFromJoin();
    notifyListeners();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        _k,
        jsonEncode({
          'products': [for (final x in products) x.toJson()],
          'bills': [for (final x in bills.take(500)) x.toJson()],
          'upi': upi,
          'open': open,
          'billNo': billNo,
          'customers': customers.take(300).toList(),
        }));
  }

  /// Join me jo services / items chune the — wahi dukaan ke products ban jaate hain
  void _seedFromJoin() {
    final v = Store.i.vendor;
    if (v == null) return;
    final subs = List<String>.from(v['subs'] ?? const []);
    final chosen = Map<String, dynamic>.from(v['items'] ?? const {});
    final isPrd = v['ty'] == 'prd';
    var n = 0;
    for (final s in subs) {
      Sub? sub;
      for (final t in Catalog.types.values) {
        for (final c in t.cats) {
          for (final x in c.subs) {
            if (x.n == s) sub = x;
          }
        }
      }
      final pick = List<String>.from(chosen[s] ?? const []);
      final list = sub?.items ?? <Item>[];
      final use = pick.isEmpty ? list : list.where((i) => pick.contains(i.n)).toList();
      for (final it in use) {
        products.add(Product(id: 'p${n++}', name: it.n, emoji: it.e, group: s, price: it.p > 0 ? it.p : 199, stock: isPrd ? 20 : null));
      }
      for (final extra in pick.where((x) => !list.any((i) => i.n == x))) {
        products.add(Product(id: 'p${n++}', name: extra, emoji: sub?.e ?? '🛍️', group: s, price: 199, stock: isPrd ? 20 : null));
      }
      if (use.isEmpty && pick.isEmpty) {
        products.add(Product(id: 'p${n++}', name: s, emoji: sub?.e ?? '🛍️', group: s, price: 299, stock: isPrd ? 20 : null));
      }
    }
    _save();
  }

  List<String> get groups => {for (final p in products) p.group}.toList();

  // ---------- cart ----------
  int get cartQty => cart.values.fold(0, (a, b) => a + b.qty);
  int get cartTotal => cart.values.fold(0, (a, b) => a + b.total);

  void add(Product p) {
    if (p.off) return;
    cart.update(p.id, (l) => l..qty += 1, ifAbsent: () => Line(p, 1));
    notifyListeners();
  }

  void dec(Product p) {
    final l = cart[p.id];
    if (l == null) return;
    l.qty--;
    if (l.qty <= 0) cart.remove(p.id);
    notifyListeners();
  }

  void clearCart() {
    cart.clear();
    notifyListeners();
  }

  Bill checkout({required String customer, required String phone, required String pay}) {
    final b = Bill(
      no: 'B-${billNo++}',
      customer: customer.isEmpty ? 'Walk-in' : customer,
      phone: phone,
      pay: pay,
      at: DateTime.now(),
      items: [for (final l in cart.values) {'name': l.p.name, 'emoji': l.p.emoji, 'qty': l.qty, 'price': l.p.price}],
      total: cartTotal,
    );
    for (final l in cart.values) {
      if (l.p.stock != null) l.p.stock = (l.p.stock! - l.qty).clamp(0, 1 << 30);
    }
    bills.insert(0, b);
    if (phone.isNotEmpty && !customers.any((c) => c['phone'] == phone)) {
      customers.insert(0, {'name': customer, 'phone': phone});
    }
    cart.clear();
    _save();
    notifyListeners();
    return b;
  }

  // ---------- products ----------
  void addProduct(Product p) {
    products.insert(0, p);
    _save();
    notifyListeners();
  }

  void updateProduct() {
    _save();
    notifyListeners();
  }

  void removeProduct(Product p) {
    products.remove(p);
    cart.remove(p.id);
    _save();
    notifyListeners();
  }

  void setUpi(String v) {
    upi = v.trim();
    _save();
    notifyListeners();
  }

  void toggleOpen() {
    open = !open;
    _save();
    notifyListeners();
  }

  // ---------- aankde ----------
  bool _same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  List<Bill> billsOn(DateTime d) => bills.where((b) => _same(b.at, d)).toList();
  int salesOn(DateTime d) => billsOn(d).fold(0, (a, b) => a + b.total);
  int get todaySales => salesOn(DateTime.now());
  int get todayBills => billsOn(DateTime.now()).length;
  int get todayPcs => billsOn(DateTime.now()).fold(0, (a, b) => a + b.pcs);
  int get stockPcs => products.where((p) => p.stock != null && !p.off).fold(0, (a, b) => a + b.stock!);
  int get stockValue => products.where((p) => p.stock != null && !p.off).fold(0, (a, b) => a + b.stock! * b.price);
  int get lowItems => products.where((p) => p.stock != null && p.stock! > 0 && p.stock! <= 5).length;
  int get outItems => products.where((p) => p.off || (p.stock != null && p.stock! == 0)).length;
}

String inr(num n) {
  final neg = n < 0;
  final s = n.abs().round().toString();
  String out;
  if (s.length <= 3) {
    out = s;
  } else {
    final last = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    out = '${parts.join(',')},$last';
  }
  return '${neg ? '-' : ''}₹$out';
}

String inrK(num n) => n >= 1000 ? '₹${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}k' : '₹${n.round()}';
