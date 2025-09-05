import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// EIN Screen für Zählerstation:
/// A) Setup: Name eingeben -> Weiter
/// B) Run:  AppBar (Gelb aus Theme) + "#" Eingabe + "Zählen" + Liste + roter Papierkorb
/// Feedback: nur Fehlerbanner (rot, vollbreit); bei Erfolg kurzer grüner Highlight des neuen Eintrags.
class CountingStationPage extends StatefulWidget {
  const CountingStationPage({super.key});

  @override
  State<CountingStationPage> createState() => _CountingStationPageState();
}

class _CountingStationPageState extends State<CountingStationPage> {
  // Farben (blau/weiß für Controls)
  static const Color _blue = Color(0xFF1565C0);
  static const Color _blueDark = Color(0xFF0D47A1);

  // Phase
  String? _stationName; // null => Setup

  // Setup
  final _stationCtrl = TextEditingController();
  String? _stationError;
  bool _busy = false;

  // Run
  final _startCtrl = TextEditingController();
  final _startFocus = FocusNode();

  // Nur Fehler (kein Success-Text)
  String? _errorMsg;
  Timer? _errorTimer;

  // Letzter neu angelegter Runden-Dokument-ID für grünes Highlight
  String? _lastAddedDocId;
  Timer? _highlightTimer;

  // Cache für Läufernamen
  final Map<String, String> _runnerNameCache = {};

  @override
  void dispose() {
    _stationCtrl.dispose();
    _startCtrl.dispose();
    _startFocus.dispose();
    _errorTimer?.cancel();
    _highlightTimer?.cancel();
    super.dispose();
  }

  // ---------- Setup ----------
  InputDecoration _blueInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(color: Colors.black54),
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: _blue, width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: _blueDark, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.red, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      errorText: _stationError,
    );
  }

  Future<void> _goRun() async {
    final v = _stationCtrl.text.trim();
    if (v.isEmpty) {
      setState(() => _stationError = 'Bitte Zählerstationsnamen eingeben.');
      return;
    }
    setState(() {
      _stationError = null;
      _busy = true;
    });
    setState(() {
      _stationName = v;
      _busy = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startFocus.requestFocus();
    });
  }

  // ---------- Run ----------
  void _showError(String msg, {int millis = 1600}) {
    _errorTimer?.cancel();
    setState(() => _errorMsg = msg);
    _errorTimer = Timer(Duration(milliseconds: millis), () {
      if (!mounted) return;
      setState(() => _errorMsg = null);
    });
  }

  Future<String> _getRunnerName(String runnerId) async {
    if (_runnerNameCache.containsKey(runnerId)) return _runnerNameCache[runnerId]!;
    try {
      final d = await FirebaseFirestore.instance.collection('Laufer').doc(runnerId).get();
      final m = d.data() ?? {};
      final a = (m['displayName'] ?? '').toString().trim();
      if (a.isNotEmpty) {
        _runnerNameCache[runnerId] = a;
        return a;
      }
      final fn = (m['firstName'] ?? m['vorname'] ?? '').toString().trim();
      final ln = (m['lastName'] ?? m['nachname'] ?? m['name'] ?? '').toString().trim();
      final combo = [fn, ln].where((s) => s.isNotEmpty).join(' ');
      final nick = (m['nickname'] ?? m['spitzname'] ?? '').toString().trim();
      final best = combo.isNotEmpty ? combo : nick;
      _runnerNameCache[runnerId] = best;
      return best;
    } catch (_) {
      return '';
    }
  }

  Future<void> _countLap() async {
    final raw = _startCtrl.text.trim();
    if (raw.isEmpty) {
      _showError('Startnummer eingeben.');
      _refocus();
      return;
    }
    final startNumber = int.tryParse(raw);
    if (startNumber == null) {
      _showError('Ungültige Startnummer.');
      _startCtrl.clear();
      _refocus();
      return;
    }

    try {
      // 1) Startnummer validieren
      final q = await FirebaseFirestore.instance
          .collection('Laufer')
          .where('startNumber', isEqualTo: startNumber)
          .limit(1)
          .get();

      if (q.docs.isEmpty) {
        _showError('Startnummer nicht gefunden.');
        _startCtrl.clear();
        _refocus();
        return;
      }
      final runnerId = q.docs.first.id;

      // 2) Runde erfassen
      final ref = await FirebaseFirestore.instance.collection('Runden').add({
        'runnerId': runnerId,
        'startNumber': startNumber,
        'stationName': _stationName,
        'counterName': _stationName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Erfolg: kein Text, nur kurzer grüner Highlight der neu erfassten Zeile
      _highlightTimer?.cancel();
      setState(() => _lastAddedDocId = ref.id);
      _highlightTimer = Timer(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _lastAddedDocId = null);
      });

      _startCtrl.clear();
      _refocus();
    } catch (e) {
      _showError('Fehler: $e');
      _refocus();
    }
  }

  void _refocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startFocus.requestFocus();
    });
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: _blue,
      foregroundColor: Colors.white,
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      minimumSize: const Size(220, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
    final buttonStyleLarge = ElevatedButton.styleFrom(
      backgroundColor: _blue,
      foregroundColor: Colors.white,
      minimumSize: const Size(220, 56),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
    );

    final appBar = AppBar(
      title: Text(_stationName == null ? 'Zählerstation' : 'Zählerstation: $_stationName'),
    );

    if (_stationName == null) {
      // Setup
      return Scaffold(
        appBar: appBar,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _stationCtrl,
                    textAlign: TextAlign.center,
                    cursorColor: _blue,
                    style: const TextStyle(color: _blue, fontSize: 18),
                    decoration: _blueInputDecoration('Name der Zählerstation'),
                    onChanged: (_) {
                      if (_stationError != null) setState(() => _stationError = null);
                    },
                    onSubmitted: (_) => _goRun(),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _busy ? null : _goRun,
                    style: buttonStyle,
                    child: _busy
                        ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Weiter'),
                  ),
                ],
              ),
            ),
          ),
        ),
        backgroundColor: Colors.grey.shade100,
      );
    }

    // Run
    return Scaffold(
      appBar: appBar,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Eingabe zentriert
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _startCtrl,
                          focusNode: _startFocus,
                          keyboardType: TextInputType.number,
                          onSubmitted: (_) => _countLap(),
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            hintText: '#',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                          ),
                          cursorColor: _blue,
                          style: const TextStyle(fontSize: 26, letterSpacing: 1.0, color: _blue),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: 220,
                            child: ElevatedButton.icon(
                              onPressed: _countLap,
                              icon: const Icon(Icons.add),
                              label: const Text('Zählen'),
                              style: buttonStyleLarge,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Fehlerbanner (vollbreit, leicht rot hinterlegt)
                if (_errorMsg != null) ...[
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.10),
                      border: Border.all(color: Colors.red.withOpacity(0.6)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMsg!,
                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Liste Stationseinträge
                Expanded(
                  child: _StationEntriesList(
                    stationName: _stationName!,
                    getRunnerName: _getRunnerName,
                    onAfterDelete: _refocus,
                    highlightDocId: _lastAddedDocId,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      backgroundColor: Colors.grey.shade100,
    );
  }
}

class _StationEntriesList extends StatelessWidget {
  final String stationName;
  final Future<String> Function(String runnerId) getRunnerName;
  final VoidCallback onAfterDelete;
  final String? highlightDocId;

  const _StationEntriesList({
    required this.stationName,
    required this.getRunnerName,
    required this.onAfterDelete,
    required this.highlightDocId,
  });

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance
        .collection('Runden')
        .where('stationName', isEqualTo: stationName)
        .orderBy('createdAt', descending: true);

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
              future: runnerId.isEmpty ? Future.value('') : getRunnerName(runnerId),
              builder: (context, nameSnap) {
                final runnerName = nameSnap.data ?? '';
                final isHighlight = highlightDocId != null && highlightDocId == doc.id;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  color: isHighlight ? Colors.green.withOpacity(0.12) : Colors.transparent,
                  child: ListTile(
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
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          when,
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      tooltip: 'Löschen',
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        try {
                          await FirebaseFirestore.instance.collection('Runden').doc(doc.id).delete();
                        } catch (_) {
                          // ignore
                        } finally {
                          onAfterDelete(); // Fokus zurück ins Eingabefeld
                        }
                      },
                    ),
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
