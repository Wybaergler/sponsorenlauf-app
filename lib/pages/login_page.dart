import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sponsorenlauf_app/pages/login_success_page.dart';
import 'package:sponsorenlauf_app/pages/public_landing_page.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback showRegisterPage;
  const LoginPage({super.key, required this.showRegisterPage});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Form + Validierung
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
    if ((v ?? '').isEmpty) return 'Bitte Passwort eingeben.';
    if ((v ?? '').length < 6) return 'Mindestens 6 Zeichen.';
    return null;
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Die E-Mail-Adresse ist ungültig.';
      case 'user-disabled':
        return 'Dieses Konto wurde deaktiviert.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-Mail oder Passwort ist falsch.';
      case 'too-many-requests':
        return 'Zu viele Versuche. Bitte später erneut versuchen.';
      case 'network-request-failed':
        return 'Keine Netzwerkverbindung.';
      case 'operation-not-allowed':
        return 'E-Mail/Passwort-Anmeldung ist nicht aktiviert.';
      default:
        return 'Anmeldung fehlgeschlagen. Bitte später erneut versuchen.';
    }
  }

  Future<void> _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final nav = Navigator.of(context);
    setState(() => _loading = true);

    // Ladeindikator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;
      nav.pop(); // Loader schließen
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginSuccessPage()),
            (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      nav.pop(); // Loader schließen
      _showErrorDialog(_friendlyAuthError(e));
    } catch (_) {
      if (!mounted) return;
      nav.pop(); // Loader schließen
      _showErrorDialog('Unerwarteter Fehler. Bitte später erneut versuchen.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final typed = _emailController.text.trim();
    final email = typed.isNotEmpty ? typed : await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Passwort zurücksetzen'),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'E-Mail',
              hintText: 'name@example.com',
            ),
            autofillHints: const [AutofillHints.email],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Abbrechen')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()), child: const Text('Senden')),
          ],
        );
      },
    );

    if (email == null || email.isEmpty) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-Mail zum Zurücksetzen gesendet.')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showErrorDialog(switch (e.code) {
        'invalid-email' => 'Die E-Mail-Adresse ist ungültig.',
        'user-not-found' => 'Kein Konto mit dieser E-Mail gefunden.',
        'network-request-failed' => 'Keine Netzwerkverbindung.',
        _ => 'Konnte E-Mail nicht senden. Bitte später erneut versuchen.',
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Login fehlgeschlagen"),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar ohne Farb-Overrides -> nutzt euer app_theme.dart / colorScheme
      appBar: AppBar(
        title: const Text('Anmelden'),
        elevation: 0,
      ),
      backgroundColor: Colors.grey[200], // wie im Original
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

                  // Kurze Subline (statt großem Formular-Titel)
                  Text(
                    'Melde dich als Läufer an.',
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
                    obscureText: _obscure,
                    enableSuggestions: false,
                    autocorrect: false,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => _signIn(),
                    decoration: InputDecoration(
                      labelText: 'Passwort',
                      prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[500]),
                      suffixIcon: IconButton(
                        tooltip: _obscure ? 'Passwort anzeigen' : 'Passwort ausblenden',
                        icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscure = !_obscure),
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

                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _loading ? null : _resetPassword,
                      child: const Text('Passwort vergessen?'),
                    ),
                  ),

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _signIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.secondary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _loading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Einloggen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),

                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Noch kein Konto?', style: TextStyle(color: Colors.grey[700])),
                      TextButton(
                        onPressed: _loading ? null : widget.showRegisterPage,
                        child: Text(
                          'Registrieren',
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
                            (route) => false,
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
