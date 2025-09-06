
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard
import 'package:intl/intl.dart';

import '../config/billing_config.dart';
import '../services/email_service.dart';

/// Option 2:
/// Kompakte Liste der Sponsoren. Tap auf eine Karte öffnet ein Modal (Bottom-Sheet)
/// mit vollständigen Details (CSV kopieren & E-Mail versenden).
class SponsorInvoicesPage extends StatefulWidget {
  static const routeName = '/sponsor_invoices';
  const SponsorInvoicesPage({super.key});

  @override
  State<SponsorInvoicesPage> createState() => _SponsorInvoicesPageState();
}

class _SponsorInvoicesPageState extends State<SponsorInvoicesPage> {
  final _currency = NumberFormat.currency(
    locale: 'de_CH',
    symbol: 'CHF',
    decimalDigits: 2,
  );

  bool _onlyWithEmail = true;
  bool _onlyWithPositiveTotal = true;
  bool _sendingAll = false;

  String? _status;
  Timer? _statusTimer;

  // Caches
  final Map<String, String> _runnerNameCache = {};
  final Map<String, int> _runnerLapsCache = {};
  final Map<int, String> _startNoToRunnerId = {}; // startNumber -> runnerId

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  void _flash(String msg) {
    setState(() => _status = msg);
    _statusTimer?.cancel();
    _statusTimer = Timer(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      setState(() => _status = null);
    });
  }

  // ---------- Feld-Helper (unterstützt verschachtelte Keys) ----------
  dynamic _getAtPath(Map<String, dynamic> m, String path) {
    dynamic cur = m;
    for (final part in path.split('.')) {
      if (cur is Map<String, dynamic> && cur.containsKey(part)) {
        cur = cur[part];
      } else {
        return null;
      }
    }
    return cur;
  }

  String _firstString(Map<String, dynamic> m, List<String> paths) {
    for (final p in paths) {
      final v = _getAtPath(m, p);
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return '';
  }

  num? _firstNum(Map<String, dynamic> m, List<String> paths) {
    for (final p in paths) {
      final v = _getAtPath(m, p);
      final n = _asNum(v);
      if (n != null) return n;
    }
    return null;
  }

  int? _firstInt(Map<String, dynamic> m, List<String> paths) {
    for (final p in paths) {
      final v = _getAtPath(m, p);
      final n = _asInt(v);
      if (n != null) return n;
    }
    return null;
  }

  num? _asNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    if (v is String) return num.tryParse(v.replaceAll(',', '.'));
    return null;
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  // ---------- Läufer-Infos ----------
  Future<String> _runnerName(String runnerId) async {
    if (runnerId.isEmpty) return '';
    if (_runnerNameCache.containsKey(runnerId)) return _runnerNameCache[runnerId]!;
    try {
      final d = await FirebaseFirestore.instance.collection('Laufer').doc(runnerId).get();
      final m = (d.data() ?? {}) as Map<String, dynamic>;
      final display = _firstString(m, ['displayName']);
      if (display.isNotEmpty) {
        _runnerNameCache[runnerId] = display;
        return display;
      }
      final fn = _firstString(m, ['firstName', 'vorname']);
      final ln = _firstString(m, ['lastName', 'nachname', 'name']);
      final nick = _firstString(m, ['nickname', 'spitzname']);
      final combo = [fn, ln].where((e) => e.isNotEmpty).join(' ').trim();
      final best = combo.isNotEmpty ? combo : nick;
      _runnerNameCache[runnerId] = best;
      return best;
    } catch (_) {
      return '';
    }
  }

  Future<String> _runnerIdFromStartNo(int startNo) async {
    if (startNo <= 0) return '';
    if (_startNoToRunnerId.containsKey(startNo)) return _startNoToRunnerId[startNo]!;
    try {
      final q = await FirebaseFirestore.instance
          .collection('Laufer')
          .where('startNumber', isEqualTo: startNo)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) {
        final id = q.docs.first.id;
        _startNoToRunnerId[startNo] = id;
        return id;
      }
    } catch (_) {}
    return '';
  }

  Future<int> _lapsByRunnerId(String runnerId) async {
    if (runnerId.isEmpty) return 0;

    final cached = _runnerLapsCache[runnerId];
    if (cached != null) return cached;

    // 1) Versuch: aus Läufer-Dokument lesen
    try {
      final d = await FirebaseFirestore.instance.collection('Laufer').doc(runnerId).get();
      final m = (d.data() ?? {}) as Map<String, dynamic>;
      final fromDoc = _firstInt(m, ['currentLaps', 'runden', 'laps']);
      if (fromDoc != null) {
        _runnerLapsCache[runnerId] = fromDoc;
        return fromDoc;
      }
    } catch (_) {}

    // 2) Fallback: Runden zählen nach runnerId
    try {
      final q = FirebaseFirestore.instance
          .collection('Runden')
          .where('runnerId', isEqualTo: runnerId);
      try {
        final agg = await q.count().get();
        final int c = (agg.count is int)
            ? (agg.count as int)
            : int.tryParse('${agg.count}') ?? 0;
        _runnerLapsCache[runnerId] = c;
        return c;
      } catch (_) {
        final snap = await q.get();
        final c = snap.size;
        _runnerLapsCache[runnerId] = c;
        return c;
      }
    } catch (_) {
      return 0;
    }
  }

  Future<int> _lapsByStartNo(int startNo) async {
    if (startNo <= 0) return 0;
    final rid = await _runnerIdFromStartNo(startNo);
    if (rid.isNotEmpty) return _lapsByRunnerId(rid);

    // Fallback: Runden nach startNumber zählen (falls so gespeichert wurde)
    try {
      final q = FirebaseFirestore.instance
          .collection('Runden')
          .where('startNumber', isEqualTo: startNo);
      try {
        final agg = await q.count().get();
        final int c = (agg.count is int)
            ? (agg.count as int)
            : int.tryParse('${agg.count}') ?? 0;
        return c;
      } catch (_) {
        final snap = await q.get();
        return snap.size;
      }
    } catch (_) {
      return 0;
    }
  }

  // ---------- Datenaufbereitung: Spenden gruppieren ----------
  Future<List<_SponsorGroup>> _loadGroups() async {
    final qs = await FirebaseFirestore.instance.collection('Spenden').get();

    final Map<String, _SponsorGroup> groups = {};

    for (final doc in qs.docs) {
      final m = (doc.data()) as Map<String, dynamic>;

      // Sponsor-E-Mail (viele Aliasse)
      final email = _firstString(m, [
        'sponsorEmail',
        'sponsor.email',
        'email',
        'sponsor_email',
        'sponsorEmailAddress',
      ]);
      if (email.isEmpty) continue;

      // Sponsor-Name (optional)
      final sponsorName = _firstString(m, [
        'sponsorName',
        'sponsor.name',
        'name',
        'sponsorNameDisplay',
      ]);

      // runnerId oder via Startnummer herleitbar
      String runnerId = _firstString(m, [
        'runnerId',
        'runnerID',
        'runnerUid',
        'uid',
        'userId',
        'runner.id'
      ]);
      final int? startNo = _firstInt(m, [
        'startNumber',
        'startnummer',
        'startNo',
        'nummer',
      ]);

      groups.putIfAbsent(email, () => _SponsorGroup(email: email, sponsorName: sponsorName));

      // Betragsfelder (viele Aliasse):
      final num fixed = _firstNum(m, [
            'fixedAmount',
            'betragFix',
            'fixed',
            'fixedCHF',
            'betrag_fix',
            'betragFixCHF',
            'fix',
            'fixAmount',
          ]) ?? 0;
      final num perLap = _firstNum(m, [
            'perLapAmount',
            'betragProRunde',
            'perLap',
            'amountPerRound',
            'amountPerLap',
            'betrag_pro_runde',
            'perLapCHF',
            'proRunde',
            'pro_runde',
            'pledgePerLap',
          ]) ?? 0;

      // Aggregierte Total-Felder (falls vorhanden)
      final num? aggregated = _firstNum(m, [
        'currentTotal',
        'current_total',
        'aggregates.total',
        'calc.total',
        'total',
        'totalCHF',
        'amountTotal',
        'sum',
      ]);

      // Läufe ermitteln, falls nötig
      int laps = 0;
      if (aggregated == null || aggregated <= 0) {
        if (perLap > 0) {
          if (runnerId.isEmpty && (startNo ?? 0) > 0) {
            runnerId = await _runnerIdFromStartNo(startNo!);
          }
          if (runnerId.isNotEmpty) {
            laps = await _lapsByRunnerId(runnerId);
          } else if ((startNo ?? 0) > 0) {
            laps = await _lapsByStartNo(startNo!);
          }
        }
      }

      final num totalForThisDonation =
          (aggregated != null && aggregated > 0) ? aggregated : (fixed + perLap * laps);

      groups[email]!.items.add(_SponsorItem(
        donationId: doc.id,
        runnerId: runnerId,
        startNumber: startNo,
        currentTotal: totalForThisDonation,
        perLap: perLap == 0 ? null : perLap,
        fixed: fixed == 0 ? null : fixed,
      ));
    }

    // Läufernamen & Summen
    for (final g in groups.values) {
      for (final it in g.items) {
        if (it.runnerId.isNotEmpty) {
          it.runnerName = await _runnerName(it.runnerId);
        } else if ((it.startNumber ?? 0) > 0) {
          final rid = await _runnerIdFromStartNo(it.startNumber!);
          it.runnerId = rid;
          it.runnerName = await _runnerName(rid);
        }
      }
      g.recalc();
    }

    // Filter
    final filtered = groups.values.where((g) {
      if (_onlyWithEmail && g.email.isEmpty) return false;
      if (_onlyWithPositiveTotal && g.total <= 0) return false;
      return true;
    }).toList();

    // sortieren
    filtered.sort((a, b) => a.email.toLowerCase().compareTo(b.email.toLowerCase()));
    return filtered;
  }

  // ---------- Versand ----------
  Future<void> _sendOne(_SponsorGroup g) async {
    if (g.email.isEmpty) {
      _flash('Kein Empfänger vorhanden.');
      return;
    }
    if (g.total <= 0) {
      _flash('Total = 0 – nichts zu versenden.');
      return;
    }
    final html = _buildInvoiceHtml(g);
    final subject = '${BillingConfig.paymentRefPrefix} – Rechnung ${_currency.format(g.total)}';
    try {
      await EmailService.queueEmail(to: g.email, subject: subject, html: html);
      _flash(BillingConfig.testMode
          ? 'Test-E-Mail an ${BillingConfig.testRecipient} in Warteschlange.'
          : 'E-Mail an ${g.email} in Warteschlange.');
    } catch (e) {
      _flash('Fehler beim Versand: $e');
    }
  }

  Future<void> _sendAll(List<_SponsorGroup> groups) async {
    setState(() => _sendingAll = true);
    int ok = 0, skipped = 0, fail = 0;
    for (final g in groups) {
      if (g.email.isEmpty || g.total <= 0) {
        skipped++;
        continue;
      }
      try {
        final html = _buildInvoiceHtml(g);
        final subject =
            '${BillingConfig.paymentRefPrefix} – Rechnung ${_currency.format(g.total)}';
        await EmailService.queueEmail(to: g.email, subject: subject, html: html);
        ok++;
      } catch (_) {
        fail++;
      }
    }
    setState(() => _sendingAll = false);
    _flash('Senden: $ok ok, $skipped übersprungen, $fail Fehler'
        '${BillingConfig.testMode ? ' (TESTMODUS)' : ''}.');
  }

  // ---------- HTML ----------
  String _buildInvoiceHtml(_SponsorGroup g) {
    final rows = StringBuffer();
    for (final it in g.items) {
      rows.writeln('''
        <tr>
          <td style="padding:6px 8px;border-bottom:1px solid #eee;">${_esc(it.runnerName)}</td>
          <td style="padding:6px 8px;border-bottom:1px solid #eee;color:#555;">${_esc(_lineDetail(it))}</td>
          <td style="padding:6px 8px;border-bottom:1px solid #eee;text-align:right;">${_currency.format(it.currentTotal)}</td>
        </tr>
      ''');
    }

    final totalRow = '''
      <tr>
        <td colspan="2" style="padding:10px 8px;font-weight:700;text-align:right;">Total</td>
        <td style="padding:10px 8px;font-weight:700;text-align:right;">${_currency.format(g.total)}</td>
      </tr>
    ''';

    final org = _esc(BillingConfig.orgName);
    final iban = _esc(BillingConfig.iban);
    final ref = _esc(
        '${BillingConfig.paymentRefPrefix} – ${DateFormat('yyyy').format(DateTime.now())}');
    final infoContact = (BillingConfig.contactEmail.isNotEmpty)
        ? '<p style="color:#666;">Fragen? Kontakt: ${_esc(BillingConfig.contactEmail)}</p>'
        : '';

    return '''
<!doctype html>
<html>
  <body style="font-family:Arial,sans-serif; color:#222; line-height:1.5;">
    <h2 style="margin:0 0 12px 0;">Sponsorenlauf – Rechnung</h2>
    <p>Guten Tag</p>
    <p>Vielen Dank für Ihre Unterstützung! Nachfolgend die Übersicht Ihrer Zusage(n):</p>

    <table cellspacing="0" cellpadding="0" style="border-collapse:collapse; width:100%; max-width:720px;">
      <thead>
        <tr>
          <th align="left" style="padding:6px 8px;border-bottom:2px solid #444;">Läufer</th>
          <th align="left" style="padding:6px 8px;border-bottom:2px solid #444;">Details</th>
          <th align="right" style="padding:6px 8px;border-bottom:2px solid #444;">Betrag</th>
        </tr>
      </thead>
      <tbody>
        $rows
        $totalRow
      </tbody>
    </table>

    <h3 style="margin-top:18px;">Zahlungsinformationen</h3>
    <p>
      Empfänger: <b>$org</b><br>
      IBAN: <b>$iban</b><br>
      Zahlungszweck/Referenz: <b>$ref</b>
    </p>

    $infoContact
    <p>Freundliche Grüsse<br>$org</p>

    ${BillingConfig.testMode ? '<p style="color:#d35400"><b>[TESTMODUS]</b> Diese E-Mail ging an die Testadresse.</p>' : ''}
  </body>
</html>
''';
  }

  String _lineDetail(_SponsorItem it) {
    final parts = <String>[];
    if ((it.fixed ?? 0) > 0) parts.add('Fixbetrag');
    if ((it.perLap ?? 0) > 0) parts.add('Pro Runde');
    return parts.isEmpty ? '' : parts.join(' + ');
  }

  String _esc(String s) =>
      s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final bannerTest = BillingConfig.testMode
        ? Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.6)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('[TESTMODUS] Mails werden an testRecipient geleitet.',
                style: TextStyle(color: Colors.deepOrange)),
          )
        : const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sponsor-Abrechnung & E-Mail'),
      ),
      backgroundColor: Colors.grey.shade100,
      body: FutureBuilder<List<_SponsorGroup>>(
        future: _loadGroups(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Fehler: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final groups = snap.data!;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  bannerTest,
                  if (bannerTest is! SizedBox) const SizedBox(height: 12),

                  // Filter + Aktionen
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _BoolChip(
                        label: 'Nur mit E-Mail',
                        value: _onlyWithEmail,
                        onChanged: (v) => setState(() => _onlyWithEmail = v),
                      ),
                      _BoolChip(
                        label: 'Nur Total > 0',
                        value: _onlyWithPositiveTotal,
                        onChanged: (v) => setState(() => _onlyWithPositiveTotal = v),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _sendingAll
                            ? null
                            : () async {
                                final g = await _loadGroups();
                                await _sendAll(g);
                              },
                        icon: const Icon(Icons.send),
                        label: Text(_sendingAll ? 'Senden…' : 'Alle senden (gefiltert)'),
                      ),
                    ],
                  ),

                  if (_status != null) ...[
                    const SizedBox(height: 10),
                    Text(_status!, style: const TextStyle(color: Colors.black54)),
                  ],
                  const SizedBox(height: 12),

                  if (groups.isEmpty)
                    const Text('Keine Daten für die aktuellen Filter.'),
                  for (final g in groups) _groupCard(context, g),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _groupCard(BuildContext context, _SponsorGroup g) {
    // maximal 2 Vorschau-Zeilen
    final preview = g.items.take(2).toList();
    final more = g.items.length - preview.length;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: InkWell(
        onTap: () => _openDetailSheet(context, g),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          g.sponsorName.isNotEmpty ? g.sponsorName : g.email,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        if (g.sponsorName.isNotEmpty)
                          Text(g.email, style: const TextStyle(color: Colors.black54)),
                      ],
                    ),
                  ),
                  Text(_currency.format(g.total),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  const Icon(Icons.expand_more),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),

              // Kurzvorschau
              Column(
                children: [
                  for (final it in preview)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: Row(
                        children: [
                          Expanded(child: Text(it.runnerName.isEmpty ? '(ohne Name)' : it.runnerName)),
                          Expanded(child: Text(_lineDetail(it), style: const TextStyle(color: Colors.black54))),
                          Text(_currency.format(it.currentTotal)),
                        ],
                      ),
                    ),
                  if (more > 0)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('…und $more weitere',
                          style: const TextStyle(color: Colors.black54)),
                    ),
                ],
              ),

              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () => _sendOne(g),
                  icon: const Icon(Icons.email_outlined),
                  label: const Text('E-Mail an Sponsor'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDetailSheet(BuildContext context, _SponsorGroup g) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final rows = g.items
            .map((it) => [
                  it.runnerName,
                  _lineDetail(it),
                  _currency.format(it.currentTotal),
                ])
            .toList();

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.93,
          builder: (_, controller) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                g.sponsorName.isNotEmpty ? g.sponsorName : g.email,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                              ),
                              if (g.sponsorName.isNotEmpty)
                                Text(g.email, style: const TextStyle(color: Colors.black54)),
                            ],
                          ),
                        ),
                        Text(_currency.format(g.total),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            final csv = _toCsv(rows, header: ['Läufer', 'Details', 'Betrag (CHF)']);
                            await Clipboard.setData(ClipboardData(text: csv));
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('CSV in die Zwischenablage kopiert.')),
                              );
                            }
                          },
                          icon: const Icon(Icons.copy_all),
                          label: const Text('CSV kopieren'),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _sendOne(g),
                          icon: const Icon(Icons.email_outlined),
                          label: const Text('E-Mail an Sponsor'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(),

                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(2),
                        1: FlexColumnWidth(2),
                        2: IntrinsicColumnWidth(),
                      },
                      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                      children: [
                        const TableRow(
                          children: [
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text('Läufer', style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text('Details', style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text('Betrag', style: TextStyle(fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                        ),
                        for (final it in g.items)
                          TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(it.runnerName),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(_lineDetail(it), style: const TextStyle(color: Colors.black54)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(_currency.format(it.currentTotal)),
                                ),
                              ),
                            ],
                          ),
                        TableRow(
                          children: [
                            const SizedBox(),
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text('Total', style: TextStyle(fontWeight: FontWeight.w700)),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  _currency.format(g.total),
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _toCsv(List<List<String>> rows, {List<String>? header}) {
    final buf = StringBuffer();
    if (header != null) buf.writeln(header.map(_csvCell).join(';'));
    for (final r in rows) {
      buf.writeln(r.map(_csvCell).join(';'));
    }
    return buf.toString();
  }

  String _csvCell(String s) {
    final needQuote = s.contains(';') || s.contains('"') || s.contains('\n');
    var t = s.replaceAll('"', '""');
    if (needQuote) t = '"$t"';
    return t;
  }
}

// ---------- kleine UI-Helfer ----------
class _BoolChip extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _BoolChip({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: value,
      onSelected: (v) => onChanged(v),
    );
  }
}

// ---------- Modelle ----------
class _SponsorItem {
  final String donationId;
  String runnerId;
  final int? startNumber;
  final num currentTotal;
  final num? perLap;
  final num? fixed;
  String runnerName = '';

  _SponsorItem({
    required this.donationId,
    required this.runnerId,
    required this.startNumber,
    required this.currentTotal,
    this.perLap,
    this.fixed,
  });
}

class _SponsorGroup {
  final String email;
  final String sponsorName;
  final List<_SponsorItem> items = [];
  num total = 0;

  _SponsorGroup({required this.email, required this.sponsorName});

  void recalc() {
    total = 0;
    for (final it in items) {
      total += it.currentTotal;
    }
  }
}
