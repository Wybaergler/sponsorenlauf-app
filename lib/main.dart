import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

// WICHTIG: getrennte Optionen pro Flavor
import 'firebase_options_dev.dart' as dev_options;
import 'firebase_options_prod.dart' as prod_options;

import 'auth/auth_gate.dart';
import 'theme/app_theme.dart';
import 'auth/login_or_register.dart';
import 'pages/public_landing_page.dart';
import 'pages/runner_dashboard_page.dart';
import 'pages/edit_profile_page.dart';
import 'admin/admin_dashboard_page.dart';
import 'pages/sponsoring_page.dart';
import 'navigation/route_arguments.dart';
import 'widgets/flavor_banner.dart';

const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'prod');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: flavor == 'dev'
        ? dev_options.DefaultFirebaseOptions.currentPlatform
        : prod_options.DefaultFirebaseOptions.currentPlatform,
  );

  await FirebaseAppCheck.instance.activate(
    webProvider: ReCaptchaV3Provider(
      // falls du für PROD einen anderen Key hast, hier per Flavor trennen
      flavor == 'dev'
          ? '6Len3cErAAAAAC3lF-dInttqgYAgMWg5WIWSl9as'
          : '6Len3cErAAAAAC3lF-dInttqgYAgMWg5WIWSl9as',
    ),
    androidProvider: AndroidProvider.playIntegrity,
    appleProvider: AppleProvider.deviceCheck,
  );

  if (kDebugMode) {
    // kurze Kontrolle im Log
    debugPrint('🔥 FLAVOR: $flavor');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FlavorBanner(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Sponsorenlauf App',
        theme: AppTheme.theme,
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
      ),
    );
  }
}