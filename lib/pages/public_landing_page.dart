import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sponsorenlauf_app/auth/login_or_register.dart'; // WICHTIGER IMPORT
import 'package:sponsorenlauf_app/components/runner_tile.dart';
import 'package:sponsorenlauf_app/pages/leaderboard_page.dart';
import 'package:sponsorenlauf_app/pages/runner_dashboard_page.dart';

class PublicLandingPage extends StatefulWidget {
  static const routeName = '/';
  const PublicLandingPage({super.key});

  @override
  State<PublicLandingPage> createState() => _PublicLandingPageState();
}

class _PublicLandingPageState extends State<PublicLandingPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _auth.authStateChanges().listen((User? user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isLoggedIn = _currentUser != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Sponsorenlauf EVP"),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (isLoggedIn)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8.0),
                color: Colors.red[700],
                child: Text(
                  "Du bist als Läufer angemeldet: ${_currentUser!.email}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 24.0),
              child: Center(
                child: Column(
                  children: [
                    Image.asset('assets/images/logo.png', height: 180),
                    const SizedBox(height: 24),
                    const Text("Gemeinsam laufen für einen guten Zweck!", textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF005DA4))),
                    const SizedBox(height: 16),
                    const Text("Hier steht eine inspirierende Beschreibung des Sponsorenlaufs...", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, height: 1.5)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const Text(
                    "Unsere Läuferinnen und Läufer",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: isLoggedIn
                        ? ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, RunnerDashboardPage.routeName);
                      },
                      style: ElevatedButton.styleFrom(minimumSize: const Size(0, 50), padding: const EdgeInsets.symmetric(horizontal: 24)),
                      icon: const Icon(Icons.person),
                      label: const Text("Zu meinem Konto"),
                    )
                        : ElevatedButton.icon(
                      // --- HIER IST DIE ÄNDERUNG ---
                      onPressed: () {
                        Navigator.pushNamed(context, LoginOrRegister.routeName);
                      },
                      style: ElevatedButton.styleFrom(minimumSize: const Size(0, 50), padding: const EdgeInsets.symmetric(horizontal: 24)),
                      icon: const Icon(Icons.directions_run),
                      label: const Text("Registrieren / Anmelden für Läufer"),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const LeaderboardPage()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        minimumSize: const Size(0, 50),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                      ),
                      icon: const Icon(Icons.leaderboard),
                      label: const Text("Lauf live mitverfolgen"),
                    ),
                  ),
                  const SizedBox(height: 20),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection("Laufer").where('isPublic', isEqualTo: true).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return const Text("Ein Fehler ist aufgetreten.");
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Padding(padding: EdgeInsets.all(32.0), child: Text("Noch keine öffentlichen Läuferprofile.")));
                      }
                      final users = snapshot.data!.docs;
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final userDocument = users[index];
                          final userData = userDocument.data() as Map<String, dynamic>;
                          final name = userData['name'] ?? userData['email'];
                          final imageUrl = userData['profileImageUrl'] ?? '';
                          final runnerId = userDocument.id;
                          final teamName = userData['teamName'] ?? '';
                          final motivation = userData['motivation'] ?? '';
                          return RunnerTile(
                            runnerId: runnerId,
                            name: name,
                            imageUrl: imageUrl,
                            teamName: teamName,
                            motivation: motivation,
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}