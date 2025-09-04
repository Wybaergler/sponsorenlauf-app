import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FinalAccountingPage extends StatelessWidget {
  const FinalAccountingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Abrechnung – Vorschau (Beta)')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('Laufer')
            .orderBy('startNumber', descending: false)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Fehler: ${snap.error}'));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('Keine Läufer gefunden.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final d = docs[i].data();
              final name = (d['name'] ?? '').toString();
              final start = d['startNumber'];
              final email = (d['email'] ?? '').toString();
              final startTxt = (start is num) ? start.toInt().toString() : '–';
              return ListTile(
                leading: CircleAvatar(child: Text(startTxt)),
                title: Text(name.isEmpty ? docs[i].id : name),
                subtitle: Text(email),
              );
            },
          );
        },
      ),
    );
  }
}
