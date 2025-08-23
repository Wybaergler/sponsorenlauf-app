import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});
  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _nameController = TextEditingController();
  final _teamNameController = TextEditingController();
  final _motivationController = TextEditingController();
  final _currentUser = FirebaseAuth.instance.currentUser;

  bool _isLoading = true;
  bool _isPublic = true;
  String _profileImageUrl = '';
  Uint8List? _selectedImageBytes;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (_currentUser == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection("Laufer")
          .doc(_currentUser.uid)
          .get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _nameController.text = data['name'] ?? '';
          _teamNameController.text = data['teamName'] ?? '';
          _motivationController.text = data['motivation'] ?? '';
          _isPublic = data['isPublic'] ?? true;
          _profileImageUrl = data['profileImageUrl'] ?? '';
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final bytes = await pickedFile.readAsBytes();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) return;

    img.Image resizedImage = img.copyResize(image, width: 800);
    final compressedBytes =
        Uint8List.fromList(img.encodeJpg(resizedImage, quality: 85));

    if (mounted) {
      setState(() {
        _selectedImageBytes = compressedBytes;
      });
    }
  }

  // HIER IST DIE EINZIGE ÄNDERUNG ZUM STABILEN CODE
  Future<void> _saveProfile() async {
    if (_currentUser == null) return;
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Der Name darf nicht leer sein.")));
      return;
    }

    showDialog(
        context: context,
        builder: (context) => const Center(child: CircularProgressIndicator()),
        barrierDismissible: false);

    String imageUrlToSave = _profileImageUrl;

    try {
      if (_selectedImageBytes != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child(_currentUser.uid);
        await ref.putData(_selectedImageBytes!);
        imageUrlToSave = await ref.getDownloadURL();
      }

      await FirebaseFirestore.instance
          .collection("Laufer")
          .doc(_currentUser.uid)
          .set({
        'name': _nameController.text.trim(),
        'teamName': _teamNameController.text.trim(),
        'motivation': _motivationController.text.trim(),
        'isPublic': _isPublic,
        'profileImageUrl': imageUrlToSave,
      }, SetOptions(merge: true));

      if (mounted) {
        // ZUERST den Ladekreis schließen
        Navigator.of(context).pop();
        // DANN zur Profilseite zurückkehren
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Ladekreis auch im Fehlerfall schließen
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Fehler beim Speichern: $e")));
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _teamNameController.dispose();
    _motivationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? backgroundImage;
    if (_selectedImageBytes != null) {
      backgroundImage = MemoryImage(_selectedImageBytes!);
    } else if (_profileImageUrl.isNotEmpty) {
      backgroundImage = NetworkImage(_profileImageUrl);
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Profil bearbeiten")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24.0),
              children: [
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: backgroundImage,
                        child: backgroundImage == null
                            ? const Icon(Icons.person,
                                size: 60, color: Colors.grey)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.secondary,
                          child: IconButton(
                              icon: const Icon(Icons.camera_alt,
                                  color: Colors.white),
                              onPressed: _pickImage),
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                        labelText: "Voller Name (Pflichtfeld)")),
                const SizedBox(height: 20),
                TextField(
                    controller: _teamNameController,
                    decoration: const InputDecoration(
                        labelText: "Teamname (optional)")),
                const SizedBox(height: 20),
                TextField(
                    controller: _motivationController,
                    decoration:
                        const InputDecoration(labelText: "Meine Motivation..."),
                    maxLines: 4),
                const SizedBox(height: 30),
                SwitchListTile(
                  title: const Text("Profil öffentlich anzeigen"),
                  subtitle: const Text(
                      "Dein Name und Bild erscheinen auf der Startseite."),
                  value: _isPublic,
                  onChanged: (bool value) => setState(() => _isPublic = value),
                  activeColor: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  onPressed: _saveProfile,
                  icon: const Icon(Icons.save),
                  label: const Text("Änderungen speichern"),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16)),
                )
              ],
            ),
    );
  }
}
