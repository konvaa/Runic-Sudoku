import 'dart:math';

import 'package:flutter/material.dart';

import '../games/runic_sudoku/chapter_theme.dart';
import '../games/runic_sudoku/progression.dart';
import 'app.dart';

/// Campaign level select: chapters with lock/unlock state, completion, and the
/// current "next" level highlighted. Daily puzzle is a separate main-menu entry.
///
/// Unlock state is read LIVE from the player's completed set via
/// [Progression] (so it can never drift from a cached set). The screen rebuilds
/// reactively on profile changes via the [AnimatedBuilder] AND force-refreshes
/// when returning from a level, so a freshly-unlocked chapter/level is always
/// reflected in the current run (Phase 3.5 bug 2 fix).
class LevelSelectScreen extends StatefulWidget {
  final AppServices services;

  const LevelSelectScreen({super.key, required this.services});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  AppServices get services => widget.services;

  Future<void> _openLevel(String levelId) async {
    final puzzle = services.levelPool.byId(levelId);
    if (puzzle == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => services.puzzleScreen(puzzle)),
    );
    // Returning from a (possibly completed) level: re-read unlock/next state.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rune Trials')),
      // The campaign list spans all chapters, so use the neutral background.
      body: ChapterBackground(
        assetPath: ChapterBackgrounds.neutral,
        overlayOpacity: 0.6,
        child: SafeArea(
          child: AnimatedBuilder(
            animation: services.appController,
            builder: (context, _) => _buildList(context),
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final progression = services.progression;
    final pc = services.progressionController;
    final children = <Widget>[];

    for (final chapter in progression.chapters) {
      final unlocked = pc.isChapterUnlocked(chapter.id);
      children.add(_ChapterHeader(
        chapter: chapter,
        unlocked: unlocked,
        completed: pc.completedInChapter(chapter),
      ));

      if (!unlocked) {
        final reason = progression
            .levelsById[chapter.levelIds.first]?.unlockRequirement;
        children.add(_LockedChapterRow(reason: reason));
        continue;
      }

      for (final levelId in chapter.levelIds) {
        children.add(_LevelTile(
          services: services,
          levelId: levelId,
          onOpen: () => _openLevel(levelId),
        ));
      }
    }

    return ListView(padding: const EdgeInsets.all(16), children: children);
  }
}

class _ChapterHeader extends StatelessWidget {
  final ChapterMeta chapter;
  final bool unlocked;
  final int completed;

  const _ChapterHeader({
    required this.chapter,
    required this.unlocked,
    required this.completed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 6, left: 4),
      child: Row(
        children: [
          if (!unlocked)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(Icons.lock, size: 18, color: scheme.outline),
            ),
          Expanded(
            child: Text(
              chapter.displayName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: unlocked ? scheme.primary : scheme.outline,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Text('$completed/${chapter.size}',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _LockedChapterRow extends StatelessWidget {
  final String? reason;
  const _LockedChapterRow({this.reason});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.lock_outline),
        title: const Text('Locked'),
        subtitle: Text(reason ?? 'Complete earlier levels to unlock.'),
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  final AppServices services;
  final String levelId;
  final VoidCallback onOpen;

  const _LevelTile({
    required this.services,
    required this.levelId,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pc = services.progressionController;
    final meta = services.progression.levelsById[levelId]!;
    final completed = pc.isCompleted(levelId);
    final unlocked = pc.isLevelUnlocked(levelId);
    final isNext = pc.isNext(levelId);
    // Show at least 1 min so sub-60s levels don't read "~0 min".
    final estMinutes = max(1, (meta.estimatedSolveTime.inSeconds / 60).round());

    final Widget leading;
    if (completed) {
      leading = Icon(Icons.check_circle, color: scheme.primary);
    } else if (!unlocked) {
      leading = Icon(Icons.lock, color: scheme.outline);
    } else {
      leading = Icon(
        isNext ? Icons.play_circle_fill : Icons.radio_button_unchecked,
        color: isNext ? scheme.primary : scheme.outline,
      );
    }

    return Card(
      shape: isNext
          ? RoundedRectangleBorder(
              side: BorderSide(color: scheme.primary, width: 2),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: ListTile(
        leading: leading,
        title: Text('${meta.difficultyLabel} ${meta.levelOrder}'),
        subtitle: Text('~$estMinutes min'),
        trailing: isNext
            ? const Chip(label: Text('Next'))
            : (unlocked ? const Icon(Icons.chevron_right) : null),
        onTap: () {
          if (unlocked) {
            onOpen();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(meta.unlockRequirement)),
            );
          }
        },
      ),
    );
  }
}
