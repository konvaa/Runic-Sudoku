import 'package:flutter/material.dart';

import '../games/runic_sudoku/chapter_theme.dart';
import 'app.dart';
import 'routes.dart';

/// Title screen: Daily puzzle (with streak), Campaign, Settings.
///
/// Styled to match the game's dark fantasy look (stone background + gold runes)
/// so the menu feels like the same app as the level select / puzzle screens.
class MainMenuScreen extends StatelessWidget {
  final AppServices services;

  const MainMenuScreen({super.key, required this.services});

  // Direct colors (not a custom ThemeData) so the menu looks right regardless of
  // the global light/dark AppTheme — see PHASE359B_NOTES.md.
  static const Color _gold = Color(0xFFE0A94A);
  static const Color _onGold = Color(0xFF120E08);
  static const Color _light = Color(0xFFF2EAD8);
  static const Size _buttonSize = Size(220, 50);

  void _openDaily(BuildContext context) {
    final daily = services.levelPool.dailyFor(DateTime.now());
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => services.puzzleScreen(daily, isDaily: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final primaryStyle = FilledButton.styleFrom(
      backgroundColor: _gold,
      foregroundColor: _onGold,
      minimumSize: _buttonSize,
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
    );
    final outlineStyle = OutlinedButton.styleFrom(
      foregroundColor: _light,
      side: BorderSide(color: _light.withValues(alpha: 0.6)),
      minimumSize: _buttonSize,
    );

    return Scaffold(
      body: ChapterBackground(
        assetPath: ChapterBackgrounds.neutral,
        overlayOpacity: 0.55,
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'ᚱᚢᚾᛁᚲ',
                  style: theme.textTheme.displayMedium?.copyWith(color: _gold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Runic Sudoku',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: _light,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 48),
                // Streak rebuilds when the profile changes.
                AnimatedBuilder(
                  animation: services.appController,
                  builder: (context, _) {
                    final streak = services.appController.dailyStreak;
                    return Column(
                      children: [
                        FilledButton.icon(
                          style: primaryStyle,
                          onPressed: () => _openDaily(context),
                          icon: const Icon(Icons.today),
                          label: const Text('Daily Puzzle'),
                        ),
                        if (streak > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '🔥 $streak day streak',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: _gold),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  style: primaryStyle,
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoutes.levelSelect),
                  icon: const Icon(Icons.map),
                  label: const Text('Rune Trials'),
                ),
                const SizedBox(height: 14),
                // Free Play (Phase 3.66): unlocks after the Quick Runes chapter.
                AnimatedBuilder(
                  animation: services.appController,
                  builder: (context, _) {
                    final unlocked =
                        services.progressionController.freePlayUnlocked;
                    if (unlocked) {
                      return FilledButton.icon(
                        style: primaryStyle,
                        onPressed: () => Navigator.of(context)
                            .pushNamed(AppRoutes.freePlay),
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Free Play'),
                      );
                    }
                    return OutlinedButton.icon(
                      style: outlineStyle,
                      onPressed: () =>
                          ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Complete Quick Runes chapter to unlock'),
                        ),
                      ),
                      icon: const Icon(Icons.lock),
                      label: const Text('Free Play'),
                    );
                  },
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  style: outlineStyle,
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoutes.settings),
                  icon: const Icon(Icons.settings),
                  label: const Text('Settings'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
