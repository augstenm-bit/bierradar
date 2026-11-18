// Prüft die Beta-Sperre. Aufruf mit Baudatum, z. B.:
// flutter test test/beta_test.dart --dart-define=BUILD_DATUM=2026-09-18
import 'package:bier_app/beta.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Beta-Sperre richtet sich nach dem Baudatum', () async {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final b = BetaPruefung();
    await b.pruefen();
    final bau = b.buildDatum;
    // ignore: avoid_print
    print('Baudatum: $bau  gültig bis: ${b.gueltigBis}  gesperrt: ${b.gesperrt}  Grund: ${b.sperrGrund}');
    if (bau == null) {
      expect(b.gesperrt, isFalse);
    } else {
      expect(b.gesperrt, DateTime.now().isAfter(b.gueltigBis!));
    }
    debugDefaultTargetPlatformOverride = null;
  });
}
