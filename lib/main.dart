import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'auth/auth_gate.dart';
import 'theme/app_theme.dart';

import 'package:sponsorenlauf_app/pages/public_landing_page.dart';
import 'package:sponsorenlauf_app/auth/login_or_register.dart';
import 'package:sponsorenlauf_app/pages/runner_dashboard_page.dart';
import 'package:sponsorenlauf_app/pages/edit_profile_page.dart';
import 'package:sponsorenlauf_app/admin/admin_dashboard_page.dart';
import 'package:sponsorenlauf_app/pages/sponsoring_page.dart';
import 'package:sponsorenlauf_app/navigation/route_arguments.dart';

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

      // AuthGate entscheidet: eingeloggt -> RunnerDashboard, sonst -> PublicLanding
      home: const AuthGate(),

      routes: {
        LoginOrRegister.routeName: (context) => const LoginOrRegister(),
        RunnerDashboardPage.routeName: (context) => const RunnerDashboardPage(),
        '/public': (context) => const PublicLandingPage(),
        EditProfilePage.routeName: (context) => const EditProfilePage(),
        AdminDashboardPage.routeName: (context) => const AdminDashboardPage(),
      },

      onGenerateRoute: (settings) {
        if (settings.name == SponsoringPage.routeName) {
          final args = settings.arguments as SponsoringPageArguments;
          return MaterialPageRoute(
            builder: (context) => SponsoringPage(
              runnerId: args.runnerId,
              sponsorshipId: args.sponsorshipId,
            ),
          );
        }
        assert(false, 'Need to implement ${settings.name}');
        return null;
      },
    );
  }
}
