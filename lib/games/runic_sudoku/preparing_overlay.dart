import 'package:flutter/material.dart';

/// Full-screen dark overlay shown while a Free Play puzzle is being generated
/// off the UI thread (Phase 3.66). No progress bar — generation length is not
/// known in advance — just an indeterminate spinner and a short label, over the
/// same dark panel style used by the in-game HUD.
class PreparingOverlay extends StatelessWidget {
  const PreparingOverlay({super.key});

  static const Color _gold = Color(0xFFE0A94A);
  static const Color _light = Color(0xFFF2EAD8);

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.8),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(_gold),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Preparing your trial…',
                style: TextStyle(
                  color: _light,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
