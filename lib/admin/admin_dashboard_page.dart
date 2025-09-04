import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Pages
import 'package:sponsorenlauf_app/admin/sponsor_invoices_page.dart';
import 'package:sponsorenlauf_app/admin/final_accounting_page.dart'; // optionaler Button

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});
  static const routeName = '/admin_dashboard';

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late final StreamSubscription<User?> _authSub;
  User? _user;
  bool _isAdmin = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((u) async {
      setState(() {
        _user = u;
        _loading = true;
        _error = null;
        _isAdmin = false;
      });
      if (u != null) {
        await _checkAdmin(u);
      } else {
        setState(() => _loading = false);
      }
    });
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  Future<void> _checkAdmin(User u) async {
    try {
      final snap = await FirebaseFirestore.instance.collection('Laufer').doc(u.uid).get();
      final role = snap.data()?['role'];
      setState(() {
        _isAdmin = role == 'admin';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _isAdmin = false;
        _loading = false;
        _error = 'Konnte Admin-Status nicht prüfen: $e';
      });
    }
  }

  Future<void> _signOut() => FirebaseAuth.instance.signOut();

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      // Wichtig: kein `const` vor Scaffold
      return Scaffold(
        appBar: AppBar(title: const Text('Admin')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Nicht eingeloggt
    if (_user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin')),
        body: _CenteredCard(
          maxWidth: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.lock_outline, size: 48),
              SizedBox(height: 12),
              Text('Bitte zuerst anmelden.', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }

    // Kein Admin
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin')),
        body: _CenteredCard(
          maxWidth: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_encryption_gmailerrorred_outlined, size: 48),
              const SizedBox(height: 12),
              const Text('Kein Admin-Zugang.', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text('Setze auf „Laufer/{uid}“ das Feld role = "admin".'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout),
                label: const Text('Abmelden'),
              ),
            ],
          ),
        ),
      );
    }

    // Admin-Übersicht
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin-Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Abmelden',
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, c) {
                final isNarrow = c.maxWidth < 640;
                final buttonWidth = isNarrow ? double.infinity : 360.0;
                final spacing = isNarrow ? 12.0 : 16.0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text('Fehler: $_error', style: const TextStyle(color: Colors.red)),
                      ),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        _AdminActionButton(
                          width: buttonWidth,
                          icon: Icons.receipt_long,
                          title: 'Sponsor-Abrechnung (Preview)',
                          subtitle: 'Summen pro Sponsor + Details, CSV',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const SponsorInvoicesPage()),
                            );
                          },
                        ),
                        _AdminActionButton(
                          width: buttonWidth,
                          icon: Icons.calculate_outlined,
                          title: 'Finale Beträge (Preview)',
                          subtitle: 'Läufer-Summen (internes Preview)',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const FinalAccountingPage()),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Angemeldet als: ${_user?.email ?? _user?.uid}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminActionButton extends StatelessWidget {
  final double width;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;

  const _AdminActionButton({
    required this.width,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        elevation: 1.5,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Icon(Icons.apps)),
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(subtitle),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: onPressed,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Öffnen'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenteredCard extends StatelessWidget {
  final double maxWidth;
  final Widget child;
  const _CenteredCard({required this.maxWidth, required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}
