import 'package:flutter/material.dart';
import 'package:sponsorenlauf_app/pages/public_landing_page.dart';
import 'package:sponsorenlauf_app/pages/runner_dashboard_page.dart'; // NEUER IMPORT

class RegistrationSuccessPage extends StatelessWidget {
  static const routeName = '/registration_success';
  const RegistrationSuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 100, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(height: 24),
                const Text("Registrierung erfolgreich!", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                const Text("Super, du bist als Läufer:in beim Sponsorenlauf registriert. Eine Willkommens-E-Mail wurde an deine Adresse gesendet.", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.black54)),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    // --- KORREKTUR: Navigiert jetzt direkt zum Dashboard ---
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const RunnerDashboardPage()),
                          (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  child: const Text("Zu meiner Läufer-Seite"),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const PublicLandingPage()),
                          (route) => false,
                    );
                  },
                  child: const Text("Zurück zur Startseite"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}