import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:sponsorenlauf_app/pages/edit_profile_page.dart';
import 'package:sponsorenlauf_app/pages/runner_dashboard_page.dart';

class ProfileCompletionGate extends StatelessWidget {
  const ProfileCompletionGate({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const _LoadingScreen(); // Sicherheitsnetz
    }

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: docRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }
        if (snapshot.hasError) {
          return const _ErrorScreen();
        }

        final data = snapshot.data?.data();
        final isComplete = (data != null && data['isProfileComplete'] == true);

        if (isComplete) {
          return const RunnerDashboardPage();
        } else {
          return const EditProfilePage();
        }
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.error_outline, size: 48),
            SizedBox(height: 12),
            Text('Es ist ein Fehler aufgetreten.'),
          ],
        ),
      ),
    );
  }
}
