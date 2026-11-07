import 'dart:convert';
import 'package:flutter/services.dart';

/// Prototype (SJT + SJI) se nikali category → sub-service → items list
class Item {
  final String e, n;
  final int p;
  Item(this.e, this.n, this.p);
}

class Sub {
  final String e, n;
  final List<Item> items;
  Sub(this.e, this.n, this.items);
}

class Cat {
  final String e, n;
  final List<Sub> subs;
  Cat(this.e, this.n, this.subs);
}

class CType {
  final String key, l, e, h;
  final List<Cat> cats;
  CType(this.key, this.l, this.e, this.h, this.cats);
}

/// [key, emoji, title, subtitle]
typedef Opt = List<String>;

class Catalog {
  static final Map<String, CType> types = {};
  static final List<Opt> svcModes = [];
  static final List<Opt> biz = [];
  static final List<Opt> rad = [];

  static const List<Opt> roles = [
    ['retailer', '🛍️', 'Retailer', 'Seedha customer ko bechte hain'],
    ['wholesaler', '📦', 'Wholesaler', 'Thok me dukaanon ko'],
    ['manufacturer', '🏭', 'Manufacturer', 'Khud banate hain'],
    ['distributor', '🚚', 'Distributor', 'Company ka maal aage dete hain'],
    ['service', '🛠️', 'Service provider', 'Kaam / service dete hain'],
    ['other', '✨', 'Other', 'Kuch aur'],
  ];

  static Future<void> load() async {
    if (types.isNotEmpty) return;
    final j = jsonDecode(await rootBundle.loadString('assets/catalog.json'));
    for (final k in ['svc', 'prd', 'oth']) {
      final t = j['types'][k];
      types[k] = CType(
        k,
        t['l'],
        t['e'],
        t['h'],
        [
          for (final c in t['c'])
            Cat(c['e'], c['n'], [
              for (final s in c['subs'])
                Sub(s['e'], s['n'], [for (final i in s['items']) Item(i['e'], i['n'], (i['p'] as num).toInt())]),
            ]),
        ],
      );
    }
    for (final o in j['roles']['svc']['o']) {
      svcModes.add(List<String>.from(o));
    }
    for (final o in j['biz']) {
      biz.add(List<String>.from(o));
    }
    for (final o in j['rad']) {
      rad.add(List<String>.from(o));
    }
  }

  /// Service wale: "Service kaise dete hain", baaki: "Aap kaun hain"
  static List<Opt> roleOpts(String ty) => ty == 'svc' ? svcModes : roles;
  static String roleTitle(String ty) => ty == 'svc' ? 'Aap service kaise dete hain?' : 'Aap kaun hain?';
  static String roleSub(String ty) =>
      ty == 'svc' ? 'Customer ko pata chalega aap kaam kaise karte hain' : 'Ye badge aapki profile par dikhega — customer ko pata chalega aap kaise deal karte hain';
  static Opt? opt(List<Opt> l, String? k) {
    for (final o in l) {
      if (o[0] == k) return o;
    }
    return null;
  }

  static String iconFor(String service) {
    final s = service.toLowerCase();
    for (final t in types.values) {
      for (final c in t.cats) {
        for (final x in c.subs) {
          if (x.n.toLowerCase() == s) return x.e;
        }
        if (c.n.toLowerCase() == s) return c.e;
      }
    }
    return '🛠️';
  }
}
