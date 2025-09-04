import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // NEUER IMPORT
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sponsorenlauf_app/admin/counting_station_page.dart';

class AdminDashboardPage extends StatefulWidget {
  static const routeName = '/admin_dashboard';
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  bool _isCalculating = false;

  // --- HIER IST DIE NEUE, VEREINFACHTE FUNKTION ---
  Future<void> _triggerCalculation() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fehler: Nicht authentifiziert.")));
      return;
    }

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Abrechnung starten?"),
        content: const Text("Dieser Schritt startet die Berechnung der finalen Spendenbeträge. Der Prozess läuft im Hintergrund und kann einige Minuten dauern. Fortfahren?"),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Abbrechen")),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("Berechnung starten")),
        ],
      ),
    );

    if (confirm ?? false) {
      setState(() => _isCalculating = true);
      try {
        // Wir schreiben einen "Auftrag" in die 'abrechnungen'-Sammlung.
        // Die Cloud Function wird darauf reagieren.
        await FirebaseFirestore.instance.collection('abrechnungen').add({
          'triggeredBy': currentUser.uid,
          'triggeredAt': FieldValue.serverTimestamp(),
          'status': 'gestartet',
        });

        // Wir setzen den Lauf-Status direkt in der App.
        await FirebaseFirestore.instance
            .collection('Lauf')
            .doc('sponsorenlauf-2025')
            .set({'status': 'abgeschlossen'}, SetOptions(merge: true));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Abrechnungsprozess erfolgreich gestartet!"), backgroundColor: Colors.green));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fehler beim Starten der Abrechnung: $e"), backgroundColor: Colors.red));
        }
      } finally {
        if (mounted) {
          setState(() => _isCalculating = false);
        }
      }
    }
  }

  Future<void> _showEditStartNumberDialog(DocumentSnapshot runnerDoc, bool isRaceClosed) async {
    if (isRaceClosed) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Der Lauf ist bereits abgeschlossen. Startnummern können nicht mehr geändert werden.")));
      return;
    }
    final runnerData = runnerDoc.data() as Map<String, dynamic>;
    final runnerId = runnerDoc.id;
    final name = runnerData['name'] ?? 'Unbekannter Läufer';
    final currentNumber = runnerData['startNumber']?.toString() ?? '';
    final numberController = TextEditingController(text: currentNumber);
    Future<void> saveNumber() async {
      final newNumberString = numberController.text.trim();
      final int? newNumber = int.tryParse(newNumberString);
      try {
        if (newNumberString.isNotEmpty && newNumber != null) {
          await FirebaseFirestore.instance.collection('Laufer').doc(runnerId).update({'startNumber': newNumber});
        } else if (newNumberString.isEmpty) {
          await FirebaseFirestore.instance.collection('Laufer').doc(runnerId).update({'startNumber': FieldValue.delete()});
        }
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fehler beim Speichern: $e")));
        }
      }
    }
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Startnummer für $name'),
          content: TextField(controller: numberController, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'Startnummer'), autofocus: true),
          actions: <Widget>[
            TextButton(child: const Text('Abbrechen'), onPressed: () => Navigator.of(context).pop()),
            ElevatedButton(onPressed: saveNumber, child: const Text('Speichern')),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
      ),
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
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text("Lauf-Status & Abrechnung", style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        const Text("Hier können Sie den Lauf abschließen, um die finalen Spendenbeträge zu berechnen."),
                        const SizedBox(height: 16),
                        Column(
                          children: [
                            Text("Aktueller Status: ${status.toUpperCase()}", style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            ElevatedButton.icon(
                              icon: _isCalculating
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Icon(isRaceClosed ? Icons.check_circle : Icons.calculate_outlined),
                              label: Text(isRaceClosed ? "Berechnung abgeschlossen" : "Finale Beträge berechnen"),
                              onPressed: isRaceClosed || _isCalculating ? null : _triggerCalculation,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isRaceClosed ? Colors.grey : Colors.orange[800],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16,0,16,16),
                child: Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.timer_outlined),
                    label: const Text("Zähl-Station öffnen"),
                    onPressed: isRaceClosed ? null : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CountingStationPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ),
              ),
              const Divider(indent: 16, endIndent: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('Laufer').orderBy('name').snapshots(),
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
                                onTap: () {
                                  _showEditStartNumberDialog(doc, isRaceClosed);
                                },
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