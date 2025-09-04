import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sponsorenlauf_app/admin/final_accounting_page.dart';

class AdminDashboardPage extends StatefulWidget {
  static const routeName = '/admin_dashboard';
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  bool _isCalculating = false;

  Future<void> _triggerCalculation() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Abrechnung starten"),
        content: const Text("Sollen die finalen Beträge berechnet werden?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Starten')),
        ],
      ),
    );

    if (confirm ?? false) {
      setState(() => _isCalculating = true);
      try {
        await FirebaseFirestore.instance.collection('abrechnungen').add({
          'triggeredBy': currentUser.uid,
          'triggeredAt': FieldValue.serverTimestamp(),
          'status': 'gestartet',
        });

        await FirebaseFirestore.instance
            .collection('Lauf')
            .doc('sponsorenlauf-2025')
            .set({'status': 'abgeschlossen'}, SetOptions(merge: true));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Abrechnungsprozess erfolgreich gestartet!"), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Fehler beim Starten der Abrechnung: $e"), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isCalculating = false);
      }
    }
  }

  void _showEditStartNumberDialog(QueryDocumentSnapshot doc, bool isRaceClosed) {
    final runnerData = doc.data() as Map<String, dynamic>;
    final controller = TextEditingController(text: (runnerData['startNumber'] ?? '').toString());

    Future<void> saveNumber() async {
      final txt = controller.text.trim();
      final numValue = int.tryParse(txt);
      try {
        await FirebaseFirestore.instance.collection('Laufer').doc(doc.id).set(
          {'startNumber': numValue},
          SetOptions(merge: true),
        );
        if (mounted) Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Fehler beim Speichern: $e")),
        );
      }
    }

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Startnummer für ${runnerData['name'] ?? 'Unbekannt'}"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Startnummer'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          ElevatedButton(onPressed: isRaceClosed ? null : saveNumber, child: const Text('Speichern')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Dashboard")),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('Lauf').doc('sponsorenlauf-2025').snapshots(),
        builder: (context, raceStatusSnapshot) {
          if (raceStatusSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (raceStatusSnapshot.hasError) {
            return const Center(child: Text("Fehler beim Laden des Lauf-Status."));
          }
          if (!raceStatusSnapshot.hasData || !raceStatusSnapshot.data!.exists) {
            FirebaseFirestore.instance.collection('Lauf').doc('sponsorenlauf-2025').set({'status': 'offen'});
            return const Center(child: Text("Initialisiere Lauf-Status... Bitte neu laden."));
          }

          final status = raceStatusSnapshot.data?.get('status') ?? 'unbekannt';
          final bool isRaceClosed = status == 'abgeschlossen';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text("Aktueller Status: ${status.toUpperCase()}",
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),

                    // WICHTIG: Horizontal scrollbarer Button-Row → keine unendlichen Breiten
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.visibility),
                            label: const Text("Vorschau Abrechnung"),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const FinalAccountingPage()),
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            icon: _isCalculating
                                ? const SizedBox(
                                width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Icon(isRaceClosed ? Icons.check_circle : Icons.calculate_outlined),
                            label: Text(isRaceClosed ? "Berechnung abgeschlossen" : "Finale Beträge berechnen"),
                            onPressed: isRaceClosed || _isCalculating ? null : _triggerCalculation,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isRaceClosed ? Colors.grey : Colors.orange[800],
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('Laufer').snapshots(),
                  builder: (context, runnerSnapshot) {
                    if (runnerSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (runnerSnapshot.hasError) {
                      return const Center(child: Text("Ein Fehler ist aufgetreten."));
                    }
                    if (!runnerSnapshot.hasData || runnerSnapshot.data!.docs.isEmpty) {
                      return const Center(child: Text("Keine Läufer gefunden."));
                    }
                    final runners = runnerSnapshot.data!.docs;
                    return SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Team', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('E-Mail', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Startnummer', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: runners.map((doc) {
                            final runnerData = doc.data() as Map<String, dynamic>;
                            return DataRow(cells: [
                              DataCell(Text(runnerData['name'] ?? '')),
                              DataCell(Text(runnerData['teamName'] ?? '')),
                              DataCell(Text(runnerData['email'] ?? '')),
                              DataCell(
                                Text(runnerData['startNumber']?.toString() ?? '---'),
                                showEditIcon: !isRaceClosed,
                                onTap: () => _showEditStartNumberDialog(doc, isRaceClosed),
                              ),
                            ]);
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
