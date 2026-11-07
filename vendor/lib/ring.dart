import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'api.dart';

/// Ghanti (ring) system
/// - Online rehne par background service har 7 second server se nayi lead dekhta hai
///   (app band ho, phone lock ho tab bhi) → full-screen alert + lagataar ghanti
/// - App khuli ho to UI khud full-screen request dikhati hai
const kRingChannel = 'karo_ring_v1';
const kOnlineChannel = 'karo_online_v1';
const kOnlineNotifId = 7;

AndroidNotificationDetails ringAndroid() => AndroidNotificationDetails(
      kRingChannel,
      'Nayi request (ghanti)',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      visibility: NotificationVisibility.public,
      sound: const RawResourceAndroidNotificationSound('ring'),
      audioAttributesUsage: AudioAttributesUsage.alarm,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 800, 400, 800, 400, 800]),
      additionalFlags: Int32List.fromList(<int>[4]), // FLAG_INSISTENT — jab tak dekhein nahi, bajti rahe
      ongoing: true,
      autoCancel: true,
      timeoutAfter: 60000,
      color: const Color(0xFFEE6A0D),
      actions: const [
        AndroidNotificationAction('acc', 'Dekhein', showsUserInterface: true, cancelNotification: true),
        AndroidNotificationAction('rej', 'Baad me', showsUserInterface: false, cancelNotification: true),
      ],
    );

Future<void> createChannels(FlutterLocalNotificationsPlugin fln) async {
  final a = fln.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await a?.createNotificationChannel(const AndroidNotificationChannel(
    kRingChannel,
    'Nayi request (ghanti)',
    description: 'Customer ki nayi request aane par ghanti bajegi',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('ring'),
    enableVibration: true,
    audioAttributesUsage: AudioAttributesUsage.alarm,
  ));
  await a?.createNotificationChannel(const AndroidNotificationChannel(
    kOnlineChannel,
    'Online status',
    description: 'Aap online hain — requests aati rahengi',
    importance: Importance.low,
    playSound: false,
  ));
}

/// ---------------- Background service (alag isolate) ----------------
@pragma('vm:entry-point')
Future<void> bgMain(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  final fln = FlutterLocalNotificationsPlugin();
  await fln.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
  await createChannels(fln);
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
  }
  service.on('stop').listen((_) => service.stopSelf());

  bool first = true;
  Future<void> tick() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.reload();
      final vid = p.getString('vendorId') ?? '';
      if (vid.isEmpty || !(p.getBool('online') ?? true)) return;
      final seen = (p.getStringList('seenLeads') ?? []).toSet();
      final list = await Api.rpc('ko_inbox', {'p_vendor': vid}) as List;
      final fresh = <Map>[];
      for (final x in list) {
        final id = '${x['id']}';
        if (!seen.contains(id)) {
          seen.add(id);
          fresh.add(x as Map);
        }
      }
      if (fresh.isNotEmpty) {
        await p.setStringList('seenLeads', seen.toList().reversed.take(300).toList());
        if (!first) {
          for (final x in fresh) {
            await fln.show(
              (x['id'] as num).toInt(),
              '🔔 Nayi request: ${x['service']}',
              '${x['name']} · ${x['area'] ?? ''} · ${x['coins']} coin',
              NotificationDetails(android: ringAndroid()),
              payload: '${x['id']}',
            );
          }
          service.invoke('lead', {'id': fresh.first['id']});
        }
      }
      first = false;
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'Karo Online — aap ONLINE hain',
          content: list.isEmpty ? 'Nayi request aate hi ghanti bajegi' : '${list.length} request khuli hain — tap karke dekhein',
        );
      }
    } catch (_) {}
  }

  await tick();
  Timer.periodic(const Duration(seconds: 7), (_) => tick());
}

class Ring {
  Ring._();
  static final Ring i = Ring._();

  final fln = FlutterLocalNotificationsPlugin();

  /// Notification se app khule to yahan lead id aati hai
  final ValueNotifier<int?> opened = ValueNotifier<int?>(null);

  AndroidFlutterLocalNotificationsPlugin? get _a =>
      fln.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    } catch (_) {}
    await fln.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: (r) => _handle(r.payload, r.actionId),
    );
    await createChannels(fln);
    final d = await fln.getNotificationAppLaunchDetails();
    if (d != null && d.didNotificationLaunchApp) {
      _handle(d.notificationResponse?.payload, d.notificationResponse?.actionId);
    }
    await FlutterBackgroundService().configure(
      androidConfiguration: AndroidConfiguration(
        onStart: bgMain,
        autoStart: false,
        autoStartOnBoot: true,
        isForegroundMode: true,
        notificationChannelId: kOnlineChannel,
        initialNotificationTitle: 'Karo Online — aap ONLINE hain',
        initialNotificationContent: 'Nayi request aate hi ghanti bajegi',
        foregroundServiceNotificationId: kOnlineNotifId,
        foregroundServiceTypes: [AndroidForegroundType.specialUse],
      ),
      iosConfiguration: IosConfiguration(autoStart: false),
    );
    FlutterBackgroundService().on('lead').listen((e) {
      final id = (e?['id'] as num?)?.toInt();
      if (id != null) leadFromBg.add(id);
    });
  }

  final StreamController<int> leadFromBg = StreamController<int>.broadcast();

  void _handle(String? payload, String? action) {
    final id = int.tryParse(payload ?? '');
    if (id == null || action == 'rej') return;
    opened.value = id;
  }

  Future<void> stop(int leadId) => fln.cancel(leadId);

  /// Online = background service chalu
  Future<void> setOnline(bool on) async {
    final s = FlutterBackgroundService();
    try {
      if (on) {
        if (!await s.isRunning()) await s.startService();
      } else {
        s.invoke('stop');
      }
    } catch (e) {
      debugPrint('bg service: $e');
    }
  }

  /// Test: X second baad ek nakli ghanti (app band karke check karein)
  Future<bool> testRingAfter(int seconds) async {
    final when = tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));
    Future<void> go(AndroidScheduleMode m) => fln.zonedSchedule(
          999999,
          '🔔 Test: Nayi request',
          'Ghanti theek se baj rahi hai — ye sirf test hai',
          when,
          NotificationDetails(android: ringAndroid()),
          androidScheduleMode: m,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
    try {
      await go(AndroidScheduleMode.exactAllowWhileIdle);
      return true;
    } on PlatformException {
      await go(AndroidScheduleMode.inexactAllowWhileIdle);
      return false;
    }
  }

  // ---------- Permissions ----------
  Future<bool> askNotifications() async => (await _a?.requestNotificationsPermission()) ?? true;
  Future<bool> askFullScreen() async => (await _a?.requestFullScreenIntentPermission()) ?? true;
  Future<bool> askExactAlarm() async => (await _a?.requestExactAlarmsPermission()) ?? true;
  Future<bool> askBattery() async => (await Permission.ignoreBatteryOptimizations.request()).isGranted;
  Future<bool> notifOk() async => (await _a?.areNotificationsEnabled()) ?? true;
  Future<bool> batteryOk() async => Permission.ignoreBatteryOptimizations.isGranted;
  Future<void> openSettings() => openAppSettings();
}
