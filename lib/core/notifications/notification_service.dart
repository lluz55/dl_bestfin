import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Emite o payload (id da transação) sempre que o usuário toca em uma
/// notificação de lembrete, com o app em foreground/background.
final StreamController<String> notificationTapController =
    StreamController<String>.broadcast();

Future<void> initializeNotifications() async {
  tz_data.initializeTimeZones();
  try {
    final tzInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
  } catch (_) {
    // Mantém UTC como fallback se não for possível resolver o fuso local.
  }

  const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
  const linuxInit = LinuxInitializationSettings(defaultActionName: 'Abrir');

  await notificationsPlugin.initialize(
    settings: const InitializationSettings(
      android: androidInit,
      linux: linuxInit,
    ),
    onDidReceiveNotificationResponse: (response) {
      final payload = response.payload;
      if (payload != null && payload.isNotEmpty) {
        notificationTapController.add(payload);
      }
    },
  );
}

Future<bool> requestAndroidNotificationPermission() async {
  if (!Platform.isAndroid) return true;
  final android = notificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  if (android == null) return true;
  return await android.requestNotificationsPermission() ?? false;
}

Future<bool> areAndroidNotificationsEnabled() async {
  if (!Platform.isAndroid) return true;
  final android = notificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  if (android == null) return true;
  return await android.areNotificationsEnabled() ?? false;
}
