import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FinalAccountingPage extends StatefulWidget {
  const FinalAccountingPage({super.key});

  @override
  State<FinalAccountingPage> createState() => _FinalAccountingPageState();
}

class _FinalAccountingPageState extends State<FinalAccountingPage> {
  // Auth
  late final StreamSubscription<User?> _authSub;
  User? _user;
  bool _authBusy = false;
  String? _authError;
  bool _isAdmin = false;

  // Data
  bool _loading = false;
  String? _error;
  DateTime? _start;
  DateTime? _end;
  List<_RunnerRow> _rows = [];

  // Login-Form
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((u) async {
      setState(() {
        _user = u;
        _authError = null;
        _isAdmin = false;
      });
      if (u != null) {
        await _checkAdmin(u);
        if (_isAdmin) {
          await _refresh();
        }
      }
    });
  }

  @override
  void dispose() {
    _authSub.cancel();
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkAdmin(User u) async {
    try {
      final snap = await FirebaseFirestore.instance.collection('Laufer').doc(u.uid).get();
      final role = snap.data()?['role'];
      setState(() => _isAdmin = role == 'admin');
    } catch (e) {
      setState(() {
        _isAdmin = false;
        _authError = 'Konnte Admin-Status nicht prüfen: $e';
      });
    }
  }

  Future<void> _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _authBusy = true;
      _authError = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _pwdCtrl.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _authError = _friendlyAuthError(e));
    } catch (e) {
      setState(() => _authError = 'Unerwarteter Fehler: $e');
    } finally {
      if (mounted) setState(() => _authBusy = false);
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Die E-Mail-Adresse ist ungültig.';
      case 'user-disabled':
        return 'Dieses Konto wurde deaktiviert.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-Mail oder Passwort ist falsch.';
      case 'too-many-requests':
        return 'Zu viele Versuche. Bitte später erneut versuchen.';
      case 'network-request-failed':
        return 'Keine Netzwerkverbindung.';
      default:
        return 'Anmeldung fehlgeschlagen. Bitte später erneut versuchen.';
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
      _rows = [];
    });
    try {
      // Zeitfenster aus 'Lauf/sponsorenlauf-2025' (optional)
      final laufDoc = await FirebaseFirestore.instance
          .collection('Lauf')
          .doc('sponsorenlauf-2025')
          .get();
      final ld = laufDoc.data();
      if (ld != null) {
        final s = ld['startTime'];
        final e = ld['endTime'];
        if (s is Timestamp) _start = s.toDate();
        if (e is Timestamp) _end = e.toDate();
      }

      // Läufer laden
      final runnerSnap = await FirebaseFirestore.instance
          .collection('Laufer')
          .orderBy('startNumber', descending: false)
          .get();

      final rows = <_RunnerRow>[];

      // Für jeden Läufer Runden zählen + Spenden summieren
      for (final doc in runnerSnap.docs) {
        final id = doc.id;
        final d = doc.data() as Map<String, dynamic>;
        final name = (d['name'] ?? '').toString();
        final startNumberRaw = d['startNumber'];
        final int? startNumber = startNumberRaw is num ? startNumberRaw.toInt() : null;

        // RUNDEN zählen (nur Admin darf lesen -> deshalb integrierter Login)
        Query rundenQ = FirebaseFirestore.instance
            .collection('Runden')
            .where('runnerId', isEqualTo: id);
        if (_start != null) {
          rundenQ = rundenQ.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(_start!));
        }
        if (_end != null) {
          rundenQ = rundenQ.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(_end!));
        }
        final rundenSnap = await rundenQ.get();
        final rounds = rundenSnap.size;

        // SPENDEN summieren (Fix + pro Runde) – Spenden dürfen laut Regeln gelesen werden
        final spendenSnap = await FirebaseFirestore.instance
            .collection('Spenden')
            .where('runnerId', isEqualTo: id)
            .get();

        double fixed = 0.0;
        double perLap = 0.0;

        for (final sDoc in spendenSnap.docs) {
          final sd = sDoc.data() as Map<String, dynamic>;
          final num amountNum = (sd['amount'] is num) ? sd['amount'] as num : 0;
          final double amount = amountNum.toDouble();
          final String type = (sd['sponsoringType'] ?? sd['type'] ?? '').toString();
          if (type == 'fixed' || type == 'fix') {
            fixed += amount;
          } else if (type == 'perLap' || type == 'perRound') {
            perLap += amount;
          }
        }

        final total = fixed + perLap * rounds;

        rows.add(_RunnerRow(
          runnerId: id,
          name: name,
          startNumber: startNumber,
          rounds: rounds,
          fixed: fixed,
          perLap: perLap,
          total: total,
        ));
      }

      // Startnummer sortieren (Nulls ans Ende)
      rows.sort((a, b) {
        final an = a.startNumber ?? 1 << 30;
        final bn = b.startNumber ?? 1 << 30;
        return an.compareTo(bn);
      });

      if (!mounted) return;
      setState(() => _rows = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  double get _sumFixed => _rows.fold(0.0, (p, r) => p + r.fixed);
  double get _sumPerLap => _rows.fold(0.0, (p, r) => p + r.perLap);
  int get _sumRounds => _rows.fold(0, (p, r) => p + r.rounds);
  double get _sumTotal => _rows.fold(0.0, (p, r) => p + r.total);

  @override
  Widget build(BuildContext context) {
    final windowText = (_start != null || _end != null)
        ? 'Zeitraum: ${_start?.toLocal() ?? '…'} – ${_end?.toLocal() ?? '…'}'
        : 'Zeitraum: alle Daten';

    // 1) Nicht eingeloggt -> Login-Form anzeigen
    if (_user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Abrechnung – Vorschau (Login erforderlich)')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Bitte als Admin anmelden.', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'E-Mail'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'E-Mail eingeben' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _pwdCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Passwort'),
                      validator: (v) => (v == null || v.isEmpty) ? 'Passwort eingeben' : null,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _authBusy ? null : _signIn,
                        child: _authBusy
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Anmelden'),
                      ),
                    ),
                    if (_authError != null) ...[
                      const SizedBox(height: 8),
                      Text(_authError!, style: const TextStyle(color: Colors.red)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // 2) Eingeloggt, aber kein Admin
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Abrechnung – Vorschau')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock, size: 48),
                  const SizedBox(height: 12),
                  const Text('Kein Admin-Zugang.', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const Text('Bitte stelle sicher, dass dein Benutzer in „Laufer/{uid}“ die Rolle „admin“ hat.'),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _signOut, child: const Text('Abmelden')),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // 3) Admin: Datenansicht
    return Scaffold(
      appBar: AppBar(
        title: const Text('Abrechnung – Vorschau (Admin)'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _refresh,
            icon: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            tooltip: 'Aktualisieren',
          ),
          IconButton(
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
            tooltip: 'Abmelden',
          ),
        ],
      ),
      body: _error != null
          ? Center(child: Text('Fehler: $_error'))
          : _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
          ? const Center(child: Text('Keine Daten gefunden.'))
          : Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(windowText, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                final isNarrow = c.maxWidth < 600;
                if (isNarrow) {
                  // Mobile: Cards
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final r = _rows[i];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(child: Text(r.startNumber?.toString() ?? '–')),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      r.name.isEmpty ? r.runnerId : r.name,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _kv('Runden', '${r.rounds}'),
                              _kv('Fix (CHF)', r.fixed.toStringAsFixed(2)),
                              _kv('pro Runde (CHF)', r.perLap.toStringAsFixed(2)),
                              _kv('Total (CHF)', r.total.toStringAsFixed(2)),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }
                // Desktop: Tabelle
                return SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Startnr.', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Läufer', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Runden')),
                        DataColumn(label: Text('Fix (CHF)')),
                        DataColumn(label: Text('pro Runde (CHF)')),
                        DataColumn(label: Text('Total (CHF)')),
                      ],
                      rows: _rows.map((r) {
                        return DataRow(cells: [
                          DataCell(Text(r.startNumber?.toString() ?? '–')),
                          DataCell(Text(r.name.isEmpty ? r.runnerId : r.name)),
                          DataCell(Text('${r.rounds}')),
                          DataCell(Text(r.fixed.toStringAsFixed(2))),
                          DataCell(Text(r.perLap.toStringAsFixed(2))),
                          DataCell(Text(r.total.toStringAsFixed(2))),
                        ]);
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 16,
              runSpacing: 8,
              children: [
                Text('Σ Runden: $_sumRounds', style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('Σ Fix: ${_sumFixed.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('Σ pro Runde: ${_sumPerLap.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('Σ Total: ${_sumTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        SizedBox(width: 160, child: Text(k)),
        Expanded(child: Text(v, textAlign: TextAlign.right)),
      ],
    ),
  );
}

class _RunnerRow {
  final String runnerId;
  final String name;
  final int? startNumber;
  final int rounds;
  final double fixed;
  final double perLap;
  final double total;

  _RunnerRow({
    required this.runnerId,
    required this.name,
    required this.startNumber,
    required this.rounds,
    required this.fixed,
    required this.perLap,
    required this.total,
  });
}
