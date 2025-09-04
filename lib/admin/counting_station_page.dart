import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Zählerstation nach UI-Spez:
/// - EIN Pflichtfeld "Identity" (Stations-/Zählername), lokal gespeichert
/// - Identity wird als stationName UND counterName geschrieben
/// - Erfassung: Startnummer groß, Enter/„+“ zählt
/// - Liste: ALLE Erfassungen dieser Identity (neueste oben)
/// - Papierkorb pro Zeile mit kurzer Inline-Bestätigung (kein Dialog, kein Löschgrund)
class CountingStationPage extends StatefulWidget {
  const CountingStationPage({super.key});
  @override
  State<CountingStationPage> createState() => _CountingStationPageState();
}

class _CountingStationPageState extends State<CountingStationPage> {
  final _identityCtrl = TextEditingController();
  final _startCtrl = TextEditingController();
  final _startFocus = FocusNode();

  String? _identity; // Pflichtfeld
  bool _editingIdentity = false;

  bool _loading = true;
  bool _isAdmin = false;
  String _status = '';

  // Doppel-Tap-Schutz (kurzer Cooldown pro Startnummer)
  final Map<int, DateTime> _cooldown = {};

  // Cache: runnerId -> Läufername (schont Firestore)
  final Map<String, String> _runnerNameCache = {};

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  @override
  void dispose() {
    _identityCtrl.dispose();
    _startCtrl.dispose();
    _startFocus.dispose();
    super.dispose();
  }

  Future<void> _initAll() async {
    try {
      // Admin-Check
      final u = FirebaseAuth.instance.currentUser;
      if (u != null) {
        final userDoc = await FirebaseFirestore.instance.collection('Laufer').doc(u.uid).get();
        _isAdmin = (userDoc.data()?['role'] == 'admin');
      }

      // Identity aus Local Storage
      final prefs = await SharedPreferences.getInstance();
      _identity = prefs.getString('cs_identity');
      _identityCtrl.text = _identity ?? '';

      setState(() => _loading = false);

      if (_identity != null && _identity!.isNotEmpty) _requestFocus();
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

  bool get _setupComplete => (_identity ?? '').isNotEmpty;

  Future<void> _saveIdentity() async {
    final id = _identityCtrl.text.trim();
    if (id.isEmpty) {
      setState(() => _status = 'Bitte Stations-/Zählername eingeben.');
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cs_identity', id);
    setState(() {
      _identity = id;
      _editingIdentity = false;
      _status = 'Zählerstation gespeichert.';
    });
    _requestFocus();
  }

  String _fmtTime(DateTime t) => DateFormat.Hms().format(t);

  // Läufername aus "Laufer/{runnerId}" lesen & cachen
  Future<String> _getRunnerName(String runnerId) async {
    if (_runnerNameCache.containsKey(runnerId)) return _runnerNameCache[runnerId]!;
    try {
      final d = await FirebaseFirestore.instance.collection('Laufer').doc(runnerId).get();
      final m = d.data() ?? {};
      String name = _bestName(m);
      _runnerNameCache[runnerId] = name;
      return name;
    } catch (_) {
      return '';
    }
  }

  String _bestName(Map<String, dynamic> m) {
    final a = (m['displayName'] ?? '').toString().trim();
    if (a.isNotEmpty) return a;
    // Mögliche Felder im Projekt abdecken
    final fn = (m['firstName'] ?? m['vorname'] ?? '').toString().trim();
    final ln = (m['lastName'] ?? m['nachname'] ?? m['name'] ?? '').toString().trim();
    final combo = [fn, ln].where((s) => s.isNotEmpty).join(' ');
    if (combo.isNotEmpty) return combo;
    final nick = (m['nickname'] ?? m['spitzname'] ?? '').toString().trim();
    return nick;
  }

  Future<void> _countLap() async {
    if (!_setupComplete) {
      setState(() => _status = 'Zuerst Stations-/Zählername setzen.');
      return;
    }
    if (!_isAdmin) {
      setState(() => _status = 'Keine Berechtigung: nur Admins dürfen zählen.');
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

    // kleiner Cooldown (~1.5s) gegen Doppelzählung
    final now = DateTime.now();
    final last = _cooldown[startNumber];
    if (last != null && now.difference(last).inMilliseconds < 1500) {
      setState(() => _status = 'Schon gezählt – kurz warten…');
      return;
    }
    _cooldown[startNumber] = now;

    setState(() => _status = 'Zähle #$startNumber …');

    try {
      // Runner via Startnummer
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

      await FirebaseFirestore.instance.collection('Runden').add({
        'runnerId': runnerId,
        'startNumber': startNumber,
        'stationName': _identity,
        'counterName': _identity,
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _status = 'Gezählt #$startNumber • ${_fmtTime(DateTime.now())}';
        _startCtrl.clear();
      });
      _requestFocus();
    } catch (e) {
      setState(() => _status = 'Fehler: $e');
    }
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
      appBar: AppBar(title: const Text('Zählerstation')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Gelber Banner
                Container(
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: _editingIdentity || !_setupComplete
                      ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Zählerstation festlegen', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _identityCtrl,
                        decoration: const InputDecoration(
                          hintText: 'z. B. „Tor A – René“',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          FilledButton(onPressed: _saveIdentity, child: const Text('Speichern')),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => setState(() => _editingIdentity = false),
                            child: const Text('Abbrechen'),
                          ),
                        ],
                      ),
                    ],
                  )
                      : Row(
                    children: [
                      const Icon(Icons.badge_outlined),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Zählerstation: ${_identity!}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(() => _editingIdentity = true),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Ändern'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Erfassung: Startnummer groß + „Zählen“
                LayoutBuilder(
                  builder: (context, c) {
                    final isNarrow = c.maxWidth < 640;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                  : 'Startnummer (erst Station speichern)',
                              border: const OutlineInputBorder(),
                            ),
                            enabled: _setupComplete && _isAdmin,
                            style: const TextStyle(fontSize: 22),
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

                // Statuszeile
                Text(
                  _status,
                  style: TextStyle(
                    color: _status.startsWith('Fehler') ? Colors.red : Colors.black54,
                  ),
                ),

                const SizedBox(height: 12),

                // Liste aller Erfassungen dieser Identity (neueste oben)
                Expanded(
                  child: _IdentityEntriesList(
                    identity: _identity,
                    isAdmin: _isAdmin,
                    runnerNameCache: _runnerNameCache,
                    getRunnerName: _getRunnerName,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IdentityEntriesList extends StatefulWidget {
  final String? identity;
  final bool isAdmin;
  final Map<String, String> runnerNameCache;
  final Future<String> Function(String runnerId) getRunnerName;

  const _IdentityEntriesList({
    required this.identity,
    required this.isAdmin,
    required this.runnerNameCache,
    required this.getRunnerName,
  });

  @override
  State<_IdentityEntriesList> createState() => _IdentityEntriesListState();
}

class _IdentityEntriesListState extends State<_IdentityEntriesList> {
  // Für Inline-Löschbestätigung
  final Set<String> _confirming = {};

  @override
  Widget build(BuildContext context) {
    final identity = widget.identity;
    if (identity == null || identity.isEmpty) {
      return const Center(child: Text('Keine Zählerstation gesetzt.'));
    }

    final q = FirebaseFirestore.instance
        .collection('Runden')
        .where('stationName', isEqualTo: identity)
        .orderBy('createdAt', descending: true); // volle Liste, neueste oben

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Fehler: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snap.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('Noch keine Erfassungen.'));

        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final doc = docs[i];
            final m = doc.data();
            final startNumber = (m['startNumber'] ?? '').toString();
            final runnerId = (m['runnerId'] ?? '').toString();
            final ts = m['createdAt'] is Timestamp
                ? (m['createdAt'] as Timestamp).toDate().toLocal()
                : null;
            final when = ts == null ? '—' : DateFormat.Hms().format(ts);

            return FutureBuilder<String>(
              future: runnerId.isEmpty ? Future.value('') : widget.getRunnerName(runnerId),
              builder: (context, nameSnap) {
                final runnerName = nameSnap.data ?? '';

                final confirming = _confirming.contains(doc.id);

                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    child: Text(
                      startNumber.isEmpty ? '—' : startNumber,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          runnerName.isEmpty ? ' ' : runnerName,
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(when),
                  trailing: confirming
                      ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () async {
                          // Hard-Delete (gemäß bestehenden Regeln)
                          try {
                            await FirebaseFirestore.instance.collection('Runden').doc(doc.id).delete();
                          } catch (_) {}
                          if (!mounted) return;
                          setState(() => _confirming.remove(doc.id));
                        },
                        child: const Text('Ja'),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: () => setState(() => _confirming.remove(doc.id)),
                        child: const Text('Nein'),
                      ),
                    ],
                  )
                      : IconButton(
                    tooltip: 'Löschen',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: widget.isAdmin
                        ? () => setState(() => _confirming.add(doc.id))
                        : null,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
