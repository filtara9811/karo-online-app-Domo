import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data.dart';
import '../theme.dart';

/// Login — mobile number + OTP (demo OTP: 1234; asli OTP Fast2SMS se chaaran 5 me)
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _ph = TextEditingController();
  final _otp = TextEditingController();
  bool _sent = false;
  bool _busy = false;

  Future<void> _next() async {
    final ph = _ph.text.replaceAll(RegExp(r'\D'), '');
    if (!_sent) {
      if (ph.length != 10) {
        toast(context, 'Sahi 10 ankon ka mobile number daaliye');
        return;
      }
      setState(() => _busy = true);
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      setState(() {
        _busy = false;
        _sent = true;
      });
      toast(context, 'OTP bheja gaya (demo OTP: 1234)');
      return;
    }
    if (_otp.text.trim() != '1234') {
      toast(context, 'OTP galat hai — demo me 1234 daaliye');
      return;
    }
    await Store.i.login(ph);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 30, 22, 22),
          children: [
            Center(
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(26), boxShadow: K.shadow(.15)),
                clipBehavior: Clip.antiAlias,
                child: Image.asset('assets/logo.png', fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 18),
            Text('Karo Online', textAlign: TextAlign.center, style: tx(26, w: FontWeight.w800)),
            Text('BUSINESS', textAlign: TextAlign.center, style: tx(12, w: FontWeight.w800, c: K.gold).copyWith(letterSpacing: 4)),
            const SizedBox(height: 8),
            Text('Apni dukaan ke leads, orders aur bill — ek jagah', textAlign: TextAlign.center, style: tx(13.5, w: FontWeight.w500, c: K.muted)),
            const SizedBox(height: 30),
            Box(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_sent ? 'OTP daaliye' : 'Mobile number', style: tx(15, w: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(_sent ? '+91 ${_ph.text} par bheja gaya' : 'Isi number par OTP aayega', style: tx(12, c: K.muted, w: FontWeight.w500)),
                  const SizedBox(height: 14),
                  if (!_sent)
                    _field(_ph, '98xxx xxxxx', TextInputType.phone, 10, prefix: '+91  ')
                  else
                    _field(_otp, '• • • •', TextInputType.number, 4, center: true),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 52,
                    child: DecoratedBox(
                      decoration: BoxDecoration(gradient: K.accGrad, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: K.acc.withValues(alpha: .3), blurRadius: 14, offset: const Offset(0, 6))]),
                      child: TextButton(
                        onPressed: _busy ? null : _next,
                        child: _busy
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : Text(_sent ? 'Login karein' : 'OTP bhejein', style: tx(15.5, w: FontWeight.w800, c: Colors.white)),
                      ),
                    ),
                  ),
                  if (_sent)
                    TextButton(onPressed: () => setState(() => _sent = false), child: Text('Number badlein', style: tx(13, c: K.acc, w: FontWeight.w700))),
                ],
              ),
            ),
            const SizedBox(height: 26),
            Text('Powered by Filipra Private Limited', textAlign: TextAlign.center, style: tx(11, c: K.muted, w: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, TextInputType t, int max, {String? prefix, bool center = false}) {
    return TextField(
      controller: c,
      keyboardType: t,
      maxLength: max,
      textAlign: center ? TextAlign.center : TextAlign.start,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: tx(center ? 24 : 17, w: FontWeight.w800).copyWith(letterSpacing: center ? 10 : 1),
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        prefixText: prefix,
        prefixStyle: tx(17, w: FontWeight.w800, c: K.muted),
        filled: true,
        fillColor: K.iv,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: K.line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: K.line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: K.acc, width: 1.6)),
      ),
    );
  }
}
