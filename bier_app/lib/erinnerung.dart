// „Aktion endet morgen!“ – lokale Erinnerung am Vortag des Ablaufs (iPhone und Android, ohne Server).

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_daten;
import 'package:timezone/timezone.dart' as tz;

import 'daten.dart';

final _plugin = FlutterLocalNotificationsPlugin();
bool _bereit = false;

Future<void> _einrichten() async {
  if (_bereit) return;
  tz_daten.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Europe/Vienna'));
  await _plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ),
  );
  _bereit = true;
}

int _id(String schluessel) => schluessel.hashCode & 0x3fffffff;

/// Plant die Erinnerung für den Vortag um 18 Uhr (bzw. sofort in 1 Minute, wenn das schon vorbei ist).
Future<String> erinnerungPlanen(Angebot a, String schluessel) async {
  try {
    await _einrichten();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, sound: true);
    final vortag = tz.TZDateTime(tz.local, a.bis.year, a.bis.month, a.bis.day).subtract(const Duration(hours: 6));
    final jetzt = tz.TZDateTime.now(tz.local);
    if (a.bis.isBefore(DateTime(jetzt.year, jetzt.month, jetzt.day))) return 'Diese Aktion ist schon vorbei.';
    final wann = vortag.isAfter(jetzt) ? vortag : jetzt.add(const Duration(minutes: 1));
    await _plugin.zonedSchedule(
      id: _id(schluessel),
      scheduledDate: wann,
      title: '⏰ Aktion endet bald: ${a.bier.name}',
      body: '${a.verpackung.bezeichnung} um ${euro(a.preis)} bei ${a.haendler} – nur noch bis ${a.bis.day}.${a.bis.month}.!',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'erinnerung',
          'Erinnerungen',
          channelDescription: 'Erinnert dich, bevor eine gemerkte Aktion endet',
          importance: Importance.high,
          priority: Priority.high,
          color: Color(0xFF2EF2B1),
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    return vortag.isAfter(jetzt)
        ? 'Gemerkt! Erinnerung am ${wann.day}.${wann.month}. um 18 Uhr.'
        : 'Gemerkt! Die Aktion endet bald – Erinnerung kommt gleich.';
  } catch (e) {
    debugPrint('Erinnerung fehlgeschlagen: $e');
    return 'Gemerkt! (Erinnerung konnte nicht gestellt werden.)';
  }
}

Future<void> erinnerungLoeschen(String schluessel) async {
  try {
    await _einrichten();
    await _plugin.cancel(id: _id(schluessel));
  } catch (_) {}
}
