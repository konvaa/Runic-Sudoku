import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show compute, visibleForTesting;

import '../../../core/profile/app_controller.dart';
import '../../../core/save/local_save_repository.dart' show SaveStore;
import '../board_config.dart';
import '../generator/level_data.dart';
import '../generator/puzzle_generator.dart';
import '../solver/difficulty_constants.dart';
import 'deep_pool.dart';

/// Top-level isolate entry: generate one guarded Deep puzzle for the board
/// described by [boardJson] (a `BoardConfig.toJson()` map). Returns its level
/// JSON, or null if generation failed. Runs via [compute] so it never touches
/// the UI thread.
Map<String, dynamic>? generateOneDeepLevelJson(Map<String, dynamic> boardJson) {
  try {
    final r = PuzzleGenerator(board: BoardConfig.fromJson(boardJson)).generate(
      target: DifficultyLabel.deep,
      maxAttempts: 1500,
      freePlay: true,
    );
    return r.level.toJson();
  } on StateError {
    return null;
  }
}

/// Two-layer supply of Deep Free Play puzzles (Phase 3.66.1):
///
///  1. A read-only **bundled pool** shipped in the app (always available).
///  2. A **rolling cache** of background-generated puzzles persisted in the
///     [SaveStore]. Consumed first; refilled on a background isolate when the
///     player is NOT in an active game.
///
/// Deep is never generated on-demand at tap time (its guarded P95 is seconds on
/// low-end devices) — [nextPuzzle] only reads the cache/pool, so it is instant.
class DeepFreePlayCache {
  static const int maxCacheSize = 15;

  /// Persisted key of the rolling cache for [BoardConfig.sixBySix] — the only
  /// board shipped today. Must equal `cacheKeyFor(BoardConfig.sixBySix)`.
  static const String cacheKey = 'deep_freeplay_cache_6x6';

  /// Persisted rolling-cache key for [board], namespaced per board config so a
  /// future second board never interleaves into another board's cache.
  static String cacheKeyFor(BoardConfig board) =>
      'deep_freeplay_cache_${board.dimensions.toToken()}';

  /// The pre-chapter-system, unnamespaced key. Its contents are treated as
  /// orphaned (NOT migrated): the rolling cache is regenerable supply, not
  /// player progress — the bundled pool still serves Deep instantly while the
  /// namespaced cache refills. [load] removes the stale entry once.
  static const String legacyCacheKey = 'deep_freeplay_cache';

  final SaveStore store;
  final AppController appController;
  final List<DeepPuzzleEntry> bundledPool;

  /// The board this cache serves. Defaults to Chapter 1's 6×6 board so the
  /// existing wiring (and tests) stay unchanged.
  final BoardConfig board;

  final Future<Map<String, dynamic>?> Function() _generate;
  final Random _rng;

  final List<DeepPuzzleEntry> _cache = [];
  bool _loaded = false;
  bool _refilling = false; // a refill loop is currently active
  bool _paused = false; // gameplay active → do not refill
  Future<void>? _refillTask;

  DeepFreePlayCache({
    required this.store,
    required this.appController,
    required this.bundledPool,
    this.board = BoardConfig.sixBySix,
    Future<Map<String, dynamic>?> Function()? generate,
    Random? rng,
  })  : _generate = generate ??
            (() => compute(generateOneDeepLevelJson, board.toJson())),
        _rng = rng ?? Random();

  /// This instance's persisted cache key (namespaced by [board]).
  String get storeKey => cacheKeyFor(board);

  /// Loads the persisted cache from the store. Safe to call repeatedly.
  Future<void> load() async {
    if (_loaded) return;
    // One-time cleanup of the pre-namespacing key (orphaned, regenerable data;
    // removing a missing key is a no-op).
    await store.remove(legacyCacheKey);
    final raw = await store.get(storeKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        _cache
          ..clear()
          ..addAll([
            for (final e in list)
              DeepPuzzleEntry.fromJson(e as Map<String, dynamic>),
          ]);
      } catch (_) {
        // Corrupt cache: start empty (the bundled pool still serves puzzles).
        _cache.clear();
      }
    }
    _loaded = true;
  }

  bool get hasCache => _cache.isNotEmpty;
  int get cacheSize => _cache.length;

  /// Background refill task (for tests to await).
  @visibleForTesting
  Future<void>? get refillTask => _refillTask;

  /// Returns the next Deep puzzle, marking it as seen. Priority: rolling cache
  /// (consumed), then the bundled pool (preferring unseen, else cycling). Null
  /// only if BOTH layers are empty (should not happen with a shipped pool).
  Future<DeepPuzzleEntry?> nextPuzzle() async {
    await load();
    final used = appController.deepUsedIds;

    // 1. Rolling cache has priority. Prefer an unseen one, else take the first.
    if (_cache.isNotEmpty) {
      var idx = _cache.indexWhere((e) => !used.contains(e.puzzleId));
      if (idx < 0) idx = 0;
      final entry = _cache.removeAt(idx);
      await _persistCache();
      await appController.markDeepUsed(entry.puzzleId);
      return entry;
    }

    // 2. Bundled pool. Prefer unseen; if all seen, cycle a random one.
    if (bundledPool.isNotEmpty) {
      final unseen = [
        for (final e in bundledPool)
          if (!used.contains(e.puzzleId)) e,
      ];
      final pick = unseen.isNotEmpty
          ? unseen[_rng.nextInt(unseen.length)]
          : bundledPool[_rng.nextInt(bundledPool.length)];
      await appController.markDeepUsed(pick.puzzleId);
      return pick;
    }

    // 3. Nothing available.
    return null;
  }

  /// Starts background refilling if not already running and the cache is below
  /// [maxCacheSize]. Called when leaving gameplay (level complete / app pause) or
  /// from the Free Play entry. No-op while paused or already filling.
  void startRefill() {
    _paused = false;
    if (_refilling) return;
    if (bundledPool.isEmpty && _cache.length >= maxCacheSize) return;
    if (_cache.length >= maxCacheSize) return;
    _refilling = true;
    _refillTask = _runRefill();
  }

  /// Stops background refilling (called when a puzzle starts / app pauses). Any
  /// in-flight isolate result is discarded — generation cannot be hard-killed, so
  /// the current puzzle completes then is dropped, and no further work is queued.
  void stopRefill() {
    _refilling = false;
    _paused = true;
  }

  /// Stop after this many consecutive misses (generation failures or duplicate
  /// patterns) so a degenerate generator can never spin the loop forever.
  static const int _maxConsecutiveMisses = 60;

  Future<void> _runRefill() async {
    await load();
    var misses = 0;
    while (_refilling &&
        !_paused &&
        _cache.length < maxCacheSize &&
        misses < _maxConsecutiveMisses) {
      final json = await _generate();
      if (!_refilling || _paused) break; // cancelled mid-flight: discard result
      if (json == null) {
        misses++;
        continue; // generation failed: try again (bounded)
      }
      final data = LevelData.fromJson(json);
      final id = deepIdFromGiven(data.givenCells);
      final dup = _cache.any((e) => e.puzzleId == id) ||
          bundledPool.any((e) => e.puzzleId == id);
      if (dup) {
        misses++;
        continue;
      }
      misses = 0;
      _cache.add(DeepPuzzleEntry(puzzleId: id, data: data));
      await _persistCache();
    }
    _refilling = false;
  }

  Future<void> _persistCache() async {
    await store.put(
      storeKey,
      jsonEncode([for (final e in _cache) e.toJson()]),
    );
  }
}
