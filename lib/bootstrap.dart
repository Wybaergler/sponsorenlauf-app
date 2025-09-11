import 'package:firebase_core/firebase_core.dart';
import 'app_flavor.dart';
import 'firebase_options_dev.dart' as dev;
import 'firebase_options_prod.dart' as prod;

Future<void> initFirebase() async {
  final flavor = currentFlavor();
  final opts = (flavor == AppFlavor.dev)
      ? dev.DefaultFirebaseOptions.currentPlatform
      : prod.DefaultFirebaseOptions.currentPlatform;
  await Firebase.initializeApp(options: opts);
}