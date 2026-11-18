// Beta-Version: Willkommen für Bierpiraten, Ablauf nach 30 Tagen, Fernsperre.

import 'dart:convert';
import 'dart:io' show HttpDate;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Wird beim Bauen gesetzt: --dart-define=BUILD_DATUM=2026-11-18
const _buildDatumText = String.fromEnvironment('BUILD_DATUM');

/// So lange gilt eine Beta-Version ab dem Bauen.
const betaTage = 30;

/// Einstellungsdatei im GitHub-Projekt: damit kann Michael alte Versionen sperren.
const _betaUrl = 'https://raw.githubusercontent.com/augstenm-bit/bierradar/main/server/beta.json';

class BetaPruefung extends ChangeNotifier {
  static const _schluessel = 'bier_app_beta_v1';

  bool geprueft = false;
  bool willkommenGesehen = false;
  int testerNummer = 0;
  bool gesperrt = false;
  String sperrGrund = '';

  DateTime? get buildDatum => _buildDatumText.isEmpty ? null : DateTime.tryParse(_buildDatumText);
  DateTime? get gueltigBis => buildDatum?.add(const Duration(days: betaTage));

  /// Die Sperre gilt nur für die Android-Beta (iPhone läuft ohnehin nur 7 Tage).
  bool get sperreAktiv => defaultTargetPlatform == TargetPlatform.android && buildDatum != null;

  Future<void> pruefen() async {
    final prefs = await SharedPreferences.getInstance();
    final gespeichert = prefs.getString(_schluessel);
    var spaetesteZeit = DateTime.now();
    var ferngesperrt = false;
    var nachricht = '';
    if (gespeichert != null) {
      try {
        final j = jsonDecode(gespeichert) as Map<String, dynamic>;
        willkommenGesehen = j['willkommen'] == true;
        testerNummer = (j['nummer'] as num?)?.toInt() ?? 0;
        final zeit = DateTime.tryParse(j['zeit'] as String? ?? '');
        if (zeit != null && zeit.isAfter(spaetesteZeit)) spaetesteZeit = zeit;
        ferngesperrt = j['fern'] == true;
        nachricht = j['nachricht'] as String? ?? '';
      } catch (_) {}
    }
    if (testerNummer == 0) testerNummer = 2 + math.Random().nextInt(998);

    if (sperreAktiv) {
      // Datum vom Internet holen (hilft gegen Zurückstellen der Handy-Uhr) und Fernsperre lesen.
      try {
        final r = await http.get(Uri.parse(_betaUrl)).timeout(const Duration(seconds: 10));
        final datum = r.headers['date'];
        if (datum != null) {
          final serverZeit = HttpDate.parse(datum).toLocal();
          if (serverZeit.isAfter(spaetesteZeit)) spaetesteZeit = serverZeit;
        }
        if (r.statusCode == 200) {
          final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
          final mindest = DateTime.tryParse(j['mindestBuild'] as String? ?? '');
          ferngesperrt = j['gesperrt'] == true || (mindest != null && buildDatum!.isBefore(mindest));
          nachricht = j['nachricht'] as String? ?? '';
        }
      } catch (_) {
        // Offline: letzter bekannter Stand gilt.
      }

      if (ferngesperrt) {
        gesperrt = true;
        sperrGrund = nachricht.isNotEmpty ? nachricht : 'Diese Beta-Version wurde von Michael beendet.';
      } else if (spaetesteZeit.isAfter(gueltigBis!)) {
        gesperrt = true;
        sperrGrund = 'Deine Beta-Zeit ist abgelaufen.';
      }
    }

    await _speichern(spaetesteZeit, ferngesperrt, nachricht);
    geprueft = true;
    notifyListeners();
  }

  Future<void> willkommenBestaetigen() async {
    willkommenGesehen = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final alt = prefs.getString(_schluessel);
    final j = alt == null ? <String, dynamic>{} : jsonDecode(alt) as Map<String, dynamic>;
    j['willkommen'] = true;
    j['nummer'] = testerNummer;
    await prefs.setString(_schluessel, jsonEncode(j));
  }

  Future<void> _speichern(DateTime zeit, bool fern, String nachricht) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _schluessel,
      jsonEncode({
        'willkommen': willkommenGesehen,
        'nummer': testerNummer,
        'zeit': zeit.toIso8601String(),
        'fern': fern,
        'nachricht': nachricht,
      }),
    );
  }
}
