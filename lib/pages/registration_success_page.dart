import 'package:flutter/material.dart';

class RegistrationSuccessPage extends StatefulWidget {
  const RegistrationSuccessPage({super.key});

  @override
  State<RegistrationSuccessPage> createState() => _RegistrationSuccessPageState();
}

class _RegistrationSuccessPageState extends State<RegistrationSuccessPage> {
  @override
  void initState() {
    super.initState();
    _autoNavigate();
  }

  Future<void> _autoNavigate() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrierung erfolgreich')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, size: 72),
              const SizedBox(height: 16),
              const Text(
                'Dein Konto wurde angelegt.',
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
