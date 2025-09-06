import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard
import 'package:intl/intl.dart';

import 'package:sponsorenlauf_app/config/billing_config.dart';
import 'package:sponsorenlauf_app/services/email_service.dart';

/// Sponsor-Abrechnung & E-Mail
/// - Aggregation nach normalisierter E-Mail
/// - Inline-Expand via ExpansionTile (robust)
/// - Per-Lap-Details: "x Runden à CHF y.yy" in UI und E-Mail
class SponsorInvoicesPage extends StatefulWidget {
  static const routeName = '/sponsor_invoices';
  const SponsorInvoicesPage({super.key});

  @override
  State<SponsorInvoicesPage> createState() => _SponsorInvoicesPageState();
}

class _SponsorInvoicesPageState extends State<SponsorInvoicesPage> {
  final _currency =
  NumberFormat.currency(locale: 'de_CH', symbol: 'CHF', decimalDigits: 2);

  bool _onlyWithEmail = true;
  bool _onlyWithPositiveTotal = true;
  bool _sendingAll = false;

  String? _status;
  Timer? _statusTimer;

  Future<List<_SponsorGroup>>? _groupsFuture;

  // Caches
  final Map<String, String> _runnerNameCache = {};
  final Map<String, int> _runnerLapsCache = {};
  final Map<int, String> _startNoToRunnerId = {};

  @override
  void initState() {
    super.initState();
    _groupsFuture = _loadGroups();
  }

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

  void _refresh() {
    setState(() {
      _groupsFuture = _loadGroups();
    });
  }

  // ---------- E-Mail-Normalisierung ----------
  String _normalizeEmail(String raw) {
    var s = raw.trim();
    final m = RegExp(r'<\s*([^>]+)\s*>').firstMatch(s);
    if (m != null) s = m.group(1) ?? s;
    s = s.toLowerCase();

    final at = s.indexOf('@');
    if (at <= 0) return s;

    var local = s.substring(0, at);
    final domain = s.substring(at + 1);

    if (domain == 'gmail.com' || domain == 'googlemail.com') {
      final plus = local.indexOf('+');
      if (plus >= 0) local = local.substring(0, plus);
      local = local.replaceAll('.', '');
    }
    local = local.replaceAll(RegExp(r'\s+'), '');

    return '$local@$domain';
  }

  // ---------- Feld-Helper ----------
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
      if (v is num) return v;
      if (v is String) {
        final n = num.tryParse(v.replaceAll(',', '.'));
        if (n != null) return n;
      }
    }
    return null;
  }

  int? _firstInt(Map<String, dynamic> m, List<String> paths) {
    for (final p in paths) {
      final v = _getAtPath(m, p);
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) {
        final n = int.tryParse(v);
        if (n != null) return n;
      }
    }
    return null;
  }

  // ---------- Läufer-Infos ----------
  Future<String> _runnerName(String runnerId) async {
    if (runnerId.isEmpty) return '';
    final cached = _runnerNameCache[runnerId];
    if (cached != null) return cached;
    try {
      final d = await FirebaseFirestore.instance
          .collection('Laufer')
          .doc(runnerId)
          .get();
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
    final cached = _startNoToRunnerId[startNo];
    if (cached != null) return cached;

    try {
      var q = await FirebaseFirestore.instance
          .collection('Laufer')
          .where('startNumber', isEqualTo: startNo)
          .limit(1)
          .get();
      if (q.docs.isEmpty) {
        q = await FirebaseFirestore.instance
            .collection('Laufer')
            .where('startnummer', isEqualTo: startNo)
            .limit(1)
            .get();
      }
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

    // 1) currentLaps/runden/laps aus Läufer-Dokument
    try {
      final d = await FirebaseFirestore.instance
          .collection('Laufer')
          .doc(runnerId)
          .get();
      final m = (d.data() ?? {}) as Map<String, dynamic>;
      final fromDoc = _firstInt(m, ['currentLaps', 'runden', 'laps']);
      if (fromDoc != null) {
        _runnerLapsCache[runnerId] = fromDoc;
        return fromDoc;
      }
    } catch (_) {}

    // 2) Fallback: Runden zählen
    try {
      final q = FirebaseFirestore.instance
          .collection('Runden')
          .where('runnerId', isEqualTo: runnerId);
      try {
        final agg = await q.count().get();
        final c = (agg.count is int)
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

    try {
      final q = FirebaseFirestore.instance
          .collection('Runden')
          .where('startNumber', isEqualTo: startNo);
      try {
        final agg = await q.count().get();
        return (agg.count is int)
            ? (agg.count as int)
            : int.tryParse('${agg.count}') ?? 0;
      } catch (_) {
        final snap = await q.get();
        return snap.size;
      }
    } catch (_) {
      return 0;
    }
  }

  // ---------- Datenaufbereitung ----------
  Future<List<_SponsorGroup>> _loadGroups() async {
    final qs = await FirebaseFirestore.instance.collection('Spenden').get();
    final Map<String, _SponsorGroup> groups = {};

    for (final doc in qs.docs) {
      final m = (doc.data()) as Map<String, dynamic>;

      final rawEmail = _firstString(m, [
        'sponsorEmail','sponsor.email','email','sponsor_email','sponsorEmailAddress','kontakt.email',
      ]);
      final normEmail = _normalizeEmail(rawEmail);
      if (normEmail.isEmpty || !normEmail.contains('@')) {
        continue;
      }

      final sponsorName = _firstString(m, [
        'sponsorName','sponsor.name','name','sponsorNameDisplay','kontakt.name',
      ]);

      String runnerId = _firstString(m, [
        'runnerId','runnerID','runnerUid','uid','userId','runner.id'
      ]);
      final int? startNo = _firstInt(m, [
        'startNumber','startnummer','startNo','nummer','runner.startNumber','runner.startnummer',
      ]);

      groups.putIfAbsent(
        normEmail,
            () => _SponsorGroup(
          key: normEmail,
          emailDisplay: rawEmail.trim(),
          sponsorName: sponsorName,
        ),
      );
      if (groups[normEmail]!.sponsorName.isEmpty && sponsorName.isNotEmpty) {
        groups[normEmail]!.sponsorName = sponsorName;
      }

      num fixed = _firstNum(m, [
        'fixedAmount','betragFix','fixed','fixedCHF','betrag_fix','betragFixCHF','fix','fixAmount','pledge.fixed',
      ]) ?? 0;
      num perLap = _firstNum(m, [
        'perLapAmount','betragProRunde','perLap','amountPerRound','amountPerLap','betrag_pro_runde','perLapCHF','proRunde','pro_runde','pledgePerLap','pledge.perLap',
      ]) ?? 0;

      final sponsoringType = _firstString(m, ['sponsoringType']);
      final num? sponsoringAmount = _firstNum(m, ['amount']);
      if (sponsoringAmount != null && sponsoringType.isNotEmpty) {
        if (sponsoringType.toLowerCase() == 'perlap' && perLap == 0) perLap = sponsoringAmount;
        if ((sponsoringType.toLowerCase() == 'fixed' || sponsoringType.toLowerCase() == 'fix') && fixed == 0) fixed = sponsoringAmount;
      }

      final num? aggregated = _firstNum(m, [
        'currentTotal','current_total','aggregates.total','calc.total','total','totalCHF','amountTotal','sum',
      ]);

      int laps = 0;
      if ((aggregated == null || aggregated <= 0) && perLap > 0) {
        if (runnerId.isEmpty && (startNo ?? 0) > 0) {
          runnerId = await _runnerIdFromStartNo(startNo!);
        }
        if (runnerId.isNotEmpty) {
          laps = await _lapsByRunnerId(runnerId);
        } else if ((startNo ?? 0) > 0) {
          laps = await _lapsByStartNo(startNo!);
        }
      }

      final num total =
      (aggregated != null && aggregated > 0) ? aggregated : (fixed + perLap * laps);

      groups[normEmail]!.items.add(_SponsorItem(
        donationId: doc.id,
        runnerId: runnerId,
        startNumber: startNo,
        currentTotal: total,
        perLap: perLap == 0 ? null : perLap,
        fixed: fixed == 0 ? null : fixed,
        laps: laps > 0 ? laps : null,
      ));
    }

    // Namen nachladen + Gruppentotal berechnen
    for (final g in groups.values) {
      for (final it in g.items) {
        if (it.runnerId.isNotEmpty) {
          it.runnerName = await _runnerName(it.runnerId);
          if (it.laps == null) {
            final l = await _lapsByRunnerId(it.runnerId);
            if (l > 0) it.laps = l;
          }
        } else if ((it.startNumber ?? 0) > 0) {
          final rid = await _runnerIdFromStartNo(it.startNumber!);
          it.runnerId = rid;
          it.runnerName = await _runnerName(rid);
          if (it.laps == null) {
            final l = await _lapsByStartNo(it.startNumber!);
            if (l > 0) it.laps = l;
          }
        }
      }
      g.recalc();
    }

    final filtered = groups.values.where((g) {
      if (_onlyWithEmail && g.emailDisplay.trim().isEmpty) return false;
      if (_onlyWithPositiveTotal && g.total <= 0) return false;
      return true;
    }).toList();

    filtered.sort((a, b) => a.key.compareTo(b.key));
    return filtered;
  }

  // ---------- Versand ----------
  Future<void> _sendOne(_SponsorGroup g) async {
    final email = g.emailDisplay.trim();
    if (email.isEmpty) {
      _flash('Kein Empfänger vorhanden.');
      return;
    }
    if (g.total <= 0) {
      _flash('Total = 0 – nichts zu versenden.');
      return;
    }
    final html = _buildInvoiceHtml(g);
    final subject =
        '${BillingConfig.paymentRefPrefix} – Rechnung ${_currency.format(g.total)}';
    try {
      await EmailService.queueEmail(to: email, subject: subject, html: html);
      _flash(BillingConfig.testMode
          ? 'Test-E-Mail an ${BillingConfig.testRecipient} in Warteschlange.'
          : 'E-Mail an $email in Warteschlange.');
    } catch (e) {
      _flash('Fehler beim Versand: $e');
    }
  }

  Future<void> _sendAllFromCache() async {
    try {
      final groups = await (_groupsFuture ?? _loadGroups());
      await _sendAll(groups);
    } catch (e) {
      _flash('Fehler beim Laden/Senden: $e');
    }
  }

  Future<void> _sendAll(List<_SponsorGroup> groups) async {
    setState(() => _sendingAll = true);
    int ok = 0, skipped = 0, fail = 0;
    for (final g in groups) {
      final email = g.emailDisplay.trim();
      if (email.isEmpty || g.total <= 0) {
        skipped++;
        continue;
      }
      try {
        final html = _buildInvoiceHtml(g);
        final subject =
            '${BillingConfig.paymentRefPrefix} – Rechnung ${_currency.format(g.total)}';
        await EmailService.queueEmail(to: email, subject: subject, html: html);
        ok++;
      } catch (_) {
        fail++;
      }
    }
    setState(() => _sendingAll = false);
    _flash(
        'Senden: $ok ok, $skipped übersprungen, $fail Fehler${BillingConfig.testMode ? ' (TESTMODUS)' : ''}.');
  }

  // ---------- HTML ----------
  String _buildInvoiceHtml(_SponsorGroup g) {
    final rows = StringBuffer();
    for (final it in g.items) {
      rows.writeln('<tr>'
          '<td style="padding:6px 8px;border-bottom:1px solid #eee;">${_esc(it.runnerName)}</td>'
          '<td style="padding:6px 8px;border-bottom:1px solid #eee;color:#555;">${_esc(_lineDetail(it, withAmounts: true))}</td>'
          '<td style="padding:6px 8px;border-bottom:1px solid #eee;text-align:right;">${_currency.format(it.currentTotal)}</td>'
          '</tr>');
    }

    final totalRow = '<tr>'
        '<td colspan="2" style="padding:10px 8px;font-weight:700;text-align:right;">Total</td>'
        '<td style="padding:10px 8px;font-weight:700;text-align:right;">${_currency.format(g.total)}</td>'
        '</tr>';

    final org = _esc(BillingConfig.orgName);
    final iban = _esc(BillingConfig.iban);
    final ref = _esc(
        '${BillingConfig.paymentRefPrefix} – ${DateFormat('yyyy').format(DateTime.now())}');
    final infoContact = (BillingConfig.contactEmail.isNotEmpty)
        ? '<p style="color:#666;">Fragen? Kontakt: ${_esc(BillingConfig.contactEmail)}</p>'
        : '';

    return '<!doctype html><html><body style="font-family:Arial,sans-serif; color:#222; line-height:1.5;">'
        '<h2 style="margin:0 0 12px 0;">Sponsorenlauf – Rechnung</h2>'
        '<p>Guten Tag</p>'
        '<p>Vielen Dank für Ihre Unterstützung! Nachfolgend die Übersicht Ihrer Zusage(n):</p>'
        '<table cellspacing="0" cellpadding="0" style="border-collapse:collapse; width:100%; max-width:720px;">'
        '<thead><tr>'
        '<th align="left" style="padding:6px 8px;border-bottom:2px solid #444;">Läufer</th>'
        '<th align="left" style="padding:6px 8px;border-bottom:2px solid #444;">Details</th>'
        '<th align="right" style="padding:6px 8px;border-bottom:2px solid #444;">Betrag</th>'
        '</tr></thead><tbody>'
        '${rows.toString()}$totalRow'
        '</tbody></table>'
        '<h3 style="margin-top:18px;">Zahlungsinformationen</h3>'
        '<p>Empfänger: <b>$org</b><br>IBAN: <b>$iban</b><br>Zahlungszweck/Referenz: <b>$ref</b></p>'
        '$infoContact'
        '<p>Freundliche Grüsse<br>$org</p>'
        '${BillingConfig.testMode ? '<p style="color:#d35400"><b>[TESTMODUS]</b> Diese E-Mail ging an die Testadresse.</p>' : ''}'
        '</body></html>';
  }

  String _lineDetail(_SponsorItem it, {bool withAmounts = false}) {
    final parts = <String>[];
    if ((it.fixed ?? 0) > 0) {
      parts.add(withAmounts
          ? 'Fixbetrag ${_currency.format(it.fixed!)}'
          : 'Fixbetrag');
    }
    if ((it.perLap ?? 0) > 0) {
      final lapStr = (it.laps ?? 0) > 0 ? '${it.laps} Runden' : 'Pro Runde';
      final perLapStr = withAmounts ? 'à ${_currency.format(it.perLap!)}' : '';
      parts.add([lapStr, perLapStr].where((s) => s.isNotEmpty).join(' '));
    }
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
        color: const Color.fromRGBO(255, 152, 0, 0.12),
        border: Border.all(color: const Color.fromRGBO(255, 152, 0, 0.6)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text('[TESTMODUS] Mails werden an testRecipient geleitet.',
          style: TextStyle(color: Colors.deepOrange)),
    )
        : const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sponsor-Abrechnung & E-Mail'),
        actions: [
          IconButton(onPressed: _refresh, tooltip: 'Neu laden', icon: const Icon(Icons.refresh)),
        ],
      ),
      backgroundColor: Colors.grey.shade100,
      body: FutureBuilder<List<_SponsorGroup>>(
        future: _groupsFuture,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Fehler: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final groups = snap.data!;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  bannerTest,
                  if (bannerTest is! SizedBox) const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _BoolChip(
                        label: 'Nur mit E-Mail',
                        value: _onlyWithEmail,
                        onChanged: (v) {
                          _onlyWithEmail = v;
                          _refresh();
                        },
                      ),
                      _BoolChip(
                        label: 'Nur Total > 0',
                        value: _onlyWithPositiveTotal,
                        onChanged: (v) {
                          _onlyWithPositiveTotal = v;
                          _refresh();
                        },
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _sendingAll ? null : _sendAllFromCache,
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

                  if (groups.isEmpty) const Text('Keine Daten für die aktuellen Filter.'),
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
    final titleText = g.sponsorName.isNotEmpty ? g.sponsorName : g.emailDisplay;
    final subtitleText = g.sponsorName.isNotEmpty ? g.emailDisplay : null;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titleText,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  if (subtitleText != null)
                    Text(subtitleText, style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
            Text(_currency.format(g.total), style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  final rows = g.items
                      .map((it) => [
                    it.runnerName,
                    _lineDetail(it, withAmounts: true),
                    _currency.format(it.currentTotal),
                  ])
                      .toList();
                  final csv = _toCsv(rows, header: const ['Läufer', 'Details', 'Betrag (CHF)']);
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
                      child:
                      Text(it.runnerName.isEmpty ? '(ohne Name)' : it.runnerName),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(_lineDetail(it, withAmounts: true),
                          style: const TextStyle(color: Colors.black54)),
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
                      child: Text(_currency.format(g.total),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
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
  const _BoolChip(
      {required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: value,
      onSelected: onChanged,
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
  int? laps; // für "x Runden"
  String runnerName = '';

  _SponsorItem({
    required this.donationId,
    required this.runnerId,
    required this.startNumber,
    required this.currentTotal,
    this.perLap,
    this.fixed,
    this.laps,
  });
}

class _SponsorGroup {
  final String key; // normalized email
  final String emailDisplay; // original
  String sponsorName;
  final List<_SponsorItem> items = [];
  num total = 0;

  _SponsorGroup({
    required this.key,
    required this.emailDisplay,
    required this.sponsorName,
  });

  void recalc() {
    total = 0;
    for (final it in items) {
      total += it.currentTotal;
    }
  }
}