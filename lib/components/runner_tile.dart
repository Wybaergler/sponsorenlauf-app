import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sponsorenlauf_app/pages/sponsoring_page.dart';

class RunnerTile extends StatelessWidget {
  final String runnerId;
  final String name;
  final String imageUrl;
  final String teamName;
  final String motivation;

  const RunnerTile({
    super.key,
    required this.runnerId,
    required this.name,
    required this.imageUrl,
    required this.teamName,
    required this.motivation,
  });

  @override
  Widget build(BuildContext context) {
    // Prüfen, ob ein Benutzer aktuell eingeloggt ist
    final bool isLoggedIn = FirebaseAuth.instance.currentUser != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                  child: imageUrl.isEmpty ? const Icon(Icons.person, size: 30, color: Colors.grey) : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                      if (teamName.isNotEmpty)
                        Text(teamName, style: TextStyle(color: Colors.grey[600]), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            
            if (motivation.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('"$motivation"', style: const TextStyle(fontStyle: FontStyle.italic), maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
            
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // ================================================================
                // HIER IST DER KONDITIONALE BUTTON
                // ================================================================
                ElevatedButton.icon(
                  // Wenn eingeloggt, ist onPressed null (deaktiviert), sonst wird navigiert
                  onPressed: isLoggedIn ? null : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SponsoringPage(runnerId: runnerId),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                  ),
                  icon: const Icon(Icons.favorite_border, size: 18),
                  label: const Text("Unterstützen"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}