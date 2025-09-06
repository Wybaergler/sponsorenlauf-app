import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class EditProfilePage extends StatefulWidget {
  static const routeName = '/edit_profile';
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  final _motivationCtrl= TextEditingController();

  final _streetCtrl = TextEditingController();
  final _zipCtrl    = TextEditingController();
  final _cityCtrl   = TextEditingController();
  final _countryCtrl= TextEditingController(text: 'CH');

  bool _loading = true;
  bool _saving  = false;

  String? _imageUrl;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _motivationCtrl.dispose();
    _streetCtrl.dispose();
    _zipCtrl.dispose();
    _cityCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) { setState(() => _loading = false); return; }
    try {
      final snap = await FirebaseFirestore.instance.collection('Laufer').doc(uid).get();
      final m = (snap.data() ?? <String, dynamic>{});

      String _firstString(List<String> keys) {
        for (final k in keys) {
          final v = m[k];
          if (v is String && v.trim().isNotEmpty) return v.trim();
        }
        return '';
      }

      Map<String, dynamic> _map(String key) =>
          (m[key] is Map<String, dynamic>) ? (m[key] as Map<String, dynamic>) : <String, dynamic>{};

      _firstNameCtrl.text = _firstString(['firstName', 'vorname']);
      _lastNameCtrl.text  = _firstString(['lastName', 'nachname', 'name']);
      _motivationCtrl.text= _firstString(['motivation', 'motto', 'about']);

      final addr = _map('address');
      _streetCtrl.text  = (addr['street'] ?? m['street'] ?? '').toString();
      _zipCtrl.text     = (addr['zip'] ?? m['zip'] ?? '').toString();
      _cityCtrl.text    = (addr['city'] ?? m['city'] ?? '').toString();
      _countryCtrl.text = (addr['country'] ?? m['country'] ?? 'CH').toString();

      _imageUrl = (m['imageUrl'] ?? m['photoUrl'])?.toString();
    } catch (_) {
      // Felder bleiben leer
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Pflichtfeld' : null;
  String? _zip(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Pflichtfeld';
    final ok = RegExp(r'^\d{4}$').hasMatch(t); // CH-PLZ
    return ok ? null : 'PLZ (4 Ziffern)';
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        'firstName': _firstNameCtrl.text.trim(),
        'vorname':   _firstNameCtrl.text.trim(),
        'lastName':  _lastNameCtrl.text.trim(),
        'nachname':  _lastNameCtrl.text.trim(),

        'motivation': _motivationCtrl.text.trim(),
        'motto':      _motivationCtrl.text.trim(),

        'address': {
          'street':  _streetCtrl.text.trim(),
          'zip':     _zipCtrl.text.trim(),
          'city':    _cityCtrl.text.trim(),
          'country': _countryCtrl.text.trim().isEmpty ? 'CH' : _countryCtrl.text.trim(),
        },
        'street':  _streetCtrl.text.trim(),
        'zip':     _zipCtrl.text.trim(),
        'city':    _cityCtrl.text.trim(),
        'country': _countryCtrl.text.trim().isEmpty ? 'CH' : _countryCtrl.text.trim(),
      };

      await FirebaseFirestore.instance.collection('Laufer').doc(uid).set(
        data,
        SetOptions(merge: true),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil gespeichert.')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler beim Speichern: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      setState(() => _uploadingPhoto = true);
      final XFile? x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600);
      if (x == null) { setState(() => _uploadingPhoto = false); return; }
      Uint8List bytes = await x.readAsBytes();
      final ref = FirebaseStorage.instance.ref().child('profile_photos/$uid.jpg');
      final meta = SettableMetadata(contentType: 'image/jpeg', cacheControl: 'public,max-age=604800');
      await ref.putData(bytes, meta);
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance.collection('Laufer').doc(uid).set({
        'imageUrl': url,
        'photoUrl': url,
      }, SetOptions(merge: true));
      if (!mounted) return;
      setState(() => _imageUrl = url);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto aktualisiert.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Foto-Upload fehlgeschlagen: $e')));
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: Colors.white),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: Colors.blue),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final initials = (() {
      final f = _firstNameCtrl.text.trim();
      final l = _lastNameCtrl.text.trim();
      return ((f.isNotEmpty ? f[0] : '') + (l.isNotEmpty ? l[0] : '')).toUpperCase();
    })();

    return Scaffold(
      appBar: AppBar(title: const Text('Profil bearbeiten')),
      backgroundColor: Colors.grey.shade200,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.grey.shade300,
                          backgroundImage: (_imageUrl != null && _imageUrl!.isNotEmpty)
                              ? NetworkImage(_imageUrl!)
                              : null,
                          child: (_imageUrl == null || _imageUrl!.isEmpty)
                              ? Text(initials, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _uploadingPhoto ? null : _pickAndUploadPhoto,
                            icon: _uploadingPhoto
                                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.photo),
                            label: Text(_uploadingPhoto ? 'Lade Foto…' : 'Foto ändern'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: _firstNameCtrl,
                          decoration: _dec('Vorname'),
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          validator: _req,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _lastNameCtrl,
                          decoration: _dec('Nachname'),
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          validator: _req,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _motivationCtrl,
                      decoration: _dec('Motivation (optional)', hint: 'Warum läufst du mit?'),
                      maxLines: 3,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 20),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Adresse', style: Theme.of(context).textTheme.titleMedium),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _streetCtrl,
                      decoration: _dec('Strasse und Nr.'),
                      textInputAction: TextInputAction.next,
                      validator: _req,
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      SizedBox(
                        width: 120,
                        child: TextFormField(
                          controller: _zipCtrl,
                          decoration: _dec('PLZ'),
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          validator: _zip,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _cityCtrl,
                          decoration: _dec('Ort'),
                          textInputAction: TextInputAction.next,
                          validator: _req,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 100,
                        child: TextFormField(
                          controller: _countryCtrl,
                          decoration: _dec('Land'),
                          textInputAction: TextInputAction.done,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.save),
                        label: Text(_saving ? 'Speichere…' : 'Speichern'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
