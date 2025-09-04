import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CountingStationPage extends StatefulWidget {
  const CountingStationPage({super.key});

  @override
  State<CountingStationPage> createState() => _CountingStationPageState();
}

class _CountingStationPageState extends State<CountingStationPage> {
  final _stationCtrl = TextEditingController();
  final _startCtrl = TextEditingController();

  bool _busy = false;
  String _status = '';

  @override
  void dispose() {
    _stationCtrl.dispose();
    _startCtrl.dispose();
    super.dispose();
  }

  Future<void> _countLap() async {
    if (_busy) return;
    final station = _stationCtrl.text.trim();
    final raw = _startCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _status = 'Bitte Startnummer eingeben.');
      return;
    }
    final startNumber = int.tryParse(raw);
    if (startNumber == null) {
      setState(() => _status = 'Ungültige Startnummer.');
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Zähle…';
    });

    try {
      // Läufer via Startnummer suchen
      final q = await FirebaseFirestore.instance
          .collection('Laufer')
          .where('startNumber', isEqualTo: startNumber)
          .limit(1)
          .get();

      if (q.docs.isEmpty) {
        setState(() {
          _busy = false;
          _status = 'Keine Läufer:in mit #$startNumber gefunden.';
        });
        return;
      }

      final runnerId = q.docs.first.id;

      // Runde schreiben
      await FirebaseFirestore.instance.collection('Runden').add({
        'runnerId': runnerId,
        'startNumber': startNumber,
        'station': station.isEmpty ? '—' : station,
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _busy = false;
        _status = 'Runde gezählt für #$startNumber.';
        _startCtrl.clear();
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _status = 'Fehler: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // SAFE MODE: zentriert, feste Breite, keine Streams/Overlays
    return Scaffold(
      appBar: AppBar(title: const Text('Zählerstation (Safe Mode)')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min, // wichtig: keine unendliche Höhe
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _stationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Stationsname (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _startCtrl,
                        keyboardType: TextInputType.number,
                        onSubmitted: (_) => _countLap(),
                        decoration: const InputDecoration(
                          labelText: 'Startnummer',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _busy ? null : _countLap,
                        icon: _busy
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.add),
                        label: const Text('Zählen'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _status,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
