import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api.dart';
import '../data.dart';
import '../theme.dart';

/// Login — prototype jaisa: poster + brand, 2 bade button, neeche se cream panel (number → OTP → success)
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  int step = 0; // 0 welcome, 1 number, 2 otp, 3 success
  bool viaWa = false;
  String cc = '+91';
  final _ph = TextEditingController();
  /// Supabase Auth ka OTP 6 ank ka hota hai
  static const kOtpLen = 6;
  final _otp = List.generate(kOtpLen, (_) => TextEditingController());
  final _otpF = List.generate(kOtpLen, (_) => FocusNode());
  Timer? _t;
  int resend = 30;
  bool busy = false;
  late final AnimationController _zoom = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat(reverse: true);

  @override
  void dispose() {
    _t?.cancel();
    _zoom.dispose();
    super.dispose();
  }

  String get ph => _ph.text.replaceAll(RegExp(r'\D'), '');
  String get otp => _otp.map((c) => c.text).join();

  void _go(int s) {
    setState(() => step = s);
    if (s == 1) Future.delayed(const Duration(milliseconds: 350), () {});
  }

  Future<void> _send() async {
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(ph)) {
      toast(context, '⚠️ Sahi 10 ankon ka mobile number daaliye');
      return;
    }
    if (busy) return;
    setState(() => busy = true);
    try {
      await Api.auth.sendOtp(ph);
    } catch (e) {
      if (mounted) {
        setState(() => busy = false);
        toast(context, '⚠️ $e');
      }
      return;
    }
    if (!mounted) return;
    setState(() => busy = false);
    for (final c in _otp) {
      c.clear();
    }
    resend = 30;
    _t?.cancel();
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => resend = resend > 0 ? resend - 1 : 0);
      if (resend == 0) t.cancel();
    });
    _go(2);
    // WhatsApp OTP abhi nahi — dono button SMS bhejte hain (sach batate hain)
    toast(context, viaWa ? 'OTP SMS se bheja (WhatsApp OTP jald aa raha hai)' : 'OTP SMS se bheja');
    Future.delayed(const Duration(milliseconds: 400), () => _otpF[0].requestFocus());
  }

  Future<void> _verify() async {
    if (otp.length != kOtpLen || busy) return;
    FocusScope.of(context).unfocus();
    setState(() => busy = true);
    try {
      await Api.auth.verifyOtp(ph, otp);
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      for (final c in _otp) {
        c.clear();
      }
      _otpF[0].requestFocus();
      toast(context, '⚠️ $e');
      return;
    }
    if (!mounted) return;
    setState(() {
      busy = false;
      step = 3;
    });
  }

  Future<void> _continue() async {
    if (busy) return;
    setState(() => busy = true);
    await Store.i.afterLogin();
    if (!mounted) return;
    setState(() => busy = false);
    if (Store.i.error != null && !Store.i.loggedIn) toast(context, '⚠️ ${Store.i.error}');
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF1A120A),
      resizeToAvoidBottomInset: true,
      body: Stack(children: [
        // poster (dheere zoom — video jaisa ehsaas)
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _zoom,
            builder: (_, c) => Transform.scale(scale: 1.0 + _zoom.value * .06, child: c),
            child: Image.asset('assets/login-poster.jpg', fit: BoxFit.cover),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: .35), Colors.transparent, Colors.transparent, Colors.black.withValues(alpha: step == 0 ? .55 : .2)],
                stops: const [0, .18, .6, 1],
              ),
            ),
          ),
        ),
        // brand
        Positioned(
          left: 20,
          top: mq.padding.top + 14,
          child: Row(children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), boxShadow: K.shadow(.3)),
              clipBehavior: Clip.antiAlias,
              child: Image.asset('assets/logo.png', fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text.rich(TextSpan(children: [
                TextSpan(text: 'Karo ', style: tx(30, w: FontWeight.w800, c: Colors.white)),
                TextSpan(text: 'Online', style: tx(30, w: FontWeight.w800, c: const Color(0xFFFFA62B))),
              ])),
              Text('SHOP · EXPLORE · GROW', style: tx(11, w: FontWeight.w700, c: Colors.white).copyWith(letterSpacing: 3)),
            ]),
          ]),
        ),
        // play badge
        if (step == 0)
          Align(
            alignment: const Alignment(0, -.15),
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: .35), border: Border.all(color: Colors.white70, width: 2)),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 56),
            ),
          ),
        // welcome buttons
        AnimatedPositioned(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          left: 20,
          right: 20,
          bottom: step == 0 ? mq.padding.bottom + 34 : -220,
          child: Column(children: [
            _bigBtn(
              icon: Icons.call_rounded,
              text: 'Login with Mobile Number',
              bg: Colors.white.withValues(alpha: .86),
              fg: const Color(0xFF1D2B3A),
              onTap: () {
                viaWa = false;
                _go(1);
              },
            ),
            const SizedBox(height: 14),
            _bigBtn(
              icon: Icons.chat_rounded,
              text: 'Login with WhatsApp',
              bg: const Color(0xFF1FA855),
              fg: Colors.white,
              onTap: () {
                viaWa = true;
                _go(1);
              },
            ),
          ]),
        ),
        // cream panel
        AnimatedPositioned(
          duration: const Duration(milliseconds: 460),
          curve: Curves.easeOutCubic,
          left: 0,
          right: 0,
          bottom: step == 0 ? -520 : 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(22, 20, 22, 22 + mq.padding.bottom),
            decoration: const BoxDecoration(color: K.cream, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(.08, 0), end: Offset.zero).animate(a), child: c)),
              child: KeyedSubtree(key: ValueKey(step), child: _panel()),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _panel() {
    if (step == 3) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
          builder: (_, v, __) => Transform.scale(
            scale: v,
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFDDF3E4), border: Border.all(color: const Color(0xFFEAF7EE), width: 8)),
              child: Container(
                margin: const EdgeInsets.all(6),
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF2BB55F), Color(0xFF16904A)])),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 56),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text('Login Successful!', style: tx(24, w: FontWeight.w800, c: K.txt)),
        const SizedBox(height: 4),
        Text('Welcome back to Karo Online', style: tx(14, w: FontWeight.w500, c: K.sub)),
        const SizedBox(height: 18),
        _orangeBtn('Continue', _continue, enabled: !busy, loading: busy),
      ]);
    }
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        onTap: () => _go(step - 1),
        child: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(color: Color(0xFFEFE7D6), shape: BoxShape.circle),
          child: const Icon(Icons.chevron_left_rounded, color: K.txt),
        ),
      ),
      const SizedBox(height: 14),
      if (step == 1) ...[
        Text('Enter Mobile Number', style: tx(23, w: FontWeight.w800, c: K.txt)),
        const SizedBox(height: 4),
        Text(viaWa ? 'WhatsApp par 4-digit OTP aayega' : "We'll send you a 4-digit OTP", style: tx(14, w: FontWeight.w500, c: K.sub)),
        const SizedBox(height: 18),
        Row(children: [
          Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFF1D7B8), width: 1.5)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: cc,
                style: tx(16, w: FontWeight.w700, c: K.txt),
                items: const [
                  DropdownMenuItem(value: '+91', child: Text('🇮🇳 +91')),
                  DropdownMenuItem(value: '+971', child: Text('🇦🇪 +971')),
                  DropdownMenuItem(value: '+1', child: Text('🇺🇸 +1')),
                  DropdownMenuItem(value: '+44', child: Text('🇬🇧 +44')),
                ],
                onChanged: (v) => setState(() => cc = v ?? '+91'),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _ph,
              autofocus: true,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              style: tx(17, w: FontWeight.w700, c: K.txt).copyWith(letterSpacing: 1.2),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'Enter mobile number',
                hintStyle: tx(16, w: FontWeight.w600, c: const Color(0xFFB5AC9A)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: K.or, width: 1.5)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: K.orD, width: 2)),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        _orangeBtn('Send OTP', _send, enabled: ph.length == 10),
        const SizedBox(height: 14),
        Center(
          child: Text.rich(
            TextSpan(style: tx(12, w: FontWeight.w500, c: K.sub), children: const [
              TextSpan(text: 'By continuing, you agree to our '),
              TextSpan(text: 'Terms & Conditions', style: TextStyle(decoration: TextDecoration.underline)),
              TextSpan(text: ' and '),
              TextSpan(text: 'Privacy Policy', style: TextStyle(decoration: TextDecoration.underline)),
            ]),
            textAlign: TextAlign.center,
          ),
        ),
      ],
      if (step == 2) ...[
        Text('Enter OTP', style: tx(23, w: FontWeight.w800, c: K.txt)),
        const SizedBox(height: 4),
        Row(children: [
          Text('OTP sent to ', style: tx(14, w: FontWeight.w500, c: K.sub)),
          Text('$cc ${ph.substring(0, 5)} ${ph.substring(5)}', style: tx(14, w: FontWeight.w800, c: K.txt)),
          const SizedBox(width: 8),
          GestureDetector(onTap: () => _go(1), child: Text('Edit', style: tx(14, w: FontWeight.w800, c: K.orD))),
        ]),
        const SizedBox(height: 18),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var k = 0; k < kOtpLen; k++)
            Flexible(
              child: Container(
              constraints: const BoxConstraints(maxWidth: 54),
              height: 62,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: TextField(
                controller: _otp[k],
                focusNode: _otpF[k],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: kOtpLen, // poora OTP paste ho sake
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: tx(24, w: FontWeight.w800, c: K.txt),
                onChanged: (v) {
                  if (v.length == 2) {
                    // bhare dabbe me naya ank — sirf naya rakho, aage badho
                    _otp[k].text = v.substring(1);
                    if (k < kOtpLen - 1) _otpF[k + 1].requestFocus();
                  } else if (v.length > 2) {
                    // SMS se poora OTP paste / autofill hua — dabbon me baant do
                    final d = v.replaceAll(RegExp(r'\D'), '');
                    for (var j = 0; j < kOtpLen; j++) {
                      _otp[j].text = j < d.length ? d[j] : '';
                    }
                    _otpF[(d.length.clamp(1, kOtpLen)) - 1].requestFocus();
                  } else {
                    if (v.isNotEmpty && k < kOtpLen - 1) _otpF[k + 1].requestFocus();
                    if (v.isEmpty && k > 0) _otpF[k - 1].requestFocus();
                  }
                  setState(() {});
                  if (otp.length == kOtpLen) _verify();
                },
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFF1D7B8), width: 1.5)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: K.or, width: 2)),
                ),
              ),
            ),
            ),
        ]),
        const SizedBox(height: 10),
        Center(
          child: resend > 0
              ? Text('Resend OTP in 00:${resend.toString().padLeft(2, '0')}', style: tx(13, w: FontWeight.w600, c: K.sub))
              : GestureDetector(onTap: _send, child: Text('Resend OTP', style: tx(13.5, w: FontWeight.w800, c: K.orD))),
        ),
        const SizedBox(height: 14),
        _orangeBtn('Verify & Login', _verify, enabled: otp.length == kOtpLen && !busy, loading: busy),
        const SizedBox(height: 12),
        Center(child: Text('Naya number = Sign up · pehle wala = seedha Login', textAlign: TextAlign.center, style: tx(11.5, w: FontWeight.w500, c: K.sub))),
      ],
    ]);
  }

  Widget _bigBtn({required IconData icon, required String text, required Color bg, required Color fg, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: .5)), boxShadow: K.shadow(.25)),
        child: Row(children: [
          Icon(icon, color: fg, size: 24),
          Expanded(child: Text(text, textAlign: TextAlign.center, style: tx(16.5, w: FontWeight.w800, c: fg))),
          Icon(Icons.arrow_forward_rounded, color: fg, size: 24),
        ]),
      ),
    );
  }
}

/// Prototype ka bada orange button (disabled = halka)
Widget _orangeBtn(String t, VoidCallback onTap, {bool enabled = true, bool loading = false}) {
  return GestureDetector(
    onTap: enabled ? onTap : null,
    child: AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1 : .45,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: K.orGrad,
          borderRadius: BorderRadius.circular(16),
          boxShadow: enabled ? [BoxShadow(color: K.orD.withValues(alpha: .3), blurRadius: 16, offset: const Offset(0, 6))] : null,
        ),
        child: loading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : Text(t, style: tx(16.5, w: FontWeight.w800, c: Colors.white)),
      ),
    ),
  );
}
