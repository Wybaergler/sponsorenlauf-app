import 'package:flutter/material.dart';
import 'package:sponsorenlauf_app/pages/edit_profile_page.dart';
import 'package:sponsorenlauf_app/pages/runner_dashboard_page.dart';

class RegistrationSuccessPage extends StatelessWidget {
  const RegistrationSuccessPage({super.key});

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
                'Registrierung erfolgreich.\n\nVielen Dank, dass du als Läufer am Sponsorenlauf dabei bist!'
                    '\n\nErgänze jetzt dein Profil. Das ist wichtig, damit Sponsoren dich als Läufer sehen können.'
                    '\nFüge auch ein Bild hinzu. Viel Spass!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () async {
                  // 1) Erst zur Profilbearbeitung (OHNE Stack zu leeren)
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const EditProfilePage()),
                  );
                  if (!context.mounted) return;

                  // 2) Nach Rückkehr (z. B. nach Speichern/Pop) sicher ins Dashboard
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const RunnerDashboardPage()),
                        (route) => false,
                  );
                },
                child: const Text('Profil jetzt ergänzen'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
