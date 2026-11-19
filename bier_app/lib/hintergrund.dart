// iPhone ohne Push: Die App schaut im Hintergrund ab und zu selbst nach neuen Angeboten
// (iOS entscheidet, wann) und meldet neue Treffer mit einer Benachrichtigung am Handy.

import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color, WidgetsFlutterBinding;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'daten.dart';
import 'zustand.dart';

const hintergrundAufgabe = 'com.michaelaugsten.bierApp.angebote';
const _gesehenSchluessel = 'bier_app_gesehen_v1';

bool get _istIphone => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// Wird beim App-Start aufgerufen (nur iPhone – Android hat echte Push-Meldungen).
Future<void> hintergrundEinrichten() async {
  if (!_istIphone) return;
  try {
    await Workmanager().initialize(hintergrundStart);
    // Wer das Willkommen schon hinter sich hat, wird (einmalig, iOS fragt nur einmal) um Meldungen gebeten.
    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getString('bier_app_beta_v1') ?? '').contains('"willkommen":true')) {
      await FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, sound: true, badge: false);
    }
    await Workmanager().registerPeriodicTask(
      hintergrundAufgabe,
      hintergrundAufgabe,
      frequency: const Duration(hours: 1),
    );
  } catch (e) {
    debugPrint('Hintergrund-Abruf nicht verfügbar: $e');
  }
}

@pragma('vm:entry-point')
void hintergrundStart() {
  Workmanager().executeTask((aufgabe, _) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    try {
      await neueTrefferMelden();
    } catch (e) {
      debugPrint('Hintergrund-Prüfung fehlgeschlagen: $e');
    }
    return true;
  });
}

String _schluessel(Treffer t) => AppZustand.angebotSchluessel(t.angebot);

List<Treffer> _passende(AppZustand z) =>
    z.treffer(z.angebote).where((t) => t.bewertung != Bewertung.zuTeuer).toList();

/// Merkt sich alle aktuell passenden Angebote als „schon gesehen“ (z. B. wenn die App offen ist).
Future<void> trefferAlsGesehenMerken(AppZustand z) async {
  if (!_istIphone || z.angebote.isEmpty) return;
  final prefs = await SharedPreferences.getInstance();
  final gesehen = (prefs.getStringList(_gesehenSchluessel) ?? []).toSet()
    ..addAll(_passende(z).map(_schluessel));
  await prefs.setStringList(_gesehenSchluessel, gesehen.toList().reversed.take(600).toList());
}

/// Holt die neuesten Angebote und meldet neue Treffer.
Future<int> neueTrefferMelden() async {
  final z = AppZustand();
  await z.auswahlLaden();
  await z.angeboteAktualisieren();
  final prefs = await SharedPreferences.getInstance();
  final gespeichert = prefs.getStringList(_gesehenSchluessel);
  final gesehen = (gespeichert ?? []).toSet();
  final passende = _passende(z);
  final neu = passende.where((t) => !gesehen.contains(_schluessel(t))).toList();

  gesehen.addAll(passende.map(_schluessel));
  await prefs.setStringList(_gesehenSchluessel, gesehen.toList().reversed.take(600).toList());

  // Allererster Lauf: nur merken, nichts melden (sonst käme eine Flut alter Angebote).
  if (gespeichert == null || neu.isEmpty) return 0;

  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    settings: const InitializationSettings(
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  final String titel;
  final String text;
  if (neu.length == 1) {
    final t = neu.first;
    final a = t.angebot;
    titel = t.bewertung == Bewertung.spezialitaet
        ? '🌏 ${a.bier.name} ist da!'
        : '🍺 ${a.bier.name} um ${euro(t.preisFuerMich)}';
    text =
        '${a.verpackung.bezeichnung} bei ${a.haendler} · ${euro(t.literPreis)}/l · gültig ${zeitraum(a.von, a.bis)}';
  } else {
    titel = '🍺 ${neu.length} neue Bier-Aktionen für dich';
    text = neu
        .take(4)
        .map((t) => '${t.angebot.bier.name} ${euro(t.preisFuerMich)} (${t.angebot.haendler})')
        .join(' · ');
  }

  await plugin.show(
    id: DateTime.now().millisecondsSinceEpoch & 0x3fffffff,
    title: titel,
    body: text,
    notificationDetails: const NotificationDetails(
      iOS: DarwinNotificationDetails(),
      android: AndroidNotificationDetails(
        'angebote',
        'Bier-Angebote',
        importance: Importance.high,
        priority: Priority.high,
        color: Color(0xFF2EF2B1),
      ),
    ),
  );
  return neu.length;
}
