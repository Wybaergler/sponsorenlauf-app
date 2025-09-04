import 'package:flutter/material.dart';

class LoginSuccessPage extends StatefulWidget {
  const LoginSuccessPage({super.key});

  @override
  State<LoginSuccessPage> createState() => _LoginSuccessPageState();
}

class _LoginSuccessPageState extends State<LoginSuccessPage> {
  @override
  void initState() {
    super.initState();
    _autoNavigate();
  }

  Future<void> _autoNavigate() async {
    // kurze Erfolgspause
    await Future.delayed(const Duration(seconds: 2));
    // WICHTIG: context erst NACH dem await verwenden
    if (!mounted) return;
    // Zur Startseite/ersten Route zurück
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login erfolgreich')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, size: 72),
              const SizedBox(height: 16),
              const Text(
                'Du bist eingeloggt.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('Weiter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
