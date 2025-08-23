import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sponsorenlauf_app/admin/counting_station_page.dart';

class AdminDashboardPage extends StatefulWidget {
  // --- HIER IST DIE KORREKTE POSITION ---
  static const routeName = '/admin_dashboard';

  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  // Die routeName-Zeile wurde von hier entfernt.

  Future<void> _showEditStartNumberDialog(DocumentSnapshot runnerDoc) async {
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
          content: TextField(
            controller: numberController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Startnummer'),
            autofocus: true,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Abbrechen'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              onPressed: saveNumber,
              child: const Text('Speichern'),
            ),
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.timer_outlined),
                label: const Text("Zähl-Station öffnen"),
                onPressed: () {
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
          const Divider(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Laufer')
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text("Ein Fehler ist aufgetreten."));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("Keine Läufer gefunden."));
                }

                final runners = snapshot.data!.docs;

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
                            showEditIcon: true,
                            onTap: () {
                              _showEditStartNumberDialog(doc);
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
      ),
    );
  }
}