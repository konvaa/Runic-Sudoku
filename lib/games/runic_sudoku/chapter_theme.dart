import 'package:flutter/material.dart';

import 'progression.dart';

/// Single source of truth for per-chapter background art (Phase 3.59).
///
/// Maps a chapter's difficulty label → bundled background asset. Selection lives
/// ONLY here; widgets ask via [forLabel] / [forLevel] rather than hardcoding
/// paths. Keying on the difficulty label (not the order-based chapter id) keeps
/// it stable if chapter ordering ever changes.
class ChapterBackgrounds {
  const ChapterBackgrounds._();

  static const String _dir = 'assets/backgrounds/';

  /// Neutral fallback (unknown chapter, or screens that span all chapters).
  static const String neutral = '${_dir}default_rune_bg.png';

  static const Map<String, String> _byLabel = {
    'Quick': '${_dir}quick_runes_bg.png',
    'Normal': '${_dir}normal_seals_bg.png',
    'Tricky': '${_dir}tricky_glyphs_bg.png',
    'Deep': '${_dir}deep_chambers_bg.png',
  };

  /// Background for a difficulty label; [neutral] if null/unknown.
  static String forLabel(String? label) => _byLabel[label] ?? neutral;

  /// Background for a specific level (resolved via its chapter). Falls back to
  /// [neutral] for levels not in the campaign (e.g. legacy manual puzzles).
  static String forLevel(Progression progression, String levelId) =>
      forLabel(progression.levelsById[levelId]?.difficultyLabel);

  /// All asset paths (for pubspec/bundling reference).
  static List<String> get allAssets => [..._byLabel.values, neutral];
}

/// Stacks a chapter background image, a dark readability overlay, then [child].
///
/// The overlay keeps the grid, rune input and UI legible over the art; its
/// opacity is adjustable (default ~0.55). A missing asset falls back to the
/// theme surface color so the screen never breaks.
class ChapterBackground extends StatelessWidget {
  final String assetPath;
  final Widget child;
  final double overlayOpacity;

  const ChapterBackground({
    super.key,
    required this.assetPath,
    required this.child,
    this.overlayOpacity = 0.55,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          assetPath,
          fit: BoxFit.cover,
          // Cache at a reasonable decode size; backgrounds don't need full res.
          errorBuilder: (_, __, ___) => ColoredBox(color: scheme.surface),
        ),
        ColoredBox(color: Colors.black.withValues(alpha: overlayOpacity)),
        child,
      ],
    );
  }
}
