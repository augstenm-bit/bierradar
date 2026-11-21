// Startsequenz darf bei Bildschirmgröße 0 nicht hängen (Android meldet beim ersten Bild manchmal 0).
import 'package:bier_app/seiten/intro.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Bier-Oberfläche bei Größe 0 endet sofort', () {
    expect(oberflaechePfad(Size.zero, 0, 0).getBounds(), Rect.zero);
    expect(oberflaechePfad(const Size(0, 800), 0.5, 0.3).getBounds(), Rect.zero);
  });

  test('Bier-Oberfläche bei normaler Größe', () {
    final b = oberflaechePfad(const Size(400, 800), 0.5, 0.3).getBounds();
    expect(b.width, closeTo(400, 0.01));
  });

  testWidgets('Startsequenz läuft bei Größe 0 ohne Hängen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox.shrink(child: Intro(fertig: () {})),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(Intro), findsOneWidget);
  });
}
