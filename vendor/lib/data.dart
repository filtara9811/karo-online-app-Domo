import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ek request — lead (service) ya order (dukaan se saamaan)
class Req {
  final String id;
  final String name;
  final String service;
  final IconData icon;
  final String area;
  final double km;
  final String need;
  final int coins;
  final int slots;
  final bool isOrder;
  final String amount;
  final DateTime at;
  String status; // naya | chal | done | pending | missed | rejected
  Req({
    required this.id,
    required this.name,
    required this.service,
    required this.icon,
    required this.area,
    required this.km,
    required this.need,
    this.coins = 1,
    this.slots = 3,
    this.isOrder = false,
    this.amount = '',
    DateTime? at,
    this.status = 'naya',
  }) : at = at ?? DateTime.now();

  String get initial => name.isEmpty ? '?' : name[0].toUpperCase();
}

/// Abhi ke liye namoone ka data (chaaran 5 me Supabase se aayega)
class Store extends ChangeNotifier {
  Store._();
  static final Store i = Store._();

  bool loggedIn = false;
  String phone = '';
  String shopName = 'Ashu Garments';
  int coins = 503;
  bool online = true;

  final List<Req> requests = [];
  final List<Req> leads = [];

  static final _rnd = Random();
  static const _pool = [
    ['Rahul', 'AC repair', 'Bara Hindu Rao, Delhi', 'AC thanda nahi kar raha', Icons.ac_unit_rounded],
    ['Priya', 'Plumber', 'Sadar Bazar, Delhi', 'Ghar par visit chahiye', Icons.plumbing_rounded],
    ['Sameer', 'Bridal makeup', 'Subzi Mandi, Delhi', 'Aaj shaam tak kaam', Icons.brush_rounded],
    ['Neha', 'Electrician', 'Kamla Nagar, Delhi', 'Pankha nahi chal raha', Icons.electrical_services_rounded],
    ['Imran', 'Carpenter', 'Chandni Chowk, Delhi', 'Almari ka darwaza theek', Icons.handyman_rounded],
  ];

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    loggedIn = p.getBool('loggedIn') ?? false;
    phone = p.getString('phone') ?? '';
    coins = p.getInt('coins') ?? 503;
    online = p.getBool('online') ?? true;
    _seed();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('loggedIn', loggedIn);
    await p.setString('phone', phone);
    await p.setInt('coins', coins);
    await p.setBool('online', online);
  }

  void _seed() {
    if (requests.isNotEmpty || leads.isNotEmpty) return;
    for (var k = 0; k < 3; k++) {
      final x = _pool[k];
      requests.add(Req(
        id: 'R${100 + k}', name: x[0] as String, service: x[1] as String, area: x[2] as String,
        need: x[3] as String, icon: x[4] as IconData, km: .2 + k * .3, coins: k + 1, slots: 3 - k,
        at: DateTime.now().subtract(Duration(minutes: k * 3)),
      ));
    }
    requests.add(Req(id: 'O201', name: 'Meena Kapoor', service: 'Order · 3 item', area: 'Bara Hindu Rao, Delhi', need: 'Round Neck Tee ×2, Formal Shirt ×1', icon: Icons.shopping_bag_rounded, km: .4, isOrder: true, amount: '₹1,148', coins: 0));
    requests.add(Req(id: 'O202', name: 'Deepak Jain', service: 'Order · 1 item', area: 'Karol Bagh, Delhi', need: 'Kurta Pyjama set (L)', icon: Icons.shopping_bag_rounded, km: 2.1, isOrder: true, amount: '₹899', coins: 0));
    const names = ['Imran', 'Pooja', 'Arjun', 'Sana', 'Vikas', 'Ritu', 'Kabir', 'Anil', 'Farah', 'Mohit', 'Geeta', 'Raju'];
    const st = ['chal', 'done', 'pending', 'chal', 'done', 'chal', 'pending', 'done', 'chal', 'pending', 'chal', 'done'];
    for (var k = 0; k < names.length; k++) {
      final x = _pool[k % _pool.length];
      leads.add(Req(
        id: 'L${300 + k}', name: names[k], service: x[1] as String, area: x[2] as String, need: x[3] as String,
        icon: x[4] as IconData, km: .3 + k * .2, status: st[k], at: DateTime.now().subtract(Duration(hours: 1 + k * 5)),
      ));
    }
  }

  List<Req> get pendingLeads => requests.where((r) => !r.isOrder && r.status == 'naya').toList();
  List<Req> get pendingOrders => requests.where((r) => r.isOrder && r.status == 'naya').toList();
  int count(String s) => leads.where((l) => l.status == s).length;

  Req? byId(String? id) {
    for (final r in requests) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Nayi request aayi (demo) — asli me Supabase/FCM se aayegi
  Req newDemoRequest() {
    final x = _pool[_rnd.nextInt(_pool.length)];
    final r = Req(
      id: 'R${DateTime.now().millisecondsSinceEpoch % 100000}', name: x[0] as String, service: x[1] as String,
      area: x[2] as String, need: x[3] as String, icon: x[4] as IconData, km: (2 + _rnd.nextInt(18)) / 10,
      coins: 1 + _rnd.nextInt(2), slots: 1 + _rnd.nextInt(3),
    );
    requests.insert(0, r);
    notifyListeners();
    return r;
  }

  /// Accept: coin katega, lead "chal rahi" me jayegi. false = coin kam hain
  bool accept(Req r) {
    if (!r.isOrder && coins < r.coins) return false;
    if (!r.isOrder) coins -= r.coins;
    r.status = 'chal';
    requests.remove(r);
    if (!r.isOrder) leads.insert(0, r);
    _save();
    notifyListeners();
    return true;
  }

  void reject(Req r) {
    r.status = 'rejected';
    requests.remove(r);
    notifyListeners();
  }

  void setStatus(Req r, String s) {
    r.status = s;
    notifyListeners();
  }

  void setOnline(bool v) {
    online = v;
    _save();
    notifyListeners();
  }

  void addCoins(int n) {
    coins += n;
    _save();
    notifyListeners();
  }

  Future<void> login(String ph) async {
    loggedIn = true;
    phone = ph;
    await _save();
    notifyListeners();
  }

  Future<void> logout() async {
    loggedIn = false;
    await _save();
    notifyListeners();
  }
}

String ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'abhi';
  if (d.inMinutes < 60) return '${d.inMinutes} min';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return '${d.inDays} din';
}
