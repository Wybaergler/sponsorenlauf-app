import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class StartNumberEditPage extends StatefulWidget {
  final String runnerId;
  final String displayName;
  final int? current;

  const StartNumberEditPage({
    super.key,
    required this.runnerId,
    required this.displayName,
    required this.current,
  });

  @override
  State<StartNumberEditPage> createState() => _StartNumberEditPageState();
}

class _StartNumberEditPageState extends State<StartNumberEditPage> {
  late final TextEditingController _ctrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.current?.toString() ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save({bool clear = false}) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      int? value;
      if (!clear) {
        final t = _ctrl.text.trim();
        value = t.isEmpty ? null : int.tryParse(t);
        if (t.isNotEmpty && value == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bitte eine gültige Zahl eingeben.')),
            );
          }
          setState(() => _saving = false);
          return;
        }
      }
      await FirebaseFirestore.instance
          .collection('Laufer')
          .doc(widget.runnerId)
          .set({'startNumber': clear ? null : value}, SetOptions(merge: true));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = 'Startnummer – ${widget.displayName}';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Startnummer (leer = entfernen)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saving ? null : () => _save(clear: false),
                    icon: _saving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save),
                    label: const Text('Speichern'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _saving ? null : () => _save(clear: true),
                  icon: const Icon(Icons.delete),
                  label: const Text('Entfernen'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
