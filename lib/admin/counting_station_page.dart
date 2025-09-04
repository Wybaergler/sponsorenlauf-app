import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CountingStationPage extends StatefulWidget {
  const CountingStationPage({super.key});

  @override
  State<CountingStationPage> createState() => _CountingStationPageState();
}

class _CountingStationPageState extends State<CountingStationPage> {
  final TextEditingController _stationCtrl = TextEditingController();
  final TextEditingController _startCtrl = TextEditingController();

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
    return Scaffold(
      appBar: AppBar(title: const Text('Zählerstation')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Stationsname (kein Dialog → stabiler)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _stationCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Stationsname (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Zähl-Eingabe
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

            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _status,
                style: const TextStyle(color: Colors.black54),
              ),
            ),

            const SizedBox(height: 12),
            Expanded(child: _RecentLaps()),
          ],
        ),
      ),
    );
  }
}

class _RecentLaps extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('Runden')
        .orderBy('createdAt', descending: true)
        .limit(40);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Fehler: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('Noch keine gezählten Runden.'));
        }

        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final d = docs[i];
            final m = d.data();
            final sn = (m['startNumber'] ?? '').toString();
            final station = (m['station'] ?? '—').toString();
            final ts = (m['createdAt'] is Timestamp)
                ? (m['createdAt'] as Timestamp).toDate().toLocal().toString()
                : '—';
            final runnerId = (m['runnerId'] ?? '').toString();

            return ListTile(
              leading: CircleAvatar(child: Text(sn.isEmpty ? '—' : sn)),
              title: Text('Station: $station'),
              subtitle: Text('$ts\n$runnerId'),
              isThreeLine: true,
              trailing: IconButton(
                tooltip: 'Löschen',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  try {
                    await FirebaseFirestore.instance.collection('Runden').doc(d.id).delete();
                  } catch (_) {}
                },
              ),
            );
          },
        );
      },
    );
  }
}
