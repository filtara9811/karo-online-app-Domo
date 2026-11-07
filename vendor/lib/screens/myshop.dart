import 'package:flutter/material.dart';
import '../data.dart';
import '../theme.dart';

/// My Shop — (agla build: shop card, QR, stock, invoices, aaj ke orders, POS)
class MyShopTab extends StatelessWidget {
  const MyShopTab({super.key});
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
      children: [
        Box(
          gradient: K.darkCard,
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            const Icon(Icons.storefront_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(Store.i.shopName, style: tx(18, w: FontWeight.w800, c: Colors.white))),
          ]),
        ),
      ],
    );
  }
}
