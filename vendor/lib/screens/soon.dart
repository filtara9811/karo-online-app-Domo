import 'package:flutter/material.dart';
import '../theme.dart';

/// Jo screen agle chaaran me banegi uska saaf placeholder
class SoonScreen extends StatelessWidget {
  final String title;
  final int step;
  final IconData icon;
  const SoonScreen({super.key, required this.title, required this.step, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: K.iv, surfaceTintColor: K.iv, title: Text(title, style: tx(19, w: FontWeight.w800))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(gradient: K.goldGrad, shape: BoxShape.circle, boxShadow: K.shadow(.15)),
              child: Icon(icon, size: 40, color: K.ink),
            ),
            const SizedBox(height: 16),
            Text(title, style: tx(20, w: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('Ye screen chaaran $step me bilkul prototype jaisi banegi', textAlign: TextAlign.center, style: tx(13.5, c: K.muted)),
          ]),
        ),
      ),
    );
  }
}
