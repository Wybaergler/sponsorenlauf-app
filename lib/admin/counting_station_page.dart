import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CountingStationPage extends StatefulWidget {
  const CountingStationPage({super.key});

  @override
  State<CountingStationPage> createState() => _CountingStationPageState();
}

class _CountingStationPageState extends State<CountingStationPage> {
  final TextEditingController _startCtrl = TextEditingController();
  final FocusNode _startFocus = FocusNode();
  String? _stationName;
  bool _busy = false;
  String? _lastMessage;

  @override
  void dispose() {
    _startCtrl.dispose();
    _startFocus.dispose();
    super.dispose();
  }

  Future<void> _ensureStationName() async {
    if (_stationName != null && _stationName!.trim().isNotEmpty) return;
    final ctrl = TextEditingController(text: _stationName ?? '');
    final name = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zählerstation benennen'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Stationsname (z. B. „Tor A“)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('OK')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      setState(() => _stationName = name);
    }
  }

  Future<void> _submitStartNumber() async {
    if (_busy) return;
    final raw = _startCtrl.text.trim();
    if (raw.isEmpty) return;

    final startNumber = int.tryParse(raw);
    if (startNumber == null) {
      _toast('Bitte eine gültige Startnummer eingeben.');
      _startCtrl.clear();
      _requestFocus();
      return;
    }

    setState(() => _busy = true);
    try {
      // 1) Runner via Startnummer finden
      final q = await FirebaseFirestore.instance
          .collection('Laufer')
          .where('startNumber', isEqualTo: startNumber)
          .limit(1)
          .get();

      if (q.docs.isEmpty) {
        _toast('Keine Läufer:in mit Startnummer $startNumber gefunden.');
        return;
      }

      final runnerDoc = q.docs.first;
      final runnerId = runnerDoc.id;

      // 2) Runde anlegen
      await FirebaseFirestore.instance.collection('Runden').add({
        'runnerId': runnerId,
        'startNumber': startNumber,
        'station': _stationName ?? 'unbenannt',
        'createdAt': FieldValue.serverTimestamp(),
      });

      _toast('Runde gezählt für #$startNumber');
    } catch (e) {
      _toast('Fehler beim Zählen: $e');
    } finally {
      if (!mounted) return;
      setState(() => _busy = false);
      _startCtrl.clear();
      _requestFocus();
    }
  }

  void _requestFocus() {
    // sanft nach dem Frame, um MouseTracker/Focus-Stress zu vermeiden
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startFocus.requestFocus();
    });
  }

  void _toast(String msg) {
    setState(() => _lastMessage = msg);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _deleteLap(String lapId) async {
    try {
      await FirebaseFirestore.instance.collection('Runden').doc(lapId).delete();
      _toast('Runde entfernt.');
    } catch (e) {
      _toast('Löschen fehlgeschlagen: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = 'Zählerstation${_stationName == null ? '' : ' – ${_stationName!}'}';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Station benennen',
            onPressed: _ensureStationName,
            icon: const Icon(Icons.edit_location_alt),
          ),
          IconButton(
            tooltip: 'Neu laden',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 720;

          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Eingabezeile
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _startCtrl,
                        focusNode: _startFocus,
                        keyboardType: TextInputType.number,
                        onSubmitted: (_) => _submitStartNumber(),
                        decoration: const InputDecoration(
                          labelText: 'Startnummer eingeben',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _busy ? null : _submitStartNumber,
                        icon: _busy
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.add),
                        label: const Text('Zählen'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),
                if (_lastMessage != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(_lastMessage!, style: const TextStyle(color: Colors.black54)),
                  ),

                const SizedBox(height: 12),

                // Letzte Runden (Stream)
                Expanded(
                  child: _RecentLapsList(
                    narrow: narrow,
                    onDelete: _deleteLap,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Beim ersten Build Fokus setzen
    _requestFocus();
  }
}

class _RecentLapsList extends StatelessWidget {
  final bool narrow;
  final void Function(String lapId) onDelete;

  const _RecentLapsList({required this.narrow, required this.onDelete});

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

        if (narrow) {
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final d = docs[i];
              final m = d.data();
              final sn = (m['startNumber'] ?? '').toString();
              final station = (m['station'] ?? '').toString();
              final ts = (m['createdAt'] is Timestamp)
                  ? (m['createdAt'] as Timestamp).toDate().toLocal().toString()
                  : '—';
              return ListTile(
                leading: CircleAvatar(child: Text(sn.isEmpty ? '—' : sn)),
                title: Text('Station: ${station.isEmpty ? '—' : station}'),
                subtitle: Text(ts),
                trailing: IconButton(
                  tooltip: 'Löschen',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => onDelete(d.id),
                ),
              );
            },
          );
        }

        // Breite Ansicht als Tabelle
        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('#')),
              DataColumn(label: Text('Startnummer')),
              DataColumn(label: Text('RunnerId')),
              DataColumn(label: Text('Station')),
              DataColumn(label: Text('Zeit')),
              DataColumn(label: Text('Aktion')),
            ],
            rows: [
              for (int i = 0; i < docs.length; i++)
                _toRow(context, i, docs[i]),
            ],
          ),
        );
      },
    );
  }

  DataRow _toRow(BuildContext context, int i, QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    final sn = (m['startNumber'] ?? '').toString();
    final runnerId = (m['runnerId'] ?? '').toString();
    final station = (m['station'] ?? '').toString();
    final time = (m['createdAt'] is Timestamp)
        ? (m['createdAt'] as Timestamp).toDate().toLocal()
        : null;

    return DataRow(cells: [
      DataCell(Text('${i + 1}')),
      DataCell(Text(sn.isEmpty ? '—' : sn)),
      DataCell(SelectableText(runnerId.isEmpty ? '—' : runnerId)),
      DataCell(Text(station.isEmpty ? '—' : station)),
      DataCell(Text(time == null ? '—' : time.toString())),
      DataCell(
        IconButton(
          tooltip: 'Löschen',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => onDelete(d.id),
        ),
      ),
    ]);
  }
}
