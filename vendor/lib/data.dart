import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'catalog.dart';

/// Ek lead (customer ki request)
class Req {
  final int id;
  final String name, phone, service, category, icon, need, area;
  final int budget, coins, slots, taken;
  final DateTime at, expires;
  String step; // accept | action | working | reached | done | review
  Req({
    required this.id,
    required this.name,
    this.phone = '',
    required this.service,
    this.category = '',
    required this.icon,
    this.need = '',
    this.area = '',
    this.budget = 0,
    this.coins = 1,
    this.slots = 5,
    this.taken = 0,
    required this.at,
    DateTime? expires,
    this.step = 'accept',
  }) : expires = expires ?? at.add(const Duration(minutes: 30));

  factory Req.fromJson(Map<String, dynamic> j) {
    final svc = (j['service'] ?? '').toString();
    final ic = (j['icon'] ?? '').toString();
    DateTime p(String k) => DateTime.tryParse((j[k] ?? '').toString())?.toLocal() ?? DateTime.now();
    return Req(
      id: (j['id'] as num).toInt(),
      name: (j['name'] ?? 'Customer').toString(),
      phone: (j['phone'] ?? '').toString(),
      service: svc,
      category: (j['category'] ?? '').toString(),
      icon: ic.isNotEmpty ? ic : Catalog.iconFor(svc),
      need: (j['need'] ?? '').toString(),
      area: (j['area'] ?? '').toString(),
      budget: (j['budget'] as num?)?.toInt() ?? 0,
      coins: (j['coins'] as num?)?.toInt() ?? 1,
      slots: (j['slots'] as num?)?.toInt() ?? 5,
      taken: (j['taken'] as num?)?.toInt() ?? 0,
      at: p('created_at'),
      expires: j['expires_at'] == null ? null : p('expires_at'),
      step: (j['step'] ?? 'accept').toString(),
    );
  }

  String get initial => name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
  Duration get left => expires.difference(DateTime.now());
}

/// 6 kadam — prototype jaisa
const kSteps = ['accept', 'action', 'working', 'done', 'review'];
const kStepLabel = {
  'accept': 'Accept',
  'action': 'Action',
  'working': 'Working',
  'reached': 'Working',
  'done': 'Done',
  'review': 'Review',
  'skip': 'Skipped',
};

class Store extends ChangeNotifier {
  Store._();
  static final Store i = Store._();

  String phone = '';
  Map<String, dynamic>? vendor; // backend se
  bool online = true;
  bool loading = false;
  String? error;

  List<Req> inbox = []; // khuli leads (accept nahi ki)
  List<Req> leads = []; // meri leads (accept ki hui)
  final Set<int> _hidden = {}; // reject / local hata di
  Timer? _poll;

  bool get loggedIn => phone.isNotEmpty && Api.auth.signedIn;
  bool get joined => vendor != null;
  String get vendorId => (vendor?['id'] ?? '').toString();
  String get shopName => (vendor?['shop_name'] ?? 'Meri dukaan').toString();
  String get ownerName => (vendor?['owner_name'] ?? '').toString();
  int get coins => (vendor?['coins'] as num?)?.toInt() ?? 0;
  List<String> get subs => List<String>.from(vendor?['subs'] ?? const []);
  List<String> get cats => List<String>.from(vendor?['cats'] ?? const []);
  Map<String, dynamic> get settings => Map<String, dynamic>.from(vendor?['settings'] ?? const {});

  /// Lead settings / store profile / mapping save — server par, turant leads isi hisaab se aayengi
  Future<void> updateVendor(Map<String, dynamic> patch) async {
    final v = Map<String, dynamic>.from(vendor ?? {});
    v.addAll(patch);
    // phone server login se leta hai — yahan se nahi
    final saved = await Api.rpc('ko_vendor_save', {
      'p': {
        'shop_name': v['shop_name'],
        'owner_name': v['owner_name'],
        'area': v['area'],
        'ty': v['ty'],
        'role': v['role'],
        'biz': v['biz'],
        'radius': '${v['radius'] ?? '5'}',
        'cats': v['cats'] ?? [],
        'subs': v['subs'] ?? [],
        'items': v['items'] ?? {},
        'settings': v['settings'] ?? {},
      }
    });
    vendor = Map<String, dynamic>.from(saved);
    await _save();
    notifyListeners();
    refresh();
  }

  Future<void> saveSettings(Map<String, dynamic> patch) {
    final s = settings..addAll(patch);
    return updateVendor({'settings': s});
  }

  /// "+ New lead" — vendor ki apni lead (dukaan par aaya / phone aaya)
  Future<void> addManualLead(Map<String, dynamic> p) async {
    await Api.rpc('ko_vendor_add_lead', {'p': p});
    await refresh();
  }

  final Set<int> pinned = {};
  void togglePin(int id) {
    pinned.contains(id) ? pinned.remove(id) : pinned.add(id);
    notifyListeners();
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    online = p.getBool('online') ?? true;
    if (Api.auth.signedIn) {
      // phone sirf asli login (OTP session) se — purane demo login wale ko dobara OTP dena hoga
      phone = Api.auth.phone;
      final v = p.getString('vendor');
      if (v != null) vendor = jsonDecode(v);
    } else {
      phone = '';
      vendor = null;
      await _save();
    }
    // Session khatam (refresh token bekaar / server ne mana) → login screen
    Api.auth.changes.listen((s) {
      if (s == null && phone.isNotEmpty) _clear();
    });
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('phone', phone);
    await p.setBool('online', online);
    if (vendor == null) {
      await p.remove('vendor');
      await p.remove('vendorId');
    } else {
      await p.setString('vendor', jsonEncode(vendor));
      await p.setString('vendorId', vendorId);
    }
  }

  /// OTP verify ke baad: server par is login ki dukaan hai? (nahi = Join flow)
  Future<void> afterLogin() async {
    if (!Api.auth.signedIn) return;
    phone = Api.auth.phone;
    error = null;
    try {
      final v = await Api.rpc('ko_me');
      vendor = v == null ? null : Map<String, dynamic>.from(v);
    } catch (e) {
      vendor = null;
      error = e.toString();
    }
    await _save();
    notifyListeners();
  }

  /// Server par dukaan save (join flow). App abhi home par nahi jaati — success screen ke "Done" par [applyVendor].
  Future<Map<String, dynamic>> saveVendor(Map<String, dynamic> data) async {
    final v = await Api.rpc('ko_vendor_save', {'p': data});
    return Map<String, dynamic>.from(v);
  }

  Future<void> applyVendor(Map<String, dynamic> v) async {
    vendor = v;
    online = true;
    await _save();
    notifyListeners();
  }

  Future<void> logout() async {
    await Api.auth.signOut();
    await _clear();
  }

  Future<void> _clear() async {
    stopPolling();
    phone = '';
    vendor = null;
    inbox = [];
    leads = [];
    _seen.clear();
    _first = true;
    await _save();
    notifyListeners();
  }

  // ---------------- leads ----------------
  void startPolling() {
    _poll?.cancel();
    refresh();
    _poll = Timer.periodic(const Duration(seconds: 6), (_) => refresh());
  }

  void stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  /// Nayi aayi lead ids (UI ko ghanti / full-screen ke liye)
  final StreamController<Req> newLead = StreamController<Req>.broadcast();
  final Set<int> _seen = {};
  bool _first = true;

  Future<void> refresh() async {
    if (!joined) return;
    try {
      final a = await Api.rpc('ko_inbox');
      final b = await Api.rpc('ko_my_leads');
      final ib = [for (final x in (a as List)) Req.fromJson(Map<String, dynamic>.from(x))].where((r) => !_hidden.contains(r.id)).toList();
      final auto = settings['accept'] == 'auto';
      final minC = (settings['minCoins'] as num?)?.toInt() ?? 10;
      for (final r in ib) {
        if (!_seen.contains(r.id)) {
          _seen.add(r.id);
          if (auto && coins >= minC + r.coins) {
            accept(r); // Auto accept — coin kat-ta hai
          } else if (!_first) {
            newLead.add(r);
          }
        }
      }
      _first = false;
      inbox = ib;
      leads = [for (final x in (b as List)) Req.fromJson(Map<String, dynamic>.from(x))];
      error = null;
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  Req? byId(int? id) {
    for (final r in inbox) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Accept: server par coin katega. null = ho gaya, warna galti ka message
  Future<String?> accept(Req r) async {
    try {
      final res = Map<String, dynamic>.from(await Api.rpc('ko_lead_accept', {'p_lead': r.id}));
      if (res['ok'] != true) return (res['msg'] ?? 'Nahi ho paya').toString();
      vendor?['coins'] = res['coins'];
      _hidden.add(r.id);
      inbox.removeWhere((x) => x.id == r.id);
      await _save();
      notifyListeners();
      refresh();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> reject(Req r) async {
    _hidden.add(r.id);
    inbox.removeWhere((x) => x.id == r.id);
    notifyListeners();
    try {
      await Api.rpc('ko_lead_reject', {'p_lead': r.id});
    } catch (_) {}
  }

  Future<void> setStep(Req r, String s) async {
    r.step = s;
    notifyListeners();
    try {
      await Api.rpc('ko_lead_step', {'p_lead': r.id, 'p_step': s});
    } catch (_) {}
  }

  Future<void> setOnline(bool v) async {
    online = v;
    await _save();
    notifyListeners();
    try {
      await Api.rpc('ko_set_online', {'p_online': v});
    } catch (_) {}
  }

  /// Demo coins (server par demo mode band ho to mana) — null = ho gaya, warna galti
  Future<String?> addCoins(int n) async {
    try {
      final c = await Api.rpc('ko_coins_add', {'p_n': n});
      vendor?['coins'] = c;
      await _save();
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Test: apni hi pehli service par ek asli lead banao (customer ki jagah)
  Future<void> testLead() async {
    final s = subs.isNotEmpty ? subs.first : 'General request';
    await Api.rpc('ko_lead_create', {
      'p': {
        'customer_name': 'Test Customer',
        'customer_phone': '9999999999',
        'service': s,
        'icon': Catalog.iconFor(s),
        'need': '$s chahiye — aaj hi',
        'budget': 500,
        'area': (vendor?['area'] ?? 'Delhi').toString(),
      }
    });
    await refresh();
  }

  // ---------------- leads ke ginti ----------------
  int count(String bucket) {
    switch (bucket) {
      case 'pending':
        return leads.where((l) => l.step == 'accept').length;
      case 'chal':
        return leads.where((l) => ['action', 'working', 'reached'].contains(l.step)).length;
      case 'done':
        return leads.where((l) => ['done', 'review'].contains(l.step)).length;
      case 'skip':
        return leads.where((l) => l.step == 'skip').length;
      case 'new':
        return leads.where((l) => DateTime.now().difference(l.at).inHours < 24 && l.step == 'accept').length;
    }
    return leads.length;
  }
}

String ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'abhi';
  if (d.inMinutes < 60) return '${d.inMinutes} min';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return '${d.inDays} din';
}

String hm(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'am' : 'pm'}';
}

void debugLog(Object o) {
  if (kDebugMode) debugPrint('$o');
}
