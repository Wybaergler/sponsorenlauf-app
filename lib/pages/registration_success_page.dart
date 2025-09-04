import 'package:flutter/material.dart';
import 'package:sponsorenlauf_app/pages/runner_dashboard_page.dart';

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

    // Nach erfolgreicher Registrierung: direkt ins Dashboard und Stack leeren
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RunnerDashboardPage()),
          (route) => false,
    );
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
            children: const [
              Icon(Icons.check_circle, size: 72),
              SizedBox(height: 16),
              Text(
                'Dein Konto wurde angelegt.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 24),
              CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
