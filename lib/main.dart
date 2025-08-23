import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sponsorenlauf_app/auth/auth_gate.dart';
import 'package:sponsorenlauf_app/pages/edit_profile_page.dart';
import 'package:sponsorenlauf_app/pages/profile_page.dart';
import 'package:sponsorenlauf_app/pages/public_landing_page.dart';
import 'package:sponsorenlauf_app/pages/sponsoring_page.dart'; // Wichtiger Import für die Route
import 'package:sponsorenlauf_app/theme/app_theme.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sponsorenlauf App',
      theme: AppTheme.theme,
      
      // ANPASSUNG: Wir definieren die "Straßenkarte" unserer App
      initialRoute: '/', // Die Startseite ist die Wurzel ('/')
      routes: {
        '/': (context) => const PublicLandingPage(),
        '/auth': (context) => const AuthGate(),
        '/profile': (context) => const ProfilePage(),
        '/edit_profile': (context) => const EditProfilePage(),
      },

      // Diese spezielle Funktion wird aufgerufen, wenn ein Link nicht exakt
      // auf eine der oben genannten Routen passt.
      onGenerateRoute: (settings) {
        // Wir prüfen, ob der Link mit unserem Sponsoring-Pattern übereinstimmt.
        if (settings.name != null && settings.name!.startsWith('/sponsorship/')) {
          // Wir extrahieren die ID aus dem Link (der Teil nach dem letzten '/')
          final sponsorshipId = settings.name!.split('/').last;

          // Wir erstellen die Sponsoring-Seite im Bearbeitungsmodus.
          // WICHTIG: Die runnerId ist im Link nicht enthalten, daher müssen wir sie
          // innerhalb der SponsoringPage aus der Datenbank nachladen.
          return MaterialPageRoute(
            builder: (context) => SponsoringPage(sponsorshipId: sponsorshipId, runnerId: ''),
          );
        }
        
        // Wenn die URL unbekannt ist, machen wir nichts.
        return null;
      },
    );
  }
}