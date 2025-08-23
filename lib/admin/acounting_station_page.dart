import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
// Der Import für 'all_laps_page.dart' wird nicht mehr benötigt und wurde entfernt.

class CountingStationPage extends StatefulWidget {
  const CountingStationPage({super.key});

  @override
  State<CountingStationPage> createState() => _CountingStationPageState();
}

class _CountingStationPageState extends State<CountingStationPage> {
  String? _stationName;
  final _startNumberController = TextEditingController();
  final FocusNode _startNumberFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showSetupDialog());
  }
  
  @override
  void dispose() {
    _startNumberController.dispose();
    _startNumberFocusNode.dispose();
    super.dispose();
  }

  Future<void> _showSetupDialog() async {
    final nameController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Setup Zähl-Station'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: "Ihr Name / Stationsname"),
            autofocus: true,
            onSubmitted: (_) {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.of(context).pop(nameController.text.trim());
              }
            },
          ),
          actions: <Widget>[
            ElevatedButton(
              child: const Text('Starten'),
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  Navigator.of(context).pop(nameController.text.trim());
                }
              },
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _stationName = result;
      });
    } else {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _findAndAddLap() async {
    if (_stationName == null) return;
    final numberString = _startNumberController.text.trim();
    if (numberString.isEmpty) return;
    
    final number = int.tryParse(numberString);
    if (number == null) return;

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('Laufer')
          .where('startNumber', isEqualTo: number)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final runnerDoc = querySnapshot.docs.first;
        final runnerData = runnerDoc.data();

        final lapData = {
          'runnerId': runnerDoc.id,
          'runnerName': runnerData['name'] ?? 'Unbekannt',
          'startNumber': runnerData['startNumber'],
          'runnerImageUrl': runnerData['profileImageUrl'] ?? '',
          'stationName': _stationName,
          'createdAt': FieldValue.serverTimestamp(),
        };
        await FirebaseFirestore.instance.collection('Runden').add(lapData);

        _startNumberController.clear();
        _startNumberFocusNode.requestFocus();

      } else {
        _showErrorDialog("Kein Läufer mit der Startnummer $numberString gefunden.");
      }
    } catch (e) {
      _showErrorDialog("Ein Fehler ist aufgetreten: $e");
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Fehler"),
        content: Text(message),
        actions: [
          ElevatedButton(
            autofocus: true,
            onPressed: () {
              Navigator.pop(context);
              _startNumberController.clear();
              _startNumberFocusNode.requestFocus();
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteLap(String lapId) async {
    try {
      await FirebaseFirestore.instance.collection('Runden').doc(lapId).delete();
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Runde storniert."), backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Fehler beim Stornieren: $e"), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_stationName == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Zähl-Station Setup")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Zähl-Station: $_stationName"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _startNumberController,
              focusNode: _startNumberFocusNode,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(hintText: '#'),
              onSubmitted: (_) => _findAndAddLap(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _findAndAddLap,
                icon: const Icon(Icons.add),
                label: const Text("+1 Runde erfassen"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const Divider(height: 40),
            
            // ================================================================
            // HIER SIND DIE ÄNDERUNGEN
            // ================================================================
            const Text("Alle Erfassungen:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                // Die Abfrage hat jetzt KEIN .limit(3) mehr
                stream: FirebaseFirestore.instance
                    .collection('Runden')
                    .where('stationName', isEqualTo: _stationName)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, lapSnapshot) {
                  if (lapSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!lapSnapshot.hasData || lapSnapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("Noch keine Runden erfasst."));
                  }
                  final allLaps = lapSnapshot.data!.docs; // Umbenannt für Klarheit
                  return ListView.builder(
                    itemCount: allLaps.length,
                    itemBuilder: (context, index) {
                      final lap = allLaps[index];
                      final lapData = lap.data() as Map<String, dynamic>;
                      final imageUrl = lapData['runnerImageUrl'] ?? '';
                      String formattedTime = '...';
                      if (lapData['createdAt'] != null) {
                        final timestamp = (lapData['createdAt'] as Timestamp).toDate();
                        formattedTime = DateFormat('HH:mm:ss').format(timestamp);
                      }
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey[200],
                            backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                            child: imageUrl.isEmpty ? const Icon(Icons.person) : null,
                          ),
                          title: Text("${lapData['runnerName']}"),
                          subtitle: Text("Startnr: ${lapData['startNumber']} | Zeit: $formattedTime"),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _deleteLap(lap.id),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            // Der "Alle anzeigen"-Button wurde entfernt
          ],
        ),
      ),
    );
  }
}