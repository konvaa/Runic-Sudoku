import 'package:flutter/material.dart';

import '../games/runic_sudoku/runic_sudoku_rules.dart';

/// Shows the informational "How to Play" modal (Phase: UX fix 4).
///
/// Purely informational — a few swipeable cards, no interactive tutorial, no game
/// state touched. Dark modal styled to match the in-game HUD (black @ 0.85 + gold
/// outline, light text, gold titles). Scrolls per-card so it fits small phones.
Future<void> showHowToPlayDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (_) => const _HowToPlayDialog(),
  );
}

class _HowToPlayCard {
  final IconData icon;
  final String title;
  final String body;
  const _HowToPlayCard(this.icon, this.title, this.body);
}

const List<_HowToPlayCard> _cards = [
  _HowToPlayCard(
    Icons.grid_4x4,
    'One rune per row, column and box',
    // Rune count is templated from the Chapter 1 constant (not a literal) so
    // the copy can become chapter-aware later. Rendered text is unchanged.
    'Place each of the ${RunicSudokuRules.chapter1RuneCount} rune symbols '
        'exactly once in every row, column, and carved section. Logic only — '
        'no guessing needed.',
  ),
  _HowToPlayCard(
    Icons.touch_app_outlined,
    'Tap to play',
    'Tap a cell to select it, then tap a rune to place it. Use Notes mode to '
        'mark candidates. Tap a filled cell again to clear it.',
  ),
  _HowToPlayCard(
    Icons.lightbulb_outline,
    'Check & Hints',
    'Check reveals mistakes — your first Check per puzzle is free. Need a '
        'nudge? Hint shows your next logical step. Both are optional and never '
        'forced.',
  ),
  _HowToPlayCard(
    Icons.shield_outlined,
    'No tricks. Just puzzles.',
    'No energy bars. No lives. Ads appear only between levels, never during '
        'play. Remove Ads is available as a one-time purchase.',
  ),
];

class _HowToPlayDialog extends StatefulWidget {
  const _HowToPlayDialog();

  @override
  State<_HowToPlayDialog> createState() => _HowToPlayDialogState();
}

class _HowToPlayDialogState extends State<_HowToPlayDialog> {
  static const Color _gold = Color(0xFFE0A94A);
  static const Color _onGold = Color(0xFF120E08);

  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _page == _cards.length - 1;

  void _go(int page) => _controller.animateToPage(
        page,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Bounded card area so the PageView has a height but never overflows a 6".
    final cardHeight = (size.height * 0.42).clamp(220.0, 360.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _gold.withValues(alpha: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'How to Play',
              style: TextStyle(
                color: _gold,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: cardHeight,
              child: PageView.builder(
                controller: _controller,
                itemCount: _cards.length,
                onPageChanged: (p) => setState(() => _page = p),
                itemBuilder: (context, i) => _CardView(card: _cards[i]),
              ),
            ),
            const SizedBox(height: 8),
            _Dots(count: _cards.length, index: _page, color: _gold),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: _page > 0 ? () => _go(_page - 1) : null,
                  icon: const Icon(Icons.arrow_back),
                  color: _gold,
                  disabledColor: _gold.withValues(alpha: 0.25),
                  tooltip: 'Previous',
                ),
                const Spacer(),
                if (_isLast)
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: _onGold,
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Got it!'),
                  )
                else
                  IconButton(
                    onPressed: () => _go(_page + 1),
                    icon: const Icon(Icons.arrow_forward),
                    color: _gold,
                    tooltip: 'Next',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CardView extends StatelessWidget {
  final _HowToPlayCard card;
  const _CardView({required this.card});

  static const Color _gold = Color(0xFFE0A94A);
  static const Color _light = Color(0xFFF2EAD8);

  @override
  Widget build(BuildContext context) {
    // Scrollable so long copy never overflows the fixed card height on small
    // screens.
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(card.icon, size: 52, color: _gold),
          const SizedBox(height: 16),
          Text(
            card.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _gold,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            card.body,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _light.withValues(alpha: 0.92),
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int index;
  final Color color;
  const _Dots({required this.count, required this.index, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == index ? 10 : 7,
            height: i == index ? 10 : 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == index ? color : color.withValues(alpha: 0.3),
            ),
          ),
      ],
    );
  }
}
