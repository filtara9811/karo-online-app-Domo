import 'package:flutter/material.dart';

/// Intro: 2 second kaali screen (logo) -> narangi screen, logo ke teer par chamak
class KoSplash extends StatefulWidget {
  final bool ready; // page load ho gaya?
  final VoidCallback onDone;
  const KoSplash({super.key, required this.ready, required this.onDone});
  @override
  State<KoSplash> createState() => _KoSplashState();
}

class _KoSplashState extends State<KoSplash> with TickerProviderStateMixin {
  late final AnimationController _in =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  late final AnimationController _shine =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
  bool _orange = false;
  bool _minOver = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) setState(() => _orange = true);
    });
    Future.delayed(const Duration(milliseconds: 3600), () {
      if (!mounted) return;
      _minOver = true;
      _check();
    });
  }

  @override
  void didUpdateWidget(covariant KoSplash old) {
    super.didUpdateWidget(old);
    _check();
  }

  void _check() {
    if (_done || !_minOver || !widget.ready) return;
    _done = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _in.dispose();
    _shine.dispose();
    super.dispose();
  }

  Widget _mark(double w) {
    return SizedBox(
      width: w,
      child: Stack(children: [
        Image.asset('assets/splash_mark.png', width: w, filterQuality: FilterQuality.high),
        // teer par chalti chamak
        AnimatedBuilder(
          animation: _shine,
          builder: (_, child) {
            final t = _shine.value * 1.8 - .4;
            return ShaderMask(
              blendMode: BlendMode.srcATop,
              shaderCallback: (r) => LinearGradient(
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
                colors: const [Color(0x00FFFFFF), Color(0xDDFFFFFF), Color(0x00FFFFFF)],
                stops: [(t - .12).clamp(0.0, 1.0), t.clamp(0.0, 1.0), (t + .12).clamp(0.0, 1.0)],
              ).createShader(r),
              child: child,
            );
          },
          child: Image.asset('assets/splash_arrow.png', width: w, filterQuality: FilterQuality.high),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeInOut,
      color: _orange ? const Color(0xFFF47B20) : Colors.black,
      alignment: Alignment.center,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 550),
        switchInCurve: Curves.easeOutCubic,
        transitionBuilder: (c, a) => FadeTransition(
            opacity: a, child: ScaleTransition(scale: Tween(begin: .94, end: 1.0).animate(a), child: c)),
        child: !_orange
            ? FadeTransition(
                key: const ValueKey('black'),
                opacity: CurvedAnimation(parent: _in, curve: Curves.easeOut),
                child: ScaleTransition(
                  scale: Tween(begin: .9, end: 1.0).animate(CurvedAnimation(parent: _in, curve: Curves.easeOutBack)),
                  child: Image.asset('assets/splash_full.jpg', width: w * .72, filterQuality: FilterQuality.high),
                ),
              )
            : Column(key: const ValueKey('orange'), mainAxisSize: MainAxisSize.min, children: [
                _mark(w * .5),
                const SizedBox(height: 18),
                const Text('Karo Online',
                    style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: .3)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white60)),
                  child: const Text('BETA VERSION',
                      style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1.8)),
                ),
                const SizedBox(height: 28),
                const SizedBox(
                    width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.6)),
              ]),
      ),
    );
  }
}
