import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sponsorenlauf_app/auth/login_or_register.dart';
import 'package:sponsorenlauf_app/pages/profile_page.dart';

class AuthGate extends StatelessWidget {
  // NEU: Definiert den "Straßennamen" für diese Seite
  static const routeName = '/auth';

  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            // Wir verwenden hier KEINE Navigation. Der AuthGate ENTSCHEIDET,
            // welche Seite er anzeigt. Das ist stabiler.
            return const ProfilePage();
          } else {
            return const LoginOrRegister();
          }
        },
      ),
    );
  }
}