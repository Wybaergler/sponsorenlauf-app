import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sponsorenlauf_app/admin/admin_dashboard_page.dart';
import 'package:sponsorenlauf_app/pages/edit_profile_page.dart';
import 'package:sponsorenlauf_app/pages/sponsoring_page.dart';
import 'package:sponsorenlauf_app/auth/auth_gate.dart';
import 'package:sponsorenlauf_app/navigation/route_arguments.dart';

// KORRIGIERTER KLASSENNAME
class RunnerDashboardPage extends StatefulWidget {
  static const routeName = '/profile'; // Der Routenname bleibt gleich
  final bool showSuccessDialog;

  const RunnerDashboardPage({
    super.key,
    this.showSuccessDialog = false,
  });

  @override
  // KORRIGIERTER STATE-KLASSENNAME
  State<RunnerDashboardPage> createState() => _RunnerDashboardPageState();
}

// KORRIGIERTER STATE-KLASSENNAME
class _RunnerDashboardPageState extends State<RunnerDashboardPage> {
  final currentUser = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    if (widget.showSuccessDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showSuccessDialog();
        }
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Registrierung erfolgreich!"),
        content: const Text(
          "Super, du bist als Läufer:in beim Sponsorenlauf registriert. Fülle als nächstes dein Profil aus, um Sponsoren zu finden.",
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final name = _userData?['name'] ?? '';
              final isAdmin = (_userData?['role'] ?? 'user') == 'admin';
              if (name.isEmpty && !isAdmin) {
                Navigator.pushReplacementNamed(context, EditProfilePage.routeName);
              }
            },
            child: const Text("Profil jetzt ausfüllen"),
          ),
        ],
      ),
    );
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, AuthGate.routeName, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection("Laufer").doc(currentUser!.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Ein Fehler ist aufgetreten: ${snapshot.error}"));
          }
          if (snapshot.hasData && snapshot.data!.exists) {
            _userData = snapshot.data!.data() as Map<String, dynamic>;
            final imageUrl = _userData!['profileImageUrl'] ?? '';
            final bool isAdmin = (_userData!['role'] ?? 'user') == 'admin';
            final int lapCount = _userData!['rundenAnzahl'] ?? 0;

            return Scaffold(
              appBar: AppBar(
                title: const Text("Mein Dashboard"), // Titel angepasst
                actions: [
                  IconButton(onPressed: signOut, icon: const Icon(Icons.logout))
                ],
              ),
              body: ListView(
                padding: const EdgeInsets.all(24.0),
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                      child: imageUrl.isEmpty ? const Icon(Icons.person, size: 60, color: Colors.grey) : null,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildProfileDetailRow("Name", _userData!['name'] ?? 'Nicht angegeben'),
                  _buildProfileDetailRow("E-Mail", _userData!['email'] ?? 'Nicht angegeben'),
                  _buildProfileDetailRow("Team", _userData!['teamName'] ?? 'Kein Team'),
                  _buildProfileDetailRow("Motivation", _userData!['motivation'] ?? 'Keine Angabe'),
                  _buildProfileDetailRow("Sichtbarkeit", (_userData!['isPublic'] ?? true) ? "Öffentlich" : "Privat"),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, EditProfilePage.routeName),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text("Profil bearbeiten"),
                  ),
                  if (isAdmin) ...[
                    const Divider(height: 60, thickness: 1),
                    const Text("Admin Bereich", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, AdminDashboardPage.routeName);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
                      icon: const Icon(Icons.admin_panel_settings),
                      label: const Text("Lauf verwalten"),
                    ),
                  ],
                  const Divider(height: 60, thickness: 1),
                  const Text("Meine Runden", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Gesamt:", style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 10),
                          Text(lapCount.toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 4),
                          const Text("Runden", style: TextStyle(fontSize: 18)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('Runden').where('runnerId', isEqualTo: currentUser!.uid).orderBy('createdAt', descending: true).snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
                      final laps = snapshot.data!.docs;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Einzel-Erfassungen:", style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 4),
                          ...laps.map((lapDoc) {
                            final lapData = lapDoc.data() as Map<String, dynamic>;
                            String formattedTime = '...';
                            if (lapData['createdAt'] != null) {
                              final timestamp = (lapData['createdAt'] as Timestamp).toDate();
                              formattedTime = DateFormat('HH:mm:ss').format(timestamp);
                            }
                            return Text("• Runde erfasst um $formattedTime durch ${lapData['stationName']}");
                          }).toList(),
                        ],
                      );
                    },
                  ),
                  const Divider(height: 60, thickness: 1),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Meine Sponsoren", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pushNamed(context, SponsoringPage.routeName, arguments: SponsoringPageArguments(runnerId: currentUser!.uid)),
                        style: ElevatedButton.styleFrom(minimumSize: const Size(120, 40), textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text("Hinzufügen"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text("Als Läufer kannst Du hier selbst eine zugesagte Spende von einem Sponsor erfassen.", style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic)),
                  ),
                  const SizedBox(height: 20),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('Spenden').where('runnerId', isEqualTo: currentUser!.uid).orderBy('createdAt', descending: true).snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(16.0), child: Text("Du hast noch keine Sponsoren erfasst.")));
                      final sponsorships = snapshot.data!.docs;
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Sponsor')),
                            DataColumn(label: Text('Fix (CHF)'), numeric: true),
                            DataColumn(label: Text('Pro Runde (CHF)'), numeric: true),
                            DataColumn(label: Text('Total (prov.)'), numeric: true),
                          ],
                          rows: sponsorships.map((doc) {
                            final sponsor = doc.data() as Map<String, dynamic>;
                            final amount = (sponsor['amount'] ?? 0.0) as num;
                            final isFixed = sponsor['sponsoringType'] == 'fixed';
                            final bool addedByRunner = sponsor['addedByRunner'] ?? false;
                            final fixedAmount = isFixed ? amount : 0.0;
                            final perLapAmount = isFixed ? 0.0 : amount;
                            final totalAmount = fixedAmount + (perLapAmount * lapCount);
                            return DataRow(
                                onSelectChanged: addedByRunner ? (selected) {
                                  if (selected ?? false) {
                                    Navigator.pushNamed(context, SponsoringPage.routeName, arguments: SponsoringPageArguments(runnerId: currentUser!.uid, sponsorshipId: doc.id));
                                  }
                                } : null,
                                cells: [
                                  DataCell(Text(sponsor['sponsorName'], style: TextStyle(color: addedByRunner ? Colors.blue : null, decoration: addedByRunner ? TextDecoration.underline : null))),
                                  DataCell(Text(fixedAmount > 0 ? fixedAmount.toStringAsFixed(2) : '-')),
                                  DataCell(Text(perLapAmount > 0 ? perLapAmount.toStringAsFixed(2) : '-')),
                                  DataCell(Text(totalAmount.toStringAsFixed(2))),
                                ]);
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          } else {
            return const Center(child: Text("Benutzerdaten nicht gefunden."));
          }
        },
      ),
    );
  }

  Widget _buildProfileDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 18)),
          const Divider(),
        ],
      ),
    );
  }
}