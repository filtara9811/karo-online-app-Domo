import 'dart:async';
import 'package:flutter/material.dart';
import '../data.dart';
import '../ring.dart';
import '../theme.dart';
import 'incoming.dart';

/// Requests inbox — prototype jaisa: Leads | Orders, har card par Reject / Accept
void openRequests(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const RequestsSheet(),
  );
}

class RequestsSheet extends StatefulWidget {
  const RequestsSheet({super.key});
  @override
  State<RequestsSheet> createState() => _RequestsSheetState();
}

class _RequestsSheetState extends State<RequestsSheet> {
  int tab = 0;
  Timer? _t;

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

  Future<void> _demo() async {
    final r = Store.i.newDemoRequest();
    await Ring.i.ringNow(r);
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => IncomingScreen(req: r), fullscreenDialog: true));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.i,
      builder: (context, _) {
        final s = Store.i;
        final list = tab == 0 ? s.pendingLeads : s.pendingOrders;
        return Container(
          height: MediaQuery.of(context).size.height * .9,
          decoration: const BoxDecoration(color: K.iv, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(children: [
            const SizedBox(height: 10),
            Container(width: 44, height: 5, decoration: BoxDecoration(color: K.line, borderRadius: BorderRadius.circular(3))),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 12, 6),
              child: Row(children: [
                Text('Requests', style: tx(22, w: FontWeight.w800)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _demo,
                  icon: const Icon(Icons.add_alert_rounded, size: 18, color: K.acc),
                  label: Text('Demo request', style: tx(12.5, w: FontWeight.w800, c: K.acc)),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(backgroundColor: Colors.white),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: const Color(0xFFEDE6D6), borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  _seg(0, 'Leads', s.pendingLeads.length, K.red),
                  _seg(1, 'Orders', s.pendingOrders.length, K.green),
                ]),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.inbox_rounded, size: 48, color: K.goldL),
                        const SizedBox(height: 8),
                        Text('Abhi koi nayi request nahi', style: tx(14, w: FontWeight.w700, c: K.muted)),
                        Text('Nayi request aate hi ghanti bajegi', style: tx(12, c: K.muted)),
                      ]),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                      children: [for (final r in list) ReqCard(req: r)],
                    ),
            ),
          ]),
        );
      },
    );
  }

  Widget _seg(int i, String t, int n, Color c) => Expanded(
        child: GestureDetector(
          onTap: () => setState(() => tab = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 48,
            decoration: BoxDecoration(color: tab == i ? K.ink : Colors.transparent, borderRadius: BorderRadius.circular(13)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(t, style: tx(16, w: FontWeight.w800, c: tab == i ? Colors.white : K.muted)),
              const SizedBox(width: 8),
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                child: Text('$n', style: tx(11.5, w: FontWeight.w800, c: Colors.white)),
              ),
            ]),
          ),
        ),
      );
}

class ReqCard extends StatelessWidget {
  final Req req;
  const ReqCard({super.key, required this.req});

  String _left() {
    final d = const Duration(minutes: 20) - DateTime.now().difference(req.at);
    if (d.isNegative) return 'samay khatam';
    return '${d.inMinutes}m ${(d.inSeconds % 60).toString().padLeft(2, '0')}s';
  }

  @override
  Widget build(BuildContext context) {
    final r = req;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: K.line), boxShadow: K.shadow(.05)),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(radius: 21, backgroundColor: const Color(0xFFEFE9DC), child: Text(r.initial, style: tx(16, w: FontWeight.w800))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(r.name, style: tx(16, w: FontWeight.w800), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 5),
                const Icon(Icons.verified_rounded, size: 18, color: Color(0xFF2563EB)),
              ]),
              Row(children: [
                Icon(r.icon, size: 14, color: K.acc),
                const SizedBox(width: 4),
                Flexible(child: Text(r.service, style: tx(12.5, w: FontWeight.w700), overflow: TextOverflow.ellipsis)),
              ]),
              Row(children: [
                const Icon(Icons.location_on_rounded, size: 14, color: K.red),
                const SizedBox(width: 3),
                Flexible(child: Text('${r.area} · ${r.km.toStringAsFixed(1)} km', style: tx(11.5, c: K.muted, w: FontWeight.w500), overflow: TextOverflow.ellipsis)),
              ]),
            ]),
          ),
          Text(_left(), style: tx(12, w: FontWeight.w800, c: K.acc)),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFFAF6EC), borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Icon(r.isOrder ? Icons.shopping_bag_rounded : r.icon, color: K.gold),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.need, style: tx(14, w: FontWeight.w800), maxLines: 2, overflow: TextOverflow.ellipsis),
                Text(r.isOrder ? '${r.amount} · ${r.service}' : '${r.coins} coin · ${r.slots} slots left', style: tx(11.5, c: K.muted)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                Ring.i.stop(r);
                Store.i.reject(r);
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: const BorderSide(color: K.line, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Reject', style: tx(15, w: FontWeight.w800, c: K.acc)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () => acceptReq(context, r),
              style: ElevatedButton.styleFrom(
                backgroundColor: K.acc,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Accept', style: tx(15, w: FontWeight.w800, c: Colors.white)),
            ),
          ),
        ]),
      ]),
    );
  }
}

/// Accept — coin katega; coin kam ho to recharge ka message
bool acceptReq(BuildContext context, Req r) {
  Ring.i.stop(r);
  final ok = Store.i.accept(r);
  if (!ok) {
    toast(context, 'Coins kam hain — pehle recharge karein');
    return false;
  }
  toast(context, r.isOrder ? 'Order accept — ${r.name} ko bata diya' : '${r.coins} coin kata — ${r.name} ki lead aapki');
  return true;
}
