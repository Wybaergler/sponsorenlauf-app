import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sponsorenlauf_app/pages/public_landing_page.dart';
import 'package:sponsorenlauf_app/pages/registration_success_page.dart';

class RegisterPage extends StatefulWidget {
  final VoidCallback showLoginPage;
  const RegisterPage({super.key, required this.showLoginPage});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Neu: Form + Validierung
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Bitte E-Mail eingeben.';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
    if (!ok) return 'Die E-Mail-Adresse ist ungültig.';
    return null;
  }

  String? _validatePassword(String? v) {
    final s = (v ?? '');
    if (s.isEmpty) return 'Bitte Passwort eingeben.';
    if (s.length < 6) return 'Mindestens 6 Zeichen.';
    return null;
  }

  String? _validateConfirm(String? v) {
    final s = (v ?? '');
    if (s.isEmpty) return 'Bitte Passwort bestätigen.';
    if (s != _passwordController.text) return 'Die Passwörter stimmen nicht überein.';
    return null;
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Mit dieser E-Mail gibt es bereits ein Konto.';
      case 'invalid-email':
        return 'Die E-Mail-Adresse ist ungültig.';
      case 'weak-password':
        return 'Passwort ist zu schwach (mind. 6 Zeichen).';
      case 'operation-not-allowed':
        return 'E-Mail/Passwort-Registrierung ist nicht aktiviert.';
      case 'network-request-failed':
        return 'Keine Netzwerkverbindung.';
      default:
        return 'Registrierung fehlgeschlagen. Bitte später erneut versuchen.';
    }
  }

  Future<void> _signUp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final nav = Navigator.of(context);
    setState(() => _loading = true);

    // Ladeindikator (in jedem Pfad wieder schließen)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Firestore-Profil anlegen (wie in deinem Code)
      await FirebaseFirestore.instance.collection("Laufer").doc(credential.user!.uid).set({
        'uid': credential.user!.uid,
        'email': _emailController.text.trim(),
        'name': '',
        'teamName': '',
        'motivation': '',
        'profileImageUrl': '',
        'isPublic': true,
        'role': 'user',
      });

      // Begrüssungs-Mail (wie in deinem Code)
      await FirebaseFirestore.instance.collection("mail").add({
        'to': [_emailController.text.trim()],
        'message': {
          'subject': 'Willkommen beim EVP Sponsorenlauf!',
          'html': '<p>Hallo!</p><p>Vielen Dank für deine Registrierung.</p>',
        },
      });

      if (!mounted) return;
      nav.pop(); // Loader schließen
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const RegistrationSuccessPage()),
            (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      nav.pop(); // Loader schließen
      _showErrorDialog(_friendlyAuthError(e));
    } catch (e) {
      if (!mounted) return;
      nav.pop(); // Loader schließen
      _showErrorDialog('Unerwarteter Fehler. Bitte später erneut versuchen.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Registrierung fehlgeschlagen"),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Konsistente AppBar (Farben via app_theme.dart / colorScheme)
      appBar: AppBar(
        title: const Text('Registrieren'),
        elevation: 0,
      ),
      backgroundColor: Colors.grey[200], // wie bei dir
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/logo.png', height: 150),
                  const SizedBox(height: 24),

                  // Subline statt großem Formular-Titel
                  Text(
                    'Erstelle dein Läufer-Konto.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),

                  // E-Mail
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: InputDecoration(
                      labelText: 'E-Mail',
                      hintText: 'name@example.com',
                      prefixIcon: Icon(Icons.email_outlined, color: Colors.grey[500]),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey).copyWith(width: 1),
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                      ),
                      fillColor: Colors.white,
                      filled: true,
                    ),
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 10),

                  // Passwort
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePass,
                    enableSuggestions: false,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: 'Passwort',
                      prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[500]),
                      suffixIcon: IconButton(
                        tooltip: _obscurePass ? 'Passwort anzeigen' : 'Passwort ausblenden',
                        icon: Icon(_obscurePass ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscurePass = !_obscurePass),
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey).copyWith(width: 1),
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                      ),
                      fillColor: Colors.white,
                      filled: true,
                    ),
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: 10),

                  // Passwort bestätigen
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirm,
                    enableSuggestions: false,
                    autocorrect: false,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _signUp(),
                    decoration: InputDecoration(
                      labelText: 'Passwort bestätigen',
                      prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[500]),
                      suffixIcon: IconButton(
                        tooltip: _obscureConfirm ? 'Passwort anzeigen' : 'Passwort ausblenden',
                        icon: Icon(_obscureConfirm ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey).copyWith(width: 1),
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                      ),
                      fillColor: Colors.white,
                      filled: true,
                    ),
                    validator: _validateConfirm,
                  ),

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _signUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.secondary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _loading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Registrieren', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),

                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Bereits ein Konto?', style: TextStyle(color: Colors.grey[700])),
                      TextButton(
                        onPressed: _loading ? null : widget.showLoginPage,
                        child: Text(
                          'Zum Login',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  TextButton.icon(
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
      ),
    );
  }
}
