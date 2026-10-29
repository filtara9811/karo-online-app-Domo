import 'package:flutter/material.dart';
import '../data.dart';
import '../ring.dart';
import '../theme.dart';
import 'soon.dart';

/// My Profile — abhi: ghanti settings + test, permissions, logout. Baaki chaaran 4 me.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with WidgetsBindingObserver {
  bool notif = true, battery = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final n = await Ring.i.notifOk();
    final b = await Ring.i.batteryOk();
    if (mounted) {
      setState(() {
        notif = n;
        battery = b;
      });
    }
  }

  Future<void> _test() async {
    await Ring.i.askNotifications();
    await Ring.i.askExactAlarm();
    final r = Store.i.newDemoRequest();
    final exact = await Ring.i.ringAfter(r, 10);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text('10 second me ghanti bajegi', style: tx(17, w: FontWeight.w800)),
        content: Text(
          'Ab app band kar dijiye (Recent apps se hata dein) aur phone lock kar dijiye.\n\n10 second baad poori screen par nayi request aayegi aur ghanti bajti rahegi.'
          '${exact ? '' : '\n\n(Is phone par exact alarm ki permission nahi mili, isliye thoda late baj sakti hai.)'}',
          style: tx(13.5, w: FontWeight.w500),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text('Theek hai', style: tx(14, w: FontWeight.w800, c: K.acc)))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.i,
      builder: (context, _) {
        final s = Store.i;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: K.iv,
            surfaceTintColor: K.iv,
            title: Text('My Profile', style: tx(19, w: FontWeight.w800)),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
            children: [
              Box(
                gradient: K.darkCard,
                child: Row(children: [
                  const CircleAvatar(radius: 26, backgroundColor: K.goldL, child: Icon(Icons.storefront_rounded, color: K.ink)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.shopName, style: tx(17, w: FontWeight.w800, c: Colors.white)),
                      Text('+91 ${s.phone}', style: tx(12.5, c: K.goldL)),
                    ]),
                  ),
                  Text('${s.coins}\ncoins', textAlign: TextAlign.right, style: tx(13, w: FontWeight.w800, c: K.goldL)),
                ]),
              ),
              const SizedBox(height: 16),
              Text('GHANTI (NAYI REQUEST)', style: tx(11.5, w: FontWeight.w800, c: K.muted).copyWith(letterSpacing: 1)),
              const SizedBox(height: 8),
              Box(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  SwitchListTile(
                    value: s.online,
                    activeThumbColor: K.green,
                    onChanged: (v) async {
                      s.setOnline(v);
                      await Ring.i.setOnline(v);
                    },
                    title: Text('Online rahein', style: tx(14.5, w: FontWeight.w800)),
                    subtitle: Text('Online hone par app band ho tab bhi ghanti bajegi', style: tx(12, c: K.muted)),
                  ),
                  const Divider(height: 1, color: K.line),
                  _perm(Icons.notifications_active_rounded, 'Notification permission', notif, () async {
                    await Ring.i.askNotifications();
                    _check();
                  }),
                  _perm(Icons.fullscreen_rounded, 'Lock screen par poori screen alert', null, () => Ring.i.askFullScreen()),
                  _perm(Icons.battery_charging_full_rounded, 'Battery: No restriction', battery, () async {
                    await Ring.i.askBattery();
                    _check();
                  }),
                  _perm(Icons.rocket_launch_rounded, 'Autostart (Xiaomi / Oppo / Vivo)', null, () => Ring.i.openSettings()),
                ]),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _test,
                  icon: const Icon(Icons.notifications_active_rounded, color: Colors.white),
                  label: Text('Ghanti test karein (10 second)', style: tx(15, w: FontWeight.w800, c: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: K.acc, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                ),
              ),
              const SizedBox(height: 6),
              Text('Test ke baad app band karke phone lock kar dein — ghanti bajni chahiye.', style: tx(11.5, c: K.muted), textAlign: TextAlign.center),
              const SizedBox(height: 18),
              Text('DUKAAN', style: tx(11.5, w: FontWeight.w800, c: K.muted).copyWith(letterSpacing: 1)),
              const SizedBox(height: 8),
              Box(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  for (final x in const [
                    [Icons.store_rounded, 'Dukaan ki jaankari'],
                    [Icons.schedule_rounded, 'Dukaan ka samay'],
                    [Icons.payments_rounded, 'Shop rent / AutoPay'],
                    [Icons.qr_code_2_rounded, 'Mera QR'],
                    [Icons.support_agent_rounded, 'Help & support'],
                  ])
                    ListTile(
                      leading: Icon(x[0] as IconData, color: K.gold),
                      title: Text(x[1] as String, style: tx(14, w: FontWeight.w700)),
                      trailing: const Icon(Icons.chevron_right_rounded, color: K.muted),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SoonScreen(title: x[1] as String, step: 4, icon: x[0] as IconData))),
                    ),
                ]),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  await Ring.i.setOnline(false);
                  await s.logout();
                  if (context.mounted) Navigator.popUntil(context, (r) => r.isFirst);
                },
                icon: const Icon(Icons.logout_rounded, color: K.red),
                label: Text('Logout', style: tx(14.5, w: FontWeight.w800, c: K.red)),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: const BorderSide(color: K.line), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              ),
              const SizedBox(height: 14),
              Text('Karo Online Business · v1.0 · Powered by Filipra Private Limited', textAlign: TextAlign.center, style: tx(11, c: K.muted)),
            ],
          ),
        );
      },
    );
  }

  Widget _perm(IconData i, String t, bool? ok, VoidCallback f) => ListTile(
        leading: Icon(i, color: K.gold),
        title: Text(t, style: tx(13.5, w: FontWeight.w700)),
        trailing: ok == true
            ? const Icon(Icons.check_circle_rounded, color: K.green)
            : TextButton(onPressed: f, child: Text(ok == false ? 'Chalu karein' : 'Kholein', style: tx(12.5, w: FontWeight.w800, c: K.acc))),
        onTap: f,
      );
}
