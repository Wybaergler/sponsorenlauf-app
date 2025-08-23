import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sponsorenlauf_app/pages/public_landing_page.dart'; // WICHTIGER NEUER IMPORT

class LoginPage extends StatefulWidget {
  final VoidCallback showRegisterPage;
  const LoginPage({super.key, required this.showRegisterPage});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<void> _signIn() async {
    showDialog(context: context, builder: (context) => const Center(child: CircularProgressIndicator()), barrierDismissible: false);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (mounted) Navigator.pop(context);
      _showErrorDialog(e.message ?? "Ein unbekannter Fehler ist aufgetreten.");
    }
  }

  void _showErrorDialog(String message) {
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text("Login fehlgeschlagen"), content: Text(message), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))]));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
                const Text(
                  'Als Läufer anmelden',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(hintText: 'E-Mail', prefixIcon: Icon(Icons.email_outlined, color: Colors.grey[500]), enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white), borderRadius: BorderRadius.all(Radius.circular(12))), focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade400), borderRadius: const BorderRadius.all(Radius.circular(12))), fillColor: Colors.white, filled: true),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(hintText: 'Passwort', prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[500]), enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white), borderRadius: BorderRadius.all(Radius.circular(12))), focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade400), borderRadius: const BorderRadius.all(Radius.circular(12))), fillColor: Colors.white, filled: true),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _signIn,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.secondary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                    ),
                    child: const Text('Einloggen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Noch kein Konto?', style: TextStyle(color: Colors.grey[700])),
                    TextButton(
                      onPressed: widget.showRegisterPage,
                      child: Text('Hier registrieren', style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextButton.icon(
                  // --- HIER IST DIE ANGEPASSTE LOGIK ---
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const PublicLandingPage()),
                      (Route<dynamic> route) => false,
                    );
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