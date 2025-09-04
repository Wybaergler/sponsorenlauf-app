import 'package:flutter/material.dart';
import 'package:sponsorenlauf_app/pages/edit_profile_page.dart';

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
                onPressed: () {
                  // Erfolgsseite verlassen und direkt zur Profilbearbeitung
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const EditProfilePage()),
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