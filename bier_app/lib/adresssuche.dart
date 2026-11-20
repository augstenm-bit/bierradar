// Adresse → Koordinaten über die freie Karte OpenStreetMap (Nominatim).
// Es wird nur der eingetippte Text geschickt, sonst nichts.

import 'dart:convert';

import 'package:http/http.dart' as http;

class AdressTreffer {
  const AdressTreffer(this.text, this.breite, this.laenge);
  final String text;
  final double breite;
  final double laenge;
}

/// Sucht Adressen in Österreich. Leere Liste, wenn nichts gefunden oder kein Internet.
Future<List<AdressTreffer>> adresseSuchen(String eingabe) async {
  final q = eingabe.trim();
  if (q.length < 3) return [];
  final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
    'q': q,
    'format': 'jsonv2',
    'countrycodes': 'at',
    'limit': '5',
    'addressdetails': '1',
    'accept-language': 'de',
  });
  try {
    final r = await http
        .get(uri, headers: {'User-Agent': 'BierRadar/1.0 (Beta-App)'})
        .timeout(const Duration(seconds: 12));
    if (r.statusCode != 200) return [];
    final liste = jsonDecode(utf8.decode(r.bodyBytes)) as List;
    return [
      for (final e in liste.cast<Map<String, dynamic>>())
        AdressTreffer(_kurz(e), double.parse(e['lat'] as String), double.parse(e['lon'] as String)),
    ];
  } catch (_) {
    return [];
  }
}

/// Kurze, lesbare Adresse, z. B. „Hinterbergerstraße 2, 4400 Steyr“.
String _kurz(Map<String, dynamic> e) {
  final a = (e['address'] as Map?)?.cast<String, dynamic>() ?? {};
  final strasse = [a['road'], a['house_number']].whereType<String>().join(' ');
  final ort = [
    a['postcode'],
    a['city'] ?? a['town'] ?? a['village'] ?? a['municipality'],
  ].whereType<String>().join(' ');
  final kurz = [strasse, ort].where((x) => x.isNotEmpty).join(', ');
  return kurz.isNotEmpty ? kurz : (e['display_name'] as String? ?? '').split(',').take(3).join(',');
}
