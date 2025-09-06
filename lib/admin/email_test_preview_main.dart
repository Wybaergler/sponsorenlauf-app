import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import 'email_test_page.dart';
import '../theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const _EmailTestApp());
}

class _EmailTestApp extends StatelessWidget {
  const _EmailTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Email Test',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const EmailTestPage(),
    );
  }
}