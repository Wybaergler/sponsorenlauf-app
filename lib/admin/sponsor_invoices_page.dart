import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/billing_config.dart';
import '../services/email_service.dart';

class SponsorInvoicesPage extends StatefulWidget {
  static const routeName = '/sponsor_invoices';
  const SponsorInvoicesPage({super.key});

  @override
  State<SponsorInvoicesPage> createState() => _SponsorInvoicesPageState();
}

class _SponsorInvoicesPageState extends State<SponsorInvoicesPage> {
  final _currency = NumberFormat.currency(locale: 'de_CH', symbol: 'CHF', decimalDigits: 2);

  bool _onlyWithEmail = true;
  bool _onlyWithPositiveTotal = true;
  bool _sendingAll = false;
  String? _status;
  Timer? _statusTimer;

  // Läufernamen-Cache
  final Map<String, String> _runnerNameCache = {};

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

  Future<String> _runnerName(String runnerId) async {
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
      final combo = [fn, ln].where((x) => x.isNotEmpty).join(' ');
      final nick = (m['nickname'] ?? m['spitzname'] ?? '').toString().trim();
      final best = combo.isNotEmpty ? combo : nick;
      _runnerNameCache[runnerId] = best;
      return best;
    } catch (_) {
      return '';
    }
  }

  // === Datenmodell ===
  Future<List<_SponsorGroup>> _loadGroups() async {
    final qs = await FirebaseFirestore.instance
        .collection('Spenden')
        .where('sponsorEmail', isGreaterThan: '') // nur solche mit irgendeiner Email
        .get();

    // Gruppieren nach Sponsor-Email
    final Map<String, _SponsorGroup> groups = {};
    for (final doc in qs.docs) {
      final m = doc.data();
      final email = (m['sponsorEmail'] ?? '').toString().trim();
      if (email.isEmpty) continue;

      final sponsorName = (m['sponsorName'] ?? m['name'] ?? '').toString().trim();

      groups.putIfAbsent(email, () => _SponsorGroup(email: email, sponsorName: sponsorName));

      // Betrag ermitteln
      final num? currentTotal = _asNum(m['currentTotal']); // bevorzugt Aggregation
      num itemTotal = currentTotal ?? 0;

      // Fallbacks, falls currentTotal fehlt:
      if (itemTotal == 0) {
        final num? fixed = _asNum(m['fixedAmount']) ?? _asNum(m['betragFix']);
        final num? perLap = _asNum(m['perLapAmount']) ?? _asNum(m['betragProRunde']);
        final int? laps = _asInt(m['currentLaps']) ?? _asInt(m['runden']);

        if (fixed != null && fixed > 0) {
          itemTotal = fixed;
        } else if (perLap != null && perLap > 0 && laps != null && laps >= 0) {
          itemTotal = perLap * laps;
        }
      }

      final runnerId = (m['runnerId'] ?? '').toString();

      groups[email]!.items.add(_SponsorItem(
        donationId: doc.id,
        runnerId: runnerId,
        currentTotal: itemTotal,
        perLap: _asNum(m['perLapAmount']) ?? _asNum(m['betragProRunde']),
        fixed: _asNum(m['fixedAmount']) ?? _asNum(m['betragFix']),
        laps: _asInt(m['currentLaps']) ?? _asInt(m['runden']),
      ));
    }

    // Läufernamen anreichern + Gesamttotal
    for (final g in groups.values) {
      for (final it in g.items) {
        it.runnerName = it.runnerId.isEmpty ? '' : await _runnerName(it.runnerId);
      }
      g.recalc();
    }

    // Filter anwenden
    final filtered = groups.values.where((g) {
      if (_onlyWithEmail && g.email.isEmpty) return false;
      if (_onlyWithPositiveTotal && g.total <= 0) return false;
      return true;
    }).toList();

    // sortieren nach Sponsor
    filtered.sort((a, b) => a.email.toLowerCase().compareTo(b.email.toLowerCase()));
    return filtered;
  }

  // === Versand ===
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
      await EmailService.queueEmail(
        to: g.email,
        subject: subject,
        html: html,
        // bcc kommt automatisch über EmailService/BillingConfig (falls gesetzt)
      );
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
        final subject = '${BillingConfig.paymentRefPrefix} – Rechnung ${_currency.format(g.total)}';
        await EmailService.queueEmail(to: g.email, subject: subject, html: html);
        ok++;
      } catch (_) {
        fail++;
      }
    }

    setState(() => _sendingAll = false);
    _flash('Senden abgeschlossen: $ok ok, $skipped übersprungen, $fail Fehler'
        '${BillingConfig.testMode ? ' (TESTMODUS aktiv)' : ''}.');
  }

  // === HTML-Template ===
  String _buildInvoiceHtml(_SponsorGroup g) {
    final rows = StringBuffer();
    for (final it in g.items) {
      final detail = _lineDetail(it);
      rows.writeln('''
        <tr>
          <td style="padding:6px 8px;border-bottom:1px solid #eee;">${_escape(it.runnerName)}</td>
          <td style="padding:6px 8px;border-bottom:1px solid #eee;color:#555;">${_escape(detail)}</td>
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

    final org = _escape(BillingConfig.orgName);
    final iban = _escape(BillingConfig.iban);
    final ref = _escape('${BillingConfig.paymentRefPrefix} – ${DateFormat('yyyy').format(DateTime.now())}');
    final infoContact = (BillingConfig.contactEmail.isNotEmpty)
        ? '<p style="color:#666;">Fragen? Kontakt: ${_escape(BillingConfig.contactEmail)}</p>'
        : '';

    // Sehr schlichtes, kompatibles HTML (Mail-Clients)
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
    // Human readable Positions-Text
    if ((it.fixed ?? 0) > 0) {
      return 'Fixbetrag';
    }
    if ((it.perLap ?? 0) > 0) {
      final l = it.laps;
      if (l != null) {
        return 'Pro Runde × $l';
      }
      return 'Pro Runde';
    }
    return '';
  }

  String _escape(String s) =>
      s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

  // === UI ===
  @override
  Widget build(BuildContext context) {
    final bannerTest = BillingConfig.testMode
        ? Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.12),
        border: Border.all(color: Colors.orange.withOpacity(0.6)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text('[TESTMODUS] Mails werden an testRecipient geleitet.',
          style: TextStyle(color: Colors.deepOrange)),
    )
        : const SizedBox.shrink();

    final controls = Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilterChip(
          label: const Text('Nur mit E-Mail'),
          selected: _onlyWithEmail,
          onSelected: (v) => setState(() => _onlyWithEmail = v),
        ),
        FilterChip(
          label: const Text('Nur Total > 0'),
          selected: _onlyWithPositiveTotal,
          onSelected: (v) => setState(() => _onlyWithPositiveTotal = v),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _sendingAll ? null : () async {
            final groups = await _loadGroups();
            await _sendAll(groups);
          },
          icon: const Icon(Icons.send),
          label: Text(_sendingAll ? 'Senden…' : 'Alle senden (gefiltert)'),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Sponsor-Abrechnung & E-Mail')),
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
                  controls,
                  if (_status != null) ...[
                    const SizedBox(height: 10),
                    Text(_status!, style: const TextStyle(color: Colors.black54)),
                  ],
                  const SizedBox(height: 12),
                  if (groups.isEmpty)
                    const Text('Keine Daten für die aktuellen Filter.'),
                  for (final g in groups) _groupCard(g),
                ],
              ),
            ),
          );
        },
      ),
      backgroundColor: Colors.grey.shade100,
    );
  }

  Widget _groupCard(_SponsorGroup g) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
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
                      Text(g.sponsorName.isNotEmpty ? g.sponsorName : g.email,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      if (g.sponsorName.isNotEmpty)
                        Text(g.email, style: const TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
                Text(_currency.format(g.total),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            // Tabelle
            _itemsTable(g),
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
    );
  }

  Widget _itemsTable(_SponsorGroup g) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(2),
        2: IntrinsicColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        const TableRow(
          decoration: BoxDecoration(),
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
            decoration: const BoxDecoration(),
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
    );
  }
}

// ===== Helpers / Modelle =====

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

class _SponsorItem {
  final String donationId;
  final String runnerId;
  final num currentTotal;
  final num? perLap;
  final num? fixed;
  final int? laps;

  String runnerName = '';

  _SponsorItem({
    required this.donationId,
    required this.runnerId,
    required this.currentTotal,
    this.perLap,
    this.fixed,
    this.laps,
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
