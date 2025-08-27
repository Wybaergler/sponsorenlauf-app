import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum SponsoringType { perLap, fixed }

class SponsoringPage extends StatefulWidget {
  static const routeName = '/sponsorship';
  final String runnerId;
  final String? sponsorshipId;

  const SponsoringPage({
    super.key,
    required this.runnerId,
    this.sponsorshipId,
  });

  @override
  State<SponsoringPage> createState() => _SponsoringPageState();
}

class _SponsoringPageState extends State<SponsoringPage> {
  late Future<DocumentSnapshot> _runnerFuture;
  final _formKey = GlobalKey<FormState>();
  SponsoringType _sponsoringType = SponsoringType.perLap;

  final _sponsorNameController = TextEditingController();
  final _sponsorEmailController = TextEditingController();
  final _amountController = TextEditingController();

  bool get _isEditMode => widget.sponsorshipId != null;
  bool get _isOpenedByRunner => FirebaseAuth.instance.currentUser != null;

  @override
  void initState() {
    super.initState();
    String runnerIdForFuture = widget.runnerId;

    if (_isEditMode && runnerIdForFuture.isEmpty) {
      _runnerFuture = _loadRunnerIdFromSponsorship().then((id) {
        runnerIdForFuture = id;
        return FirebaseFirestore.instance.collection('Laufer').doc(id).get();
      });
    } else {
      _runnerFuture = FirebaseFirestore.instance.collection('Laufer').doc(runnerIdForFuture).get();
    }

    if (_isEditMode) {
      _loadSponsorshipData();
    }
  }

  Future<String> _loadRunnerIdFromSponsorship() async {
    if (widget.sponsorshipId == null) return '';
    try {
      final doc = await FirebaseFirestore.instance.collection('Spenden').doc(widget.sponsorshipId).get();
      return doc.data()?['runnerId'] ?? '';
    } catch (e) {
      return '';
    }
  }

  Future<void> _loadSponsorshipData() async {
    if (widget.sponsorshipId == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('Spenden').doc(widget.sponsorshipId).get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _sponsorNameController.text = data['sponsorName'] ?? '';
          _sponsorEmailController.text = data['sponsorEmail'] ?? '';
          _amountController.text = (data['amount'] ?? 0.0).toString();
          _sponsoringType = (data['sponsoringType'] == 'fixed') ? SponsoringType.fixed : SponsoringType.perLap;
        });
      }
    } catch (e) {
      debugPrint("Fehler beim Laden der Sponsoring-Daten: $e");
    }
  }

  @override
  void dispose() {
    _sponsorNameController.dispose();
    _sponsorEmailController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<Map<String, String>> _getRunnerData() async {
    try {
      final runnerDoc = await FirebaseFirestore.instance.collection('Laufer').doc(widget.runnerId).get();
      if (runnerDoc.exists) {
        return {
          'name': runnerDoc.data()?['name'] ?? 'Einem Läufer',
          'email': runnerDoc.data()?['email'] ?? '',
        };
      }
    } catch (e) {
      debugPrint("Fehler beim Laden der Läufer-Daten: $e");
    }
    return {'name': 'Einem Läufer', 'email': ''};
  }

  Future<void> _submitSponsorship() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    showDialog(context: context, builder: (context) => const Center(child: CircularProgressIndicator()));

    try {
      final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
      final bool wasAddedByRunner = !_isEditMode && _isOpenedByRunner;
      final Map<String, dynamic> sponsorshipData = {
        'runnerId': widget.runnerId,
        'sponsorName': _sponsorNameController.text.trim(),
        'sponsorEmail': _sponsorEmailController.text.trim(),
        'amount': amount,
        'sponsoringType': _sponsoringType.name,
      };

      String sponsorshipDocId;

      if (_isEditMode) {
        sponsorshipDocId = widget.sponsorshipId!;
        await FirebaseFirestore.instance.collection('Spenden').doc(sponsorshipDocId).update(sponsorshipData);
      } else {
        sponsorshipData['createdAt'] = FieldValue.serverTimestamp();
        sponsorshipData['addedByRunner'] = wasAddedByRunner;
        final docRef = await FirebaseFirestore.instance.collection('Spenden').add(sponsorshipData);
        sponsorshipDocId = docRef.id;
      }

      if (!_isEditMode) {
        final runnerData = await _getRunnerData();
        final runnerName = runnerData['name']!;
        final runnerEmail = runnerData['email']!;
        final projectId = FirebaseFirestore.instance.app.options.projectId;
        String zusageText;
        if (_sponsoringType == SponsoringType.fixed) {
          zusageText = "einen Fixbetrag von <b>CHF ${amount.toStringAsFixed(2)}</b>";
        } else {
          zusageText = "einen Betrag von <b>CHF ${amount.toStringAsFixed(2)} pro Runde</b>";
        }

        String sponsorshipLinkHtml = '';
        if (!wasAddedByRunner) {
          sponsorshipLinkHtml = '<p>Sollten Sie Ihre Zusage bearbeiten wollen, können Sie dies über den folgenden Link tun:</p><p><a href="https://$projectId.web.app/sponsorship/$sponsorshipDocId">Ihre Zusage bearbeiten</a></p>';
        }

        await FirebaseFirestore.instance.collection('mail').add({
          'to': [_sponsorEmailController.text.trim()],
          'message': {
            'subject': 'Bestätigung Ihrer Unterstützung für den Sponsorenlauf!',
            'html': '''
              <p>Hallo ${_sponsorNameController.text.trim()},</p>
              <p>vielen Dank für Ihre Zusage, <b>$runnerName</b> beim Sponsorenlauf der EVP mit $zusageText zu unterstützen.</p>
              <p>Ihre Zusage wurde erfolgreich erfasst. Der Läufer $runnerName wurde ebenfalls direkt per E-Mail informiert. Nach dem Lauf werden wir Sie über den finalen Spendenbetrag informieren.</p>
              $sponsorshipLinkHtml
              <p>Mit freundlichen Grüssen,<br>Ihr Sponsorenlauf-Team</p>
            ''',
          },
        });

        if (runnerEmail.isNotEmpty) {
          await FirebaseFirestore.instance.collection('mail').add({
            'to': [runnerEmail],
            'message': {
              'subject': 'Neue Unterstützung für Ihren Sponsorenlauf!',
              'html': '<p>Hallo $runnerName,</p><p>Gute Nachrichten! <b>${_sponsorNameController.text.trim()}</b> hat soeben eine neue Spendenzusage für Sie gemacht: $zusageText.</p><p>Sie können alle Ihre Sponsoren in Ihrem Dashboard in der App einsehen.</p><p>Weiterhin viel Erfolg beim Sammeln!</p>',
            },
          });
        }
      }

      if (mounted) {
        Navigator.pop(context);
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ein Fehler ist aufgetreten: $e")));
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Vielen Dank!"),
        content: Text(
          _isEditMode
              ? "Die Zusage wurde erfolgreich aktualisiert."
              : "Ihre Zusage wurde erfolgreich gespeichert. Eine Bestätigung wurde an die angegebene E-Mail Adresse gesendet.",
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? "Sponsor bearbeiten" : (_isOpenedByRunner ? "Sponsor erfassen" : "Läufer unterstützen")),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: _runnerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Läuferinformationen konnten nicht geladen werden."));
          }

          final runnerData = snapshot.data!.data() as Map<String, dynamic>;
          final name = runnerData['name'] ?? 'Unbekannter Läufer';
          final imageUrl = runnerData['profileImageUrl'] ?? '';
          final motivation = runnerData['motivation'] ?? 'Keine Angabe';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_isOpenedByRunner || _isEditMode)
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                            child: imageUrl.isEmpty ? const Icon(Icons.person, size: 50, color: Colors.grey) : null,
                          ),
                          const SizedBox(height: 16),
                          Text("Sie unterstützen:", style: TextStyle(color: Colors.grey[600])),
                          const SizedBox(height: 4),
                          Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          if (motivation.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 16),
                            Text('"$motivation"', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic)),
                          ]
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    _isEditMode ? "Zusage bearbeiten" : "Spendenzusage",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 20),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Column(
                        children: [
                          SegmentedButton<SponsoringType>(
                            segments: const [
                              ButtonSegment(value: SponsoringType.perLap, label: Text("Pro Runde")),
                              ButtonSegment(value: SponsoringType.fixed, label: Text("Fixbetrag")),
                            ],
                            selected: {_sponsoringType},
                            onSelectionChanged: (newSelection) {
                              setState(() {
                                _sponsoringType = newSelection.first;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: 200,
                            child: TextFormField(
                              controller: _amountController,
                              textAlign: TextAlign.center,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                              decoration: InputDecoration(
                                hintText: "${_sponsoringType == SponsoringType.fixed ? "Spendenbetrag (CHF)" : "Betrag pro Runde (CHF)"} *",
                                hintStyle: TextStyle(color: Colors.grey[600]),
                                floatingLabelBehavior: FloatingLabelBehavior.never,
                                border: const OutlineInputBorder(),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Theme.of(context).colorScheme.secondary),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Bitte Betrag angeben.';
                                if (double.tryParse(value) == null) return 'Ungültige Zahl.';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _sponsorNameController,
                        decoration: const InputDecoration(
                          labelText: "Name des Sponsors *",
                        ),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Bitte den Namen des Sponsors angeben.' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _sponsorEmailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: "E-Mail des Sponsors *",
                          helperText: _isOpenedByRunner
                              ? "Gib die E-Mail des Sponsors an oder deine eigene, falls die Abrechnung über dich laufen soll."
                              : "Wird für die Bestätigung und Abrechnung verwendet.",
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Bitte eine E-Mail angeben.';
                          final emailRegExp = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                          if (!emailRegExp.hasMatch(value)) return 'Bitte eine gültige E-Mail angeben.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: _submitSponsorship,
                        child: Text(_isEditMode ? "Änderungen speichern" : "Spendenzusage abschicken"),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}