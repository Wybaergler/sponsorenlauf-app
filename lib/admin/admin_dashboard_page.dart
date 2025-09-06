import 'package:flutter/material.dart';

// Seiten einbinden (existieren bereits)
import 'counting_station_page.dart';
import 'start_number_manager_page.dart';
import 'final_accounting_page.dart';
import 'sponsor_invoices_page.dart';

class AdminDashboardPage extends StatelessWidget {
  static const routeName = '/admin_dashboard';
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Einheitliche Button-Styles (blau/weiß)
    final primaryBtn = ElevatedButton.styleFrom(
      minimumSize: const Size(220, 48),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Admin-Dashboard')),
      backgroundColor: Colors.grey.shade100,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionHeader('Laufsteuerung'),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _DashboardCard(
                    title: 'Zählerstation öffnen',
                    subtitle: 'Runden erfassen im Browser (mobil & Desktop).',
                    icon: Icons.fact_check,
                    child: SizedBox(
                      width: 220,
                      child: ElevatedButton.icon(
                        style: primaryBtn,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CountingStationPage()),
                        ),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Zählerstation'),
                      ),
                    ),
                  ),
                  _DashboardCard(
                    title: 'Startnummern vergeben',
                    subtitle: 'Startnummern zu Läufer:innen zuweisen.',
                    icon: Icons.confirmation_number_outlined,
                    child: SizedBox(
                      width: 220,
                      child: ElevatedButton.icon(
                        style: primaryBtn,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const StartNumberManagerPage()),
                        ),
                        icon: const Icon(Icons.edit),
                        label: const Text('Startnummern'),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              _SectionHeader('Abrechnung'),

              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _DashboardCard(
                    title: 'Finale Beträge (Gesamt)',
                    subtitle: 'Vorschau der Gesamtabrechnung pro Läufer.',
                    icon: Icons.summarize_outlined,
                    child: SizedBox(
                      width: 220,
                      child: ElevatedButton.icon(
                        style: primaryBtn,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const FinalAccountingPage()),
                        ),
                        icon: const Icon(Icons.preview),
                        label: const Text('Gesamt-Vorschau'),
                      ),
                    ),
                  ),
                  _DashboardCard(
                    title: 'Sponsor-Abrechnung & E-Mail',
                    subtitle: 'Gruppiert nach Sponsor • Versand per E-Mail.',
                    icon: Icons.email_outlined,
                    child: SizedBox(
                      width: 220,
                      child: ElevatedButton.icon(
                        style: primaryBtn,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SponsorInvoicesPage()),
                        ),
                        icon: const Icon(Icons.mail),
                        label: const Text('Abrechnung & Mail'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ——— Kleine Hilfs-Widgets für aufgeräumtes Layout ———

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  const _DashboardCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 12),
                    child,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
