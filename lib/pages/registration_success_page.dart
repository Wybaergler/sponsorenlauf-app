import 'package:flutter/material.dart';
import 'package:sponsorenlauf_app/auth/auth_gate.dart';
import 'package:sponsorenlauf_app/pages/public_landing_page.dart';

class RegistrationSuccessPage extends StatelessWidget {
  static const routeName = '/registration_success';
  const RegistrationSuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 100, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(height: 24),
                const Text("Registrierung erfolgreich!", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                const Text(
                  "Du hast Dich erfolgreich als Läufer für unseren Sponsorenlauf registriert, herzliche willkommen und vielen Dank. Du hast soeben eine E-Mail erhalten (siehe eventuell auch im SPAM Ordner nach). In der E-Mail findest du einen Link zu dieser App und auch einen persönlichen Sponsorenlink.\n\n"
                      "Erzähle Deinen Freunden, Verwandten und Bekannten über E-Mail, WhatsApp, Instagram und und und, dass Du am Sponsorenlauf mitmachst und bitte um die finanzielle Unterstützung für Deine Sponsorenlauf-Runden! Du kannst einfach deinen Sponsorenlink teilen und jeder kann direkt Online Spenden für Deinen Lauf zusagen.\n\n"
                      "Wichtig aber: gehe vorher jetzt sofort und auf deine persönliche Läuferseite und ergänze Dein Profil mit einem Foto, Deinem Namen und Deiner Motivation. Dann erfahren Deine Sponsoren sofort mehr über Dich wenn Sie auf Deine persönliche Spendenseite kommen.\n\n"
                      "Auf deiner persönlichen Läuferseite kannst Du aber noch viel mehr: du siehst dort sofort wer für Dich eine Sponsorenzusage gemacht hat. Wenn Dir jemand mündlich eine Sponsorenzusage macht kann Du diese dort erfassen. Später nach dem Lauf siehst Du dann alles über Deine Runden und das Gesamtergebnis pro Sponsor.\n\n"
                      "Also: gehe jetzt sofort auf deine persönliche Läuferseite, ergänze Dein Profil dann erzähl über Deinen Einsatz und frage um Sponsoren-Unterstützung nach!! Viel Spass",
                  textAlign: TextAlign.justify,
                  style: TextStyle(fontSize: 16, height: 1.5),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const AuthGate()), (route) => false),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    child: const Text("Zu meiner Läufer-Seite"),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const PublicLandingPage()), (route) => false),
                  child: const Text("Zurück zur Startseite"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}