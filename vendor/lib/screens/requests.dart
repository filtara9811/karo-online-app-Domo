import 'dart:async';
import 'package:flutter/material.dart';
import '../data.dart';
import '../ring.dart';
import '../theme.dart';

/// Requests inbox — prototype jaisa: Leads | Orders, har card par timer + Reject / Accept
void openRequests(BuildContext context) {
  Store.i.refresh();
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
  bool testing = false;

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

  Future<void> _test() async {
    setState(() => testing = true);
    try {
      await Store.i.testLead();
      if (mounted) toast(context, '✓ Test lead server par bani — ghanti bajegi');
    } catch (e) {
      if (mounted) toast(context, '⚠️ $e');
    }
    if (mounted) setState(() => testing = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.i,
      builder: (context, _) {
        final s = Store.i;
        final list = tab == 0 ? s.inbox : const <Req>[];
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
                  onPressed: testing ? null : _test,
                  icon: testing ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_alert_rounded, size: 18, color: K.acc),
                  label: Text('Test lead', style: tx(12.5, w: FontWeight.w800, c: K.acc)),
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
                  _seg(0, 'Leads', s.inbox.length, K.red),
                  _seg(1, 'Orders', 0, K.green),
                ]),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: RefreshIndicator(
                color: K.acc,
                onRefresh: s.refresh,
                child: list.isEmpty
                    ? ListView(children: [
                        const SizedBox(height: 80),
                        const Center(child: Icon(Icons.inbox_rounded, size: 48, color: K.goldL)),
                        const SizedBox(height: 8),
                        Center(child: Text(tab == 0 ? 'Abhi koi nayi request nahi' : 'Online orders chaaran 3 me', style: tx(14, w: FontWeight.w700, c: K.muted))),
                        Center(child: Text(tab == 0 ? 'Customer request bhejte hi yahan aayegi aur ghanti bajegi' : 'Digital dukaan ke orders yahan aayenge', style: tx(12, c: K.muted))),
                      ])
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                        children: [for (final r in list) ReqCard(key: ValueKey(r.id), req: r)],
                      ),
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

class ReqCard extends StatefulWidget {
  final Req req;
  const ReqCard({super.key, required this.req});
  @override
  State<ReqCard> createState() => _ReqCardState();
}

class _ReqCardState extends State<ReqCard> {
  bool busy = false;
  bool open = false;

  String _left() {
    final d = widget.req.left;
    if (d.isNegative) return 'samay khatam';
    return '${d.inMinutes}m ${(d.inSeconds % 60).toString().padLeft(2, '0')}s';
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.req;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: K.line), boxShadow: K.shadow(.05)),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(radius: 21, backgroundColor: K.ink, child: Text(r.initial, style: tx(16, w: FontWeight.w800, c: Colors.white))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(r.name, style: tx(16, w: FontWeight.w800), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 5),
                const Icon(Icons.verified_rounded, size: 18, color: Color(0xFF2563EB)),
              ]),
              Text('${r.icon} ${r.service}', style: tx(12.5, w: FontWeight.w700), overflow: TextOverflow.ellipsis),
              if (r.area.isNotEmpty) Text('📍 ${r.area}', style: tx(11.5, c: K.muted, w: FontWeight.w500), overflow: TextOverflow.ellipsis),
            ]),
          ),
          Text(_left(), style: tx(12, w: FontWeight.w800, c: K.acc)),
        ]),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => setState(() => open = !open),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFFAF6EC), borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              Row(children: [
                Container(width: 42, height: 42, alignment: Alignment.center, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: Text(r.icon, style: const TextStyle(fontSize: 20))),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.need.isEmpty ? '${r.service} chahiye' : r.need, style: tx(14, w: FontWeight.w800), maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text('${r.coins} coin · ${r.slots - r.taken} slots left', style: tx(11.5, c: K.muted)),
                  ]),
                ),
                AnimatedRotation(turns: open ? .5 : 0, duration: const Duration(milliseconds: 200), child: const Icon(Icons.arrow_drop_down_rounded, color: K.muted, size: 28)),
              ]),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                child: !open
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Row(children: [
                          _chip('🕐 ${hm(r.at)}'),
                          _chip(r.budget > 0 ? '💰 ₹${r.budget}' : '💰 —'),
                          _chip('👥 ${r.taken}/${r.slots} ne li'),
                        ]),
                      ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: busy
                  ? null
                  : () {
                      Ring.i.stop(r.id);
                      Store.i.reject(r);
                    },
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13), side: const BorderSide(color: K.line, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: Text('Reject', style: tx(15, w: FontWeight.w800, c: K.acc)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: busy
                  ? null
                  : () async {
                      setState(() => busy = true);
                      await acceptReq(context, r);
                      if (mounted) setState(() => busy = false);
                    },
              style: ElevatedButton.styleFrom(backgroundColor: K.acc, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)) : Text('Accept · ${r.coins} coin', style: tx(15, w: FontWeight.w800, c: Colors.white)),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _chip(String t) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 7),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
          child: Text(t, style: tx(11, w: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      );
}

/// Accept — server par coin katega. true = ho gaya
Future<bool> acceptReq(BuildContext context, Req r) async {
  Ring.i.stop(r.id);
  final err = await Store.i.accept(r);
  if (!context.mounted) return err == null;
  toast(context, err ?? '✓ ${r.coins} coin kata — ${r.name} ki lead aapki. "Leads" me dekhein');
  return err == null;
}
