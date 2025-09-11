import 'package:flutter/material.dart';

class FlavorBanner extends StatelessWidget {
  final Widget child;

  const FlavorBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    const flavor = String.fromEnvironment('FLAVOR');

    if (flavor == 'dev') {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Banner(
          message: "DEV",
          location: BannerLocation.topStart,
          color: Colors.red,
          child: child,
        ),
      );
    }

    // Für prod oder andere Flavors nur das normale child zurückgeben
    return child;
  }
}
