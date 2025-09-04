import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sponsorenlauf_app/firebase_options.dart';
import 'package:sponsorenlauf_app/theme/app_theme.dart';
import 'package:sponsorenlauf_app/admin/sponsor_invoices_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  ).then((_) {
    runApp(const _PreviewApp());
  });
}

class _PreviewApp extends StatelessWidget {
  const _PreviewApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sponsor-Abrechnung – Vorschau',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const SponsorInvoicesPage(),
    );
  }
}
