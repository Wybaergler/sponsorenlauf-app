import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
// WICHTIG: AuthGate-Import wird entfernt
import 'package:sponsorenlauf_app/navigation/route_arguments.dart';
import 'package:sponsorenlauf_app/admin/admin_dashboard_page.dart';
import 'package:sponsorenlauf_app/pages/edit_profile_page.dart';
import 'package:sponsorenlauf_app/pages/runner_dashboard_page.dart';
import 'package:sponsorenlauf_app/pages/public_landing_page.dart';
import 'package:sponsorenlauf_app/pages/sponsoring_page.dart';
import 'package:sponsorenlauf_app/theme/app_theme.dart';
import 'firebase_options.dart';
import 'package:sponsorenlauf_app/auth/login_or_register.dart'; // WICHTIGER NEUER IMPORT

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

      // Die Routenkarte wird vereinfacht
      initialRoute: PublicLandingPage.routeName,
      routes: {
        PublicLandingPage.routeName: (context) => const PublicLandingPage(),
        LoginOrRegister.routeName: (context) => const LoginOrRegister(), // NEUE ROUTE
        RunnerDashboardPage.routeName: (context) => const RunnerDashboardPage(),
        EditProfilePage.routeName: (context) => const EditProfilePage(),
        AdminDashboardPage.routeName: (context) => const AdminDashboardPage(),
      },

      onGenerateRoute: (settings) {
        if (settings.name == SponsoringPage.routeName) {
          final args = settings.arguments as SponsoringPageArguments;
          return MaterialPageRoute(
            builder: (context) {
              return SponsoringPage(
                runnerId: args.runnerId,
                sponsorshipId: args.sponsorshipId,
              );
            },
          );
        }
        assert(false, 'Need to implement ${settings.name}');
        return null;
      },
    );
  }
}