import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'data.dart';

/// Ghanti (ring) system:
/// - Nayi request par full-screen alert + lagataar bajne wali ghanti (FLAG_INSISTENT)
/// - Online rehne par foreground service ("Aap online hain")
/// - Test: 10 second baad ghanti — app band karke check karein
class Ring {
  Ring._();
  static final Ring i = Ring._();

  final fln = FlutterLocalNotificationsPlugin();
  static const channelId = 'karo_ring_v1';
  static const onlineChannel = 'karo_online_v1';
  static const onlineId = 7;

  /// Notification se app khule to yahan request id aati hai
  final ValueNotifier<String?> opened = ValueNotifier<String?>(null);

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

    await _a?.createNotificationChannel(const AndroidNotificationChannel(
      channelId,
      'Nayi request (ghanti)',
      description: 'Customer ki nayi request aane par ghanti bajegi',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('ring'),
      enableVibration: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    ));
    await _a?.createNotificationChannel(const AndroidNotificationChannel(
      onlineChannel,
      'Online status',
      description: 'Aap online hain — requests aati rahengi',
      importance: Importance.low,
      playSound: false,
    ));

    final d = await fln.getNotificationAppLaunchDetails();
    if (d != null && d.didNotificationLaunchApp) {
      _handle(d.notificationResponse?.payload, d.notificationResponse?.actionId);
    }
  }

  void _handle(String? payload, String? action) {
    if (payload == null || payload.isEmpty) return;
    final r = Store.i.byId(payload);
    if (r != null && action == 'rej') {
      Store.i.reject(r);
      return;
    }
    opened.value = payload;
  }

  NotificationDetails _ringDetails() => NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
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
          additionalFlags: Int32List.fromList(<int>[4]), // FLAG_INSISTENT: jab tak dekhein nahi, bajti rahe
          ongoing: true,
          autoCancel: true,
          timeoutAfter: 45000,
          color: const Color(0xFFC85A1B),
          actions: const [
            AndroidNotificationAction('acc', 'Accept', showsUserInterface: true, cancelNotification: true),
            AndroidNotificationAction('rej', 'Reject', showsUserInterface: false, cancelNotification: true),
          ],
        ),
      );

  int _nid(String id) => id.hashCode & 0x7fffffff;

  /// Abhi ghanti bajao (request aayi)
  Future<void> ringNow(Req r) async {
    await fln.show(_nid(r.id), 'Nayi request: ${r.service}', '${r.name} · ${r.area} · ${r.km.toStringAsFixed(1)} km', _ringDetails(), payload: r.id);
  }

  /// Test: X second baad ghanti — app band ho tab bhi
  Future<bool> ringAfter(Req r, int seconds) async {
    final when = tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));
    Future<void> go(AndroidScheduleMode m) => fln.zonedSchedule(
          _nid(r.id),
          'Nayi request: ${r.service}',
          '${r.name} · ${r.area} · ${r.km.toStringAsFixed(1)} km',
          when,
          _ringDetails(),
          androidScheduleMode: m,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: r.id,
        );
    try {
      await go(AndroidScheduleMode.exactAllowWhileIdle);
      return true;
    } on PlatformException {
      await go(AndroidScheduleMode.inexactAllowWhileIdle);
      return false; // thoda late baj sakti hai
    }
  }

  Future<void> stop(Req r) => fln.cancel(_nid(r.id));

  /// Online = foreground service chalu (Android app ko band nahi karega)
  Future<void> setOnline(bool on) async {
    final a = _a;
    if (a == null) return;
    try {
      if (on) {
        await a.startForegroundService(
          onlineId,
          'Karo Online — aap ONLINE hain',
          'Nayi request aate hi ghanti bajegi',
          notificationDetails: const AndroidNotificationDetails(
            onlineChannel,
            'Online status',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            playSound: false,
            color: Color(0xFF2F9E5F),
          ),
          startType: AndroidServiceStartType.startSticky,
          foregroundServiceTypes: {AndroidServiceForegroundType.foregroundServiceTypeSpecialUse},
        );
      } else {
        await a.stopForegroundService();
      }
    } catch (e) {
      debugPrint('foreground service: $e');
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
