// Standort ermitteln – genau genug für einen Umkreis ab 1 km.

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'zustand.dart';

/// Fragt (falls nötig) nach der Standort-Erlaubnis und speichert den aktuellen Standort.
/// [fragen] = false: nur still aktualisieren, wenn die Erlaubnis schon da ist.
Future<bool> standortErmitteln(AppZustand z, {bool fragen = true}) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var erlaubnis = await Geolocator.checkPermission();
    if (erlaubnis == LocationPermission.denied && fragen) {
      erlaubnis = await Geolocator.requestPermission();
    }
    if (erlaubnis == LocationPermission.denied || erlaubnis == LocationPermission.deniedForever) return false;

    // Genauer Standort (Umkreis ab 1 km). Android ohne Google-Dienste, damit keine Zusatz-Abfrage kommt.
    final einstellungen = defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            forceLocationManager: true,
            timeLimit: const Duration(seconds: 20),
          )
        : AppleSettings(accuracy: LocationAccuracy.best, timeLimit: const Duration(seconds: 20));
    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(locationSettings: einstellungen);
    } catch (_) {
      pos = await Geolocator.getLastKnownPosition(forceAndroidLocationManager: true);
    }
    if (pos == null) return false;

    // iPhone: Ist „Genauer Standort“ aus, liefert iOS nur einen ungefähren Ort (mehrere km daneben).
    var ungenau = pos.accuracy > 1000;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        ungenau = ungenau || await Geolocator.getLocationAccuracy() == LocationAccuracyStatus.reduced;
      } catch (_) {}
    }
    z.standortSetzen(pos.latitude, pos.longitude, genauigkeitMeter: pos.accuracy, ungenau: ungenau);
    return true;
  } catch (e) {
    debugPrint('Standort nicht verfügbar: $e');
    return false;
  }
}

/// Für den Knopf „Standort verwenden“: fragt, und wenn früher abgelehnt → Einstellungen öffnen.
Future<void> standortFreigeben(AppZustand z) async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    await Geolocator.openLocationSettings(); // Ortungsdienste am Handy aus
    return;
  }
  final erlaubnis = await Geolocator.checkPermission();
  if (erlaubnis == LocationPermission.deniedForever) {
    await Geolocator.openAppSettings(); // früher abgelehnt → nur in den Einstellungen änderbar
    return;
  }
  await standortErmitteln(z);
}
