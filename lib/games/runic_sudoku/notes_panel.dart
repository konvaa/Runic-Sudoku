import 'package:flutter/material.dart';

/// Action row controlling notes/candidates mode plus the check & hint helpers.
///
/// Candidate marks themselves are rendered inside the board cells; this panel
/// only toggles the mode and exposes the assist actions.
class NotesPanel extends StatelessWidget {
  final bool notesMode;
  final VoidCallback onToggleNotes;
  final VoidCallback onCheck;
  final VoidCallback onHint;

  const NotesPanel({
    super.key,
    required this.notesMode,
    required this.onToggleNotes,
    required this.onCheck,
    required this.onHint,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ActionChip(
          icon: notesMode ? Icons.edit_note : Icons.edit_off,
          label: notesMode ? 'Notes: On' : 'Notes: Off',
          selected: notesMode,
          onTap: onToggleNotes,
        ),
        _ActionChip(
          icon: Icons.fact_check_outlined,
          label: 'Check',
          onTap: onCheck,
        ),
        _ActionChip(
          icon: Icons.lightbulb_outline,
          label: 'Hint',
          onTap: onHint,
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 18,
        color: selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
      ),
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}
