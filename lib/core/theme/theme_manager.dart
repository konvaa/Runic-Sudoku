import 'package:flutter/material.dart';

import 'rune_set.dart';
import 'theme_record.dart';

/// Holds the active theme and resolves symbol sets by id.
///
/// A simple [ChangeNotifier] (no DI framework). It deliberately contains NO
/// sudoku rules — it does not know or care how many symbols a game needs. It
/// only maps `symbolSetId -> SymbolSet`.
class ThemeManager extends ChangeNotifier {
  final List<ThemeRecord> available;
  final Map<String, SymbolSet> _symbolSets;
  ThemeRecord _current;

  ThemeManager({
    List<ThemeRecord>? available,
    List<SymbolSet>? symbolSets,
    ThemeRecord? initial,
  })  : available = available ?? AppThemes.all,
        _symbolSets = {
          for (final s in (symbolSets ?? const [defaultRuneSet, numericSet]))
            s.id: s,
        },
        _current = initial ?? (available ?? AppThemes.all).first;

  ThemeRecord get current => _current;

  /// The symbol set referenced by the active theme. Falls back to the default
  /// rune set if the id is unknown (so the app never crashes on a bad id).
  SymbolSet get currentSymbolSet =>
      _symbolSets[_current.symbolSetId] ?? defaultRuneSet;

  SymbolSet? symbolSetById(String id) => _symbolSets[id];

  void selectTheme(String id) {
    final match = available.where((t) => t.id == id);
    if (match.isEmpty || match.first.id == _current.id) return;
    _current = match.first;
    notifyListeners();
  }

  void toggleBrightness() {
    final target = _current.brightness == Brightness.light
        ? Brightness.dark
        : Brightness.light;
    final match = available.where((t) => t.brightness == target);
    if (match.isNotEmpty) {
      _current = match.first;
      notifyListeners();
    }
  }
}
