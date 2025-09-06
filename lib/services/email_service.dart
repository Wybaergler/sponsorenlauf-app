import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/billing_config.dart';

class EmailService {
  static Future<void> queueEmail({
    required String to,
    required String subject,
    required String html,
    String? text,
    List<String>? cc,
    List<String>? bcc,
  }) async {
    final toAddr = BillingConfig.testMode ? BillingConfig.testRecipient : to;

    final payload = <String, dynamic>{
      'to': [toAddr],
      if (cc != null && cc.isNotEmpty) 'cc': cc,
      if (bcc != null && bcc.isNotEmpty) 'bcc': bcc,
      // Viele Setups ignorieren "from" und nutzen Extension-Default aus der Konfiguration
      'message': {
        'subject': BillingConfig.testMode ? '[TEST] $subject' : subject,
        if (text != null && text.isNotEmpty) 'text': text,
        'html': html,
      },
    };

    await FirebaseFirestore.instance.collection('mail').add(payload);
  }
}
