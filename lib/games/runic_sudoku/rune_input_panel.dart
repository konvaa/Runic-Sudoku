import 'package:flutter/material.dart';

import '../../core/theme/rune_set.dart';

// Dark fantasy palette for the input "rune coins" (Phase 3.60).
const Color _runeFill = Color(0xFF1A1208); // very dark brown
const Color _runeGold = Color(0xFFE0A94A);

/// Row of value buttons (rendered using the active [SymbolSet]) plus an erase
/// button. Emits the 1-based value the player tapped.
class RuneInputPanel extends StatelessWidget {
  final SymbolSet symbolSet;

  /// How many values are selectable (e.g. 6 for 6x6).
  final int count;
  final ValueChanged<int> onValue;
  final VoidCallback onErase;

  /// Clears the whole player solution (with confirmation, handled by the
  /// caller). Null hides the Reset button — e.g. once the puzzle is solved.
  final VoidCallback? onReset;

  const RuneInputPanel({
    super.key,
    required this.symbolSet,
    required this.count,
    required this.onValue,
    required this.onErase,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var v = 1; v <= count; v++)
          _RuneButton(
            label: symbolSet.forValue(v).glyph,
            semanticLabel: symbolSet.forValue(v).accessibilityLabel,
            onTap: () => onValue(v),
          ),
        Semantics(
          label: 'Erase',
          button: true,
          child: OutlinedButton(
            onPressed: onErase,
            style: _circleButtonStyle,
            child: const Icon(Icons.backspace_outlined),
          ),
        ),
        // Reset: same look as Erase, only a different icon. Clears the whole
        // solution (with confirmation). Hidden when [onReset] is null.
        if (onReset != null)
          Semantics(
            label: 'Reset board',
            button: true,
            child: OutlinedButton(
              onPressed: onReset,
              style: _circleButtonStyle,
              child: const Icon(Icons.refresh),
            ),
          ),
      ],
    );
  }

  static final ButtonStyle _circleButtonStyle = OutlinedButton.styleFrom(
    minimumSize: const Size(52, 52),
    padding: EdgeInsets.zero,
    foregroundColor: _runeGold,
    side: const BorderSide(color: _runeGold),
    shape: const CircleBorder(),
  );
}

class _RuneButton extends StatelessWidget {
  final String label;
  final String semanticLabel;
  final VoidCallback onTap;

  const _RuneButton({
    required this.label,
    required this.semanticLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: SizedBox(
        width: 52,
        height: 52,
        child: FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            padding: EdgeInsets.zero,
            backgroundColor: _runeFill,
            foregroundColor: _runeGold,
            shape: const CircleBorder(),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
