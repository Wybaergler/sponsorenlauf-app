import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/billing_config.dart';
import '../services/email_service.dart';

class EmailTestPage extends StatefulWidget {
  static const routeName = '/email_test';
  const EmailTestPage({super.key});

  @override
  State<EmailTestPage> createState() => _EmailTestPageState();
}

class _EmailTestPageState extends State<EmailTestPage> {
  final _toCtrl = TextEditingController(text: BillingConfig.testRecipient);
  final _subjectCtrl = TextEditingController(
    text: '${BillingConfig.paymentRefPrefix} – Test',
  );
  final _bodyCtrl = TextEditingController(
    text: '''
<p>Hallo 👋</p>
<p>Dies ist ein <b>Test</b> für den Rechnungsversand über Firebase (mail-Collection).</p>
<p>Organisation: ${BillingConfig.orgName}<br>
IBAN: ${BillingConfig.iban}</p>
<p>Datum: ${DateFormat('dd.MM.yyyy – HH:mm').format(DateTime.now())}</p>
''',
  );

  bool _sending = false;
  String? _status;

  @override
  void dispose() {
    _toCtrl.dispose();
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _status = null;
    });
    try {
      await EmailService.queueEmail(
        to: _toCtrl.text.trim(),
        subject: _subjectCtrl.text.trim(),
        html: _bodyCtrl.text,
        bcc: BillingConfig.bccEmail.isNotEmpty ? [BillingConfig.bccEmail] : null,
      );
      if (!mounted) return;
      setState(() => _status = 'E-Mail in Warteschlange (mail-Collection) – Extension versendet.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-Mail queued ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Fehler: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Versand: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('E-Mail Testversand')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Testversand über Firebase mail-Collection',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _toCtrl,
                decoration: const InputDecoration(
                  labelText: 'Empfänger',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _subjectCtrl,
                decoration: const InputDecoration(
                  labelText: 'Betreff',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bodyCtrl,
                minLines: 8,
                maxLines: 20,
                decoration: const InputDecoration(
                  labelText: 'HTML-Inhalt',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 220,
                child: ElevatedButton.icon(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send),
                  label: Text(_sending ? 'Senden…' : 'Senden'),
                ),
              ),
              if (_status != null) ...[
                const SizedBox(height: 12),
                Text(_status!, style: const TextStyle(color: Colors.black54)),
              ],
              const SizedBox(height: 8),
              if (BillingConfig.testMode)
                const Text(
                  'TESTMODUS aktiv: Mails gehen an BillingConfig.testRecipient (Betreff mit [TEST]).',
                  style: TextStyle(color: Colors.deepOrange),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
