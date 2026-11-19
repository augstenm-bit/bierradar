// Standort ermitteln (nur ungefähr – reicht, um das nächste Gebiet zu finden).

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'zustand.dart';

/// Fragt (falls nötig) nach der Standort-Erlaubnis und speichert den Standort.
/// [fragen] = false: nur still aktualisieren, wenn die Erlaubnis schon da ist.
Future<bool> standortErmitteln(AppZustand z, {bool fragen = true}) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var erlaubnis = await Geolocator.checkPermission();
    if (erlaubnis == LocationPermission.denied && fragen) {
      erlaubnis = await Geolocator.requestPermission();
    }
    if (erlaubnis == LocationPermission.denied || erlaubnis == LocationPermission.deniedForever) return false;
    // Auf Android ohne Google-Dienste („Standortgenauigkeit“-Abfrage) – ungefähr reicht völlig.
    final einstellungen = defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.low,
            forceLocationManager: true,
            timeLimit: const Duration(seconds: 15),
          )
        : const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 15));
    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(locationSettings: einstellungen);
    } catch (_) {
      pos = await Geolocator.getLastKnownPosition(forceAndroidLocationManager: true);
    }
    if (pos == null) return false;
    z.standortSetzen(pos.latitude, pos.longitude);
    return true;
  } catch (e) {
    debugPrint('Standort nicht verfügbar: $e');
    return false;
  }
}
