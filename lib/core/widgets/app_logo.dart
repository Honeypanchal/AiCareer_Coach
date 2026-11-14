import 'package:flutter/material.dart';

/// The PrepPilot paper-plane mark (white, transparent background).
/// Draw it on the purple gradient, like the app icon.
class AppLogoMark extends StatelessWidget {
  final double size;

  const AppLogoMark({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/logo/logo_mark.png',
      width: size,
      height: size,
      semanticLabel: 'PrepPilot logo',
      // Keeps the layout steady if the image ever fails to load.
      errorBuilder: (_, _, _) => SizedBox(width: size, height: size),
    );
  }
}
