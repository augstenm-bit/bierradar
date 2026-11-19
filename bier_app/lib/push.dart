// Push-Meldungen (nur Android): Themen abonnieren und eintreffende Angebote anzeigen,
// wenn sie zum eigenen Wunschpreis passen.

import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'daten.dart';
import 'zustand.dart';

const _themenSchluessel = 'bier_app_push_themen_v1';
final _benachrichtigungen = FlutterLocalNotificationsPlugin();

const _kanal = AndroidNotificationChannel(
  'angebote',
  'Bier-Angebote',
  description: 'Meldungen, wenn deine Biere günstig zu haben sind',
  importance: Importance.high,
);

bool get pushMoeglich => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

String themaFuer(String bierId, Verpackung v) => 'b_${bierId}_${v.name}';

/// Wird beim App-Start aufgerufen.
Future<void> pushStarten(AppZustand z) async {
  if (!pushMoeglich) return;
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_imHintergrund);
    await _lokalEinrichten();
    FirebaseMessaging.onMessage.listen((m) => _verarbeiten(m.data, z));

    // Themen jedes Mal abgleichen, wenn sich die Auswahl ändert (kurz gesammelt).
    Timer? warte;
    void abgleichen() {
      warte?.cancel();
      warte = Timer(const Duration(seconds: 2), () => _themenAbgleichen(z));
    }

    z.addListener(abgleichen);
    abgleichen();
  } catch (e) {
    debugPrint('Push konnte nicht gestartet werden: $e');
  }
}

/// Erst nach „Anheuern“ nach Benachrichtigungen fragen.
Future<void> benachrichtigungenErfragen() async {
  if (!pushMoeglich) return;
  try {
    await FirebaseMessaging.instance.requestPermission();
  } catch (_) {}
}

Future<void> _lokalEinrichten() async {
  await _benachrichtigungen.initialize(
    settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
  );
  await _benachrichtigungen
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_kanal);
}

Future<void> _themenAbgleichen(AppZustand z) async {
  if (!z.geladen) return;
  final soll = <String>{
    for (final e in z.auswahl.entries)
      for (final v in e.value.keys) themaFuer(e.key, v),
  };
  final prefs = await SharedPreferences.getInstance();
  final ist = (prefs.getStringList(_themenSchluessel) ?? []).toSet();
  final fm = FirebaseMessaging.instance;
  for (final t in soll.difference(ist)) {
    await fm.subscribeToTopic(t);
  }
  for (final t in ist.difference(soll)) {
    await fm.unsubscribeFromTopic(t);
  }
  await prefs.setStringList(_themenSchluessel, soll.toList());
  debugPrint('Push-Themen: $soll');
}

@pragma('vm:entry-point')
Future<void> _imHintergrund(RemoteMessage m) async {
  await Firebase.initializeApp();
  await _lokalEinrichten();
  final z = AppZustand();
  await z.auswahlLaden();
  await _verarbeiten(m.data, z);
}

/// Prüft das Angebot gegen den eigenen Wunschpreis und zeigt ggf. eine Benachrichtigung.
Future<void> _verarbeiten(Map<String, dynamic> d, AppZustand z) async {
  if (d['art'] != 'angebot') return;
  final angebot = Angebot.ausJson({
    'bierId': d['bierId'],
    'verpackung': d['verpackung'],
    'haendler': d['haendler'],
    'preis': double.tryParse('${d['preis']}') ?? 0,
    'kartenPreis': double.tryParse('${d['kartenPreis'] ?? ''}'),
    'karte': d['karte'],
    'von': d['von'],
    'bis': d['bis'],
    'statt': double.tryParse('${d['statt'] ?? ''}'),
    'regionen': d['regionen'],
    'gebiete': d['gebiete'],
  });
  if (angebot == null) return;
  final treffer = z.treffer([angebot]);
  if (treffer.isEmpty || treffer.first.bewertung == Bewertung.zuTeuer) return;
  final t = treffer.first;

  final titel = switch (t.bewertung) {
    Bewertung.spezialitaet => '🌏 ${angebot.bier.name} ist da!',
    Bewertung.nurMitKarte =>
      '💳 ${angebot.bier.name}: ${euro(angebot.kartenPreis!)} mit ${angebot.karte!.titel}',
    _ => '🍺 ${angebot.bier.name} um ${euro(t.preisFuerMich)}',
  };
  final rabatt = angebot.statt != null && angebot.statt! > t.preisFuerMich
      ? ' · −${((1 - t.preisFuerMich / angebot.statt!) * 100).round()} %'
      : '';
  final text =
      '${angebot.verpackung.bezeichnung} bei ${angebot.haendler} · ${euro(t.literPreis)}/l$rabatt · '
      'gültig ${zeitraum(angebot.von, angebot.bis)}';

  await _benachrichtigungen.show(
    id: jsonEncode(d).hashCode & 0x7fffffff,
    title: titel,
    body: text,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        _kanal.id,
        _kanal.name,
        channelDescription: _kanal.description,
        importance: Importance.high,
        priority: Priority.high,
        color: const Color(0xFF2EF2B1),
      ),
    ),
  );
}
