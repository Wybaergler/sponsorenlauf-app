import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class SponsorInvoicesPage extends StatefulWidget {
  const SponsorInvoicesPage({super.key});

  @override
  State<SponsorInvoicesPage> createState() => _SponsorInvoicesPageState();
}

class _SponsorInvoicesPageState extends State<SponsorInvoicesPage> {
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

  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Aggregation
  final Map<String, _SponsorAgg> _bySponsor = {};

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

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
      _bySponsor.clear();
    });
    try {
      // Zeitfenster optional aus Lauf-Doku
      final laufDoc = await FirebaseFirestore.instance.collection('Lauf').doc('sponsorenlauf-2025').get();
      final ld = laufDoc.data();
      if (ld != null) {
        final s = ld['startTime'];
        final e = ld['endTime'];
        if (s is Timestamp) _start = s.toDate();
        if (e is Timestamp) _end = e.toDate();
      }

      // 1) Runden je Läufer vorladen (Admin-Leserecht erforderlich)
      final runnersSnap = await FirebaseFirestore.instance.collection('Laufer').get();
      final runnerIds = runnersSnap.docs.map((d) => d.id).toList();

      final Map<String, int> roundsByRunner = {};
      for (final rid in runnerIds) {
        Query q = FirebaseFirestore.instance.collection('Runden').where('runnerId', isEqualTo: rid);
        if (_start != null) q = q.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(_start!));
        if (_end != null) q = q.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(_end!));
        final rSnap = await q.get();
        roundsByRunner[rid] = rSnap.size;
      }

      // 2) Spenden lesen und pro Sponsor aggregieren
      final spSnap = await FirebaseFirestore.instance.collection('Spenden').get();
      for (final sDoc in spSnap.docs) {
        final sd = sDoc.data() as Map<String, dynamic>;
        final email = (sd['sponsorEmail'] ?? '').toString().trim().toLowerCase();
        if (email.isEmpty) continue; // ohne Mail keine Abrechnung
        final name = (sd['sponsorName'] ?? '').toString();
        final runnerId = (sd['runnerId'] ?? '').toString();
        final type = (sd['sponsoringType'] ?? sd['type'] ?? '').toString();
        final num amountNum = (sd['amount'] is num) ? sd['amount'] as num : 0;
        final double amount = amountNum.toDouble();
        final rounds = roundsByRunner[runnerId] ?? 0;

        final agg = _bySponsor.putIfAbsent(email, () => _SponsorAgg(email: email, name: name));
        agg.countSpenden += 1;
        if (type == 'fixed' || type == 'fix') {
          agg.fixedSum += amount;
          agg.details.add(_SponsorDetail(runnerId: runnerId, type: 'fixed', amount: amount, rounds: rounds));
        } else if (type == 'perLap' || type == 'perRound') {
          agg.perLapSum += amount;
          agg.details.add(_SponsorDetail(runnerId: runnerId, type: 'perLap', amount: amount, rounds: rounds));
        } else {
          agg.details.add(_SponsorDetail(runnerId: runnerId, type: type, amount: amount, rounds: rounds));
        }
      }

      // Totale berechnen
      for (final agg in _bySponsor.values) {
        agg.total = agg.fixedSum + agg.perLapSum * _sumRoundsOf(agg);
      }

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _sumRoundsOf(_SponsorAgg agg) {
    int sum = 0;
    for (final d in agg.details) {
      sum += d.rounds;
    }
    return sum;
  }

  // CSV Export → im Dialog anzeigbar & kopierbar (kein dart:html nötig)
  void _exportAllCsv() {
    final lines = <String>[];
    lines.add('sponsorEmail;sponsorName;countSpenden;fixedSum;perLapSum;total');
    final keys = _bySponsor.keys.toList()..sort();
    for (final k in keys) {
      final a = _bySponsor[k]!;
      lines.add([
        a.email,
        a.name.replaceAll(';', ','),
        a.countSpenden.toString(),
        a.fixedSum.toStringAsFixed(2),
        a.perLapSum.toStringAsFixed(2),
        a.total.toStringAsFixed(2),
      ].join(';'));
    }
    final csv = lines.join('\n');
    _showCsvDialog('Sponsoren – Übersicht (CSV)', csv);
  }

  void _exportSponsorCsv(_SponsorAgg agg) {
    final lines = <String>[];
    lines.add('sponsorEmail;sponsorName;runnerId;type;amount;rounds;rowTotal');
    for (final d in agg.details) {
      final rowTotal = d.type == 'perLap' ? d.amount * d.rounds : d.amount;
      lines.add([
        agg.email,
        agg.name.replaceAll(';', ','),
        d.runnerId,
        d.type,
        d.amount.toStringAsFixed(2),
        d.rounds.toString(),
        rowTotal.toStringAsFixed(2),
      ].join(';'));
    }
    final csv = lines.join('\n');
    _showCsvDialog('Sponsor – Detail (CSV)', csv);
  }

  void _showCsvDialog(String title, String csv) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 600,
            child: SelectableText(csv),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: csv));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('CSV in die Zwischenablage kopiert.')),
                  );
                }
              },
              child: const Text('In Zwischenablage'),
            ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Schliessen')),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final windowText = (_start != null || _end != null)
        ? 'Zeitraum: ${_start?.toLocal() ?? '…'} – ${_end?.toLocal() ?? '…'}'
        : 'Zeitraum: alle Daten';

    // 1) Nicht eingeloggt → Login
    if (_user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sponsor-Abrechnung (Login)')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
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
                ]),
              ),
            ),
          ),
        ),
      );
    }

    // 2) Kein Admin
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sponsor-Abrechnung')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.lock, size: 48),
                const SizedBox(height: 12),
                const Text('Kein Admin-Zugang.', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                const Text('Stelle sicher, dass dein Benutzer in „Laufer/{uid}“ die Rolle „admin“ hat.'),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _signOut, child: const Text('Abmelden')),
              ]),
            ),
          ),
        ),
      );
    }

    // 3) Admin-Ansicht
    final items = _bySponsor.values.toList()
      ..sort((a, b) => a.email.compareTo(b.email));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sponsor-Abrechnung (Preview)'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _refresh,
            icon: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            tooltip: 'Aktualisieren',
          ),
          IconButton(
            onPressed: items.isEmpty ? null : _exportAllCsv,
            icon: const Icon(Icons.table_view),
            tooltip: 'CSV (Übersicht)',
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
          : items.isEmpty
          ? const Center(child: Text('Keine Sponsoren gefunden.'))
          : LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 700;
          if (narrow) {
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final a = items[i];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.name.isNotEmpty ? a.name : a.email, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(a.email, style: const TextStyle(color: Colors.black54)),
                        const SizedBox(height: 8),
                        _kv('Spenden', '${a.countSpenden}'),
                        _kv('Fix (CHF)', a.fixedSum.toStringAsFixed(2)),
                        _kv('pro Runde (CHF)', a.perLapSum.toStringAsFixed(2)),
                        _kv('Total (CHF)', a.total.toStringAsFixed(2)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _openDetail(a),
                              icon: const Icon(Icons.receipt_long),
                              label: const Text('Details'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () => _exportSponsorCsv(a),
                              icon: const Icon(Icons.table_rows),
                              label: const Text('CSV Sponsor'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }
          // Desktop-Tabelle
          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Sponsor')),
                  DataColumn(label: Text('E-Mail')),
                  DataColumn(label: Text('#Spenden')),
                  DataColumn(label: Text('Fix (CHF)')),
                  DataColumn(label: Text('pro Runde (CHF)')),
                  DataColumn(label: Text('Total (CHF)')),
                  DataColumn(label: Text('Aktionen')),
                ],
                rows: items.map((a) {
                  return DataRow(cells: [
                    DataCell(Text(a.name.isNotEmpty ? a.name : '—')),
                    DataCell(Text(a.email)),
                    DataCell(Text('${a.countSpenden}')),
                    DataCell(Text(a.fixedSum.toStringAsFixed(2))),
                    DataCell(Text(a.perLapSum.toStringAsFixed(2))),
                    DataCell(Text(a.total.toStringAsFixed(2))),
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _openDetail(a),
                          icon: const Icon(Icons.receipt_long),
                          tooltip: 'Details',
                        ),
                        IconButton(
                          onPressed: () => _exportSponsorCsv(a),
                          icon: const Icon(Icons.table_rows),
                          tooltip: 'CSV Sponsor',
                        ),
                      ],
                    )),
                  ]);
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openDetail(_SponsorAgg agg) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _SponsorDetailPage(agg: agg)),
    );
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        SizedBox(width: 180, child: Text(k)),
        Expanded(child: Text(v, textAlign: TextAlign.right)),
      ],
    ),
  );
}

class _SponsorAgg {
  final String email;
  final String name;
  int countSpenden = 0;
  double fixedSum = 0;
  double perLapSum = 0;
  double total = 0;
  final List<_SponsorDetail> details = [];

  _SponsorAgg({required this.email, required String name}) : name = name.trim();
}

class _SponsorDetail {
  final String runnerId;
  final String type; // fixed | perLap | other
  final double amount;
  final int rounds;

  _SponsorDetail({
    required this.runnerId,
    required this.type,
    required this.amount,
    required this.rounds,
  });
}

class _SponsorDetailPage extends StatelessWidget {
  final _SponsorAgg agg;
  const _SponsorDetailPage({required this.agg});

  @override
  Widget build(BuildContext context) {
    final rows = agg.details;
    final total = rows.fold<double>(
      0, (p, d) => p + (d.type == 'perLap' ? d.amount * d.rounds : d.amount),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Sponsor: ${agg.name.isNotEmpty ? agg.name : agg.email}'),
        actions: [
          IconButton(
            onPressed: () => _exportCsv(context),
            icon: const Icon(Icons.table_view),
            tooltip: 'CSV export',
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: rows.length + 1,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          if (i == rows.length) {
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('Σ Total (CHF): ${total.toStringAsFixed(2)}',
                  textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600)),
            );
          }
          final d = rows[i];
          final rowTotal = d.type == 'perLap' ? d.amount * d.rounds : d.amount;
          return ListTile(
            leading: CircleAvatar(child: Text('${i + 1}')),
            title: Text('Runner: ${d.runnerId}'),
            subtitle: Text('Typ: ${d.type} · Betrag: ${d.amount.toStringAsFixed(2)} · Runden: ${d.rounds}'),
            trailing: Text(rowTotal.toStringAsFixed(2)),
          );
        },
      ),
    );
  }

  void _exportCsv(BuildContext context) async {
    final lines = <String>[];
    lines.add('sponsorEmail;sponsorName;runnerId;type;amount;rounds;rowTotal');
    for (final d in agg.details) {
      final rowTotal = d.type == 'perLap' ? d.amount * d.rounds : d.amount;
      lines.add([
        agg.email,
        agg.name.replaceAll(';', ','),
        d.runnerId,
        d.type,
        d.amount.toStringAsFixed(2),
        d.rounds.toString(),
        rowTotal.toStringAsFixed(2),
      ].join(';'));
    }
    final csv = lines.join('\n');
    await Clipboard.setData(ClipboardData(text: csv));
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV in die Zwischenablage kopiert.')),
    );
  }
}
