// „Meine Orte“: Zuhause 1, Zuhause 2, Arbeit – festlegen in den Einstellungen, umschalten auf der Radar-Seite.

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
            'Auf der Radar-Seite kannst du zwischen diesen Orten umschalten. Die Adressen bleiben nur auf deinem Handy.',
            style: TextStyle(color: textGedaempft, fontSize: 12),
          ),
        ),
        for (final (art, name, symbol) in ortArten)
          ListTile(
            leading: Text(symbol, style: const TextStyle(fontSize: 24)),
            title: Text(name),
            subtitle: Text(z.orte[art]?.adresse ?? 'Noch nicht festgelegt – antippen'),
            trailing: const Icon(Icons.edit_location_alt_outlined),
            onTap: () => ortBearbeiten(context, z, art, name),
          ),
      ],
    );
  }
}

/// Dialog: Adresse suchen oder aktuellen Standort übernehmen.
Future<void> ortBearbeiten(BuildContext context, AppZustand z, String art, String name) => showDialog<void>(
  context: context,
  builder: (_) => ZustandScope(
    zustand: z,
    child: _OrtDialog(art: art, name: name),
  ),
);

class _OrtDialog extends StatefulWidget {
  const _OrtDialog({required this.art, required this.name});
  final String art;
  final String name;

  @override
  State<_OrtDialog> createState() => _OrtDialogState();
}

class _OrtDialogState extends State<_OrtDialog> {
  final _eingabe = TextEditingController();
  List<AdressTreffer> _treffer = [];
  bool _sucht = false;
  String? _meldung;
  Timer? _warte;

  @override
  void dispose() {
    _eingabe.dispose();
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

  @override
  Widget build(BuildContext context) {
    final z = ZustandScope.of(context);
    final vorhanden = z.orte[widget.art];
    return AlertDialog(
      backgroundColor: karteFarbe,
      title: Text('${widget.name} festlegen'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (vorhanden != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text('Jetzt: ${vorhanden.adresse}', style: const TextStyle(color: textGedaempft)),
              ),
            TextField(
              controller: _eingabe,
              autofocus: true,
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
                  z.ortSetzen(widget.art, Ort(t.text, t.breite, t.laenge));
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
                    Ort('Mein Standort (gespeichert)', z.standortBreite!, z.standortLaenge!),
                  );
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
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Schließen')),
      ],
    );
  }
}

/// Umschalter auf der Radar-Seite: Aktueller Standort · Zuhause 1 · Zuhause 2 · Arbeit.
class OrtUmschalter extends StatelessWidget {
  const OrtUmschalter({super.key, required this.z});
  final AppZustand z;

  @override
  Widget build(BuildContext context) {
    Widget knopf(String art, String text) {
      final aktiv = z.ortWahl == art;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(text, style: TextStyle(fontSize: 12.5, color: aktiv ? const Color(0xFF00271A) : null)),
          selected: aktiv,
          selectedColor: radarGruen,
          showCheckmark: false,
          visualDensity: VisualDensity.compact,
          onSelected: (_) {
            if (art != 'standort' && !z.orte.containsKey(art)) {
              final name = ortArten.firstWhere((o) => o.$1 == art).$2;
              ortBearbeiten(context, z, art, name);
              return;
            }
            z.ortWaehlen(art);
            if (art == 'standort') standortErmitteln(z, fragen: false);
          },
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          knopf('standort', '📍 Aktuell'),
          for (final (art, name, symbol) in ortArten) knopf(art, '$symbol $name'),
        ],
      ),
    );
  }
}
