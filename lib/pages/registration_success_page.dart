import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sponsorenlauf_app/pages/runner_dashboard_page.dart';
import 'package:sponsorenlauf_app/pages/public_landing_page.dart';

class RegistrationSuccessPage extends StatelessWidget {
  const RegistrationSuccessPage({super.key});

  Future<void> _signOut(BuildContext context) async {
    final nav = Navigator.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await FirebaseAuth.instance.signOut();
      if (!nav.mounted) return;
      nav.pop(); // Loader schließen
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PublicLandingPage()),
            (route) => false,
      );
    } catch (_) {
      if (!nav.mounted) return;
      nav.pop(); // Loader schließen
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Abmelden fehlgeschlagen. Bitte erneut versuchen.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registriert'),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Abmelden',
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      backgroundColor: Colors.grey[200],
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle,     // ausgefüllt
                  size: 120,
                  color: cs.secondary,     // gleiches Blau wie Button
                  semanticLabel: 'Registrierung erfolgreich',
                ),
                const SizedBox(height: 32),
                const Text(
                  "Willkommen an Bord!",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Dein Läufer-Konto wurde erstellt.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => const RunnerDashboardPage()),
                            (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    child: const Text("Zu meinem Dashboard"),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const PublicLandingPage()),
                          (route) => false,
                    );
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Zurück zum Sponsorenlauf'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
