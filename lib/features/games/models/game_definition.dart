import 'package:flutter/material.dart';

enum EmotionalTarget { anxiety, mood, focus }

extension EmotionalTargetLabel on EmotionalTarget {
  String get label {
    switch (this) {
      case EmotionalTarget.anxiety:
        return 'Ansiedad';
      case EmotionalTarget.mood:
        return 'Estado de ánimo';
      case EmotionalTarget.focus:
        return 'Enfoque';
    }
  }
}

class GameDefinition {
  const GameDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.emotionalTarget,
    required this.icon,
  });

  final String id;
  final String title;
  final String description;
  final EmotionalTarget emotionalTarget;
  final IconData icon;

  static const List<GameDefinition> all = [
    GameDefinition(
      id: 'zen_garden',
      title: 'Jardín Zen',
      description: 'Traza caminos entre las piedras. Tu ritmo, tu patrón.',
      emotionalTarget: EmotionalTarget.anxiety,
      icon: Icons.spa_outlined,
    ),
    GameDefinition(
      id: 'color_zones',
      title: 'Colorear por zonas',
      description: 'Toca las zonas para colorearlas. Sin objetivo, sin tiempo.',
      emotionalTarget: EmotionalTarget.mood,
      icon: Icons.palette_outlined,
    ),
    GameDefinition(
      id: 'focus_point',
      title: 'Punto de enfoque',
      description: 'Sigue el punto con tu dedo. Respira.',
      emotionalTarget: EmotionalTarget.anxiety,
      icon: Icons.radio_button_checked,
    ),
    GameDefinition(
      id: 'soft_memory',
      title: 'Memoria suave',
      description: 'Repite la secuencia de colores. Sin prisa.',
      emotionalTarget: EmotionalTarget.focus,
      icon: Icons.grid_view_rounded,
    ),
    GameDefinition(
      id: 'thought_bubbles',
      title: 'Burbujas',
      description: 'Toca las burbujas para dejarlas ir.',
      emotionalTarget: EmotionalTarget.mood,
      icon: Icons.bubble_chart_outlined,
    ),
    GameDefinition(
      id: 'constellations',
      title: 'Constelaciones',
      description: 'Une las estrellas y descubre las historias del cielo.',
      emotionalTarget: EmotionalTarget.focus,
      icon: Icons.star_outline_rounded,
    ),
  ];
}
