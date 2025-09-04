import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class StartNumberManagerPage extends StatefulWidget {
  const StartNumberManagerPage({super.key});

  @override
  State<StartNumberManagerPage> createState() => _StartNumberManagerPageState();
}

class _StartNumberManagerPageState extends State<StartNumberManagerPage> {
  bool _isAdmin = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    try {
      final u = FirebaseAuth.instance.currentUser;
      if (u == null) {
        setState(() { _isAdmin = false; _checking = false; });
        return;
      }
      final snap = await FirebaseFirestore.instance.collection('Laufer').doc(u.uid).get();
      setState(() {
        _isAdmin = snap.data()?['role'] == 'admin';
        _checking = false;
      });
    } catch (_) {
      setState(() { _isAdmin = false; _checking = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return Scaffold(
        appBar: AppBar(title: const Text('Startnummern-Vergabe')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Startnummern-Vergabe')),
        body: const Center(child: Text('Kein Admin-Zugang.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Startnummern-Vergabe'),
        actions: [
          IconButton(
            tooltip: 'Neu laden',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        // Wichtig: KEIN orderBy → wir sortieren lokal stabil
        stream: FirebaseFirestore.instance.collection('Laufer').snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Fehler: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs.toList();

          // Lokale Sortierung: erst nach startNumber (nulls zuletzt), dann Name/Email
          docs.sort((a, b) {
            int? sa = _toIntOrNull(a.data()['startNumber']);
            int? sb = _toIntOrNull(b.data()['startNumber']);
            if (sa == null && sb == null) {
              return _nameOf(a).toLowerCase().compareTo(_nameOf(b).toLowerCase());
            }
            if (sa == null) return 1; // null ans Ende
            if (sb == null) return -1;
            final cmp = sa.compareTo(sb);
            if (cmp != 0) return cmp;
            return _nameOf(a).toLowerCase().compareTo(_nameOf(b).toLowerCase());
          });

          if (docs.isEmpty) {
            return const Center(child: Text('Keine Läufer gefunden.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d = docs[i];
              final data = d.data();
              final name = _nameOf(d);
              final sn = (data['startNumber'] ?? '').toString();
              final ctrl = TextEditingController(text: sn);

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('UID: ${d.id}', style: const TextStyle(color: Colors.black54)),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: ctrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Startnummer',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final val = ctrl.text.trim();
                          int? snum = int.tryParse(val);
                          if (val.isEmpty) snum = null;
                          try {
                            await FirebaseFirestore.instance
                                .collection('Laufer')
                                .doc(d.id)
                                .set({'startNumber': snum}, SetOptions(merge: true));
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Gespeichert.')),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Fehler: $e')),
                            );
                          }
                        },
                        icon: const Icon(Icons.save),
                        label: const Text('Speichern'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  static int? _toIntOrNull(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  String _nameOf(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();
    String dn = (data['displayName'] ?? '').toString().trim();
    if (dn.isNotEmpty) return dn;
    final fn = (data['firstName'] ?? data['vorname'] ?? '').toString().trim();
    final ln = (data['lastName'] ?? data['nachname'] ?? '').toString().trim();
    if (fn.isNotEmpty || ln.isNotEmpty) return [fn, ln].where((x) => x.isNotEmpty).join(' ');
    final em = (data['email'] ?? '').toString().trim();
    if (em.isNotEmpty) return em;
    return 'Läufer ${d.id}';
  }
}
