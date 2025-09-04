import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// MVP Counting Station:
/// - Pflicht: Station + Zähler (lokal gespeichert)
/// - Nur eigene Station in der Liste (letzte 15)
/// - Keyboard-first (Enter zählt), Mobile: großer + Button
/// - Undo der letzten Runde (30s)
class CountingStationPage extends StatefulWidget {
  const CountingStationPage({super.key});

  @override
  State<CountingStationPage> createState() => _CountingStationPageState();
}

class _CountingStationPageState extends State<CountingStationPage> {
  final _startCtrl = TextEditingController();
  final _startFocus = FocusNode();

  String? _stationName;
  String? _counterName;

  bool _isAdmin = false;
  bool _loading = true;
  String _status = '';

  // Undo
  String? _lastLapId;
  DateTime? _lastLapAt;
  Timer? _undoTimer;

  // Cooldown gegen Doppelzählungen (per Startnummer)
  final Map<int, DateTime> _cooldown = {};

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  @override
  void dispose() {
    _undoTimer?.cancel();
    _startCtrl.dispose();
    _startFocus.dispose();
    super.dispose();
  }

  Future<void> _initAll() async {
    try {
      // Admin-Check
      final u = FirebaseAuth.instance.currentUser;
      if (u != null) {
        final doc = await FirebaseFirestore.instance.collection('Laufer').doc(u.uid).get();
        _isAdmin = (doc.data()?['role'] == 'admin');
      }

      // Station/Zähler aus Local Storage
      final prefs = await SharedPreferences.getInstance();
      _stationName = prefs.getString('cs_station');
      _counterName = prefs.getString('cs_counter');

      setState(() => _loading = false);

      // Fokus direkt setzen, wenn Setup komplett
      if (_stationName != null && _stationName!.isNotEmpty && mounted) {
        _requestFocus();
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _status = 'Init-Fehler: $e';
      });
    }
  }

  void _requestFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startFocus.requestFocus();
    });
  }

  Future<void> _openSettings() async {
    final stationCtrl = TextEditingController(text: _stationName ?? '');
    final counterCtrl = TextEditingController(text: _counterName ?? '');
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zählerstation einrichten'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: stationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Stationsname (z. B. "Tor A")',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: counterCtrl,
                decoration: const InputDecoration(
                  labelText: 'Zählername (dein Name)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Beides ist Pflicht. Wird lokal gespeichert.'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Speichern')),
        ],
      ),
    );

    if (res == true) {
      final s = stationCtrl.text.trim();
      final c = counterCtrl.text.trim();
      if (s.isEmpty || c.isEmpty) {
        setState(() => _status = 'Bitte Station und Zähler angeben.');
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cs_station', s);
      await prefs.setString('cs_counter', c);
      setState(() {
        _stationName = s;
        _counterName = c;
        _status = 'Station/Zähler gespeichert.';
      });
      _requestFocus();
    }
  }

  bool get _setupComplete =>
      (_stationName ?? '').isNotEmpty && (_counterName ?? '').isNotEmpty;

  String _fmt(DateTime t) => DateFormat.Hms().format(t);

  Future<void> _countLap() async {
    if (!_setupComplete) {
      setState(() => _status = 'Bitte zuerst Station/Zähler einrichten.');
      return;
    }
    if (!_isAdmin) {
      setState(() => _status = 'Keine Berechtigung: Nur Admins dürfen zählen.');
      return;
    }

    final raw = _startCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _status = 'Startnummer eingeben.');
      return;
    }
    final startNumber = int.tryParse(raw);
    if (startNumber == null) {
      setState(() => _status = 'Ungültige Startnummer.');
      return;
    }

    // Cooldown (2s) pro Startnummer
    final now = DateTime.now();
    final last = _cooldown[startNumber];
    if (last != null && now.difference(last).inMilliseconds < 1500) {
      setState(() => _status = 'Schon gezählt – kurz warten…');
      return;
    }
    _cooldown[startNumber] = now;

    setState(() => _status = 'Zähle #$startNumber …');

    try {
      // Runner via Startnummer finden
      final q = await FirebaseFirestore.instance
          .collection('Laufer')
          .where('startNumber', isEqualTo: startNumber)
          .limit(1)
          .get();

      if (q.docs.isEmpty) {
        setState(() => _status = 'Keine Läufer:in mit #$startNumber gefunden.');
        return;
      }
      final runnerId = q.docs.first.id;

      // Runde anlegen
      final ref = await FirebaseFirestore.instance.collection('Runden').add({
        'runnerId': runnerId,
        'startNumber': startNumber,
        'stationName': _stationName,
        'counterName': _counterName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Undo-Fenster (30s)
      _undoTimer?.cancel();
      _lastLapId = ref.id;
      _lastLapAt = DateTime.now();
      _undoTimer = Timer(const Duration(seconds: 30), () {
        if (!mounted) return;
        setState(() {
          _lastLapId = null;
          _lastLapAt = null;
        });
      });

      setState(() {
        _status = 'Gezählt #$startNumber • ${_fmt(DateTime.now())}';
        _startCtrl.clear();
      });

      _requestFocus();
    } catch (e) {
      setState(() => _status = 'Fehler: $e');
    }
  }

  Future<void> _undoLast() async {
    if (_lastLapId == null || _lastLapAt == null) return;
    final age = DateTime.now().difference(_lastLapAt!);
    if (age > const Duration(seconds: 30)) {
      setState(() => _status = 'Zu spät zum Rückgängig machen.');
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('Runden').doc(_lastLapId).delete();
      setState(() {
        _status = 'Letzte Runde entfernt.';
        _lastLapId = null;
        _lastLapAt = null;
      });
    } catch (e) {
      setState(() => _status = 'Undo fehlgeschlagen: $e');
    }
    _requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Zählerstation')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zählerstation'),
        actions: [
          IconButton(
            tooltip: 'Einstellungen',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Setup-Hinweis (Pflicht)
                if (!_setupComplete)
                  Card(
                    color: Colors.yellow.shade50,
                    child: ListTile(
                      leading: const Icon(Icons.warning_amber_outlined),
                      title: const Text('Station & Zähler noch nicht gesetzt'),
                      subtitle: const Text('Bitte oben rechts auf „Einstellungen“ tippen.'),
                      trailing: FilledButton(
                        onPressed: _openSettings,
                        child: const Text('Einrichten'),
                      ),
                    ),
                  ),

                // Eingabezeile
                LayoutBuilder(
                  builder: (context, c) {
                    final isNarrow = c.maxWidth < 560;
                    return Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _startCtrl,
                            focusNode: _startFocus,
                            keyboardType: TextInputType.number,
                            onSubmitted: (_) => _countLap(),
                            decoration: InputDecoration(
                              labelText: _setupComplete
                                  ? 'Startnummer (Enter = zählen)'
                                  : 'Startnummer (erst Einrichten)',
                              border: const OutlineInputBorder(),
                            ),
                            enabled: _setupComplete && _isAdmin,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 56,
                          width: isNarrow ? 120 : 160,
                          child: ElevatedButton.icon(
                            onPressed: (_setupComplete && _isAdmin) ? _countLap : null,
                            icon: const Icon(Icons.add),
                            label: const Text('Zählen'),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 8),
                // Status + Undo
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _status,
                        style: TextStyle(color: _status.startsWith('Fehler') ? Colors.red : Colors.black54),
                      ),
                    ),
                    if (_lastLapId != null)
                      FilledButton.tonalIcon(
                        onPressed: _undoLast,
                        icon: const Icon(Icons.undo),
                        label: const Text('Rückgängig (30s)'),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Letzte 15 der eigenen Station
                Expanded(
                  child: _StationRecentList(stationName: _stationName),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StationRecentList extends StatelessWidget {
  final String? stationName;
  const _StationRecentList({required this.stationName});

  @override
  Widget build(BuildContext context) {
    if (stationName == null || stationName!.isEmpty) {
      return const Center(child: Text('Keine Station gewählt.'));
    }

    final q = FirebaseFirestore.instance
        .collection('Runden')
        .where('stationName', isEqualTo: stationName)
        .orderBy('createdAt', descending: true)
        .limit(15);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Fehler: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('Noch keine Runden an dieser Station.'));
        }

        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final d = docs[i].data();
            final sn = (d['startNumber'] ?? '').toString();
            final counter = (d['counterName'] ?? '').toString();
            final ts = d['createdAt'] is Timestamp
                ? (d['createdAt'] as Timestamp).toDate().toLocal()
                : null;
            final when = ts == null ? '—' : DateFormat.Hms().format(ts);
            return ListTile(
              dense: true,
              leading: CircleAvatar(child: Text(sn.isEmpty ? '—' : sn)),
              title: Text('Zähler: ${counter.isEmpty ? '—' : counter}'),
              subtitle: Text(when),
            );
          },
        );
      },
    );
  }
}
