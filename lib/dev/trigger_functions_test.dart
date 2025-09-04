import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sponsorenlauf_app/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const _App());
}

class _App extends StatefulWidget {
  const _App({super.key});
  @override State<_App> createState() => _AppState();
}

class _AppState extends State<_App> {
  String log = 'Starte Test…';
  @override void initState() { super.initState(); _run(); }

  Future<void> _run() async {
    final buf = StringBuffer();
    try {
      buf.writeln('1) Läufer suchen…');
      final runners = await FirebaseFirestore.instance.collection('Laufer').limit(1).get();
      final runnerId = runners.docs.isNotEmpty ? runners.docs.first.id : 'TEST_RUNNER';
      buf.writeln('   runnerId = $runnerId');

      const email = 'test+sandbox@sponsorenlauf.app';
      const name = 'Test Sponsor';
      const amount = 12.34;

      buf.writeln('2) Spende anlegen (fixed CHF $amount)…');
      final ref = await FirebaseFirestore.instance.collection('Spenden').add({
        'runnerId': runnerId,
        'sponsoringType': 'fixed',
        'amount': amount,
        'sponsorEmail': email,
        'sponsorName': name,
        'createdAt': Timestamp.now(),
      });
      buf.writeln('   spendeId = ${ref.id} (warte auf Trigger)…');
      await Future.delayed(const Duration(seconds: 8));

      final sp = await ref.get();
      final ct = sp.data()?['currentTotal'];
      buf.writeln('3a) currentTotal in Spende = $ct');

      final key = base64Url.encode(utf8.encode(email.toLowerCase()));
      final spon = await FirebaseFirestore.instance.collection('stats_sponsor').doc(key).get();
      buf.writeln('3b) stats_sponsor existiert: ${spon.exists} '
          '(countSpenden=${spon.data()?['countSpenden']}, total=${spon.data()?['total']})');

      final rsDoc = await FirebaseFirestore.instance.collection('stats_runner').doc(runnerId).get();
      buf.writeln('3c) stats_runner existiert: ${rsDoc.exists} '
          '(rounds=${rsDoc.data()?['rounds']}, total=${rsDoc.data()?['total']})');

      setState(() => log = buf.toString());
    } catch (e) {
      setState(() => log = '$buf\nFEHLER: $e');
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(appBar: AppBar(title: const Text('Functions Trigger Test')),
      body: Padding(padding: const EdgeInsets.all(12), child: SelectableText(log))),
  );
}
