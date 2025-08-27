import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sponsorenlauf_app/auth/login_or_register.dart';
// WICHTIG: Wir importieren die ProfilePage hier NICHT mehr.

// Dies ist eine neue, extrem simple und stabile Seite, die nach dem Login angezeigt wird.
// Sie hat KEINEN Datenbankzugriff und kann daher nicht im Ladekreis hängen bleiben.
class LoggedInLandingPage extends StatelessWidget {
  const LoggedInLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Willkommen"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Ausloggen",
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Erfolgreich eingeloggt als:",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                "${FirebaseAuth.instance.currentUser?.email}",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 40),
              // Dieser Button ist vorerst nur ein Platzhalter.
              // Später wird er zur neuen Profil-Bearbeiten-Seite führen.
              ElevatedButton(
                onPressed: () {
                  // TODO: Navigation zur neuen ProfileEditPage implementieren
                },
                child: const Text("Profil ansehen / bearbeiten"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class AuthGate extends StatelessWidget {
  static const routeName = '/auth';
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            // Führt jetzt zur neuen, stabilen Platzhalter-Seite
            return const LoggedInLandingPage();
          } else {
            return const LoginOrRegister();
          }
        },
      ),
    );
  }
}