import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

class EditProfilePage extends StatefulWidget {
  static const routeName = '/edit_profile';
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  // Pflichtfelder
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _motivationCtrl = TextEditingController();
  final _targetLapsCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _houseNoCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  // Info
  String? _email;

  // Bild
  String _profileImageUrl = '';
  Uint8List? _selectedImageBytes;

  bool _isPublic = true;
  bool _isLoading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _motivationCtrl.dispose();
    _targetLapsCtrl.dispose();
    _streetCtrl.dispose();
    _houseNoCtrl.dispose();
    _zipCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    _email = user.email;

    try {
      final doc = await FirebaseFirestore.instance.collection("Laufer").doc(user.uid).get();
      final data = doc.data();

      if (data != null) {
        // Namen (mit Fallback)
        final first = (data['firstName'] ?? '').toString();
        final last  = (data['lastName'] ?? '').toString();
        if (first.isEmpty && last.isEmpty) {
          final dn = (data['name'] ?? data['displayName'] ?? '').toString().trim();
          final parts = dn.split(RegExp(r'\s+'));
          if (parts.isNotEmpty) _firstNameCtrl.text = parts.first;
          if (parts.length > 1) _lastNameCtrl.text = parts.sublist(1).join(' ');
        } else {
          _firstNameCtrl.text = first;
          _lastNameCtrl.text  = last;
        }

        _motivationCtrl.text = (data['motivation'] ?? '').toString();

        final tl = data['targetLaps'];
        if (tl is num) _targetLapsCtrl.text = tl.toInt().toString();
        if (tl is String && tl.trim().isNotEmpty) {
          final parsed = int.tryParse(tl.trim());
          if (parsed != null) _targetLapsCtrl.text = parsed.toString();
        }

        // Bild (altes Feld bevorzugen)
        final p1 = (data['profileImageUrl'] ?? '').toString().trim();
        final p2 = (data['photoUrl'] ?? '').toString().trim();
        _profileImageUrl = p1.isNotEmpty ? p1 : p2;

        // Public
        final ip = data['isPublic'];
        _isPublic = ip is bool ? ip : true;

        // Adresse
        final addr = (data['address'] ?? {}) as Map<String, dynamic>;
        _streetCtrl.text  = (addr['street'] ?? '').toString();
        _houseNoCtrl.text = (addr['number'] ?? '').toString();
        _zipCtrl.text     = (addr['zip'] ?? '').toString();
        _cityCtrl.text    = (addr['city'] ?? '').toString();
      }
    } catch (_) {
      // UI bleibt freundlich
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (pickedFile == null) return;

    final bytes = await pickedFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return;
    final resized = img.copyResize(decoded, width: 800);
    final compressed = Uint8List.fromList(img.encodeJpg(resized, quality: 85));

    if (!mounted) return;
    setState(() => _selectedImageBytes = compressed);
  }

  String? _reqText(String? v, String label) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return '$label ist erforderlich.';
    if (s.length < 2 && (label == 'Vorname' || label == 'Name' || label == 'Ort' || label == 'Strasse')) {
      return 'Zu kurz.';
    }
    return null;
  }

  String? _reqNumber(String? v, String label) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return '$label ist erforderlich.';
    if (!RegExp(r'^\d+$').hasMatch(s)) return '$label nur Ziffern.';
    return null;
  }

  String? _reqTargetLaps(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Anzahl Runden ist erforderlich.';
    final n = int.tryParse(s);
    if (n == null || n < 0) return 'Bitte eine nicht-negative Zahl eingeben.';
    return null;
  }

  Future<void> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    String imageUrl = _profileImageUrl;
    try {
      // Bild hochladen (alter Pfad)
      if (_selectedImageBytes != null) {
        final ref = FirebaseStorage.instance.ref().child('profile_images').child(user.uid);
        await ref.putData(_selectedImageBytes!, SettableMetadata(contentType: 'image/jpeg', cacheControl: 'no-cache'));
        imageUrl = await ref.getDownloadURL();
      }

      final first = _firstNameCtrl.text.trim();
      final last  = _lastNameCtrl.text.trim();
      final display = [first, last].where((e) => e.isNotEmpty).join(' ');
      final target = int.parse(_targetLapsCtrl.text.trim());

      final payload = <String, dynamic>{
        'firstName': first,
        'lastName': last,
        'displayName': display,
        'name': display, // Kompatibilität
        'motivation': _motivationCtrl.text.trim(),
        'isPublic': _isPublic,
        'profileImageUrl': imageUrl,
        'targetLaps': target,
        'updatedAt': FieldValue.serverTimestamp(),
        'address': {
          'street': _streetCtrl.text.trim(),
          'number': _houseNoCtrl.text.trim(),
          'zip': _zipCtrl.text.trim(),
          'city': _cityCtrl.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      };

      await FirebaseFirestore.instance.collection("Laufer").doc(user.uid).set(
        payload,
        SetOptions(merge: true),
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // loader
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profil erfolgreich gespeichert!'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      Navigator.of(context).pop(); // zurück
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // loader
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Speichern: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Profil bearbeiten')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              if (_email != null && _email!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Text(
                    _email!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                ),
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: _selectedImageBytes != null
                          ? MemoryImage(_selectedImageBytes!)
                          : (_profileImageUrl.isNotEmpty ? NetworkImage(_profileImageUrl) : null) as ImageProvider<Object>?,
                      child: (_selectedImageBytes == null && _profileImageUrl.isEmpty)
                          ? const Icon(Icons.person, size: 60, color: Colors.grey)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.secondary,
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt, color: Colors.white),
                          onPressed: _pickImage,
                        ),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstNameCtrl,
                      decoration: const InputDecoration(labelText: 'Vorname'),
                      textInputAction: TextInputAction.next,
                      validator: (v) => _reqText(v, 'Vorname'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lastNameCtrl,
                      decoration: const InputDecoration(labelText: 'Name'),
                      textInputAction: TextInputAction.next,
                      validator: (v) => _reqText(v, 'Name'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _motivationCtrl,
                decoration: const InputDecoration(labelText: 'Motivation'),
                maxLines: 3,
                validator: (v) => _reqText(v, 'Motivation'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _targetLapsCtrl,
                decoration: const InputDecoration(labelText: 'Anzahl Runden'),
                keyboardType: TextInputType.number,
                validator: _reqTargetLaps,
              ),
              const SizedBox(height: 16),
              Text('Adresse', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _streetCtrl,
                      decoration: const InputDecoration(labelText: 'Strasse'),
                      textInputAction: TextInputAction.next,
                      validator: (v) => _reqText(v, 'Strasse'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _houseNoCtrl,
                      decoration: const InputDecoration(labelText: 'Nr.'),
                      textInputAction: TextInputAction.next,
                      validator: (v) => _reqText(v, 'Nr.'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _zipCtrl,
                      decoration: const InputDecoration(labelText: 'PLZ'),
                      keyboardType: TextInputType.number,
                      validator: (v) => _reqNumber(v, 'PLZ'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _cityCtrl,
                      decoration: const InputDecoration(labelText: 'Ort'),
                      validator: (v) => _reqText(v, 'Ort'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Profil öffentlich anzeigen'),
                subtitle: const Text('Name & Bild dürfen auf der Startseite erscheinen.'),
                value: _isPublic,
                onChanged: (v) => setState(() => _isPublic = v),
                activeColor: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _saveProfile,
                  icon: const Icon(Icons.save),
                  label: Text(_saving ? 'Speichern…' : 'Speichern'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

