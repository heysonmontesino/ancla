import 'dart:math' as math;

import 'package:flutter/material.dart';

// ─── Background star field (seed-fixed, never changes on rebuild) ─────────────

class BackgroundStar {
  const BackgroundStar({
    required this.x,
    required this.y,
    required this.opacity,
    required this.radius,
  });

  final double x;       // 0.0–1.0 normalized
  final double y;       // 0.0–1.0 normalized
  final double opacity; // 0.10–0.30
  final double radius;  // 0.5–1.5 px
}

List<BackgroundStar> generateBackgroundStars() {
  final rng = math.Random(42);
  return List.generate(200, (_) {
    return BackgroundStar(
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      opacity: 0.10 + rng.nextDouble() * 0.20,
      radius: 0.5 + rng.nextDouble() * 1.0,
    );
  });
}

// ─── Constellation data ───────────────────────────────────────────────────────

class ConstellationData {
  const ConstellationData({
    required this.name,
    required this.historia,
    required this.color,
    required this.stars,
  });

  final String name;
  final String historia;
  final Color color;

  /// Star positions, normalized 0.0–1.0.
  /// Lines connect stars[i] → stars[i+1] for each correct tap.
  final List<Offset> stars;

  int get starCount => stars.length;
}

// ─── The 8 constellations ─────────────────────────────────────────────────────

const List<ConstellationData> kConstellations = [
  // 1 — Orión (7 estrellas) — gold
  ConstellationData(
    name: 'Orión',
    historia: 'El cazador del cielo de invierno',
    color: Color(0xFFC8A876),
    stars: [
      Offset(0.50, 0.14), // head
      Offset(0.34, 0.28), // left shoulder
      Offset(0.38, 0.48), // left belt
      Offset(0.50, 0.50), // center belt
      Offset(0.62, 0.48), // right belt
      Offset(0.66, 0.28), // right shoulder
      Offset(0.72, 0.78), // right foot (Rigel)
    ],
  ),

  // 2 — Casiopea (5 estrellas) — ice blue
  ConstellationData(
    name: 'Casiopea',
    historia: 'La reina etíope en el firmamento',
    color: Color(0xFF88B0C0),
    stars: [
      Offset(0.14, 0.54),
      Offset(0.32, 0.28),
      Offset(0.50, 0.46),
      Offset(0.68, 0.26),
      Offset(0.86, 0.52),
    ],
  ),

  // 3 — Cruz del Sur (4 estrellas) — soft white
  ConstellationData(
    name: 'Cruz del Sur',
    historia: 'Guía de los navegantes del sur',
    color: Color(0xFFD0D8E8),
    stars: [
      Offset(0.50, 0.18), // top (γ Crucis)
      Offset(0.22, 0.52), // left (δ Crucis)
      Offset(0.50, 0.82), // bottom (α Crucis)
      Offset(0.78, 0.52), // right (β Crucis)
    ],
  ),

  // 4 — Escorpio (8 estrellas) — coral
  ConstellationData(
    name: 'Escorpio',
    historia: 'El escorpión de los cielos de verano',
    color: Color(0xFFC88876),
    stars: [
      Offset(0.30, 0.18),
      Offset(0.38, 0.28),
      Offset(0.44, 0.38),
      Offset(0.50, 0.46),
      Offset(0.56, 0.54),
      Offset(0.60, 0.64),
      Offset(0.56, 0.74),
      Offset(0.48, 0.82),
    ],
  ),

  // 5 — Osa Mayor (7 estrellas) — sage
  ConstellationData(
    name: 'Osa Mayor',
    historia: 'La gran osa que guarda el norte',
    color: Color(0xFF8BAF92),
    stars: [
      Offset(0.22, 0.54),
      Offset(0.36, 0.44),
      Offset(0.50, 0.40),
      Offset(0.62, 0.44),
      Offset(0.70, 0.56),
      Offset(0.76, 0.68),
      Offset(0.80, 0.80),
    ],
  ),

  // 6 — Lyra (5 estrellas) — lavender
  ConstellationData(
    name: 'Lyra',
    historia: 'La lira del músico Orfeo',
    color: Color(0xFFAA96C8),
    stars: [
      Offset(0.50, 0.20), // Vega
      Offset(0.34, 0.42),
      Offset(0.40, 0.64),
      Offset(0.60, 0.64),
      Offset(0.66, 0.42),
    ],
  ),

  // 7 — Andrómeda (6 estrellas) — peach
  ConstellationData(
    name: 'Andrómeda',
    historia: 'La princesa encadenada en las estrellas',
    color: Color(0xFFD4A89A),
    stars: [
      Offset(0.22, 0.58),
      Offset(0.34, 0.50),
      Offset(0.46, 0.44),
      Offset(0.58, 0.38),
      Offset(0.68, 0.30),
      Offset(0.76, 0.22),
    ],
  ),

  // 8 — Leo (6 estrellas) — mint
  ConstellationData(
    name: 'Leo',
    historia: 'El león que anuncia la primavera',
    color: Color(0xFF8CC4B0),
    stars: [
      Offset(0.50, 0.22),
      Offset(0.34, 0.32),
      Offset(0.26, 0.48),
      Offset(0.36, 0.62),
      Offset(0.52, 0.64),
      Offset(0.66, 0.54),
    ],
  ),
];
