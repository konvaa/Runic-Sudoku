// ============================================================================
// DEV-ONLY ENTRYPOINT for the 12×12 UX prototype spike.
//
//   flutter run -t lib/dev/main_dev_12x12.dart
//
// Deliberately a SEPARATE compile target: it is never imported by lib/main.dart
// or any production route/menu, so the prototype is structurally unreachable
// from the shipped app. Refuses to show the prototype in release builds as a
// second guard. Branch: spike/12x12-ux-prototype (throwaway).
// ============================================================================

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';

import 'dev_12x12_prototype_screen.dart';

void main() => runApp(const Dev12x12PrototypeApp());

class Dev12x12PrototypeApp extends StatelessWidget {
  const Dev12x12PrototypeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '12x12 UX Prototype (dev)',
      debugShowCheckedModeBanner: false,
      // Dark scheme approximating the game's look, so contrast/legibility
      // findings transfer to the real product.
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8D6E63),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: kReleaseMode
          ? const Scaffold(
              body: Center(
                child: Text('Dev prototype — not available in release builds.'),
              ),
            )
          : const Dev12x12PrototypeScreen(),
    );
  }
}
