import 'dart:async';
import 'package:flutter/material.dart';
import '../data.dart';
import '../ring.dart';
import '../theme.dart';
import 'requests.dart';

/// Nayi request — poori screen (phone lock ho to bhi khulti hai), ghanti bajti rehti hai
class IncomingScreen extends StatefulWidget {
  final Req req;
  const IncomingScreen({super.key, required this.req});
  @override
  State<IncomingScreen> createState() => _IncomingScreenState();
}

class _IncomingScreenState extends State<IncomingScreen> with SingleTickerProviderStateMixin {
  static const total = 30;
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  Timer? _t;
  int left = total;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => left--);
      if (left <= 0) _miss();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  void _close() {
    _t?.cancel();
    Ring.i.stop(widget.req);
    if (mounted && Navigator.canPop(context)) Navigator.pop(context);
  }

  void _miss() {
    widget.req.status = 'naya';
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.req;
    return Scaffold(
      backgroundColor: K.ink,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: K.red.withValues(alpha: .2), borderRadius: BorderRadius.circular(20)),
                child: Row(children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: K.red, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(r.isOrder ? 'NAYA ORDER' : 'NAYI REQUEST', style: tx(12, w: FontWeight.w800, c: const Color(0xFFFF8A80)).copyWith(letterSpacing: 1)),
                ]),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  Ring.i.stop(r);
                  toast(context, 'Ghanti band — request abhi bhi khuli hai');
                },
                icon: const Icon(Icons.volume_off_rounded, color: Colors.white70),
              ),
            ]),
            const Spacer(),
            SizedBox(
              width: 220,
              height: 220,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => Stack(alignment: Alignment.center, children: [
                  for (var k = 0; k < 3; k++) _ring((_pulse.value + k / 3) % 1),
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(gradient: K.goldGrad, shape: BoxShape.circle, boxShadow: [BoxShadow(color: K.gold.withValues(alpha: .5), blurRadius: 30)]),
                    child: Icon(r.icon, size: 52, color: K.ink),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 18),
            Text(r.service, style: tx(26, w: FontWeight.w800, c: Colors.white), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(r.need, style: tx(15, w: FontWeight.w600, c: K.goldL), textAlign: TextAlign.center),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .07), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white12)),
              child: Row(children: [
                CircleAvatar(radius: 22, backgroundColor: K.goldL, child: Text(r.initial, style: tx(17, w: FontWeight.w800))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(r.name, style: tx(16, w: FontWeight.w800, c: Colors.white)),
                      const SizedBox(width: 5),
                      const Icon(Icons.verified_rounded, size: 17, color: Color(0xFF60A5FA)),
                    ]),
                    Text('${r.area} · ${r.km.toStringAsFixed(1)} km', style: tx(12, c: Colors.white60), overflow: TextOverflow.ellipsis),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(r.isOrder ? r.amount : '${r.coins} coin', style: tx(16, w: FontWeight.w800, c: K.goldL)),
                  Text(r.isOrder ? 'order' : '${r.slots} slots left', style: tx(11, c: Colors.white54)),
                ]),
              ]),
            ),
            const Spacer(),
            Stack(alignment: Alignment.center, children: [
              SizedBox(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(value: left / total, strokeWidth: 4, color: K.goldL, backgroundColor: Colors.white12),
              ),
              Text('$left', style: tx(20, w: FontWeight.w800, c: Colors.white)),
            ]),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                child: SizedBox(
                  height: 58,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Store.i.reject(r);
                      _close();
                    },
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    label: Text('Reject', style: tx(16, w: FontWeight.w800, c: Colors.white)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white30, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 58,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (acceptReq(context, r)) _close();
                    },
                    icon: const Icon(Icons.check_rounded, color: Colors.white),
                    label: Text('Accept', style: tx(17, w: FontWeight.w800, c: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: K.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _ring(double v) => Container(
        width: 112 + v * 108,
        height: 112 + v * 108,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: K.goldL.withValues(alpha: (1 - v) * .7), width: 2)),
      );
}
