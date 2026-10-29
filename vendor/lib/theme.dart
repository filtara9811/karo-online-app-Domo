import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Prototype (1QR vendor panel) ke rang — #sdOv variables
class K {
  static const ink = Color(0xFF17130F);
  static const ink2 = Color(0xFF2A2117);
  static const iv = Color(0xFFF6F2E9);
  static const line = Color(0xFFE7DFCD);
  static const gold = Color(0xFFB58A3A);
  static const goldL = Color(0xFFE9D8AE);
  static const acc = Color(0xFFC85A1B);
  static const accL = Color(0xFFE07A2E);
  static const green = Color(0xFF2F9E5F);
  static const red = Color(0xFFE0342F);
  static const muted = Color(0xFF8A8373);
  static const card = Colors.white;

  static const darkCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1D1810), Color(0xFF3A2A14)],
  );
  static const accGrad = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFE07A2E), Color(0xFFC85A1B)],
  );
  static const goldGrad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE9D8AE), Color(0xFFB58A3A)],
  );

  static List<BoxShadow> shadow([double o = .08]) => [
        BoxShadow(color: Colors.black.withValues(alpha: o), blurRadius: 18, offset: const Offset(0, 8)),
      ];
}

ThemeData appTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: K.acc, surface: K.iv),
    scaffoldBackgroundColor: K.iv,
  );
  return base.copyWith(
    textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(bodyColor: K.ink, displayColor: K.ink),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: K.ink),
  );
}

TextStyle tx(double size, {FontWeight w = FontWeight.w600, Color c = K.ink, double? h}) =>
    GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: w, color: c, height: h);

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg, style: tx(13, c: Colors.white)), duration: const Duration(seconds: 2)));
}

/// Gol kono wala safed card
class Box extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final Gradient? gradient;
  final double radius;
  final VoidCallback? onTap;
  final Border? border;
  const Box({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.color = K.card, this.gradient, this.radius = 20, this.onTap, this.border});

  @override
  Widget build(BuildContext context) {
    final b = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: border ?? (gradient == null ? Border.all(color: K.line) : null),
        boxShadow: K.shadow(.05),
      ),
      child: child,
    );
    if (onTap == null) return b;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: b);
  }
}
