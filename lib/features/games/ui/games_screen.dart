import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../home/emergency_screen.dart';
import '../models/game_definition.dart';
import 'games/color_zones/color_zones_game.dart';
import 'games/focus_point/focus_point_game.dart';
import 'games/soft_memory/soft_memory_game.dart';
import 'games/zen_garden/zen_garden_game.dart';
import 'games/constellations/constellations_game.dart';
import 'games/thought_bubbles/thought_bubbles_game.dart';

class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  static const Color _bg = Color(0xFF0B0E17);
  static const Color _cardColor = Color(0xFF161B26);
  static const Color _muted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'sos_games',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const EmergencyScreen(),
          ),
        ),
        backgroundColor: const Color(0xFF7B1A1A),
        child: const Icon(
          Icons.emergency_outlined,
          color: Colors.white,
          size: 18,
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Manual back button + title
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 24, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white70,
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Volver',
                  ),
                  Expanded(
                    child: Text(
                      'Ejercicios para la mente',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 20),
              child: Text(
                'Sin puntuación. Sin presión. Solo estar.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _muted,
                ),
              ),
            ),

            // Game list
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: GameDefinition.all.length,
                separatorBuilder: (context, i) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final game = GameDefinition.all[index];
                  return _GameCard(
                    game: game,
                    onTap: () => _handleTap(context, game),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleTap(BuildContext context, GameDefinition game) {
    if (game.id == 'color_zones') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const ColorZonesGame()));
      return;
    }

    if (game.id == 'focus_point') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const FocusPointGame()));
      return;
    }

    if (game.id == 'soft_memory') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const SoftMemoryGame()));
      return;
    }

    if (game.id == 'zen_garden') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const ZenGardenGame()));
      return;
    }

    if (game.id == 'thought_bubbles') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ThoughtBubblesGame()),
      );
      return;
    }

    if (game.id == 'constellations') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ConstellationsGame()),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Próximamente',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: _cardColor,
      ),
    );
  }
}

// ─── Game card ────────────────────────────────────────────────────────────────

class _GameCard extends StatelessWidget {
  const _GameCard({required this.game, required this.onTap});

  final GameDefinition game;
  final VoidCallback onTap;

  static const Color _cardColor = Color(0xFF161B26);
  static const Color _accent = Color(0xFF3ECF8E);
  static const Color _muted = Color(0xFF6B7280);

  Color get _chipColor {
    switch (game.emotionalTarget) {
      case EmotionalTarget.anxiety:
        return const Color(0xFFAA96C8); // lavender
      case EmotionalTarget.mood:
        return const Color(0xFF8BAF92); // sage
      case EmotionalTarget.focus:
        return const Color(0xFF8BB4C8); // sky
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon box
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(game.icon, color: _accent, size: 22),
              ),
              const SizedBox(width: 16),

              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      game.description,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _muted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _EmotionalChip(
                      label: game.emotionalTarget.label,
                      color: _chipColor,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Colors.white.withValues(alpha: 0.25),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmotionalChip extends StatelessWidget {
  const _EmotionalChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
