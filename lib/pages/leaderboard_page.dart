import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum LeaderboardSort { byLaps, byDonations }

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  LeaderboardSort _currentSort = LeaderboardSort.byLaps;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Live Leaderboard"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SegmentedButton<LeaderboardSort>(
              segments: const [
                ButtonSegment(
                  value: LeaderboardSort.byLaps,
                  label: Text("Top Runden"),
                  icon: Icon(Icons.repeat),
                ),
                ButtonSegment(
                  value: LeaderboardSort.byDonations,
                  label: Text("Top Spenden"),
                  icon: Icon(Icons.euro_symbol),
                ),
              ],
              selected: {_currentSort},
              onSelectionChanged: (newSelection) {
                setState(() {
                  _currentSort = newSelection.first;
                });
              },
            ),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("Laufer")
                    .where('isPublic', isEqualTo: true)
                    .orderBy(
                      _currentSort == LeaderboardSort.byLaps ? 'rundenAnzahl' : 'aktuelleSpendensumme',
                      descending: true
                    )
                    .limit(20) // Wir zeigen die Top 20 an
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(child: Text("Ein Fehler ist aufgetreten."));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("Noch keine Daten für das Leaderboard."));
                  }
                  final users = snapshot.data!.docs;
                  
                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final userDocument = users[index];
                      final userData = userDocument.data() as Map<String, dynamic>;
                      
                      final name = userData['name'] ?? userData['email'];
                      final imageUrl = userData['profileImageUrl'] ?? '';
                      final lapCount = userData['rundenAnzahl'] ?? 0;
                      final donationSum = userData['aktuelleSpendensumme'] ?? 0.0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            radius: 25,
                            child: Text(
                              "${index + 1}",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(name),
                          subtitle: Row(
                            children: [
                               CircleAvatar(
                                radius: 15,
                                backgroundColor: Colors.transparent,
                                backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                                child: imageUrl.isEmpty ? const Icon(Icons.person, size: 15) : null,
                              ),
                              const SizedBox(width: 8),
                              Text(userData['teamName'] ?? ''),
                            ],
                          ),
                          trailing: Text(
                            _currentSort == LeaderboardSort.byLaps
                                ? "$lapCount Runden"
                                : "${(donationSum as double).toStringAsFixed(2)} CHF",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}