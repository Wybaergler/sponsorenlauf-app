import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sponsorenlauf_app/pages/public_landing_page.dart';

class RegisterPage extends StatefulWidget {
  // NEU: Definiert den "Straßennamen" für diese Seite
  static const routeName = '/register';

  final VoidCallback showLoginPage;
  const RegisterPage({super.key, required this.showLoginPage});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  Future<void> _signUp() async {
    final dialogContext = context;
    showDialog(context: dialogContext, builder: (context) => const Center(child: CircularProgressIndicator()), barrierDismissible: false);

    if (_passwordController.text != _confirmPasswordController.text) {
      Navigator.pop(dialogContext);
      _showErrorDialog("Die Passwörter stimmen nicht überein.");
      return;
    }

    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: _emailController.text.trim(), password: _passwordController.text.trim());
      await FirebaseFirestore.instance.collection("Laufer").doc(userCredential.user!.uid).set({'uid': userCredential.user!.uid, 'email': _emailController.text.trim(), 'name': '', 'teamName': '', 'motivation': '', 'profileImageUrl': '', 'isPublic': true, 'role': 'user'});
      final projectId = FirebaseFirestore.instance.app.options.projectId;
      await FirebaseFirestore.instance.collection("mail").add({
        'to': [_emailController.text.trim()],
        'message': {
          'subject': 'Willkommen beim EVP Sponsorenlauf!',
          'html': '<p>Hallo!</p><p>Dein persönlicher Sponsoring-Link:</p><p><a href="https://<deine-domain>.ch/sponsor/${userCredential.user!.uid}">https://<deine-domain>.ch/sponsor/${userCredential.user!.uid}</a></p><p>Dein Sponsorenlauf-Team</p>',
        },
      });

      if (mounted) {
        Navigator.pop(dialogContext); // Ladekreis entfernen
        // Die Navigation wird jetzt vom AuthGate übernommen.
      }

    } on FirebaseAuthException catch (e) {
      if (mounted) {
        Navigator.pop(dialogContext);
        _showErrorDialog(e.message ?? "Ein unbekannter Fehler ist aufgetreten.");
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text("Registrierung fehlgeschlagen"), content: Text(message), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))]));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(elevation: 0, backgroundColor: Colors.transparent, foregroundColor: Colors.grey[800]),
      backgroundColor: Colors.grey[200],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/images/logo.png', height: 150),
                const SizedBox(height: 50),
                const Text('Als Läufer neu registrieren', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(hintText: 'E-Mail', prefixIcon: Icon(Icons.email_outlined, color: Colors.grey[500]), enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white), borderRadius: BorderRadius.all(Radius.circular(12))), focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade400), borderRadius: const BorderRadius.all(Radius.circular(12))), fillColor: Colors.white, filled: true)),
                const SizedBox(height: 10),
                TextField(controller: _passwordController, obscureText: true, decoration: InputDecoration(hintText: 'Passwort', prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[500]), enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white), borderRadius: BorderRadius.all(Radius.circular(12))), focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade400), borderRadius: const BorderRadius.all(Radius.circular(12))), fillColor: Colors.white, filled: true)),
                const SizedBox(height: 10),
                TextField(controller: _confirmPasswordController, obscureText: true, decoration: InputDecoration(hintText: 'Passwort bestätigen', prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[500]), enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white), borderRadius: BorderRadius.all(Radius.circular(12))), focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade400), borderRadius: const BorderRadius.all(Radius.circular(12))), fillColor: Colors.white, filled: true)),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _signUp, style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.secondary, foregroundColor: Colors.white, padding: const EdgeInsets.all(20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Registrieren', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Bereits ein Konto?', style: TextStyle(color: Colors.grey[700])),
                    TextButton(onPressed: widget.showLoginPage, child: Text('Hier einloggen', style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold))),
                  ],
                ),
                const SizedBox(height: 20),
                TextButton.icon(
                  onPressed: () {
                    // GEÄNDERT: Saubere Navigation zur Startseite
                    Navigator.popAndPushNamed(context, PublicLandingPage.routeName);
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text("Zurück zum Sponsorenlauf"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}