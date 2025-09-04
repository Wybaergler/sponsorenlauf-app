import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sponsorenlauf_app/pages/public_landing_page.dart';
import 'package:sponsorenlauf_app/pages/runner_dashboard_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const RunnerDashboardPage(); // eingeloggt
        }
        return const PublicLandingPage(); // nicht eingeloggt
      },
    );
  }
}
