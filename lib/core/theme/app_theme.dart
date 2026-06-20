import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme_record.dart';

/// Builds Flutter [ThemeData] from a [ThemeRecord]. Pure presentation glue.
class AppTheme {
  static ThemeData fromRecord(ThemeRecord record) {
    final scheme = ColorScheme.fromSeed(
      seedColor: record.seedColor,
      brightness: record.brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      // Dark AppBar across all screens (Phase 3.60) — the game sits on dark
      // fantasy backgrounds, so a light AppBar clashed. Light icons over it.
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0D0D0D),
        foregroundColor: Color(0xFFF2EAD8),
        centerTitle: true,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
    );
  }
}
