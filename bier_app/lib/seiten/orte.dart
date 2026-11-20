// „Meine Orte“: bis zu 3 Orte mit eigenem Namen – festlegen in den Einstellungen oder auf der Radar-Seite,
// umschalten auf der Radar-Seite.

import 'dart:async';

import 'package:flutter/material.dart';

import '../adresssuche.dart';
import '../main.dart';
import '../radar.dart';
import '../standort.dart';
import '../zustand.dart';

/// Abschnitt in den Einstellungen.
class MeineOrte extends StatelessWidget {
  const MeineOrte({super.key});

  @override
  Widget build(BuildContext context) {
    final z = ZustandScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            'Meine Orte',
            style: TextStyle(color: radarGruen, fontWeight: FontWeight.w700),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 2, 16, 4),
          child: Text(
            'Bis zu $maxOrte Orte mit eigenem Namen, z. B. Zuhause, Arbeit oder 2. Wohnadresse. '
            'Auf der Radar-Seite kannst du zwischen ihnen umschalten. Die Adressen bleiben nur auf deinem Handy.',
            style: TextStyle(color: textGedaempft, fontSize: 12),
          ),
        ),
        for (final e in z.orte.entries)
          ListTile(
            leading: const Icon(Icons.place, color: radarGruen),
            title: Text(e.value.name),
            subtitle: Text(e.value.adresse),
            trailing: const Icon(Icons.edit_location_alt_outlined),
            onTap: () => ortBearbeiten(context, z, e.key),
          ),
        if (z.orte.length < maxOrte)
          ListTile(
            leading: const Icon(Icons.add_location_alt_outlined, color: radarGruen),
            title: const Text('Ort hinzufügen'),
            onTap: () => ortBearbeiten(context, z, z.neueOrtKennung()),
          ),
      ],
    );
  }
}

/// Dialog: Namen geben, Adresse suchen oder aktuellen Standort übernehmen.
Future<void> ortBearbeiten(BuildContext context, AppZustand z, String art) => showDialog<void>(
  context: context,
  builder: (_) => ZustandScope(
    zustand: z,
    child: _OrtDialog(art: art),
  ),
);

class _OrtDialog extends StatefulWidget {
  const _OrtDialog({required this.art});
  final String art;

  @override
  State<_OrtDialog> createState() => _OrtDialogState();
}

class _OrtDialogState extends State<_OrtDialog> {
  final _eingabe = TextEditingController();
  late final _name = TextEditingController(text: ZustandScope.of(context).orte[widget.art]?.name ?? '');
  List<AdressTreffer> _treffer = [];
  bool _sucht = false;
  String? _meldung;
  Timer? _warte;

  @override
  void dispose() {
    _eingabe.dispose();
    _name.dispose();
    _warte?.cancel();
    super.dispose();
  }

  void _getippt(String text) {
    _warte?.cancel();
    // kurz warten, bis fertig getippt ist (schont den freien Kartendienst)
    _warte = Timer(const Duration(milliseconds: 700), () => _suchen(text));
  }

  Future<void> _suchen(String text) async {
    if (text.trim().length < 3) return;
    setState(() {
      _sucht = true;
      _meldung = null;
    });
    final t = await adresseSuchen(text);
    if (!mounted) return;
    setState(() {
      _sucht = false;
      _treffer = t;
      if (t.isEmpty) _meldung = 'Nichts gefunden – z. B. „Hinterbergerstraße 2, Steyr“ probieren.';
    });
  }

  /// Eingetippter Name, sonst „Ort 1“, „Ort 2“ …
  String get _ortName {
    final n = _name.text.trim();
    return n.isNotEmpty ? n : 'Ort ${widget.art.replaceAll(RegExp(r'[^0-9]'), '')}'.trim();
  }

  @override
  Widget build(BuildContext context) {
    final z = ZustandScope.of(context);
    final vorhanden = z.orte[widget.art];
    return AlertDialog(
      backgroundColor: karteFarbe,
      title: Text(vorhanden == null ? 'Neuer Ort' : '${vorhanden.name} ändern'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              autofocus: vorhanden == null,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 20,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.label_outline),
                hintText: 'Name, z. B. Zuhause, Arbeit, 2. Wohnadresse',
                counterText: '',
              ),
            ),
            const SizedBox(height: 8),
            if (vorhanden != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Jetzt: ${vorhanden.adresse}', style: const TextStyle(color: textGedaempft)),
              ),
            TextField(
              controller: _eingabe,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Straße Hausnummer, Ort',
              ),
              onChanged: _getippt,
              onSubmitted: _suchen,
            ),
            const SizedBox(height: 8),
            if (_sucht) const LinearProgressIndicator(),
            if (_meldung != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_meldung!, style: const TextStyle(color: textGedaempft, fontSize: 12.5)),
              ),
            for (final t in _treffer)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.place, color: radarGruen),
                title: Text(t.text),
                onTap: () {
                  z.ortSetzen(widget.art, Ort(_ortName, t.text, t.breite, t.laenge));
                  z.ortWaehlen(widget.art);
                  Navigator.pop(context);
                },
              ),
            const Divider(),
            TextButton.icon(
              icon: const Icon(Icons.my_location),
              label: const Text('Aktuellen Standort übernehmen'),
              onPressed: () async {
                final nav = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                final ok = await standortErmitteln(z);
                if (ok && z.standortBreite != null) {
                  z.ortSetzen(
                    widget.art,
                    Ort(_ortName, 'Mein Standort (gespeichert)', z.standortBreite!, z.standortLaenge!),
                  );
                  z.ortWaehlen(widget.art);
                  nav.pop();
                } else {
                  messenger.showSnackBar(const SnackBar(content: Text('Standort nicht verfügbar.')));
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        if (vorhanden != null)
          TextButton(
            onPressed: () {
              z.ortLoeschen(widget.art);
              Navigator.pop(context);
            },
            child: const Text('Löschen', style: TextStyle(color: textGedaempft)),
          ),
        if (vorhanden != null)
          TextButton(
            onPressed: () {
              z.ortSetzen(
                widget.art,
                Ort(_ortName, vorhanden.adresse, vorhanden.breite, vorhanden.laenge),
              );
              Navigator.pop(context);
            },
            child: const Text('Speichern'),
          )
        else
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
      ],
    );
  }
}

/// Umschalter auf der Radar-Seite: Aktueller Standort · eigene Orte · „+ Ort“.
/// Lange drücken auf einen Ort = ändern.
class OrtUmschalter extends StatelessWidget {
  const OrtUmschalter({super.key, required this.z});
  final AppZustand z;

  @override
  Widget build(BuildContext context) {
    Widget knopf(String art, String text) {
      final aktiv = z.ortWahl == art;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: GestureDetector(
          onLongPress: art == 'standort' ? null : () => ortBearbeiten(context, z, art),
          child: ChoiceChip(
            label: Text(text, style: TextStyle(fontSize: 12.5, color: aktiv ? const Color(0xFF00271A) : null)),
            selected: aktiv,
            selectedColor: radarGruen,
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            onSelected: (_) {
              z.ortWaehlen(art);
              if (art == 'standort') standortErmitteln(z, fragen: false);
            },
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          knopf('standort', '📍 Aktuell'),
          for (final e in z.orte.entries) knopf(e.key, '📌 ${e.value.name}'),
          if (z.orte.length < maxOrte)
            ActionChip(
              avatar: const Icon(Icons.add, size: 16, color: radarGruen),
              label: const Text('Ort', style: TextStyle(fontSize: 12.5)),
              visualDensity: VisualDensity.compact,
              onPressed: () => ortBearbeiten(context, z, z.neueOrtKennung()),
            ),
        ],
      ),
    );
  }
}

/// Einmaliger Tipp auf der Radar-Seite: erklärt die eigenen Orte. Verschwindet nach „X“ oder dem ersten Ort.
class OrtTipp extends StatelessWidget {
  const OrtTipp({super.key, required this.z});
  final AppZustand z;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 4, bottom: 6, right: 6),
    padding: const EdgeInsets.fromLTRB(12, 10, 4, 6),
    decoration: BoxDecoration(
      color: bierBernstein.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: bierBernstein.withValues(alpha: 0.4)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('💡', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Tipp: Speichere bis zu $maxOrte Orte mit eigenem Namen, z. B. Zuhause, Arbeit oder 2. Wohnadresse. '
                'Mit einem Tipp siehst du dann die Bier-Aktionen rund um diesen Ort – auch wenn du gerade woanders bist.',
                style: TextStyle(color: textHell, fontSize: 12.5, height: 1.35),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 18, color: textGedaempft),
              tooltip: 'Tipp schließen',
              onPressed: z.ortTippSchliessen,
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            icon: const Icon(Icons.add_location_alt_outlined, size: 18),
            label: const Text('Ersten Ort speichern'),
            onPressed: () => ortBearbeiten(context, z, z.neueOrtKennung()),
          ),
        ),
      ],
    ),
  );
}
