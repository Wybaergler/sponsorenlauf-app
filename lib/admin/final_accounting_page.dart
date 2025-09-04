import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FinalAccountingPage extends StatefulWidget {
  const FinalAccountingPage({super.key});

  @override
  State<FinalAccountingPage> createState() => _FinalAccountingPageState();
}

class _FinalAccountingPageState extends State<FinalAccountingPage> {
  bool _loading = false;
  String? _error;
  List<_RunnerRow> _rows = [];
  DateTime? _start;
  DateTime? _end;

  @override
  void initState() {
    super.initState();
    _loadWindowAndData();
  }

  Future<void> _loadWindowAndData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Optionales Zeitfenster aus 'Lauf/sponsorenlauf-2025'
      final laufDoc = await FirebaseFirestore.instance
          .collection('Lauf')
          .doc('sponsorenlauf-2025')
          .get();

      final data = laufDoc.data();
      if (data != null) {
        final s = data['startTime'];
        final e = data['endTime'];
        if (s is Timestamp) _start = s.toDate();
        if (e is Timestamp) _end = e.toDate();
      }

      // Läufer laden (Startnummer aufsteigend; fehlende Startnummern später sortiert ans Ende)
      final runnerSnap = await FirebaseFirestore.instance
          .collection('Laufer')
          .orderBy('startNumber', descending: false)
          .get();

      final rows = <_RunnerRow>[];

      for (final doc in runnerSnap.docs) {
        final id = doc.id;
        final rd = doc.data() as Map<String, dynamic>;
        final name = (rd['name'] ?? '') as String? ?? '';
        final startNumber = rd['startNumber'];

        // RUNDEN zählen (optional nach Zeitfenster filtern)
        Query rundenQ = FirebaseFirestore.instance
            .collection('Runden')
            .where('runnerId', isEqualTo: id);

        if (_start != null) {
          rundenQ = rundenQ.where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(_start!),
          );
        }
        if (_end != null) {
          rundenQ = rundenQ.where(
            'createdAt',
            isLessThanOrEqualTo: Timestamp.fromDate(_end!),
          );
        }

        final rundenAgg = await rundenQ.count().get();
        final int rounds = (rundenAgg.count is int) ? rundenAgg.count as int : (rundenAgg.count ?? 0);

        // SPENDEN summieren
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
          final type = (sd['sponsoringType'] ?? sd['type'] ?? '').toString();

          if (type == 'fixed') {
            fixed += amount;
          } else if (type == 'perLap') {
            perLap += amount;
          }
        }

        final total = fixed + perLap * rounds;
        rows.add(_RunnerRow(
          runnerId: id,
          name: name,
          startNumber: (startNumber is num) ? startNumber.toInt() : null,
          rounds: rounds,
          fixed: fixed,
          perLap: perLap,
          total: total,
        ));
      }

      // Sortierung: Startnummer (Nulls ans Ende)
      rows.sort((a, b) {
        final int an = a.startNumber ?? 1 << 30;
        final int bn = b.startNumber ?? 1 << 30;
        return an.compareTo(bn);
      });

      if (!mounted) return;
      setState(() {
        _rows = rows;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      // kein return im finally (Analyzer-Info vermeiden)
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  double get _sumFixed => _rows.fold(0.0, (p, r) => p + r.fixed);
  double get _sumPerLap => _rows.fold(0.0, (p, r) => p + r.perLap);
  int get _sumRounds => _rows.fold(0, (p, r) => p + r.rounds);
  double get _sumTotal => _rows.fold(0.0, (p, r) => p + r.total);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Abrechnung – Vorschau (nur Lesen)'),
        actions: [
          IconButton(
            tooltip: 'Aktualisieren',
            onPressed: _loading ? null : _loadWindowAndData,
            icon: _loading
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(child: Text('Fehler: $_error'));
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_rows.isEmpty) {
      return const Center(child: Text('Keine Daten gefunden.'));
    }

    final windowText = (_start != null || _end != null)
        ? 'Zeitraum: ${_start?.toLocal() ?? '…'} – ${_end?.toLocal() ?? '…'}'
        : 'Zeitraum: alle Daten';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Text(windowText, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: SingleChildScrollView(
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
                  return DataRow(
                    cells: [
                      DataCell(Text(r.startNumber?.toString() ?? '–')),
                      DataCell(Text(r.name.isEmpty ? r.runnerId : r.name)),
                      DataCell(Text('${r.rounds}')),
                      DataCell(Text(r.fixed.toStringAsFixed(2))),
                      DataCell(Text(r.perLap.toStringAsFixed(2))),
                      DataCell(Text(r.total.toStringAsFixed(2))),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(12.0),
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
    );
  }
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
